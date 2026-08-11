# Fully Containerized Three-Tier Architecture - Infrastructure & Deployment Guide

**Current Environment:** Development (`dev` branch)

## Overview
This repository contains the containerized decoupled architecture for the application. The current infrastructure is designed for a single-node EC2 deployment, utilizing Docker Compose to orchestrate a frontend web server, a backend API, a relational database, and a database management GUI.

This setup is strictly for the **Development Environment**. Production infrastructure (spanning multiple VPC-isolated EC2 instances with SSL/TLS encryption) is managed in the `main`/`production` branch.

## Architecture Topology & Code Explanation

*[Insert Architecture Diagram Here]*

The application runs on a custom Docker bridge network (`pulse_network`) to ensure internal DNS resolution and container isolation.

1. **Frontend (Nginx):** Acts as the entry point. It serves the static HTML/CSS/JS files directly from its filesystem. It also operates as a reverse proxy. When a user action triggers an API call (e.g., submitting a login form to `/api/login`), Nginx intercepts this traffic on Port 80 and forwards it internally to the backend container.
2. **Backend (Python/Flask):** A stateless API processing business logic. It receives the proxied data from Nginx on Port 5000, connects to the database to verify credentials, encrypts passwords using `bcrypt`, and returns a JSON response. It is completely inaccessible from the public internet.
3. **Database (MySQL 8.2):** The stateful relational database. It stores user credentials and application data. Data persistence is handled via Docker named volumes (`db_data`) mapped to the host machine to survive container restarts.
4. **Adminer:** A lightweight, web-based database management tool for inspecting schemas and table contents during development via a browser interface.

## Prerequisites & Installation
Before deploying this stack, you must provision an EC2 instance, open the correct ports, and install the required tooling.

### 1. AWS Security Group Configuration
Ensure your EC2 instance's attached Security Group has the following inbound rules:
* Port `80` (HTTP) - Open to `0.0.0.0/0` (Public web traffic)
* Port `8080` (Adminer) - Restricted strictly to your personal IP address
* Port `22` (SSH) - Restricted strictly to your personal IP address

### 2. System Tooling Installation
Connect to your EC2 instance via SSH and run the following commands to install Git, Docker, and Docker Compose:
```bash
sudo apt-get update -y
sudo apt-get install git -y
sudo apt-get install docker.io -y
sudo apt-get install docker-compose-v2 -y
sudo usermod -aG docker $USER
newgrp docker

```

## Complete Deployment Process

### 1. Clone the Repository

Pull the source code to your EC2 instance and navigate into the project directory:

```bash
git clone [https://github.com/your-username/your-repo-name.git](https://github.com/your-username/your-repo-name.git)
cd your-repo-name

```

### 2. Environment Configuration

This project requires sensitive credentials to be passed at runtime. **Never commit the `.env` file to version control.** A `.gitignore` file is configured to block it.

Create a `.env` file in the root directory alongside `docker-compose.yml`:

```bash
touch .env

```

Populate the `.env` file with the required database parameters:

```text
DB_PASSWORD=your_secure_dev_password_here

```

### 3. Build and Boot the Stack

Build the Docker images from the source code and start all containers in detached mode:

```bash
docker compose up -d --build

```

### 4. Verify Container Health

Ensure all four containers (frontend, backend, db, adminer) are running and healthy:

```bash
docker compose ps

```

To inspect backend API logs for debugging:

```bash
docker compose logs backend -f

```

## Database Initialization

The database schema is automatically initialized on the first boot. The `init.sql` file in the root directory is mounted into `/docker-entrypoint-initdb.d/` inside the MySQL container.

This script creates the `my_website_db` database and the `users` table. **This script only executes if the mounted Docker volume (`db_data`) is completely empty.**

## Service Endpoints (Development)

| Service | Internal URI (Docker) | External Access (Browser) |
| --- | --- | --- |
| **Frontend UI** | `frontend:80` | `http://<ec2-public-ip>/` |
| **Backend API** | `backend:5000` | No direct external access (Proxied via Nginx) |
| **MySQL Engine** | `db:3306` | No direct external access |
| **Adminer GUI** | `adminer:8080` | `http://<ec2-public-ip>:8080` |

### Accessing Adminer

Navigate to `http://<ec2-public-ip>:8080` in your browser and use the following credentials:

* **System:** MySQL
* **Server:** `db`
* **Username:** `root`
* **Password:** *(Value of `DB_PASSWORD` in your `.env` file)*
* **Database:** `my_website_db`

## Teardown

To stop and remove the containers while preserving database state:

```bash
docker compose down

```

*Note: To completely wipe the environment, including persistent database volumes, run `docker compose down -v`.*

## Branching Strategy

* **`dev` (Current):** Single-node deployment utilizing `docker-compose.yml` on a shared bridge network. Used for local testing and CI/CD development pipelines.
* **`production` (Future):** Multi-node deployment across dedicated EC2 instances. Internal communication uses private AWS VPC IPv4 addresses and Security Group ingress rules instead of Docker bridge networks.