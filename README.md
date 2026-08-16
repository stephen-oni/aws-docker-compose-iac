# Containerized Three-Tier Architecture (Development Environment)

## Overview

This repository contains the containerized decoupled architecture and Infrastructure as Code (IaC) for a three-tier application stack. **This specific configuration is explicitly designed for a Development (Dev) Environment.**

The infrastructure is provisioned automatically using **Terraform** with **HCP Terraform (Terraform Cloud)** as a remote state backend. Container image compilation, push automation, and remote EC2 deployment are handled via a fully automated **GitHub Actions** CI/CD pipeline.

---

## ⚠️ Security Notice: Dev vs. Production Secrets

For the purpose of this development environment, configuration values and credentials are stored securely in **GitHub Secrets** and injected into the execution environment at runtime.

If adapting this architecture for a strict **Production Environment**, secrets and access management should be decoupled and modernized:

* **AWS Credentials:** Replace long-lived IAM keys (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`) with **GitHub OIDC (OpenID Connect)** to request temporary STS tokens.
* **Application Secrets:** Move database credentials (`DB_PASSWORD`) and application keys (`SECRET_KEY`) out of GitHub Secrets and CI/CD memory. Store them natively in **AWS Secrets Manager** or **AWS Systems Manager (SSM) Parameter Store**, allowing the EC2 instance to retrieve them dynamically via an IAM Instance Profile.
* **Server Access:** Replace the static SSH key (`EC2_SSH_KEY`) with **AWS SSM Session Manager** for keyless, port-free remote execution.

---

## Infrastructure Architecture

### Architecture & CI/CD Flow

```text
[GitHub Push (dev)] ──> [GitHub Actions Runner]
                               │
        ┌──────────────────────┴──────────────────────┐
        ▼                                             ▼
[1. Terraform Cloud (State)]                [2. Amazon ECR (Images)]
  ├── Network (VPC 192.168.0.0/16)               ├── pulse-frontend:latest
  ├── ECR Repositories                           └── pulse-backend:latest
  └── Compute (EC2 t3.micro)                                  │
        │                                                     │
        └───────────────── (Dynamic IP Handoff) ──────────────┘
                                                              ▼
                                                [3. Remote EC2 Deployment via SSH]
                                                  ├── Frontend (Nginx:80)
                                                  ├── Backend (Flask:5000)
                                                  ├── Database (MySQL:3306)
                                                  └── Adminer (GUI:8080)

```

---

## Detailed CI/CD Pipeline Steps

The pipeline is defined in `.github/workflows/cicd.yml` and triggers automatically on pushes and pull requests targeting the `dev` branch. It completely eliminates the need for manual server configuration.

**Step 1: Terraform Provisioning**

* Authenticates with HCP Terraform using `TF_API_TOKEN`.
* Runs `terraform init`, `fmt`, `validate`, and `plan`.
* Executes `terraform apply -auto-approve` to provision the VPC, subnets, ECR repositories, and the EC2 instance.
* Captures the newly provisioned EC2 Public IP as a dynamic pipeline output variable, eliminating the need to hardcode the server IP in GitHub Secrets.

**Step 2: Build & Push to ECR**

* Authenticates Docker with the AWS environment.
* Builds the `/frontend` and `/backend` container images.
* Tags and pushes both images to their respective private Amazon ECR repositories.

**Step 3: Automated EC2 Deployment**

* The GitHub runner securely connects to the EC2 instance via SSH using the dynamically generated IP from Step 1.
* Authenticates the EC2 Docker engine with Amazon ECR.
* Copies `docker-compose.yml` and `init.sql` to the server via SCP.
* Injects environment variables and database secrets entirely in-memory during the `docker compose pull` and `docker compose up -d` execution, ensuring no `.env` files are ever written to the EC2 storage disk.

---

## Required GitHub Actions Secrets & Variables

To run this automated pipeline, configure the following under **Repository Settings $\rightarrow$ Secrets and variables $\rightarrow$ Actions**:

### Secrets (Encrypted values)

| Secret Name | Purpose |
| --- | --- |
| `TF_API_TOKEN` | User API token for Terraform Cloud authentication |
| `AWS_ACCESS_KEY_ID` | IAM User access key with required execution permissions |
| `AWS_SECRET_ACCESS_KEY` | IAM User secret access key |
| `EC2_SSH_KEY` | The raw multi-line `.pem` private key used to access the EC2 instance |
| `DB_PASSWORD` | Secure password for the MySQL database |
| `SECRET_KEY` | Application backend session/encryption key |

### Variables (Plaintext configuration)

| Variable Name | Purpose |
| --- | --- |
| `AWS_REGION` | Target AWS deployment region (e.g., `us-east-1`) |
| `AWS_ACCOUNT_ID` | Your 12-digit AWS account ID |
| `DB_USER` | MySQL database username (e.g., `pulseuser`) |
| `DB_NAME` | MySQL database name (e.g., `pulsedb`) |

---

## Infrastructure as Code (Terraform) Details

The Terraform code (`main.tf`, `modules/`) utilizes a highly automated approach tailored for this dev stack:

* **Pinned Canonical AMI:** Uses official Ubuntu 24.04 LTS pinned to a specific availability zone for consistent builds.
* **Current-Gen Free-Tier Compute:** Deploys a `t3.micro` instance with an 8 GB GP3 root volume to comply with AWS constraints.
* **IAM Instance Profile:** Attaches an IAM role (`pulse-ec2-ecr-read-role`) with `AmazonEC2ContainerRegistryReadOnly` permissions so the server can seamlessly pull private images.

---

## Service Endpoints

Once the GitHub Actions pipeline successfully completes, your stack is accessible at the following endpoints:

| Service | Internal URI (Docker) | External Access (Browser) |
| --- | --- | --- |
| **Frontend UI** | `frontend:80` | `http://<ec2-public-ip>/` |
| **Backend API** | `backend:5000` | Internal proxy via Nginx (`/api`) |
| **MySQL Engine** | `db:3306` | Isolated within `pulse_network` |
| **Adminer GUI** | `adminer:8080` | `http://<ec2-public-ip>:8080` |

---

## Infrastructure Teardown (Destroy)

To completely delete all provisioned AWS resources and avoid lingering billing charges:

1. Open `.github/workflows/cicd.yml`.
2. Locate the **Terraform Apply** step and change `terraform apply` to `terraform destroy`:
```yaml
- name: Terraform Destroy
  if: github.ref == 'refs/heads/dev' && github.event_name == 'push'
  run: |
    terraform destroy -auto-approve -input=false

```


3. Commit and push the workflow file to the `dev` branch:
```bash
git add .github/workflows/cicd.yml
git commit -m "chore: trigger infrastructure teardown"
git push origin dev

```


4. GitHub Actions will execute the destroy command, safely terminating all VPCs, Subnets, EC2 instances, and ECR repositories from your AWS account. Revert the workflow file back to `apply` when you are ready to provision again.