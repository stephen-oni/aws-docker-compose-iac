output "frontend_repository_url" {
  value       = module.ecr.frontend_repository_url
  description = "Frontend ECR repository URL"
}

output "backend_repository_url" {
  value       = module.ecr.backend_repository_url
  description = "Backend ECR repository URL"
}

output "ec2_public_ip" {
  value       = module.compute.public_ip
  description = "Public IP of the EC2 instance"
}