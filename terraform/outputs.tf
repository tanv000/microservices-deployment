output "ec2_public_ip" {
  description = "Public IP of EC2 instance"
  value       = aws_instance.app_instance.public_ip
}

output "user_repo_url" {
  value = aws_ecr_repository.user.repository_url
}

output "orders_repo_url" {
  value = aws_ecr_repository.orders.repository_url
}

output "inventory_repo_url" {
  value = aws_ecr_repository.inventory.repository_url
}
