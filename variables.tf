variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS deployment region"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Target deployment environment"
}

variable "vpc_cidr" {
  type        = string
  default     = "192.168.0.0/16"
  description = "VPC CIDR block"
}

variable "public_subnet_cidr" {
  type        = string
  default     = "192.168.1.0/24"
  description = "Public subnet CIDR block"
}

variable "availability_zone" {
  type        = string
  default     = "us-east-1a"
  description = "Target availability zone"
}

variable "ami_id" {
  type        = string
  default     = "ami-0c7217cdde317cfec"
  description = "Ubuntu AMI ID for target region"
}

variable "instance_type" {
  type        = string
  default     = "t3.small"
  description = "EC2 instance size"
}

variable "key_name" {
  type        = string
  default     = null
  description = "Optional SSH key pair name"
}