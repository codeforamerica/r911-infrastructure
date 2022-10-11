import requests
import sys
from awsglue import DynamicFrame
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark import SparkConf
from pyspark.context import SparkContext
from pyspark.sql.functions import col, explode, lit

args = getResolvedOptions(sys.argv, ['DATA_LAKE_URL', 'JOB_NAME', 'REDSHIFT_CONNECTION'])
config = SparkConf().set('spark.rpc.message.maxSize', '256')
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)
job_id = args['JOB_RUN_ID']

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
offset = 0
record_count = 0
url = 'https://opendata.baltimorecity.gov/egis/rest/services/NonSpatialTables/CallsForService_2021_Present/FeatureServer/0/query'
parameters = {
    'f': 'json',
    'outFields': '*',
    'resultRecordCount': 2000,
    'where': "(callDateTime >= DATE '2021-01-01' AND callDateTime <= DATE '2021-12-31')",
}
while True:
    print(f"Current offset: {offset}")
    parameters['resultOffset'] = offset
    response = requests.get(url, params=parameters)

    json_frame = (spark.read.json(sc.parallelize([response.text]))
                     .select(explode(col('features')))
                     .select('col.attributes.*'))
    count = json_frame.count()
    record_count += count

    # Save the data to the data lake so that we can retrieve it later if needed.
    glueContext.write_dynamic_frame.from_options(
        frame=DynamicFrame.fromDF(
            json_frame, glue_ctx=glueContext, name='mapped_call_types'
        ),
        connection_type='s3',
        format='json',
        connection_options={
            'path': f"{args['DATA_LAKE_URL']}maryland-baltimore/",
            'partitionKeys': [],
        },
        transformation_ctx=f"data_lake_{job_id}",
    )

    # Convert the timestamp from milliseconds to seconds and any missing fields.
    # TODO: Determine if we can avoid adding empty fields.
    updated_frame = (json_frame
                        .withColumn('calldatetime', (col('calldatetime')/1000).cast('timestamp'))
                        .withColumn('dataset', lit('Baltimore, MD'))
                        .withColumn('emergency_category', lit(None))
                        .withColumn('call_category', lit(None))
                        .withColumn('disposition', lit(None))
                        .withColumn('unit_type', lit(None))
                        .withColumn('alcohol', lit(None))
                        .withColumn('domestic_violence', lit(None))
                        .withColumn('drug', lit(None))
                        .withColumn('mental_health', lit(None))
                 )

    # Map fields to the common schema.
    mapped_fields = ApplyMapping.apply(
        frame=DynamicFrame.fromDF(
            updated_frame, glue_ctx=glueContext, name='updated_frame'
        ),
        mappings=[
            ('dataset', 'string', 'dataset', 'string'),
            ('callnumber', 'string', 'call_id', 'string'),
            ('calldatetime', 'timestamp', 'call_time', 'timestamp'),
            ('description', 'string', 'call_type', 'string'),
            ('common_call_type', 'string', 'common_call_type', 'string'),
            ('emergency_category', 'string', 'emergency_category', 'string'),
            ('call_category', 'string', 'call_category', 'string'),
            ('disposition', 'string', 'disposition', 'string'),
            ('priority', 'string', 'priority', 'string'),
            ('unit_type', 'string', 'unit_type', 'string'),
            ('alcohol', 'boolean', 'alcohol', 'boolean'),
            ('domestic_violence', 'boolean', 'domestic_violence', 'boolean'),
            ('drug', 'boolean', 'drug', 'boolean'),
            ('mental_health', 'boolean', 'mental_health', 'boolean'),
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

    offset += count
    if count < parameters['resultRecordCount']:
        break

print(f"{record_count} records found.")
job.commit()
