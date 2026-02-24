terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ---------------------------------------------------------------------------
# Optional credentials — set in terraform.tfvars (gitignored)
# If provided, the instance will be pre-configured and ready to run make start
# ---------------------------------------------------------------------------
variable "elasticsearch_endpoint" {
  description = "Elasticsearch endpoint for the EDOT demo (optional — fill in .env.override after launch if not provided)"
  default     = ""
}

variable "elasticsearch_api_key" {
  description = "Elasticsearch API key for the EDOT demo (optional)"
  default     = ""
  sensitive   = true
}

variable "additional_tags" {
  description = "Additional tags required by your AWS organization (e.g. division, org, team, project, keep-until)"
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Security group
# Ports: 22 (SSH), 8080/8089 (EDOT demo default), 8180/8189 (side-by-side)
# ---------------------------------------------------------------------------
resource "aws_security_group" "edot_demo" {
  name        = "edot-demo"
  description = "Elastic EDOT demo instance"
  vpc_id      = "vpc-05bc2eb997ce04e92"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "EDOT demo frontend"
  }

  ingress {
    from_port   = 8089
    to_port     = 8089
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "EDOT demo Locust"
  }

  ingress {
    from_port   = 8180
    to_port     = 8180
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "EDOT demo frontend (side-by-side offset)"
  }

  ingress {
    from_port   = 8189
    to_port     = 8189
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "EDOT demo Locust (side-by-side offset)"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound"
  }

  tags = merge(
    {
      Name      = "jamiepope-edot-demo"
      ManagedBy = "Terraform"
    },
    var.additional_tags
  )
}

# ---------------------------------------------------------------------------
# EC2 instance
# Matches existing instance config: same AMI, VPC, subnet, key pair, IAM profile
# t3.xlarge (4 vCPU / 16 GB) — EDOT full stack needs ~8 GB minimum
# 30 GB root volume — Docker images for 17+ services are large
# ---------------------------------------------------------------------------
resource "aws_instance" "edot_demo" {
  ami                         = "ami-005fc0f236362e99f"  # Ubuntu 22.04 LTS us-east-1
  instance_type               = "t3.xlarge"
  key_name                    = "jamie-pope-mbp"
  subnet_id                   = "subnet-0b7b6b5e78afe2154"
  vpc_security_group_ids      = [aws_security_group.edot_demo.id]
  iam_instance_profile        = "AmazonSSMRoleForInstancesQuickSetup"
  associate_public_ip_address = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  # Bootstrap: Docker (Compose v2), git, make
  user_data = <<-EOF
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

    %{~ if var.elasticsearch_endpoint != "" }
    # Pre-configure Elastic credentials
    cat > /home/ubuntu/otel-elastic-demo/elastic-otel-demo/opentelemetry-demo/.env.override <<ENVEOF
ELASTICSEARCH_ENDPOINT=${var.elasticsearch_endpoint}
ELASTICSEARCH_API_KEY=${var.elasticsearch_api_key}
ENVEOF
    chown ubuntu:ubuntu /home/ubuntu/otel-elastic-demo/elastic-otel-demo/opentelemetry-demo/.env.override
    chmod 600 /home/ubuntu/otel-elastic-demo/elastic-otel-demo/opentelemetry-demo/.env.override
    %{~ endif }
  EOF

  tags = merge(
    {
      Name      = "jamiepope-edot-demo"
      ManagedBy = "Terraform"
    },
    var.additional_tags
  )
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------
output "public_ip" {
  value       = aws_instance.edot_demo.public_ip
  description = "Public IP of the EDOT demo instance"
}

output "ssh_command" {
  value       = "ssh ubuntu@${aws_instance.edot_demo.public_ip}"
  description = "SSH command"
}

output "next_steps" {
  value = <<-MSG
    Instance ready. Next steps:
      1. SSH in:     ssh ubuntu@${aws_instance.edot_demo.public_ip}
      2. Start demo: cd ~/otel-elastic-demo/elastic-otel-demo/opentelemetry-demo && make start
      3. Frontend:   http://${aws_instance.edot_demo.public_ip}:8080
      4. Locust:     http://${aws_instance.edot_demo.public_ip}:8089

    Note: If elasticsearch_endpoint/elasticsearch_api_key were not set in
    terraform.tfvars, edit .env.override before running make start:
      ~/otel-elastic-demo/elastic-otel-demo/opentelemetry-demo/.env.override
  MSG
}
