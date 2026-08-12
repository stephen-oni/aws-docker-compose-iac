output "public_ip" {
  value       = module.compute.public_ip
  description = "Elastic IP assigned to the dev EC2 instance"
}

output "frontend_repository_url" {
  value       = module.ecr.frontend_repository_url
  description = "Frontend ECR repository URL"
}

output "backend_repository_url" {
  value       = module.ecr.backend_repository_url
  description = "Backend ECR repository URL"
}