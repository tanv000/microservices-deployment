terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.6.0"
}

provider "aws" {
  region = var.aws_region
}

# --- Remote State Backend Resources ---

# 1. S3 Bucket for Remote State File
# Note: Bucket name must be globally unique.
resource "aws_s3_bucket" "terraform_state" {
  bucket = "microservices-state-bucket-tanv000" # MUST MATCH 'backend.tf'

  tags = {
    Name = "Microservices-Terraform-State"
  }
}

# Enforce encryption on the state bucket (Security Best Practice)
resource "aws_s3_bucket_server_side_encryption_configuration" "state_bucket_encryption" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Enable versioning to keep a history of the state file (Best Practice)
resource "aws_s3_bucket_versioning" "state_bucket_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 2. DynamoDB Table for State Locking (Prevents concurrent 'terraform apply' runs)
resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = "terraform-state-lock" # MUST MATCH 'backend.tf'
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "Terraform State Lock Table"
  }
}

# --- Original Infrastructure Resources (omitted for brevity, assume they follow below) ---

# Security Group (SSH + app ports)
resource "aws_security_group" "app_sg" {
  name        = "microservices-sg"
  description = "Allow SSH and microservice ports"
  # Note: For production, replace 0.0.0.0/0 with your IP or CIDR
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5001
    to_port     = 5003
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "microservices-sg"
  }
}

# EC2 Instance and all subsequent original resources...
resource "aws_instance" "app_instance" {
  ami           = "ami-041e2808018d96e51" # Amazon Linux 2 AMI for ap-south-1 (Mumbai)
  instance_type = var.instance_type
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  # ECR, Docker, and AWS CLI setup script
  user_data = <<-EOF
              #!/bin/bash
              # Install Docker
              yum update -y
              amazon-linux-extras install docker -y || true
              systemctl enable docker
              systemctl start docker
              usermod -aG docker ec2-user

              # Install Docker Compose v2
              DOCKER_CONFIG=/home/ec2-user/.docker
              mkdir -p $DOCKER_CONFIG/cli-plugins
              curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" -o $DOCKER_CONFIG/cli-plugins/docker-compose
              chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
              chown -R ec2-user:ec2-user $DOCKER_CONFIG

              # Add Docker Compose to PATH for all users
              echo "export PATH=\$PATH:/home/ec2-user/.docker/cli-plugins" >> /etc/profile.d/docker-compose.sh
              source /etc/profile.d/docker-compose.sh

              # Install AWS CLI v2
              yum install -y unzip curl || true
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
              unzip /tmp/awscliv2.zip -d /tmp
              /tmp/aws/install || true

              # Create deploy folder
              mkdir -p /home/ec2-user/deploy
              chown -R ec2-user:ec2-user /home/ec2-user/deploy
              EOF

  tags = {
    Name = "Microservices-Host"
  }
}

# ECR Repositories
resource "aws_ecr_repository" "user" {
  name                 = "microservice-user"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "orders" {
  name                 = "microservice-orders"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "inventory" {
  name                 = "microservice-inventory"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}