output "domain_id" {
  description = "SageMaker Studio Domain ID"
  value       = aws_sagemaker_domain.studio.id
}

output "domain_arn" {
  description = "SageMaker Studio Domain ARN"
  value       = aws_sagemaker_domain.studio.arn
}

output "domain_url" {
  description = "SageMaker Studio Domain URL"
  value       = aws_sagemaker_domain.studio.url
}

output "user_profile_arn" {
  description = "SageMaker Studio User Profile ARN"
  value       = aws_sagemaker_user_profile.default_user.arn
}

output "user_profile_name" {
  description = "SageMaker Studio User Profile Name"
  value       = aws_sagemaker_user_profile.default_user.user_profile_name
}

output "security_group_id" {
  description = "Security Group ID for SageMaker Studio"
  value       = aws_security_group.sagemaker_studio.id
}

output "vpc_id" {
  description = "VPC ID used by SageMaker Studio"
  value       = aws_default_vpc.default.id
}

output "subnet_ids" {
  description = "Subnet IDs used by SageMaker Studio"
  value       = [
    aws_default_subnet.default_az1.id,
    aws_default_subnet.default_az2.id
  ]
}
