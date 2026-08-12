output "public_ip" {
  value       = aws_instance.web_server.public_ip
  description = "Public IP of the compute instance"
}