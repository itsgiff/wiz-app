# variables.tf

variable "aws_region" {
  description = "AWS region to deploy resources"
  default     = "us-west-2"
}

variable "project_name" {
  description = "Name of the project, used in resource naming"
  default     = "wiz-app"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "ubuntu_ami" {
  description = "AMI ID for Ubuntu Server 22.04 LTS"
  default     = "ami-0075013580f6322a1"  # Ubuntu Server 22.04 LTS in us-west-2
}

variable "key_name" {
  description = "Name of the EC2 key pair to use for the instances"
  type        = string
}

variable "db_instance_type" {
  description = "Instance type for the database server (wiz-db)"
  default     = "t3.micro"
}

variable "jumphost_instance_type" {
  description = "Instance type for the jumphost (wiz-jump)"
  default     = "t3.micro"
}

variable "db_backup_bucket_name" {
  description = "Name of the S3 bucket for database backups"
  default     = "wiz-app-db-backups"
}

variable "common_tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
  default = {
    Project     = "wiz-app"
    Environment = "dev"
    Terraform   = "true"
  }
}

variable "mongodb_version" {
  description = "Version of MongoDB to install"
  default     = "5.0"
}

variable "ssh_key_algorithm" {
  description = "Algorithm for the SSH key used between wiz-jump and wiz-db"
  default     = "RSA"
}

variable "ssh_key_rsa_bits" {
  description = "Number of bits for the RSA SSH key"
  type        = number
  default     = 4096
}

variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  default     = "1.30"
}

variable "eks_instance_type" {
  description = "Instance type for the EKS worker nodes"
  default     = "t3.medium"
}

variable "eks_min_size" {
  description = "Minimum number of worker nodes in the EKS cluster"
  type        = number
  default     = 1
}

variable "eks_max_size" {
  description = "Maximum number of worker nodes in the EKS cluster"
  type        = number
  default     = 3
}

variable "eks_desired_size" {
  description = "Desired number of worker nodes in the EKS cluster"
  type        = number
  default     = 2
}