Here is the updated, production-ready `README.md` file adjusted for your dynamic Terraform Cloud and GitHub Actions CI/CD automation workflow.

---

# Fully Containerized Three-Tier Architecture - Infrastructure & Deployment Guide

**Current Environment:** Development (`dev` branch)

## Overview

This repository contains the containerized decoupled architecture and Infrastructure as Code (IaC) for the application stack.

The infrastructure is provisioned automatically using **Terraform** managed via **Terraform Cloud**, deploying to an Amazon EC2 instance with an Elastic IP. Application delivery is fully automated via **GitHub Actions**, building Docker images, pushing them to **Amazon Elastic Container Registry (ECR)**, and deploying the containerized stack with **Docker Compose**.

---

## Architecture Topology & Code Explanation

```
[GitHub Push to dev] ──> [GitHub Actions Runner]
                               │
            ┌──────────────────┴──────────────────┐
            ▼                                     ▼
[1. Terraform Cloud (IaC)]          [2. Amazon ECR (Images)]
  ├── Network (VPC, Subnet, IGW)       ├── pulse-frontend:latest
  ├── ECR Repositories                 └── pulse-backend:latest
  └── Compute (EC2 + Elastic IP)                  │
            │                                     │
            └──────────────────┬──────────────────┘
                               ▼
            [3. Target EC2 Instance (Docker Compose)]
              ├── Frontend (Nginx:80)
              ├── Backend (Flask:5000)
              ├── Database (MySQL:3306)
              └── Adminer (GUI:8080)

```

The application runs on a custom Docker bridge network (`pulse_network`) on the host machine to ensure internal DNS resolution and container isolation.

1. **Frontend (Nginx):** Acts as the entry point, serving static web assets and operating as a reverse proxy. Web requests on Port 80 targeting `/api` are internally proxied to the backend container.
2. **Backend (Python/Flask):** A stateless REST API processing application logic, handling authentication, and executing database operations. It receives proxied requests on Port 5000 and is isolated from direct public access.
3. **Database (MySQL 8.2):** Relational database storing persistent state. Database state is preserved using Docker host volume mounts (`db_data`) mapped to `/var/lib/mysql`.
4. **Adminer:** Web-based database management tool running on Port 8080 for inspecting schemas and records during development.

---

## Infrastructure as Code (Terraform)

The infrastructure is modularized inside the `terraform/` or root repository structure and managed by **Terraform Cloud**:

```
├── modules/
│   ├── network/    # VPC, Internet Gateway, Public Subnet, Route Tables
│   ├── ecr/        # Amazon ECR Repositories for frontend and backend
│   └── compute/    # EC2 Instance, Security Groups, IAM Role, Elastic IP
├── main.tf         # Module orchestration
├── provider.tf     # AWS provider & default tagging
├── backend.tf      # Terraform Cloud remote backend configuration
├── variables.tf    # Infrastructure input variables
└── outputs.tf      # Exports static Elastic IP and ECR repository URLs

```

### Key Infrastructure Features:

* **IAM Instance Profile:** The EC2 instance is granted keyless read access (`AmazonEC2ContainerRegistryReadOnly`) to pull images directly from ECR.
* **Elastic IP (EIP):** Allocated and bound to the EC2 server, providing a static public IP endpoint that remains constant across instance restarts.

---

## CI/CD Pipeline (GitHub Actions)

Deployments are fully automated via `.github/workflows/deploy.yml` on every push to `dev` or `main`.

### Workflow Stages:

1. **Terraform Provisioning:** Authenticates with Terraform Cloud using `TF_API_TOKEN`, applies pending infrastructure changes, and captures the Elastic IP address (`public_ip`).
2. **Build & Push to ECR:** Authenticates with AWS, builds Docker images from `/frontend` and `/backend`, and pushes them with the `latest` tag to Amazon ECR.
3. **SSH Deployment:** Connects to the EC2 instance using the dynamically retrieved Elastic IP and SSH private key:
* Authenticates local Docker daemon to ECR via `aws ecr get-login-password`.
* Dynamically generates the runtime `.env` file from GitHub Secrets.
* Pulls updated images from ECR.
* Restarts the stack with `docker compose down --remove-orphans` and `docker compose up -d`.
* Prunes unused Docker image layers (`docker image prune -f`).



---

## Required Environment Variables & Secrets

To run this pipeline, configure the following secrets under **Repository Settings $\rightarrow$ Secrets and variables $\rightarrow$ Actions**:

| Secret Name | Purpose |
| --- | --- |
| `TF_API_TOKEN` | User/Team token for Terraform Cloud authentication |
| `AWS_ACCESS_KEY_ID` | IAM User access key with ECR/EC2/VPC permissions |
| `AWS_SECRET_ACCESS_KEY` | IAM User secret access key |
| `AWS_REGION` | Target AWS deployment region (e.g., `us-east-1`) |
| `EC2_USERNAME` | SSH user for the target server (e.g., `ubuntu`) |
| `EC2_SSH_KEY` | Private SSH key (`.pem`) for target instance authentication |
| `DB_USER` | MySQL database user |
| `DB_PASSWORD` | MySQL database root/user password |
| `DB_NAME` | Initial database schema name |
| `SECRET_KEY` | Application backend encryption key |

---

## Service Endpoints (Development)

| Service | Internal URI (Docker) | External Access (Browser) |
| --- | --- | --- |
| **Frontend UI** | `frontend:80` | `http://<elastic-ip>/` |
| **Backend API** | `backend:5000` | Internal proxy via Nginx |
| **MySQL Engine** | `db:3306` | Isolated within `pulse_network` |
| **Adminer GUI** | `adminer:8080` | `http://<elastic-ip>:8080` |

---

## Manual Server Operations

If you need to log into the EC2 server manually for maintenance:

```bash
# Connect to the instance
ssh -i /path/to/your-key.pem ubuntu@<elastic-ip>

# Navigate to the app directory
cd ~/app

# Inspect running containers
docker compose ps

# View real-time container logs
docker compose logs -f

# Force stack restart
docker compose restart

```

---

## Branching Strategy

* **`dev` (Current):** Single-node automated deployment using `docker-compose.yml`, Amazon ECR, Terraform Cloud, and Elastic IP.
* **`main` / `production`:** Multi-node deployment across isolated subnets behind an AWS Application Load Balancer (ALB) with SSL/TLS certificates and managed relational database services (RDS).