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
from pyspark.sql.functions import col, concat, create_map, explode, lit, to_utc_timestamp

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

# TODO: Get this directly from Classifyr.
mapping = {
    "ACH - Accident Hit and Run": "MVAHR",
    "ADW - Assault with Dangerous Weapon": "NCRASLTWF",
    "ALC - Alarm Commercial": "ALMB",
    "ANC - Animal Complaint": "ANIMAL",
    "ASB - Assault and Battery": "ASSAULT",
    "ASC - Assist Citizen": "CITASST",
    "ASD - Assist Other PD": "ASSIST",
    "ASL - Assault": "ASSAULT",
    "BEC - Commercial B&E": "BURGLARY",
    "BOX - Box Alarm": "ALRBOX",
    "CKW - Check on The Welfare": "WELFARE",
    "DNE - Neighbor Dispute": "CDX",
    "DOA - Dead Body": "DEATH",
    "DRG - Drug Violation": "DRUGS",
    "FIG - Fight": "FIGHT",
    "FIR - Fire Dept Assist": "ASSIST",
    "FOU - Found Property": "PROPFND",
    "FRA - Fraud": "FRAUD",
    "FWK - Fireworks": "FIREWRKS",
    "HAR - Harrassment": "HARR",
    "HUP - 911 hang Up": "911H",
    "LAO - Larceny Over $250": "LARCENY",
    "LAU - Larceny Under $250": "LARCENY",
    "LDM - Loud Music": "NEGLECT",
    "LOS - Lost Property": "PROPLOST",
    "MIS - Missing Person": "PERMISS",
    "MM - Malicious Mischief": "VANDAL",
    "PRK - Parking Violation": "PARKING",
    "ROC - Road Closure": "THAZ",
    "SUS - Suspicous Person": "PERSUSP",
    "SUV - Suspicious MV": "VEHSUSP",
    "TOW - Tow Vehicle": "TOW",
    "TRS - Trespass": "TRESPASS",
    "UNK - Unknown Problem": "TROUBLE",
}

offset = 0
record_count = 0
url = 'https://services1.arcgis.com/j8dqo2DJE7mVUBU1/arcgis/rest/services/Police_Incident_Data_-_2021/FeatureServer/0/query'
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
            'path': f"{args['DATA_LAKE_URL']}massachusetts-worcester/",
            'partitionKeys': [],
        },
        transformation_ctx=f"data_lake_{job_id}",
    )

    # Convert the timestamp to UTC and any missing fields.
    # TODO: Determine if we can avoid adding empty fields.
    updated_frame = (json_frame
                        .withColumn('call_time', to_utc_timestamp(concat(col('Date_Logged'), lit(' '), col('Time_Logged')), 'America/New_York'))
                        .withColumn('dataset', lit('Worcester, MA'))
                        .withColumn('emergency_category', lit(None))
                        .withColumn('call_category', lit(None))
                        .withColumn('disposition', lit(None))
                        .withColumn('priority', lit(None))
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
    mapped_call_types = updated_frame.withColumn('common_call_type', mapping_expression[col('Incident_Type')])

    # Map fields to the common schema.
    mapped_fields = ApplyMapping.apply(
        frame=DynamicFrame.fromDF(
            mapped_call_types, glue_ctx=glueContext, name='updated_frame'
        ),
        mappings=[
            ('dataset', 'string', 'dataset', 'string'),
            ('Incident_Number', 'string', 'call_id', 'string'),
            ('call_time', 'timestamp', 'call_time', 'timestamp'),
            ('Incident_Type', 'string', 'call_type', 'string'),
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
