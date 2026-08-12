variable "vpc_id" {
  type        = string
  description = "VPC ID passed from network module"
}

variable "public_subnet_id" {
  type        = string
  description = "Public Subnet ID passed from network module"
}

variable "ami_id" {
  type        = string
  default     = "ami-0c7217cdde317cfec" # Replace with valid Ubuntu 22.04/24.04 AMI in your AWS region
}

variable "instance_type" {
  type        = string
  default     = "t3.small"
  description = "EC2 instance type"
}

variable "key_name" {
  type        = string
  default     = null
  description = "Optional SSH key pair name"
}