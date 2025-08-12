output "step_function_arn" {
  description = "ARN of the Step Function"
  value       = aws_sfn_state_machine.file_copy_workflow.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for file copy failures"
  value       = aws_sns_topic.file_copy_failures.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for file copy tracking"
  value       = aws_dynamodb_table.file_copy_tracking.name
}

output "api_gateway_execution_arn" {
  description = "Execution ARN of the API Gateway"
  value       = module.api_gateway.execution_arn
}
