variable "vpc_cidr" {
  type        = string
  default     = "192.168.0.0/16"
  description = "private IP block for the VPC"
}

variable "public_subnet_cidr" {
  type        = string
  default     = "192.168.1.0/24"
  description = "CIDR block for the public subnet"
}


variable "availability_zone" {
  type        = string
  default     = "us-east-1a"
  description = "Availability zone for the subnets"
}

