# EC2 Public IP (used for SSH and deployment)
output "ec2_public_ip" {
  description = "Public IP of EC2 instance"
  value       = aws_instance.app_instance.public_ip
}

# ECR Repository URLs
output "user_repo_url" {
  description = "ECR repository URL for user service"
  value       = aws_ecr_repository.user.repository_url
}

output "orders_repo_url" {
  description = "ECR repository URL for orders service"
  value       = aws_ecr_repository.orders.repository_url
}

output "inventory_repo_url" {
  description = "ECR repository URL for inventory service"
  value       = aws_ecr_repository.inventory.repository_url
}

# AWS Account ID (used for ECR login and tagging)
data "aws_caller_identity" "current" {}

output "aws_account_id" {
  description = "AWS Account ID for ECR access"
  value       = data.aws_caller_identity.current.account_id
}
