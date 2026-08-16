# 1. Security Group for EC2
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

  # Outbound rule (Required for SSM Agent to reach AWS Control Plane)
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

# 2. IAM Role & Instance Profile for ECR Read-Only AND SSM Access
resource "aws_iam_role" "ec2_role" {
  name = "pulse-ec2-role"

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

# Attach ECR Read-Only Policy
resource "aws_iam_role_policy_attachment" "ecr_readonly_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Attach SSM Managed Instance Core Policy (This replaces SSH)
resource "aws_iam_role_policy_attachment" "ssm_core_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "pulse-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# 3. Provision the Single EC2 Instance (No Key Pair)
resource "aws_instance" "web_server" {
  ami                    = "ami-052355af2a014bd2c" # Official Ubuntu 24.04 LTS (amd64) us-east-1
  instance_type          = var.instance_type
  availability_zone      = "us-east-1a"
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }

  # THIS IS THE NEW PART: Automatically install Docker & AWS CLI on boot
  user_data = <<-EOF
    #!/bin/bash
    # Update package lists
    apt-get update -y

    # Install AWS CLI via Snap (highly reliable on Ubuntu)
    snap install aws-cli --classic

    # Install Docker and Docker Compose
    curl -fsSL https://get.docker.com | sh

    # Ensure Docker starts on boot
    systemctl enable --now docker

    # Add the default ubuntu user to the docker group
    usermod -aG docker ubuntu
  EOF

  # Force Terraform to recreate the instance if we change this script
  user_data_replace_on_change = true

  tags = {
    Name = "pulse-dev-server"
  }
}