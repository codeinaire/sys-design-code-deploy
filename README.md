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
