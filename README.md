# sys-design-code-deploy

An implementation of a code deploy system based on the answer to AlgoExpert's system design questions.

## Useful Info

To use the aws cli tool [some configuration needs to be done](https://docs.localstack.cloud/aws/integrations/aws-native-tools/aws-cli/#localstack-aws-cli-awslocal) or the awslocalstack wrapper can be used. I prefer to use the regular aws cli as it's a straight forward configuration and using the wrappy requires downgrading to aws cli v1

## Useful Commands

This checks the health of the localstack docker container and will output what's running

`curl http://localhost:4566/_localstack/health`
