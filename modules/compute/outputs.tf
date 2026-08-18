output "public_ip" {
  value       = aws_instance.web_server.public_ip
  description = "Public IP of the compute instance (for web access)"
}

output "instance_id" {
  value       = aws_instance.web_server.id
  description = "The ID of the EC2 instance for SSM targeting"
}