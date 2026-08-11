terraform {
  # This block ensures everyone on your team uses the same AWS provider version, 
  # preventing unexpected breaking changes.
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Use version 5.x of the AWS provider
    }
  }
}

provider "aws" {
  # The AWS region where your resources will be created
  region = "us-east-1" 
}