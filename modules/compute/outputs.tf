output "public_ip" {
  value       = aws_instance.web_server.public_ip
  description = "Public IP of the compute instance"
}

output "private_key_pem" {
  value       = tls_private_key.auto_key.private_key_pem
  description = "The generated private key for SSH access"
  sensitive   = true
}