import requests
import sys
from awsglue import DynamicFrame
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from itertools import chain
from pyspark import SparkConf
from pyspark.context import SparkContext
from pyspark.sql.functions import col, create_map, explode, lit, to_utc_timestamp

args = getResolvedOptions(sys.argv, ['DATA_LAKE_URL', 'JOB_NAME', 'REDSHIFT_CONNECTION'])
config = SparkConf().set('spark.rpc.message.maxSize', '256')
sc = SparkContext(conf=config)
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)
job_id = args['JOB_RUN_ID']

# TODO: Get this directly from Classifyr.
mapping = {
    'DOMESTIC VIOLENCE': 'DVA',
    'FIGHT': 'FIGHT',
    'LOUD NOISE DISTURBANCE': 'NEGLECT',
    'SUSPICIOUS PERSON': ' PERSUSP',
    'TRESPASSING': ' TRESPASS',
}

# Define the pre- and post-queries used by Redshift to perform an upsert.
pre_query = f"""
    DROP TABLE IF EXISTS public.{job_id};
    CREATE TABLE public.{job_id} AS SELECT * FROM public.call_data WHERE 1=2;
    """.strip()
post_query = f"""
    BEGIN;
    DELETE FROM public.call_data USING public.{job_id}
        WHERE public.{job_id}.call_id = public.call_data.call_id AND
              public.{job_id}.dataset = public.call_data.dataset;
    INSERT INTO public.call_data SELECT * FROM public.{job_id};
    DROP TABLE public.{job_id};
    END;""".strip()

# Request the full data set as JSON and read it into a dataframe.
record_count = 0
more_records = True
url = 'https://www.phoenixopendata.com/api/3/action/datastore_search_sql'
while more_records:
    sql = f"""
    SELECT * FROM "1d536ee6-7ffb-49c3-bffe-5cdd98a3c97e"
    WHERE "CALL_RECEIVED" BETWEEN DATE '2020-12-31' AND DATE '2022-01-01'
    ORDER BY "_id" ASC
    OFFSET {record_count}
    """

    response = requests.get(url, params={'sql': sql})
    response_frame = spark.read.json(sc.parallelize([response.text]))
    more_records = 'records_truncated:' in response_frame.schema.simpleString()

    json_frame = response_frame.select(explode(col('result.records'))).select('col.*')
    record_count += json_frame.count()

    # Save the data to the data lake so that we can retrieve it later if needed.
    glueContext.write_dynamic_frame.from_options(
        frame=DynamicFrame.fromDF(
            json_frame, glue_ctx=glueContext, name='mapped_call_types'
        ),
        connection_type='s3',
        format='json',
        connection_options={
            'path': f"{args['DATA_LAKE_URL']}arizona-phoenix/",
            'partitionKeys': [],
        },
        transformation_ctx=f"data_lake_{job_id}",
    )

    # Convert the timestamp to UTC and any missing fields.
    # TODO: Determine if we can avoid adding empty fields.
    updated_frame = (json_frame
                        .withColumn('call_time', to_utc_timestamp(col('CALL_RECEIVED'), 'America/Phoenix'))
                        .withColumn('dataset', lit('Phoenix, AZ'))
                        .withColumn('emergency_category', lit(None))
                        .withColumn('call_category', lit(None))
                        .withColumn('unit_type', lit(None))
                        .withColumn('alcohol', lit(None))
                        .withColumn('domestic_violence', lit(None))
                        .withColumn('drug', lit(None))
                        .withColumn('mental_health', lit(None))
                     )

    # Map call types to the common call type. We do this before mapping the fields to
    # ensure the fields in the dataframe are in the same order as the table in
    # Redshift.
    mapping_expression = create_map([lit(x) for x in chain(*mapping.items())])
    mapped_call_types = updated_frame.withColumn(
        'common_call_type',
        mapping_expression[col('FINAL_CALL_TYPE')]
    )

    # Map fields to the common schema.
    mapped_fields = ApplyMapping.apply(
        frame=DynamicFrame.fromDF(
            mapped_call_types, glue_ctx=glueContext, name='mapped_call_types'
        ),
        mappings=[
            ('dataset', 'string', 'dataset', 'string'),
            ('INCIDENT_NUM', 'string', 'call_id', 'string'),
            ('call_time', 'timestamp', 'call_time', 'timestamp'),
            ('FINAL_CALL_TYPE', 'string', 'call_type', 'string'),
            ('common_call_type', 'string', 'common_call_type', 'string'),
            ('emergency_category', 'string', 'emergency_category', 'string'),
            ('call_category', 'string', 'call_category', 'string'),
            ('DISPOSITION', 'string', 'disposition', 'string'),
            ('priority', 'string', 'priority', 'string'),
            ('unit_type', 'string', 'unit_type', 'string'),
            ('alcohol_related', 'long', 'alcohol', 'boolean'),
            ('dv_related', 'long', 'domestic_violence', 'boolean'),
            ('drug_related', 'long', 'drug', 'boolean'),
            ('mental_health', 'long', 'mental_health', 'boolean'),
        ],
        transformation_ctx=f"mapped_fields_{job_id}",
    )

    # Write the data to Redshift, ensuring any existing records are updated.
    glueContext.write_dynamic_frame.from_jdbc_conf(
        frame=mapped_fields,
        catalog_connection=args['REDSHIFT_CONNECTION'],
        connection_options={
            'database': 'r911',
            'dbtable': f"public.{job_id}",
            'preactions': pre_query,
            'postactions': post_query,
        },
        redshift_tmp_dir=args['TempDir'],
        transformation_ctx=f"redshift_{job_id}",
    )

print(f"{record_count} records found.")
job.commit()
