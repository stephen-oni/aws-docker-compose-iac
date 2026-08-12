# 1. Create Security Group for EC2
resource "aws_security_group" "ec2_sg" {
  name        = "pulse-ec2-sg"
  description = "Security group for pulse app server"
  vpc_id      = var.vpc_id

  # HTTP / Web Application access
  ingress {
    description = "Allow HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Adminer UI access
  ingress {
    description = "Allow Adminer UI access"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH access
  ingress {
    description = "Allow SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rule to download packages, updates, and pull ECR images
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

# 2. IAM Role & Instance Profile for ECR Read-Only Access
resource "aws_iam_role" "ec2_ecr_role" {
  name = "pulse-ec2-ecr-read-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_readonly_attach" {
  role       = aws_iam_role.ec2_ecr_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "pulse-ec2-instance-profile"
  role = aws_iam_role.ec2_ecr_role.name
}

# 3. Provision the Single EC2 Instance
resource "aws_instance" "web_server" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  key_name                    = var.key_name
  user_data_replace_on_change = true

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y docker.io docker-compose-v2
              sudo systemctl start docker
              sudo systemctl enable docker
              sudo usermod -aG docker ubuntu
              EOF

  tags = {
    Name = "pulse-dev-server"
  }
}

# 4. Allocate Elastic IP and associate it with the EC2 Instance
resource "aws_eip" "dev_eip" {
  domain   = "vpc"
  instance = aws_instance.web_server.id

  tags = {
    Name = "pulse-dev-eip"
  }
}