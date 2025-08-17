# Local Replication and Testing Plan for Code Deployment System (LocalStack Edition)

This document outlines a comprehensive plan to replicate and test the provided system design architecture on a local machine. This updated plan uses **LocalStack** and **Terraform** to simulate a modern, fully automated, and production-grade AWS environment.

### Guiding Principles

- **Production-Grade IaC:** Use official, community-vetted **Terraform Modules** from the Terraform Registry to define infrastructure. This promotes clean, readable, and maintainable code.
- **Infrastructure as Code (IaC):** Use **Terraform** to declaratively define and provision all AWS resources. This provides a robust, version-controlled, and repeatable setup.
- **Modern Application Code:** All Lambda functions will be written in a modern LTS version of **Node.js (e.g., 20.x)** using the latest **AWS SDK for JavaScript (v3)**.
- **Fully Automated & Event-Driven:** The entire deployment process is triggered automatically by events (API calls, S3 object creation), requiring no manual intervention after the initial trigger.
- **Truly Serverless:** Use **LocalStack API Gateway** for the initial HTTP endpoint.
- **Cloud-Native Simulation:** Use **LocalStack** to provide a high-fidelity local AWS environment.
- **Scalable Simulation:** Simulate large-scale deployments by recording their outcomes in a database.
- **Step Functions Orchestration:** Use **AWS Step Functions** to orchestrate complex multi-step workflows with built-in error handling, retries, and state management.
- **S3-Triggered Workflows:** Use S3 events to automatically trigger file distribution workflows without manual intervention.

---

### The Plan

#### Phase 1: Foundational Setup

1.  **Install Prerequisites:** Ensure you have Docker, the AWS CLI, and Terraform installed.
2.  **Project Structure:** Create a project directory. Inside, create:
    - `docker-compose.yml`: The master file to run LocalStack.
    - `./infra/`: The directory for our Terraform project (`main.tf`, `variables.tf`, etc.).
    - `./infra/step_function_definition.json`: Step Function state machine definition.
    - `./src/lambda_build_worker/`: Code for our build Lambda function (Node.js).
    - `./src/lambda_replication_worker/`: Code for the replication Lambda (Node.js).
    - `./src/lambda_regional_sync/`: Code for the regional deployment Lambda (Node.js).

#### Phase 2: Infrastructure Provisioning with Terraform

1.  **Terraform Configuration using Modules:**

    - **Action:** Create a `main.tf` file inside the `./infra/` directory that composes official Terraform modules to create the infrastructure.
    - **Provider:** The Terraform AWS provider will be configured to target the LocalStack container's endpoint (`http://localhost:4566`).
    - **Modules Used:**
      - `terraform-aws-modules/apigateway-v2/aws`: To create the API Gateway and its SQS integration.
      - `terraform-aws-modules/sqs/aws`: To create the SQS queues.
      - `terraform-aws-modules/s3-bucket/aws`: To create the S3 buckets.
      - `terraform-aws-modules/dynamodb-table/aws`: To create the DynamoDB tables.
      - `terraform-aws-modules/lambda/aws`: To create the Lambda functions, their IAM roles, and package their source code.
    - **Step Functions Integration:**
      - **AWS Step Functions State Machine:** Creates a robust workflow for file copying and tracking.
      - **SNS Topic:** For error notifications when file copies fail.
      - **DynamoDB Table:** For tracking file copy operations and their results.
      - **IAM Roles and Policies:** Proper permissions for Step Functions to access S3, DynamoDB, and SNS.
    - **Event Triggers:** The modules will also be configured to create all SQS and S3 event source mappings and notifications that connect the services into a pipeline.

2.  **Build Worker (Lambda Function):**
    - **Action:** The `build-worker` Lambda is triggered by API Gateway. It simulates the build process and uses the AWS SDK to upload the final artifact (e.g., `build-123.zip`) to the `global-builds` S3 bucket.

#### Phase 3: Implement the Automated Deployment & Replication Workflow

This phase is now fully defined by the infrastructure created by Terraform and the Lambda code, with enhanced Step Functions orchestration and S3 event triggers.

1.  **S3-Triggered Replication Worker:**

    - **Trigger:** Automatically invoked when a file is created in the `global-builds` S3 bucket.
    - **Action:** Extracts file information from S3 event and invokes the Step Function for file distribution.
    - **Event Processing:** Handles S3 ObjectCreated events and prepares input for Step Function.

2.  **Step Functions Workflow:**

    - **Trigger:** Invoked by the replication worker Lambda when S3 events occur.
    - **Input Validation:** Validates and prepares input from S3 events.
    - **Workflow Logging:** Records workflow start in DynamoDB with execution tracking.
    - **Parallel File Copying:** Uses a Map state to copy files to multiple destination buckets in parallel (up to 10 concurrent operations).
    - **Error Handling:** Built-in retry logic and error catching for each copy operation.
    - **Result Tracking:** Stores detailed results in DynamoDB including success/failure counts and timestamps.
    - **Failure Notifications:** Sends SNS notifications when file copies fail, with detailed error information.
    - **State Management:** Maintains workflow state and provides visibility into execution progress.

3.  **Regional Sync & P2P Host Simulation (Lambda):**
    - **Trigger:** Automatically invoked by S3 events in the regional buckets.
    - **Action:** Simulates the P2P distribution by writing thousands of records to the `host-deployment-logs` DynamoDB table.

#### Phase 4: Step Functions Integration Details

1.  **Step Function State Machine Features:**

    - **ValidateInput:** Validates and prepares input from S3 events with execution tracking.
    - **LogWorkflowStart:** Records workflow start in DynamoDB with comprehensive metadata.
    - **CopyToMultipleBuckets:** Map state that processes multiple destination buckets in parallel.
    - **ProcessResults:** Aggregates results from all copy operations with detailed metrics.
    - **UpdateDynamoDBFinal:** Updates DynamoDB with final workflow results using composite keys.
    - **CheckIfAllSuccessful:** Determines final workflow status based on success/failure counts.
    - **SendFailureNotification:** Sends SNS notifications for partial or complete failures with rich formatting.
    - **Error Recovery:** Multiple retry attempts with exponential backoff for transient failures.

2.  **SNS Integration:**

    - **Topic:** `file-copy-failures` for centralized error reporting.
    - **Notifications:** Rich formatted error messages with emojis and detailed information.
    - **Fallback Handling:** Graceful degradation when SNS notifications fail.

3.  **DynamoDB Tracking:**

    - **Table:** `FileCopyTracking` with composite key (fileKey + sourceBucket).
    - **Metrics:** Tracks total buckets, successful copies, failed copies, and overall status.
    - **Timestamps:** Records start and completion times for audit trails.
    - **Detailed Results:** Stores JSON-formatted results for debugging and analysis.
    - **Execution Tracking:** Links workflow executions to specific file operations.

#### Phase 5: End-to-End Testing

1.  **Step 1: Start LocalStack.**
    - **Action:** Run `docker-compose up -d`.
2.  **Step 2: Provision Infrastructure.**
    - **Action:** Navigate to the `./infra` directory and run:
      ```bash
      terraform init
      terraform apply --auto-approve
      ```
3.  **Step 3: Get API URL and Step Function ARN.**
    - **Action:** Get the API Gateway URL and Step Function ARN from Terraform outputs:
      ```bash
      terraform output -raw api_gateway_url
      terraform output -raw step_function_arn
      ```
4.  **Step 4: Trigger the pipeline.**
    - **Action:** `curl -X POST $(terraform output -raw api_gateway_url)/builds -d '{"commit": "abc123"}'`.
5.  **Step 5: Test S3-triggered workflow.**
    - **Action:** Upload a file to the global-builds bucket to trigger the workflow:
      ```bash
      awslocal s3 cp test-file.zip s3://global-builds/
      ```
6.  **Step 6: Test Step Function directly.**
    - **Action:** Test the Step Function with sample input:
      ```bash
      awslocal stepfunctions start-execution \
        --state-machine-arn $(terraform output -raw step_function_arn) \
        --input '{
          "sourceBucket": "global-builds",
          "sourceKey": "build-123.zip",
          "destinationBuckets": ["region-a-builds", "region-b-builds"]
        }'
      ```
7.  **Step 7: Verify the complete workflow.**
    - **Check Build:** `awslocal s3 ls s3://global-builds/`
    - **Check Replication:** `awslocal s3 ls s3://region-a-builds/`
    - **Check Step Function Tracking:** `awslocal dynamodb scan --table-name FileCopyTracking`
    - **Check Host Deployment:**
      ```bash
      awslocal dynamodb scan --table-name host-deployment-logs \
        --filter-expression "build_id = :build_id" \
        --expression-attribute-values '{":build_id":{"S":"build-123.zip"}}' \
        --select "COUNT"
      ```

#### Phase 6: Advanced Step Functions Testing

1.  **S3 Event Trigger Test:**

    - **Action:** Upload files to global-builds bucket and verify automatic workflow triggering.
    - **Expected:** Step Function should be automatically invoked for each file upload.

2.  **Parallel Processing Test:**

    - **Action:** Test with multiple destination buckets to verify parallel processing.
    - **Expected:** All copies should complete within the MaxConcurrency limit.

3.  **Error Handling Test:**

    - **Action:** Test with invalid bucket names or permissions to verify error handling.
    - **Expected:** SNS notifications should be sent for failed operations with rich formatting.

4.  **Retry Logic Test:**

    - **Action:** Simulate transient failures to verify retry behavior.
    - **Expected:** Operations should retry with exponential backoff.

5.  **Monitoring and Observability:**

    - **Action:** Use LocalStack's Step Functions console to monitor execution.
    - **Expected:** Full visibility into workflow state transitions and execution history.

#### Phase 7: Architecture Benefits

1.  **Event-Driven Design:**

    - **S3 Events:** Automatic triggering without polling or manual intervention.
    - **Real-time Processing:** Immediate response to file creation events.
    - **Scalability:** Handles multiple concurrent file uploads efficiently.

2.  **Robust Error Handling:**

    - **Comprehensive Tracking:** Every step is logged and tracked in DynamoDB.
    - **Rich Notifications:** Detailed SNS messages with emojis and structured information.
    - **Retry Logic:** Built-in retries with exponential backoff for transient failures.

3.  **Production-Grade Features:**
    - **Execution Tracking:** Unique execution IDs for each workflow run.
    - **Composite Keys:** Proper DynamoDB design with fileKey + sourceBucket.
    - **State Management:** Complete workflow state visibility and management.
    - **Monitoring:** Full observability into workflow execution and performance.
