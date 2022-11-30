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
url = 'https://data.cityofgainesville.org/resource/gvua-xt9q.json'
parameters = {
    '$limit': 5_000_000,
    '$order': ':id',
    '$where': "report_date between '2021-01-01T00:00:00' and '2021-12-31T11:59:59'"
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
                    .withColumn('report_date', to_utc_timestamp(col('report_date'), 'America/New_York'))
                    .withColumn('dataset', lit('Gainesville, FL'))
                    .withColumn('emergency_category', lit(None))
                    .withColumn('call_category', lit(None))
                    .withColumn('disposition', lit(None))
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
    'Affray': 'FIGHT',
    'Aircraft Incident': 'AIR',
    'Alcohol Beverage-possess by Person Under 21 Yoa': 'LIQUOR',
    'All Other Liquor Law Viol.': 'LIQUOR',
    'Animal Attack': 'BITE',
    'Animal Problem': 'ANIMAL',
    'Arson': 'FARSON',
    'Assault (simple)': 'ASSAULT',
    'Assist Citizen': 'CITASST',
    'Assist Other Agency': 'ASSIST',
    'Battery (security Guard/officer)': 'ASSAULT',
    'Battery (simple)': 'ASSAULT',
    'Bomb Threat': 'BOMB',
    'Burglary to a Structure': 'BURGLARY',
    'Burglary to Business': 'BURGLARY',
    'Burglary to Residence': 'BURGLARY',
    'Child Abuse': 'ABUSE',
    'Child Abuse (aggravated)': 'ABUSE',
    'Child Molestation': 'SEXOFFNS',
    'Computer Crimes': 'INTERNET',
    'Concealed Weapon Law Violation': 'WEAPON',
    'Crimes Against the Elderly': 'ABUSE',
    'Cyber Stalking': 'INTERNET',
    'Dating Violence Felony Battery': 'DVA',
    'Dating Violence Simple Assault': 'DVA',
    'Discharge Firearm From Vehicle Within 1000 Feet of a Person': 'WEAPON',
    'Disorderly Conduct': 'DISORD',
    'Disorderly Intoxication': 'INTOX',
    'Domestic Aggravated Assualt': 'DVA',
    'Domestic Assault': 'DVA',
    'Domestic Battery by Strangulation': 'DVA',
    'Domestic Simple Battery': 'DVA',
    'Domestic Violence Injunction': 'DVA',
    'Driving Under the Influence': 'DUI',
    'Driving While License Suspended/revoked': 'CRIMTRAF',
    'Driving With No License': 'CRIMTRAF',
    'Drug Equip/paraphernalia': 'DRUGPAR',
    'Drug Poss. of Controlled Substance': 'DRUGS',
    'Drug Violation (buying)': 'DRUGS',
    'Drug Violation (selling)': 'DRUGS',
    'Drug Violation (sid)': 'DRUGS',
    'Drug Violation (using)': 'DRUGS',
    'Embezzlement': 'VICE',
    'Escaped Prisoner': 'ESCAPE',
    'Exposure of Sexual Organs / Indecent Exposure': 'INDECENT',
    'Extortion/threats': 'EXTORT',
    'False Info to Leo': 'MISCON',
    'Forcible Fondling/child Molestation': 'SEXOFFNS',
    'Forcible Sodomy/oral': 'SEXOFFNS',
    'Found Property': 'PROPFND',
    'Found-returned Runaway': 'RUNAWAY',
    'Fraud (credit Card/atm)': 'FRAUD',
    'Fraud (worthless Check)': 'FRAUD',
    'Gambling': 'VICE',
    'Harassment': 'HARR',
    'Hit & Run': 'MVAHR',
    'Homicide': 'HOMICIDE',
    'Indecent Exposure': 'INDECENT',
    'Information': 'INFO',
    'Interfere With Custody': 'ORDERV',
    'Interfere With Custody of Child/incompetent Person': 'ORDERV',
    'Lewd or Lascivious Molestation Offender 18 or Older': 'SEXOFFNS',
    'Liquor Law Violation (sell to Minor)': 'LIQUOR',
    'Lost Property': 'PROPLOST',
    'Missing Person': 'PERMISS',
    'Noise Complaint': 'NOISE',
    'Overdose': 'OD',
    'Panhandling': 'PHANDLE',
    'Possession of a Firearm by a Minor': 'WEAPON',
    'Possess/use Drug Paraphernalia': 'DRUGPAR',
    'Poss. of Alcohol Under 21 Yoa': 'LIQUOR',
    'Prostitution': 'VICE',
    'Reckless Driving': 'RECKDRV',
    'Recovered Stolen Veh': 'VEHREC',
    'Robbery': 'ROBBERY',
    'Robbery (armed)': 'ROBBERY',
    'Robbery by Sudden Snatching': 'ROBBERY',
    'Robbery (home Invasion)': 'ROBBERY',
    'Robbery (strong Arm)': 'ROBBERY',
    'Runaway': 'RUNAWAY',
    'Sexual Battery': 'SEXOFFNS',
    'Sexual Battery - Victim 18 or Older and Physically Helpless': 'SEXOFFNS',
    'Sick / Injured Person': 'SICK',
    'Stalking (simple)': 'STKX',
    'Stolen Property (buying/receiving)': 'PROPSTLN',
    'Stolen Vehicle (auto)': 'VEHSTLN',
    'Stolen Vehicle (motorcycle)': 'VEHSTLN',
    'Stolen Vehicle (other)': 'VEHSTLN',
    'Stolen Vehicle (scooter)': 'VEHSTLN',
    'Stolen Vehicle (truck)': 'VEHSTLN',
    'Suicide': 'SUICIDE',
    'Suspicious Incident': 'SUSP',
    'Theft Grand - From Building': 'LARCENY',
    'Theft Grand - From Vending Machine': 'LARCENY',
    'Theft Grand - Pocket-picking': 'LARCENY',
    'Theft Grand - Purse Snatching': 'LARCENY',
    'Theft Grand - Retail': 'LARCENY',
    'Theft Grand - Value 300 to 4': '999',
    'Theft Petit - Bicycle': 'LARCENY',
    'Theft Petit - From Vehicle (vehicle Parts)': 'LARCENY',
    'Theft Petit - From Vending Machine': 'LARCENY',
    'Theft Petit - Other': 'LARCENY',
    'Theft Petit - Pocket-picking': 'LARCENY',
    'Theft Petit - Purse Snatching': 'LARCENY',
    'Theft Petit - Retail': 'LARCENY',
    'Threatening Phone Calls': 'THREATS',
    'Threats': 'THREATS',
    'Tow Report': 'TOW',
    'Trespass': 'TRESPASS',
    'Unlawful Sexual Activity With Minor': 'SEXOFFNS',
    'Utter Forged/counterfeit Bill': 'CNTRFT',
    'Violation of Permanent Injunction': 'ORDERV',
    'Violation of Temporary Injunction': 'ORDERV',
    'Warrant Arrest': 'PERWANT',
    'Weapons Violation': 'WEAPON',
    'Weapons Violation (possessing/concealing)': 'WEAPON',
    'Written Threat to Kill or Injure': 'THREATS',
}

mapping_expression = create_map([lit(x) for x in chain(*mapping.items())])
mapped_call_types = updated_frame.withColumn('common_call_type', mapping_expression[col('narrative')])

# Map fields to the common schema.
mapped_fields = ApplyMapping.apply(
    frame=DynamicFrame.fromDF(
        mapped_call_types, glue_ctx=glueContext, name='mapped_call_types'
    ),
    mappings=[
        ('dataset', 'string', 'dataset', 'string'),
        ('id', 'string', 'call_id', 'string'),
        ('report_date', 'timestamp', 'call_time', 'timestamp'),
        ('narrative', 'string', 'call_type', 'string'),
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
