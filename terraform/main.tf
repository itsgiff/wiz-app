# main.tf

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC and Networking
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  tags = var.common_tags
}

# Security Groups
resource "aws_security_group" "jumphost" {
  name        = "${var.project_name}-jumphost-sg"
  description = "Security group for jumphost (wiz-jump)"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-jumphost-sg"
  })
}

resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "Security group for database (wiz-db)"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description     = "MongoDB from VPC"
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    cidr_blocks     = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-db-sg"
  })
}

# Generate SSH key pair for jumphost to DB connection
resource "tls_private_key" "jumphost_db_key" {
  algorithm = var.ssh_key_algorithm
  rsa_bits  = var.ssh_key_rsa_bits
}

resource "aws_key_pair" "jumphost_db_key_pair" {
  key_name   = "${var.project_name}-jumphost-db-key"
  public_key = tls_private_key.jumphost_db_key.public_key_openssh
}

# IAM Role and Instance Profile for DB
resource "aws_iam_role" "db_role" {
  name = "${var.project_name}-db-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy" "db_policy" {
  name = "${var.project_name}-db-policy"
  role = aws_iam_role.db_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "ec2:*"
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Effect   = "Allow",
        Resource = [
          aws_s3_bucket.db_backups.arn,
          "${aws_s3_bucket.db_backups.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "db_profile" {
  name = "${var.project_name}-db-profile"
  role = aws_iam_role.db_role.name
}

# EC2 Instances
resource "aws_instance" "db" {
  ami           = var.ubuntu_ami
  instance_type = var.db_instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.db.id]
  subnet_id              = module.vpc.public_subnets[0]
  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.db_profile.name

  tags = merge(var.common_tags, {
    Name = "wiz-db"
  })

  user_data = <<-EOF
              #!/bin/bash
              # Install MongoDB and AWS CLI
              wget -qO - https://www.mongodb.org/static/pgp/server-${var.mongodb_version}.asc | sudo apt-key add -
              echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/${var.mongodb_version} multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-${var.mongodb_version}.list
              sudo apt-get update
              sudo apt-get install -y mongodb-org awscli

              # Start MongoDB
              sudo systemctl start mongod
              sudo systemctl enable mongod

              # Set up automatic backups
              echo '#!/bin/bash
              TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
              BACKUP_NAME="mongodb_backup_$TIMESTAMP.gz"
              
              # Perform MongoDB dump and compress it
              mongodump --archive | gzip > /tmp/$BACKUP_NAME
              
              # Upload to S3
              aws s3 cp /tmp/$BACKUP_NAME s3://${aws_s3_bucket.db_backups.id}/$BACKUP_NAME
              
              # Remove local backup
              rm /tmp/$BACKUP_NAME' > /home/ubuntu/backup_script.sh

              chmod +x /home/ubuntu/backup_script.sh

              # Set up cron job for daily backups at 2 AM
              (crontab -l 2>/dev/null; echo "0 2 * * * /home/ubuntu/backup_script.sh") | crontab -
              EOF
}

resource "aws_instance" "jumphost" {
  ami           = var.ubuntu_ami
  instance_type = var.jumphost_instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.jumphost.id]
  subnet_id              = module.vpc.public_subnets[0]
  associate_public_ip_address = true

  tags = merge(var.common_tags, {
    Name = "wiz-jump"
  })

  user_data = <<-EOF
              #!/bin/bash
              # Install AWS CLI
              sudo apt-get update
              sudo apt-get install -y awscli
              # Install kubectl
              sudo apt-get install -y apt-transport-https gnupg2
              curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
              echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
              sudo apt-get update
              sudo apt-get install -y kubectl
              EOF
}

# S3 Bucket for DB Backups
resource "aws_s3_bucket" "db_backups" {
  bucket = var.db_backup_bucket_name

  tags = merge(var.common_tags, {
    Name = var.db_backup_bucket_name
  })
}

resource "aws_s3_bucket_ownership_controls" "db_backups" {
  bucket = aws_s3_bucket.db_backups.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "db_backups" {
  bucket = aws_s3_bucket.db_backups.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "db_backups" {
  depends_on = [
    aws_s3_bucket_ownership_controls.db_backups,
    aws_s3_bucket_public_access_block.db_backups,
  ]

  bucket = aws_s3_bucket.db_backups.id
  acl    = "public-read"
}

resource "aws_s3_bucket_policy" "allow_public_read" {
  depends_on = [aws_s3_bucket_public_access_block.db_backups]

  bucket = aws_s3_bucket.db_backups.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.db_backups.arn}/*"
      }
    ]
  })
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "${var.project_name}-cluster"
  cluster_version = var.eks_cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      name         = "${var.project_name}-node-group"
      min_size     = var.eks_min_size
      max_size     = var.eks_max_size
      desired_size = var.eks_desired_size

      instance_types = [var.eks_instance_type]

      labels = {
        Environment = "dev"
      }

      # This ensures the node names start with "wiz-app"
      launch_template_name = "${var.project_name}-launch-template"
      launch_template_use_name_prefix = true
      launch_template_description = "EKS managed node group launch template"

      # Ensure the node names start with "wiz-app"
      pre_bootstrap_user_data = <<-EOT
        #!/bin/bash
        set -ex
        sed -i '/^KUBELET_EXTRA_ARGS=/a KUBELET_EXTRA_ARGS+=" --node-labels=eks.amazonaws.com/nodegroup=${var.project_name}-node-group,eks.amazonaws.com/nodegroup-image=$${KUBELET_IMAGE}"' /etc/eks/bootstrap.sh
        EOT
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-eks-cluster"
  })
}

# Kubernetes provider configuration
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
      command     = "aws"
    }
  }
}

# Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "wiz_db_public_ip" {
  description = "Public IP address of the wiz-db instance"
  value       = aws_instance.db.public_ip
}

output "wiz_jump_public_ip" {
  description = "Public IP address of the wiz-jump instance"
  value       = aws_instance.jumphost.public_ip
}

output "wiz_jump_public_dns" {
  description = "Public DNS of the wiz-jump instance"
  value       = aws_instance.jumphost.public_dns
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for DB backups"
  value       = aws_s3_bucket.db_backups.id
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "ssh_command_jumphost" {
  description = "Command to SSH into the wiz-jump instance"
  value       = "ssh -i <path-to-your-key> ubuntu@${aws_instance.jumphost.public_ip}"
}

output "ssh_command_db" {
  description = "Command to SSH into the wiz-db instance"
  value       = "ssh -i <path-to-your-key> ubuntu@${aws_instance.db.public_ip}"
}