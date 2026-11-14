# Cloud Native Service

A production-oriented Python FastAPI application built as part of a DevOps Engineer technical assessment. This project demonstrates containerization, application observability, automated testing, and secure deployment practices.

**Project Status:** Step 1 – Application & Containerization completed. Further assessment stages are in progress.

## Project Overview

Cloud Native Service is a lightweight REST API designed to demonstrate a production-oriented DevOps workflow.

### Current Features

- REST API built with Python and FastAPI
- Health check endpoint
- Prometheus-compatible application metrics
- Structured JSON logging to stdout
- Automated unit testing with Pytest
- Multi-stage Docker build
- Non-root container execution
- Docker HEALTHCHECK
- Docker Compose with resource limits
- Graceful application shutdown

## Technology Stack

| Category | Technology |
|---|---|
| Language | Python 3.14.3 |
| Framework | FastAPI |
| API Server | Uvicorn |
| Metrics | Prometheus Client |
| Testing | Pytest |
| Containerization | Docker |
| Orchestration (Local) | Docker Compose |
| Version Control | Git & GitHub |

## Project Structure

```text
cloud-native-service/
│
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── config.py
│   └── logging_config.py
│
├── tests/
│   └── test_app.py
│
├── docs/
│   └── screenshots/
│
├── Dockerfile
├── docker-compose.yml
├── .dockerignore
├── .gitignore
├── requirements.txt
└── requirements-dev.txt
```

## API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| GET | `/` | Application information |
| GET | `/health` | Application health check |
| GET | `/metrics` | Prometheus metrics |

### Root Response

```json
{
  "message": "Hello from DevOps Task!",
  "status": "running",
  "version": "1.0.0"
}
```

### Health Response

```json
{
  "status": "healthy",
  "environment": "development"
}
```

### API Documentation

FastAPI Swagger UI:

`http://localhost:8000/docs`

## Local Development

### Prerequisites

- Python 3.14.3
- Git
- Docker Desktop (for container deployment)

### Clone Repository

```bash
git clone https://github.com/tahsinulhoque/cloud-native-service.git

cd cloud-native-service
```

### Create Virtual Environment

Windows PowerShell:

```powershell
py -3.14 -m venv .venv

.\.venv\Scripts\Activate.ps1
```

### Install Dependencies

```powershell
python -m pip install -r requirements-dev.txt
```

### Run Application

```powershell
python -m uvicorn app.main:app --reload --port 8000
```

Application:

`http://localhost:8000`

## Testing

Run the unit tests:

```powershell
python -m pytest -v
```

Current test coverage includes:

- Root endpoint
- Health endpoint
- Prometheus metrics endpoint

**Latest verified result:** 3 tests passed.

## Docker Deployment

### Build Docker Image

```bash
docker build -t cloud-native-service:1.0.0 .
```

### Run Container

```bash
docker run -d \
  --name cloud-native-test \
  -p 8080:8000 \
  cloud-native-service:1.0.0
```

### Docker Compose

```bash
docker compose up --build -d
```

Check container status:

```bash
docker compose ps
```

View application logs:

```bash
docker compose logs -f app
```

Stop services:

```bash
docker compose down
```

### Container Security

The current Docker configuration implements:

- Multi-stage image build
- Version-pinned Python base image
- Non-root application user
- Docker HEALTHCHECK
- OCI image labels
- Resource limits through Docker Compose

### Image Size

Latest local Docker build measurement:

| Measurement | Result |
|---|---:|
| Docker content size | 50.3 MB |
| Docker disk usage | 207 MB |

These are different Docker-reported measurements.

## Observability

The application exposes Prometheus-compatible metrics:

- HTTP request count
- HTTP error count
- HTTP request latency histogram

Structured JSON logs are written to standard output for container log collection.

**Planned:** Prometheus, Grafana, Loki, Grafana Alloy, Node Exporter and cAdvisor integration.

## CI/CD Pipeline

**Status: Pending implementation**

Planned GitHub Actions workflow:

- Pull request validation
- Python linting and unit testing
- Test coverage reporting
- Dockerfile linting with Hadolint
- Shell script linting with ShellCheck
- Trivy vulnerability scanning
- Multi-architecture Docker image build
- SHA and semantic version tagging
- Container registry publishing
- EC2 deployment, smoke testing and rollback

## Infrastructure as Code

**Status: Pending implementation**

Planned AWS infrastructure using Terraform:

- VPC and EC2
- Security groups
- IAM instance profile
- Docker installation and application bootstrap
- CloudWatch Logs
- S3 remote Terraform state with locking

## Kubernetes Deployment

**Status: Pending implementation**

Planned local Kubernetes deployment:

- Kubernetes Deployment
- Minimum two replicas
- Rolling updates
- Liveness and readiness probes
- Kubernetes Service
- ConfigMap and Secret
- Resource requests and limits
- Security context
- Horizontal Pod Autoscaler

## Linux Automation

**Status: Pending implementation**

Planned `system_health.sh` script for:

- CPU utilization
- Memory utilization
- Disk usage
- Load average
- Top five memory-consuming processes
- JSON output
- Configurable warning thresholds
- Log rotation and meaningful exit codes

## Architecture

The intended end-to-end architecture:

```text
Developer
    |
    v
GitHub Repository
    |
    v
GitHub Actions CI/CD
    |
    +-- Lint
    +-- Unit Tests
    +-- Coverage
    +-- Security Scan
    |
    v
Container Registry
    |
    v
AWS EC2 Deployment
    |
    +-- Docker Application
    |
    +-- Kubernetes Deployment
         (separate local deployment flow)

Observability:
Application + Host + Containers
              |
              v
       Prometheus / Alloy
              |
         +----+----+
         |         |
         v         v
     Metrics     Loki
         |         |
         +----+----+
              |
              v
           Grafana
```

The full architecture will be updated as the CI/CD, infrastructure, Kubernetes and observability components are implemented.

## Design Decisions

- **FastAPI:** Selected for lightweight API development and automatic API documentation.
- **Multi-stage Docker build:** Separates dependency installation from the runtime image.
- **Non-root execution:** Reduces container-level privileges.
- **Structured JSON logging:** Makes application logs easier to parse and analyze.
- **Prometheus metrics:** Provides a standard format for monitoring application performance.
- **Environment-based configuration:** Separates application configuration from source code.

## Deployment & Rollback Strategy

Planned deployment approach:

1. Validate changes through CI.
2. Build and scan the container image.
3. Tag the image using the commit SHA and semantic version.
4. Publish the image to a container registry.
5. Deploy the new image to EC2.
6. Run a health-check smoke test.
7. Automatically restore the previous image if deployment fails.

## Security Considerations

The project is being developed with the following security practices:

- Non-root container execution
- No hardcoded application secrets
- Docker image vulnerability scanning
- IAM least-privilege permissions
- Restricted network exposure
- Secure configuration management

Additional security controls will be documented as they are implemented.

## AWS Cost Estimation

A production monthly AWS cost estimate will be added after the infrastructure architecture and resource sizing are finalized.

Actual cost will depend on the selected AWS region, EC2 instance, storage, network traffic and monitoring configuration.

## What I Would Improve With More Time

- Stronger application integration testing
- Improved dependency vulnerability management
- Automated deployment observability
- Infrastructure policy validation
- More advanced alerting and incident automation
- Production-grade secrets management

## AI Tool Usage

AI tools were used as development assistance for implementation guidance, troubleshooting, documentation and technical explanations. All application code, configurations and infrastructure decisions will be reviewed and validated by the candidate, who is responsible for understanding the submitted implementation.

## Author

**Md. Tahsinul Hoque Siddiki**

GitHub: https://github.com/tahsinulhoque

Project Repository: https://github.com/tahsinulhoque/cloud-native-service
