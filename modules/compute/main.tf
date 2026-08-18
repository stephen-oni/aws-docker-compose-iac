# Security Group for EC2
resource "aws_security_group" "ec2_sg" {
  name        = "pulse-ec2-sg"
  description = "Security group for pulse app server"
  vpc_id      = var.vpc_id

  # Public Web Application access only
  ingress {
    description = "Allow HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rule (Required for SSM Agent to communicate with AWS)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "pulse-ec2-sg"
  }
}