# Step Function Integration Guide

This document explains how to use the AWS Step Function integration for file copying and tracking workflows with S3 event triggers.

## Overview

The Step Function provides a robust, stateful workflow for copying files to multiple destination buckets with built-in error handling, retries, and comprehensive tracking. The workflow is automatically triggered by S3 events when files are uploaded to the global-builds bucket.

## Architecture

### Components

1. **Step Function State Machine**: `file-copy-workflow`

   - Orchestrates the entire file copying process
   - Handles parallel processing with up to 10 concurrent operations
   - Provides error handling and retry logic
   - Automatically triggered by S3 events

2. **SNS Topic**: `file-copy-failures`

   - Sends notifications when file copies fail
   - Provides detailed error information with rich formatting

3. **DynamoDB Table**: `FileCopyTracking`

   - Stores detailed tracking information for each file copy operation
   - Records success/failure counts and timestamps
   - Uses composite key (fileKey + sourceBucket) for proper data modeling

4. **Lambda Function**: `replication-worker`

   - Automatically triggered by S3 ObjectCreated events
   - Extracts file information and invokes Step Function
   - Handles S3 event processing and workflow initiation

5. **Lambda Function**: `step-function-invoker`
   - Provides an API endpoint to trigger Step Function executions manually
   - Handles input validation and error handling

## Usage

### Automatic S3-Triggered Workflow

The workflow is automatically triggered when files are uploaded to the global-builds bucket:

```bash
# Upload a file to trigger the workflow
awslocal s3 cp test-file.zip s3://global-builds/

# The replication worker will automatically:
# 1. Process the S3 event
# 2. Extract file information
# 3. Invoke the Step Function with destination buckets
# 4. Track the entire workflow in DynamoDB
```

### Direct Step Function Invocation

You can invoke the Step Function directly using the AWS CLI:

```bash
# Get the Step Function ARN
STEP_FUNCTION_ARN=$(terraform output -raw step_function_arn)

# Start an execution
awslocal stepfunctions start-execution \
  --state-machine-arn $STEP_FUNCTION_ARN \
  --input '{
    "sourceBucket": "global-builds",
    "sourceKey": "build-123.zip",
    "destinationBuckets": ["region-a-builds", "region-b-builds"]
  }'
```

### API Gateway Invocation

You can also trigger the Step Function through the API Gateway:

```bash
# Get the API Gateway URL
API_URL=$(terraform output -raw api_gateway_url)

# Invoke via API Gateway
curl -X POST $API_URL/step-function \
  -H "Content-Type: application/json" \
  -d '{
    "sourceBucket": "global-builds",
    "sourceKey": "build-123.zip",
    "destinationBuckets": ["region-a-builds", "region-b-builds"]
  }'
```

### Input Format

The Step Function expects the following input format:

```json
{
  "sourceBucket": "string",
  "sourceKey": "string",
  "destinationBuckets": ["string"]
}
```

- `sourceBucket`: The source S3 bucket name
- `sourceKey`: The key of the file to copy
- `destinationBuckets`: Array of destination bucket names

## Workflow States

### 1. ValidateInput

- **Type**: Pass state
- **Function**: Validates and prepares input from S3 events
- **Adds**: Execution tracking with timestamps and execution IDs

### 2. LogWorkflowStart

- **Type**: Task state
- **Function**: Records workflow start in DynamoDB with comprehensive metadata
- **Stores**: File key, source bucket, execution ID, status, timestamps, destination buckets

### 3. CopyToMultipleBuckets

- **Type**: Map state
- **Function**: Copies files to multiple destination buckets in parallel
- **MaxConcurrency**: 10 concurrent operations
- **Error Handling**: Retries with exponential backoff

### 4. ProcessResults

- **Type**: Pass state
- **Function**: Aggregates results from all copy operations with detailed metrics
- **Calculates**: Total buckets, successful copies, failed copies, successful/failed bucket lists

### 5. UpdateDynamoDBFinal

- **Type**: Task state
- **Function**: Updates DynamoDB with final workflow results using composite keys
- **Stores**: Final status, completion time, detailed metrics, execution ID

### 6. CheckIfAllSuccessful

- **Type**: Choice state
- **Function**: Determines final workflow status based on success/failure counts
- **Logic**: Checks if all copies were successful

### 7. SendFailureNotification

- **Type**: Task state
- **Function**: Sends SNS notifications for failures with rich formatting
- **Includes**: Emojis, detailed error information, and structured messages

## Monitoring and Tracking

### DynamoDB Tracking

The `FileCopyTracking` table stores detailed information with composite keys:

```bash
# View tracking records
awslocal dynamodb scan --table-name FileCopyTracking

# Query specific file
awslocal dynamodb get-item \
  --table-name FileCopyTracking \
  --key '{"fileKey":{"S":"build-123.zip"},"sourceBucket":{"S":"global-builds"}}'
```

### SNS Notifications

When failures occur, SNS sends rich formatted notifications with:

- File information (source bucket, key)
- Failure counts and details with emojis
- Execution ID for tracking
- Reference to DynamoDB for detailed results

### Step Function Console

You can monitor executions in the LocalStack Step Functions console:

- Execution history with full state transitions
- Input/output data for each state
- Error details and retry attempts
- Execution timing and performance metrics

## Error Handling

### Retry Logic

- **S3 Copy Operations**: 3 retries with 2-second intervals and exponential backoff
- **DynamoDB Operations**: 3 retries with 1-second intervals
- **SNS Notifications**: 2 retries with 1-second intervals

### Error States

- **AllCopiesSuccessful**: When all copies succeed
- **SomeCopiesFailed**: When some copies fail (sends rich SNS notification)
- **NotificationFailed**: When SNS notification fails

## Testing

### S3 Event Trigger Test

```bash
# Test automatic triggering by uploading a file
awslocal s3 cp test-file.zip s3://global-builds/

# Verify the workflow was triggered
awslocal stepfunctions list-executions --state-machine-arn $STEP_FUNCTION_ARN
```

### Success Scenario

```bash
# Test with valid buckets
awslocal stepfunctions start-execution \
  --state-machine-arn $STEP_FUNCTION_ARN \
  --input '{
    "sourceBucket": "global-builds",
    "sourceKey": "test-file.zip",
    "destinationBuckets": ["region-a-builds", "region-b-builds"]
  }'
```

### Failure Scenario

```bash
# Test with invalid bucket (will trigger SNS notification)
awslocal stepfunctions start-execution \
  --state-machine-arn $STEP_FUNCTION_ARN \
  --input '{
    "sourceBucket": "global-builds",
    "sourceKey": "test-file.zip",
    "destinationBuckets": ["invalid-bucket"]
  }'
```

## Integration with Existing Workflow

The Step Function is integrated into the existing deployment workflow:

1. **Build Worker** creates artifacts in `global-builds` via API Gateway
2. **S3 Event** automatically triggers the replication worker
3. **Replication Worker** invokes Step Function for file distribution
4. **Step Function** copies files to regional buckets with comprehensive tracking
5. **Regional Sync** processes files after successful copying

This provides a robust, event-driven alternative to simple S3 copy operations, especially for scenarios requiring:

- Automatic triggering without manual intervention
- Parallel processing to multiple destinations
- Comprehensive error handling and retries
- Detailed tracking and monitoring
- Rich failure notifications with execution context
