# Reimagine911 Infrastructure

This repository includes the infrastructure as code (IaC) for Code for America's
Reimagine911 project. The infrastructure components are modularized, allowing
them to be reused as needed.

![][1]

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
| networking        | VPC, subnets, and related routing confiigurations.                    |
| rails_hosting     | Ruby on Rails hosting on ECS Fargate with Aurora Postgres serverless. |
| security_scanning | Account security scanning configuration using Security Hub.           |

[1]: https://lucid.app/publicSegments/view/cb1e828c-2415-407c-be2b-abe564f5c42b/image.png
