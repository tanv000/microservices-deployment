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

# IAM role for EC2 to access ECR
resource "aws_iam_role" "ec2_role" {
  name = "microservices-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Attach AmazonEC2ContainerRegistryReadOnly (or FullAccess if you prefer)
resource "aws_iam_role_policy_attachment" "ec2_role_ecr" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "microservices-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# ECR repositories
resource "aws_ecr_repository" "user" {
  name = "user-service-repo"
}

resource "aws_ecr_repository" "orders" {
  name = "orders-service-repo"
}

resource "aws_ecr_repository" "inventory" {
  name = "inventory-service-repo"
}

# EC2 instance
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "app_instance" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # user_data to install docker, docker-compose and awscli, and prepare deploy folder
  user_data = <<-EOF
              #!/bin/bash
              set -e
              yum update -y || true
              amazon-linux-extras install docker -y || true
              systemctl start docker || service docker start || true
              systemctl enable docker || true
              usermod -aG docker ec2-user || true

              # Install docker-compose (binary)
              curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
              chmod +x /usr/local/bin/docker-compose

              # Install AWS CLI v2
              yum install -y unzip || true
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
              unzip /tmp/awscliv2.zip -d /tmp
              /tmp/aws/install || true

              # create deploy folder
              mkdir -p /home/ec2-user/deploy
              chown -R ec2-user:ec2-user /home/ec2-user/deploy
              EOF

  tags = {
    Name = "microservices-app"
  }
}
