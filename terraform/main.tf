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

# Use the default VPC (already exists in your AWS account)

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "availability-zone"
    values = ["us-east-1a"]
  }
}

# Security group: allow SSH (port 22) and HTTP (port 80) and app port 3000
resource "aws_security_group" "app_sg" {
  name        = "zero-downtime-app-sg"
  description = "Allow SSH and app traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "App port"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "zero-downtime-app-sg"
  }
}

# The EC2 instance itself

resource "aws_key_pair" "deploy_key" {
  key_name   = "zero-downtime-key"
  public_key = file("zero-downtime-key.pub")
}

resource "aws_instance" "app_server" {
  ami                    = "ami-0c02fb55956c7d316"  # Amazon Linux 2, us-east-1
  instance_type          = "t3.micro"
  subnet_id              = [for s in data.aws_subnets.default.ids : s if true][0]
  key_name               = aws_key_pair.deploy_key.key_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  tags = {
    Name = "zero-downtime-app-server"
  }
}

output "instance_public_ip" {
  value = aws_instance.app_server.public_ip
}