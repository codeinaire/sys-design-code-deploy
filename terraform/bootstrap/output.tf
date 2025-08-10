output "s3_bucket_name" {
  description = "Name of the S3 bucket used for Terraform state"
  value       = module.terraform_state_bucket.s3_bucket_id
}
