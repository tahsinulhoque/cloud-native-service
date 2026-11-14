#!/bin/bash
set -euxo pipefail

# Install Docker
apt-get update -y
apt-get install -y docker.io

systemctl enable docker
systemctl start docker

# Pull application image
docker pull "${IMAGE}"

# Run application container with CloudWatch logging
docker run -d \
  --name cloud-native-service \
  --restart unless-stopped \
  -e "ENVIRONMENT=${ENVIRONMENT}" \
  -p 80:8000 \
  --log-driver=awslogs \
  --log-opt awslogs-region=us-west-2 \
  --log-opt "awslogs-group=/cloud-native-service/${ENVIRONMENT}" \
  --log-opt awslogs-create-group=false \
  "${IMAGE}"
