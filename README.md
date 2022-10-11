# Reimagine911 Infrastructure

This repository includes the infrastructure as code (IaC) for Code for America's
Reimagine911 project. The infrastructure components are modularized, allowing
them to be reused as needed.

![Reimagine911 infrastructure architecture diagram][1]

## Accounts

Account configurations include components than only need to be deployed once for
the entire account such as the terraform backend and security hub.

## Environments

Environment configurations include components that are specific to a single
environment deployment such as the VPC, Fargate cluster, database, amd CI/CD
pipeline. 

## Modules

| Name              | Description                                                           |
|-------------------|-----------------------------------------------------------------------|
| backend           | Teraform backend configuration.                                       |
| ci_cd             | Ci/CD pipeline using CodePipeline.                                    |
| data_lake         | Data lake configuration using LakeFormation and S3.                   |
| data_warehouse    | Data warehouse configuration using Redshift.                          |
| etl               | ETL pipeline include PySpark scripts using AWS Glue.                  |
| networking        | VPC, subnets, and related routing confiigurations.                    |
| rails_hosting     | Ruby on Rails hosting on ECS Fargate with Aurora Postgres serverless. |
| security_scanning | Account security scanning configuration using Security Hub.           |

[1]: https://lucid.app/publicSegments/view/4fa858aa-7b40-4f16-81d8-186aebce330c/image.png
