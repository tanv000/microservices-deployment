#
# This file configures the remote state backend using AWS S3.
#
#
terraform {
  backend "s3" {
    # Replace 'microservices-state-bucket-yourname' with a globally unique bucket name.
    bucket         = "microservices-state-bucket-tanv000"
    key            = "microservices-deployment/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}