# Local Replication and Testing Plan for Code Deployment System (LocalStack Edition)

This document outlines a comprehensive plan to replicate and test the provided system design architecture on a local machine. This updated plan uses **LocalStack** and **Terraform** to simulate a modern, fully automated, and production-grade AWS environment.

### Guiding Principles

*   **Production-Grade IaC:** Use official, community-vetted **Terraform Modules** from the Terraform Registry to define infrastructure. This promotes clean, readable, and maintainable code.
*   **Infrastructure as Code (IaC):** Use **Terraform** to declaratively define and provision all AWS resources. This provides a robust, version-controlled, and repeatable setup.
*   **Modern Application Code:** All Lambda functions will be written in a modern LTS version of **Node.js (e.g., 20.x)** using the latest **AWS SDK for JavaScript (v3)**.
*   **Fully Automated & Event-Driven:** The entire deployment process is triggered automatically by events (API calls, S3 object creation), requiring no manual intervention after the initial trigger.
*   **Truly Serverless:** Use **LocalStack API Gateway** for the initial HTTP endpoint.
*   **Cloud-Native Simulation:** Use **LocalStack** to provide a high-fidelity local AWS environment.
*   **Scalable Simulation:** Simulate large-scale deployments by recording their outcomes in a database.

---

### The Plan

#### Phase 1: Foundational Setup

1.  **Install Prerequisites:** Ensure you have Docker, the AWS CLI, and Terraform installed.
2.  **Project Structure:** Create a project directory. Inside, create:
    *   `docker-compose.yml`: The master file to run LocalStack.
    *   `./infra/`: The directory for our Terraform project (`main.tf`, `variables.tf`, etc.).
    *   `./src/lambda_build_worker/`: Code for our build Lambda function (Node.js).
    *   `./src/lambda_replication_worker/`: Code for the replication Lambda (Node.js).
    *   `./src/lambda_regional_sync/`: Code for the regional deployment Lambda (Node.js).

#### Phase 2: Infrastructure Provisioning with Terraform

1.  **Terraform Configuration using Modules:**
    *   **Action:** Create a `main.tf` file inside the `./infra/` directory that composes official Terraform modules to create the infrastructure.
    *   **Provider:** The Terraform AWS provider will be configured to target the LocalStack container's endpoint (`http://localhost:4566`).
    *   **Modules Used:**
        *   `terraform-aws-modules/apigateway-v2/aws`: To create the API Gateway and its SQS integration.
        *   `terraform-aws-modules/sqs/aws`: To create the SQS queues.
        *   `terraform-aws-modules/s3-bucket/aws`: To create the S3 buckets.
        *   `terraform-aws-modules/dynamodb-table/aws`: To create the DynamoDB tables.
        *   `terraform-aws-modules/lambda/aws`: To create the Lambda functions, their IAM roles, and package their source code.
    *   **Event Triggers:** The modules will also be configured to create all SQS and S3 event source mappings and notifications that connect the services into a pipeline.

2.  **Build Worker (Lambda Function):**
    *   **Action:** The `build-worker` Lambda is triggered by the `build-jobs-queue`. It simulates the build process and uses the AWS SDK to upload the final artifact (e.g., `build-123.zip`) to the `global-builds` S3 bucket.

#### Phase 3: Implement the Automated Deployment & Replication Workflow

This phase is now fully defined by the infrastructure created by Terraform and the Lambda code.

1.  **Replication Worker (Lambda):**
    *   **Trigger:** Automatically invoked when a message lands in the `deployment-jobs-queue`.
    *   **Action:** It copies the artifact from `s3://global-builds` to both regional S3 buckets and updates the `replication-status` DynamoDB table.

2.  **Regional Sync & P2P Host Simulation (Lambda):**
    *   **Trigger:** Automatically invoked by S3 events in the regional buckets.
    *   **Action:** Simulates the P2P distribution by writing thousands of records to the `host-deployment-logs` DynamoDB table.

#### Phase 4: End-to-End Testing

1.  **Step 1: Start LocalStack.**
    *   **Action:** Run `docker-compose up -d`.
2.  **Step 2: Provision Infrastructure.**
    *   **Action:** Navigate to the `./infra` directory and run:
        ```bash
        terraform init
        terraform apply --auto-approve
        ```
3.  **Step 3: Get API URL.**
    *   **Action:** Get the API Gateway URL from the Terraform output:
        ```bash
        terraform output -raw api_gateway_url
        ```
4.  **Step 4: Trigger the pipeline.**
    *   **Action:** `curl -X POST $(terraform output -raw api_gateway_url)/builds -d '{"app": "my-awesome-app"}'`.
5.  **Step 5: Verify the complete workflow.**
    *   **Check Build:** `awslocal s3 ls s3://global-builds/`
    *   **Check Replication:** `awslocal s3 ls s3://region-a-builds/`
    *   **Check Status:** `awslocal dynamodb scan --table-name replication-status`
    *   **Check Host Deployment:**
        ```bash
        awslocal dynamodb scan --table-name host-deployment-logs \
          --filter-expression "build_id = :build_id" \
          --expression-attribute-values '{":build_id":{"S":"build-123.zip"}}' \
          --select "COUNT"
        ```