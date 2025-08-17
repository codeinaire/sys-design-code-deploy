# Lambda Build Worker

## Overview

The `lambda_build_worker` is a Lambda function that handles build requests by downloading files from a local file server and uploading them to the `global-builds` S3 bucket.

## Functionality

When a POST request is made to the `/builds` endpoint, the lambda function:

1. **Parses the request body** to extract the `commit` value
2. **Downloads the file** from `http://host.docker.internal:3000/<commit>`
3. **Uploads the file** to the `global-builds` S3 bucket with metadata
4. **Returns a success response** with file details

## API Endpoint

- **Method**: POST
- **Path**: `/builds`
- **Request Body**: JSON with `commit` field (required)
- **Content-Type**: `application/json`
- **Example**:
  ```json
  {
    "commit": "abc123"
  }
  ```

**Request Validation**: The API Gateway validates that:

- The request body is present
- The `commit` field is provided and is a string
- The content type is `application/json`

## Response Format

### Success Response (200)

```json
{
  "message": "Build processed successfully",
  "commit": "abc123",
  "fileName": "abc123.zip",
  "fileSize": 1024,
  "s3Location": "http://localhost:4566/global-builds/abc123.zip",
  "timestamp": "2024-08-17T17:06:00.000Z"
}
```

### Error Response (500)

```json
{
  "message": "Error processing build request",
  "error": "Commit value is missing from request body",
  "timestamp": "2024-08-17T17:06:00.000Z"
}
```

## Dependencies

- `aws-sdk`: For S3 operations
- `axios`: For HTTP requests to the local file server

## Configuration

The lambda function is configured to work with LocalStack:

- **S3 Endpoint**: `http://localhost:4566`
- **Access Key**: `test`
- **Secret Key**: `test`
- **Region**: `us-east-1`

## File Naming Convention

Files are uploaded to S3 with the naming pattern: `<commit>.zip`

## Metadata

Each uploaded file includes the following metadata:

- `commit`: The commit value from the request
- `uploaded-by`: Identifier for the lambda function
- `upload-timestamp`: ISO timestamp of when the file was uploaded

## Error Handling

The function handles various error scenarios:

- Missing request body
- Missing commit value
- File download failures
- S3 upload failures

## Testing

To test the function locally:

1. **Install dependencies**:

   ```bash
   cd src/lambda_build_worker
   npm install
   ```

2. **Run the test script**:
   ```bash
   node ../../test-build-worker.js
   ```

## Deployment

The function is deployed as a ZIP package containing:

- `index.js` - Main function code
- `node_modules/` - Dependencies
- `package.json` - Package metadata

## Infrastructure

The lambda function is integrated with:

- **API Gateway**: Exposes the `/builds` endpoint
- **S3 Bucket**: `global-builds` bucket for file storage
- **IAM Permissions**: S3 PutObject, GetObject, and ListBucket permissions

## Local Development

For local development and testing:

1. Ensure LocalStack is running
2. The local file server should be accessible at `http://host.docker.internal:3000`
3. Test with the provided test script or via API Gateway
