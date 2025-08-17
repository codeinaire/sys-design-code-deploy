# sys-design-code-deploy

An implementation of a code deploy system based on the answer to AlgoExpert's system design questions.

# To Get Started

Run the `get_started.sh` script.

## Useful Info

To use the aws cli tool [some configuration needs to be done](https://docs.localstack.cloud/aws/integrations/aws-native-tools/aws-cli/#localstack-aws-cli-awslocal) or the awslocalstack wrapper can be used. I prefer to use the regular aws cli as it's a straight forward configuration and using the wrappy requires downgrading to aws cli v1

## Useful Commands

This checks the health of the localstack docker container and will output what's running

`curl http://localhost:4566/_localstack/health`

Validate Step Functions definition

- Using file:// so the CLI reads the JSON from disk (required):

```bash
aws stepfunctions validate-state-machine-definition \
  --region us-east-1 \
  --endpoint-url http://localhost:4566 \
  --definition file://terraform/infra/step_function_definition.json
```

- Alternatively, cat the file into the flag:

```bash
aws stepfunctions validate-state-machine-definition \
  --region us-east-1 \
  --endpoint-url http://localhost:4566 \
  --definition "$(cat terraform/infra/step_function_definition.json)"
```

If you pass a plain path (e.g., `./terraform/infra/step_function_definition.json`) without `file://` or `$(cat ...)`, the CLI will try to parse the literal string and fail with an INVALID_JSON_DESCRIPTION error.

# How to Test Functionality

### Quick end-to-end test (LocalStack + Terraform)

- **1) Start stack and provision infra**

```bash
./get-started.sh
```

- **2) Health check**

```bash
curl http://localhost:4566/_localstack/health
```

- **3) Create a test artifact and upload to trigger the flow**

```bash
printf 'hello' > /tmp/test-file.zip
aws --region us-east-1 --endpoint-url http://localhost:4566 s3 cp /tmp/test-file.zip s3://global-builds/test-file.zip
```

- **4) Verify Step Function execution started**

```bash
STEP_FUNCTION_ARN=$(terraform -chdir=/Users/nousunio/Repos/Learnings/algoexpert/system-design-practicals/iq1-code-deployment/terraform/infra output -raw step_function_arn)

aws --region us-east-1 --endpoint-url http://localhost:4566 stepfunctions list-executions \
  --state-machine-arn "$STEP_FUNCTION_ARN"

EXEC_ARN=$(aws --region us-east-1 --endpoint-url http://localhost:4566 stepfunctions list-executions \
  --state-machine-arn "$STEP_FUNCTION_ARN" --query 'executions[0].executionArn' -r)

aws --region us-east-1 --endpoint-url http://localhost:4566 stepfunctions describe-execution \
  --execution-arn "$EXEC_ARN" | cat
```

- **5) Verify objects copied to destination buckets**

```bash
aws --region us-east-1 --endpoint-url http://localhost:4566 s3 ls s3://region-a-builds/
aws --region us-east-1 --endpoint-url http://localhost:4566 s3 ls s3://region-b-builds/
```

- **6) Verify tracking record in DynamoDB**

```bash
aws --region us-east-1 --endpoint-url http://localhost:4566 dynamodb scan \
  --table-name FileCopyTracking | cat
```

### Alternative tests

- **Direct Step Function invocation**

```bash
aws --region us-east-1 --endpoint-url http://localhost:4566 stepfunctions start-execution \
  --state-machine-arn "$STEP_FUNCTION_ARN" \
  --input '{"sourceBucket":"global-builds","sourceKey":"test-file.zip","destinationBuckets":["region-a-builds","region-b-builds"]}'
```

- **Invoke Lambda invoker directly**

```bash
aws --region us-east-1 --endpoint-url http://localhost:4566 lambda invoke \
  --function-name step-function-invoker \
  --payload '{"sourceBucket":"global-builds","sourceKey":"test-file.zip","destinationBuckets":["region-a-builds","region-b-builds"]}' \
  /tmp/invoker_out.json | cat
cat /tmp/invoker_out.json
```

- **Optional: invoke via API Gateway**

```bash
REST_ID=$(aws --region us-east-1 --endpoint-url http://localhost:4566 apigateway get-rest-apis \
  --query 'items[?name==`code-deploy-api`].id' -r)

# Trigger replication worker via POST /deploy
curl -s -X POST "http://localhost:4566/restapis/${REST_ID}/dev/_user_request_/deploy" -d '{}' | cat
```

### Notes

- Use `aws --endpoint-url http://localhost:4566 ...` for every AWS CLI call.
- To validate the Step Function definition:

```bash
aws --region us-east-1 --endpoint-url http://localhost:4566 stepfunctions validate-state-machine-definition \
  --definition file:///Users/nousunio/Repos/Learnings/algoexpert/system-design-practicals/iq1-code-deployment/terraform/infra/step_function_definition.json
```

- If something wedges, bring the stack down and re-run:

```bash
cd /Users/nousunio/Repos/Learnings/algoexpert/system-design-practicals/iq1-code-deployment && docker compose down -v
bash get-started.sh
```

- You can also tail LocalStack logs to see Lambda/StepFunctions activity:

```bash
docker logs -f localstack-main | cat
```

- After a success, you should see:

  - A Step Functions execution that finishes successfully.
  - `test-file.zip` in `region-a-builds/` and `region-b-builds/`.
  - A record in `FileCopyTracking`.

- If you want, I can run these for you from here.

```shellscript
bash /Users/nousunio/Repos/Learnings/algoexpert/system-design-practicals/iq1-code-deployment/get-started.sh
```

```shellscript
curl http://localhost:4566/_localstack/health
```

```shellscript
printf 'hello' > /tmp/test-file.zip
aws --region us-east-1 --endpoint-url http://localhost:4566 s3 cp /tmp/test-file.zip s3://global-builds/test-file.zip
```

```shellscript
STEP_FUNCTION_ARN=$(terraform -chdir=/Users/nousunio/Repos/Learnings/algoexpert/system-design-practicals/iq1-code-deployment/terraform/infra output -raw step_function_arn)

aws --region us-east-1 --endpoint-url http://localhost:4566 stepfunctions list-executions \
  --state-machine-arn "$STEP_FUNCTION_ARN"

EXEC_ARN=$(aws --region us-east-1 --endpoint-url http://localhost:4566 stepfunctions list-executions \
  --state-machine-arn "$STEP_FUNCTION_ARN" --query 'executions[0].executionArn' -r)

aws --region us-east-1 --endpoint-url http://localhost:4566 stepfunctions describe-execution \
  --execution-arn "$EXEC_ARN" | cat
```

```shellscript
aws --region us-east-1 --endpoint-url http://localhost:4566 s3 ls s3://region-a-builds/
aws --region us-east-1 --endpoint-url http://localhost:4566 s3 ls s3://region-b-builds/
```

```shellscript
aws --region us-east-1 --endpoint-url http://localhost:4566 dynamodb scan \
  --table-name FileCopyTracking | cat
```

```shellscript
aws --region us-east-1 --endpoint-url http://localhost:4566 stepfunctions start-execution \
  --state-machine-arn "$STEP_FUNCTION_ARN" \
  --input '{"sourceBucket":"global-builds","sourceKey":"test-file.zip","destinationBuckets":["region-a-builds","region-b-builds"]}'
```

```shellscript
aws --region us-east-1 --endpoint-url http://localhost:4566 lambda invoke \
  --function-name step-function-invoker \
  --payload '{"sourceBucket":"global-builds","sourceKey":"test-file.zip","destinationBuckets":["region-a-builds","region-b-builds"]}' \
  /tmp/invoker_out.json | cat
cat /tmp/invoker_out.json
```

```shellscript
REST_ID=$(aws --region us-east-1 --endpoint-url http://localhost:4566 apigateway get-rest-apis \
  --query 'items[?name==`code-deploy-api`].id' -r)

# Trigger replication worker via POST /deploy
curl -s -X POST "http://localhost:4566/restapis/${REST_ID}/dev/_user_request_/deploy" -d '{}' | cat
```

```shellscript
aws --region us-east-1 --endpoint-url http://localhost:4566 stepfunctions validate-state-machine-definition \
  --definition file:///Users/nousunio/Repos/Learnings/algoexpert/system-design-practicals/iq1-code-deployment/terraform/infra/step_function_definition.json
```

```shellscript
cd /Users/nousunio/Repos/Learnings/algoexpert/system-design-practicals/iq1-code-deployment && docker compose down -v
bash get-started.sh
```

```shellscript
docker logs -f localstack-main | cat
```
