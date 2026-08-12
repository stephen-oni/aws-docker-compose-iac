output "public_ip" {
  value       = aws_eip.dev_eip.public_ip
  description = "Static Elastic IP address assigned to the EC2 server"
}