provider "aws" {
  region = "us-east-1"
}

# Call the network module
module "my_network" {
  source = "./modules/network"
  
  # You can override the default variables here if needed
  vpc_cidr            = "192.168.0.0/16"
  public_subnet_cidr  = "192.168.1.0/24"
  private_subnet_cidr = "192.168.2.0/24"
  availability_zone   = "us-east-1a"
}

# Output the VPC ID to the console after applying
output "created_vpc_id" {
  value = module.my_network.vpc_id
}