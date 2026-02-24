#!/bin/bash
set -euo pipefail

apt-get update -y
apt-get install -y ca-certificates curl gnupg git make

# Docker official repo
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y \
  docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

usermod -aG docker ubuntu
hostnamectl set-hostname edot-demo

# Clone the demo repo
sudo -u ubuntu git clone https://github.com/jamie-p-pope/otel-elastic-demo.git \
  /home/ubuntu/otel-elastic-demo

# Pre-clone Elastic OTel demo so it's ready on first SSH
sudo -u ubuntu git clone https://github.com/elastic/opentelemetry-demo.git \
  /home/ubuntu/otel-elastic-demo/elastic-otel-demo/opentelemetry-demo

%{~ if elasticsearch_endpoint != "" }
# Pre-configure Elastic credentials
cat > /home/ubuntu/otel-elastic-demo/elastic-otel-demo/opentelemetry-demo/.env.override <<ENVEOF
ELASTICSEARCH_ENDPOINT=${elasticsearch_endpoint}
ELASTICSEARCH_API_KEY=${elasticsearch_api_key}
ENVEOF
chown ubuntu:ubuntu /home/ubuntu/otel-elastic-demo/elastic-otel-demo/opentelemetry-demo/.env.override
chmod 600 /home/ubuntu/otel-elastic-demo/elastic-otel-demo/opentelemetry-demo/.env.override
%{~ endif }
