resource "aws_ecr_repository" "frontend" {
  name                 = "pulse-frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = "dev"
    Project     = "pulse"
  }
}

resource "aws_ecr_repository" "backend" {
  name                 = "pulse-backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = "dev"
    Project     = "pulse"
  }
}