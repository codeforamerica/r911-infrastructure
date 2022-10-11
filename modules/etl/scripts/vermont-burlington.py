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
from pyspark.sql.functions import col, create_map, explode, lit

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

offset = 0
record_count = 0
url = 'https://maps.burlingtonvt.gov/arcgis/rest/services/Hosted/Police_Incidents_2021/FeatureServer/0/query'
parameters = {
    'f': 'json',
    'outFields': '*',
    'resultRecordCount': 1000,
    'where': '1=1',
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
            'path': f"{args['DATA_LAKE_URL']}vermont-burlington/",
            'partitionKeys': [],
        },
        transformation_ctx=f"data_lake_{job_id}",
    )

    # Add any missing fields.
    # TODO: Determine if we can avoid adding empty fields.
    updated_frame = (json_frame
                        .withColumn('dataset', lit('Burlington, VT'))
                        .withColumn('emergency_category', lit(None))
                        .withColumn('call_category', lit(None))
                        .withColumn('disposition', lit(None))
                        .withColumn('unit_type', lit(None))
                     )

    # Map call types to the common call type. We do this before mapping the fields to
    # ensure the fields in the dataframe are in the same order as the table in
    # Redshift.
    # TODO: Get this directly from Classifyr.
    mapping = {
        '911 Hangup': '911H',
        'Airport AOA Violation': 'AIRINC',
        'Animal Problem': 'ANIMAL',
        'Animals': 'ANIMAL',
        'Arson': 'FARSON',
        'Assault - Aggravated': 'ASSAULT',
        'Assault - Simple': 'ASSAULT',
        'Assist - Agency': 'ASSIST',
        'Assist - Motorist': 'VEHASST',
        'Assist - Public': 'CITASST',
        'Bad Check': 'FRAUD',
        'Bomb Threat': 'BOMB',
        'Burglary': 'BURGLARY',
        'CHINS': 'CITASST',
        'Counterfeiting': 'CNTRFT',
        'Cruelty to Animals': 'ANIMAL',
        'Custodial Interference': 'CUST',
        'Disorderly Conduct': 'DISORD',
        'DLS': 'CRIMTRAF',
        'Domestic Disturbance': 'DVNA',
        'Drugs - Possession': 'DRUGS',
        'Drugs - Sale': 'DRUGS',
        'DUI': 'DUI',
        'Extortion': 'EXTORT',
        'False Info to Police': 'MISCON',
        'False Public Alarms': 'MISCON',
        'Fireworks': 'FIREWRKS',
        'Forgery': 'FRAUD',
        'Fraud': 'FRAUD',
        'Homicide': 'HOMICIDE',
        'Identity Theft': 'FRAUD',
        'Impersonation of a Police Officer': 'CRIMPS',
        'Intoxication': 'INTOX',
        'Larceny - Other': 'LARCENY',
        'Missing Person': 'PERMISS',
        'Noise': 'NEGLECT',
        'Operations': 'ADMIN',
        'Parking': 'PARKING',
        'Possession of Stolen Property': 'PROPSTLN',
        'Retail Theft': 'LARCENY',
        'Roadway Hazard': 'THAZ',
        'Robbery': 'ROBBERY',
        'Runaway': 'RUNAWAY',
        'Sexual Assault': 'SEXOFFNS',
        'Subpoena Service': 'COURT',
        'Suicide - Attempted': 'SUICTHRT',
        'Suspicious Event': 'SUSP',
        'Trespass': 'TRESPASS',
        'TRO/FRO Service': 'COURT',
        'TRO/FRO Violation': 'ORDERV',
        'Unlawful Restraint': 'ASSAULT',
        'Untimely Death': 'DEATH',
        'Vandalism': 'VANDAL',
        'Vandalism - graffiti': 'VANDAL',
        'Weapons Offense': 'WEAPON',
        'Welfare Check': 'WELFARE',
    }

    mapping_expression = create_map([lit(x) for x in chain(*mapping.items())])
    mapped_call_types = updated_frame.withColumn('common_call_type', mapping_expression[col('call_type')])

    # Map fields to the common schema.
    mapped_fields = ApplyMapping.apply(
        frame=DynamicFrame.fromDF(
            mapped_call_types, glue_ctx=glueContext, name='mapped_call_types'
        ),
        mappings=[
            ('dataset', 'string', 'dataset', 'string'),
            ('incident_number', 'string', 'call_id', 'string'),
            ('call_time', 'string', 'call_time', 'timestamp'),
            ('call_type', 'string', 'call_type', 'string'),
            ('common_call_type', 'string', 'common_call_type', 'string'),
            ('emergency_category', 'string', 'emergency_category', 'string'),
            ('call_category', 'string', 'call_category', 'string'),
            ('disposition', 'string', 'disposition', 'string'),
            ('priority', 'string', 'priority', 'string'),
            ('unit_type', 'string', 'unit_type', 'string'),
            ('alcohol_related', 'long', 'alcohol', 'boolean'),
            ('dv_related', 'long', 'domestic_violence', 'boolean'),
            ('drug_related', 'long', 'drug', 'boolean'),
            ('mental_health', 'long', 'mental_health', 'boolean'),
        ],
        transformation_ctx=f"mapped_fields_{job_id}",
    )

    mapped_fields.printSchema()
    mapped_fields.toDF().show(5, truncate=False, vertical=True)

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
