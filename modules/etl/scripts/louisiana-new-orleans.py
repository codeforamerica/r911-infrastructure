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
from pyspark.sql.functions import col, create_map, lit, to_utc_timestamp

args = getResolvedOptions(sys.argv, ['DATA_LAKE_URL', 'JOB_NAME', 'REDSHIFT_CONNECTION'])
config = SparkConf().set('spark.rpc.message.maxSize', '256')
sc = SparkContext(conf=config)
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)
job_id = args['JOB_RUN_ID']

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
url = 'https://data.nola.gov/resource/3pha-hum9.json'
parameters = {
    '$limit': 5_000_000,
    '$order': ':id',
}
response = requests.get(url, params=parameters)
json_frame = spark.read.json(sc.parallelize([response.text]))

print(f"{json_frame.count()} records found.")

# Save the data to the data lake so that we can retrieve it later if needed.
glueContext.write_dynamic_frame.from_options(
    frame=DynamicFrame.fromDF(
        json_frame, glue_ctx=glueContext, name='mapped_call_types'
    ),
    connection_type='s3',
    format='json',
    connection_options={
        'path': f"{args['DATA_LAKE_URL']}louisiana-new-orleans/",
        'partitionKeys': [],
    },
    transformation_ctx=f"data_lake_{job_id}",
)

# Convert the timestamp to UTC and any missing fields.
# TODO: Determine if we can avoid adding empty fields.
updated_frame = (json_frame
                    .withColumn('timecreate', to_utc_timestamp(col('timecreate'), 'America/Chicago'))
                    .withColumn('dataset', lit('New Orleans, LA'))
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
# TODO: Get this directly from Classifyr.
mapping = {
    "ABANDONED VEHICLE": "VEHABND",
    "AGGRAVATED ARSON": "FARSON",
    "AGGRAVATED BATTERY BY SHOOTING": "SHOOT",
    "AGGRAVATED BATTERY DOMESTIC": "DVA",
    "AGGRAVATED BURGLARY DOMESTIC": "BURGLARY",
    "AGGRAVATED ESCAPE": "ESCAPE",
    "AGGRAVATED RAPE": "SEXOFFNS",
    "AGGRAVATED RAPE UNFOUNDED BY SPECIAL VICTIMS OR CHILD ABUSE": "SEXOFFNS",
    "ARMED ROBBERY": "ROBBERY",
    "ARMED ROBBERY WITH KNIFE": "ROBBERY",
    "AUTO ACCIDENT POLICE VEHICLE": "MVAUNK",
    "AUTO ACCIDENT WITH INJURY": "MVAINJY",
    "BOMB SCARE": "BOMB",
    "BUSINESS BURGLARY": "BURGLARY",
    "CARJACKING": "CARJACK",
    "CARJACKING- NO WEAPON": "CARJACK",
    "CURFEW VIOLATION": "CURFEW",
    "DISPERSE SUBJECTS": "CRWD",
    "DRIVING WHILE UNDER INFLUENCE": "DUI",
    "DRUG VIOLATIONS": "DRUGS",
    "EXPLOSION": "EXPLOS",
    "FIGHT": "FIGHT",
    "FORGERY": "FRAUD",
    "FUGITIVE ATTACHMENT": "PERWANT",
    "HIT & RUN CITY VEHICLE": "MVAHR",
    "ICING ON ROADS": "THAZ",
    "ILLEGAL CARRYING OF WEAPON": "WEAPON",
    "ILLEGAL CARRYING OF WEAPON- GUN": "WEAPON",
    "ILLEGAL CARRYING OF WEAPON- KNIFE": "WEAPON",
    "IMPERSONATING AN OFFICER": "CRIMPS",
    "INCIDENT REQUESTED BY ANOTHER AGENCY": "ASSIST",
    "ISSUING WORTHLESS CHECKS": "FRAUD",
    "LOST PROPERTY": "PROPLOST",
    "MEDICAL - NALOXONE": "OD",
    "MEDICAL SEXUAL ASSAULT KIT PROCESSING": "ADMIN",
    "MISSING ADULT": "PERMISS",
    "MISSING JUVENILE": "PERMISS",
    "NOISE COMPLAINT": "NEGLECT",
    "PICKPOCKET": "LARCENY",
    "POSSESSION OF STOLEN PROPERTY": "PROPSTLN",
    "PROTEST": "CIVDIS",
    "RECKLESS DRIVING": "RECKDRV",
    "RECOVERY OF VEHICLE": "VEHREC",
    "SEXUAL BATTERY": "SEXOFFNS",
    "SIMPLE ARSON": "FARSON",
    "SIMPLE BATTERY DOMESTIC": "DVA",
    "SIMPLE BURGLARY DOMESTIC": "BURGLARY",
    "SIMPLE RAPE": "SEXOFFNS",
    "SIMPLE RAPE MALE VICTIM": "SEXOFFNS",
    "SIMPLE RAPE UNFOUNDED BY SPECIAL VICTIMS OR CHILD ABUSE": "SEXOFFNS",
    "SIMPLE ROBBERY": "ROBBERY",
    "SIMPLE ROBBERY, PROPERTY SNATCHING": "ROBBERY",
    "SIMULTANEOS STOLEN/RECOVERY VEHICLE": "VEHREC",
    "SOLICITING FOR PROSTITUTION": "VICE",
    "SUICIDE": "SUICTHRT",
    "SUICIDE ATTEMPT": "SUICTHRT",
    "SUSPICIOUS PACKAGE": "SUSP",
    "SUSPICIOUS PERSON": "PERSUSP",
    "THEFT BY EMBEZZLEMENT": "VICE",
    "TRAFFIC STOP": "TSTOP",
    "UNCLASSIFIED DEATH": "DEATH",
    "VEHICLE PURSUIT": "PURSUIT",
    "VIOLATION OF PROTECTION ORDER": "ORDERV",
}

mapping_expression = create_map([lit(x) for x in chain(*mapping.items())])
mapped_call_types = updated_frame.withColumn('common_call_type', mapping_expression[col('initialtypetext')])

# Map fields to the common schema.
mapped_fields = ApplyMapping.apply(
    frame=DynamicFrame.fromDF(
        mapped_call_types, glue_ctx=glueContext, name='mapped_call_types'
    ),
    mappings=[
        ('dataset', 'string', 'dataset', 'string'),
        ('nopd_item', 'string', 'call_id', 'string'),
        ('timecreate', 'timestamp', 'call_time', 'timestamp'),
        ('initialtypetext', 'string', 'call_type', 'string'),
        ('common_call_type', 'string', 'common_call_type', 'string'),
        ('emergency_category', 'string', 'emergency_category', 'string'),
        ('call_category', 'string', 'call_category', 'string'),
        ('dispositiontext', 'string', 'disposition', 'string'),
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

job.commit()
