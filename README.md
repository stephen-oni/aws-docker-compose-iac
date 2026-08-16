# Containerized Three-Tier Architecture - Infrastructure & Deployment Guide

## Overview

This repository contains the containerized decoupled architecture and Infrastructure as Code (IaC) for the application stack configured for the **dev environment**.

The infrastructure is provisioned automatically using **Terraform** using **Terraform Cloud** as a remote state backend. Container image compilation is automated via **GitHub Actions**, which builds and pushes production-ready Docker images to **Amazon Elastic Container Registry (ECR)**.

Application stack updates are executed manually on the EC2 host using Docker Compose.

---

## Infrastructure Architecture

![Infrastructure Architecture Diagram](./architecture.png)

---

## Architecture & CI/CD Flow

```text
[GitHub Push] ──> [GitHub Actions Runner]
                           │
        ┌──────────────────┴──────────────────┐
        ▼                                     ▼
[1. Terraform Cloud (State)]        [2. Amazon ECR (Images)]
  ├── Network (VPC, Subnet, IGW)       ├── pulse-frontend:latest
  ├── ECR Repositories                 └── pulse-backend:latest
  └── Compute (EC2 Instance & Key)                │
                                                  │ (Manual Pull & Deploy)
                                                  ▼
                                    [3. Production EC2 Instance]
                                      ├── Frontend (Nginx:80)
                                      ├── Backend (Flask:5000)
                                      ├── Database (MySQL:3306)
                                      └── Adminer (GUI:8080)

```

---

## Code Explanation

The application runs on a custom Docker bridge network (`pulse_network`) on the host machine for internal DNS resolution and container isolation.

1. **Frontend (Nginx):** Entry point serving static web assets and operating as a reverse proxy. Port 80 web traffic targeting `/api` is proxied internally to the backend container.
2. **Backend (Python/Flask):** Stateless REST API processing application logic, handling authentication, and executing database operations on Port 5000. It is isolated from direct public internet access.
3. **Database (MySQL 8.2):** Relational database storing application state. Data persistence is managed via Docker host volume mounts (`db_data`) mapped to `/var/lib/mysql`.
4. **Adminer:** Web-based database management interface running on Port 8080.

---

## Infrastructure as Code (Terraform)

The infrastructure is modularized and configured for remote execution via **Terraform Cloud**:

```text
├── modules/
│   ├── compute/    # Security Group, Dynamic AMI, TLS SSH Key, IAM Role & EC2
│   ├── ecr/        # Amazon ECR Repositories for frontend and backend
│   └── network/    # VPC (192.168.0.0/16), Internet Gateway, Public Subnet, Route Table
├── main.tf         # Module orchestration
├── outputs.tf      # Exports ECR repository URLs, EC2 Public IP, and Private Key
├── provider.tf     # Terraform Cloud backend configuration & AWS provider setup
└── variables.tf    # Root input variables (t3.micro, us-east-1a)

```

### Key Infrastructure Configuration

* **Dynamic AMI Lookup:** Automatically retrieves the latest official Canonical Ubuntu 24.04 LTS (`ubuntu-noble-24.04-amd64-server-*`) image from Canonical's account (`099720109477`).
* **Automated SSH Key Pair:** Automatically provisions an RSA 4096-bit SSH key pair (`tls_private_key`) and registers it with AWS EC2 (`pulse-auto-generated-key`).
* **IAM Instance Profile:** Attaches an IAM role (`pulse-ec2-ecr-read-role`) with `AmazonEC2ContainerRegistryReadOnly` permissions to the EC2 instance for keyless image pulling from Amazon ECR.
* **Zero Credential Exposure:** AWS credentials and API tokens remain securely stored inside GitHub Repository Secrets.

---

## CI/CD Pipeline (GitHub Actions)

The pipeline is defined in `.github/workflows/cicd.yml` and triggers automatically on pushes to `dev`.

### Workflow Stages:

1. **Terraform Provisioning:** Authenticates with Terraform Cloud using `TF_API_TOKEN`, passes AWS environment credentials, and runs `terraform apply -auto-approve`.
2. **Build & Push to ECR:** Authenticates with AWS via IAM secrets, builds Docker images for `/frontend` and `/backend`, and pushes them with the `latest` tag to Amazon ECR.

---

## Required CI/CD Secrets

Configure the following secrets under **Repository Settings $\rightarrow$ Secrets and variables $\rightarrow$ Actions**:

| Secret Name | Purpose |
| --- | --- |
| `TF_API_TOKEN` | User API token for Terraform Cloud authentication |
| `AWS_ACCESS_KEY_ID` | IAM User access key with ECR/EC2/VPC execution permissions |
| `AWS_SECRET_ACCESS_KEY` | IAM User secret access key |
| `AWS_REGION` | Target AWS deployment region (`us-east-1`) |

---

## Manual Production Deployment Process

To deploy or update the stack on your EC2 instance:

### 1. Extract the Generated Private Key (First-time setup)

Fetch the automatically generated SSH private key from Terraform output and save it locally:

```bash
terraform output -raw private_key_pem > pulse-key.pem
chmod 400 pulse-key.pem

```

### 2. Connect to the EC2 Instance

```bash
ssh -i pulse-key.pem ubuntu@<ec2-public-ip>
cd ~/app

```

### 3. Authenticate Docker with Amazon ECR

```bash
aws ecr get-login-password --region <your-aws-region> | docker login --username AWS --password-stdin <your-account-id>.dkr.ecr.<your-aws-region>.amazonaws.com

```

### 4. Pull & Restart Stack

```bash
# Export the ECR Registry URI
export ECR_REGISTRY=<your-account-id>.dkr.ecr.<your-aws-region>.amazonaws.com

# Pull updated container images
docker compose pull

# Restart container services
docker compose down --remove-orphans
docker compose up -d

# Clean up stale/unused image layers
docker image prune -f

```

---

## Service Endpoints

| Service | Internal URI (Docker) | External Access (Browser) |
| --- | --- | --- |
| **Frontend UI** | `frontend:80` | `http://<ec2-public-ip>/` |
| **Backend API** | `backend:5000` | Internal proxy via Nginx |
| **MySQL Engine** | `db:3306` | Isolated within `pulse_network` |
| **Adminer GUI** | `adminer:8080` | `http://<ec2-public-ip>:8080` |