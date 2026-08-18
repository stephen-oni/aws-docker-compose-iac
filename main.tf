# 1. Network Module
module "network" {
  source = "./modules/network"

  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  availability_zone  = var.availability_zone
}

# 2. ECR Module
module "ecr" {
  source = "./modules/ecr"
}

# 3. Compute Module
module "compute" {
  source = "./modules/compute"

  vpc_id           = module.network.vpc_id
  public_subnet_id = module.network.public_subnet_id
  instance_type    = var.instance_type
}