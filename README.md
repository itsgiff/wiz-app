# Wiz-App Infrastructure

This project deploys a three-tier web application using various AWS services. It demonstrates the detection and remediation of intentional configuration weaknesses using AWS security tools.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Components](#components)
4. [Prerequisites](#prerequisites)
5. [Deployment Instructions](#deployment-instructions)
6. [Application Setup](#application-setup)
7. [Intended Misconfigurations](#intended-misconfigurations)
8. [Notable Aspects](#notable-aspects)
9. [Security Considerations](#security-considerations)
10. [Troubleshooting](#troubleshooting)
11. [Cleanup](#cleanup)
## Overview

The Wiz-App infrastructure consists of a VPC, EC2 instances for a database and a jumphost, an EKS cluster for the application tier, and an S3 bucket for database backups. It is designed to demonstrate both proper configurations and intentional misconfigurations for educational purposes.

## Architecture

```
                   +----------------+
                   |                |
                   |   Internet     |
                   |                |
                   +--------+-------+
                            |
                   +--------v-------+
                   |                |
                   |   Jumphost     |
                   | (Public Subnet)|
                   |                |
                   +--------+-------+
                            |
         +------------------v------------------+
         |                                     |
         |              VPC                    |
         |                                     |
         |  +-------------+    +------------+  |
         |  |             |    |            |  |
         |  | Database    |    |  EKS       |  |
         |  | (Public     |    | (Private   |  |
         |  |  Subnet)    |    |  Subnet)   |  |
         |  |             |    |            |  |
         |  +-------------+    +------------+  |
         |                                     |
         +-------------------------------------+
                           |
                   +-------v--------+
                   |                |
                   |  S3 Bucket     |
                   | (DB Backups)   |
                   |                |
                   +----------------+
```

## Components

1. **VPC**: A custom VPC with public and private subnets across multiple Availability Zones.
2. **EC2 Instances**:
   - Jumphost (wiz-jump): Public-facing instance for administrative access.
   - Database Server (wiz-db): Hosts MongoDB in a public subnet.
3. **EKS Cluster**: Kubernetes cluster for deploying the application tier.
4. **S3 Bucket**: Stores database backups with public read access.
5. **Security Groups**: Control network access to EC2 instances.
6. **IAM Roles**: Manage permissions for EC2 instances and EKS cluster.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform (version >= 1.0)
- kubectl
- Docker
- An EC2 key pair for SSH access

## Deployment Instructions

1. Clone this repository:
   ```
   git clone https://github.com/itsgiff/wiz-app.git
   cd wiz-app
   ```

2. Initialize Terraform:
   ```
   cd terraform
   terraform init
   ```

3. Review and modify variables in `variables.tf` if needed.

4. Plan and apply the Terraform configuration:
   ```
   terraform plan
   ```

5. Apply the configuration:
   ```
   terraform apply
   ```

6. After deployment, configure `kubectl` to interact with the EKS cluster:
   ```
   aws eks update-kubeconfig --name wiz-app-cluster --region <your-aws-region>
   ```

## Application Setup

1. Configure MongoDB:
   ```
    ssh -i <your-key.pem> ubuntu@<wiz-db-public-ip>
    sudo systemctl start mongod
    sudo systemctl enable mongod
    mongo
    use taskdb
    db.createUser({
    user: "taskuser",
    pwd: "your-secure-password",
    roles: [ { role: "readWrite", db: "taskdb" } ]
    })
    exit
   ```
   
   Update MongoDB configuration to enable authentication:   
   ```
    sudo nano /etc/mongod.conf
   ```
    Add or modify these lines:
   ```
    security:
    authorization: enabled
   ```
    Restart MongoDB:
   ```
    sudo systemctl restart mongod
   ```

2. Build and Push Docker Image to ECR:
   ```
    aws ecr create-repository --repository-name wiz-app --region <your-region>
    aws ecr get-login-password --region <your-region> | docker login --username AWS --password-stdin <your-account-id>.dkr.ecr.<your-region>.amazonaws.com
    cd ../tasky
    docker build -t wiz-app .
    docker tag wiz-app:latest <your-account-id>.dkr.ecr.<your-region>.amazonaws.com/wiz-app:latest
    docker push <your-account-id>.dkr.ecr.<your-region>.amazonaws.com/wiz-app:latest
   ```
3. Update Kubernetes Deployment:
    Edit `kubernetes/deployment.yaml` to use your ECR image.

4. Create Kubernetes Secrets:
   ```
    cd ../kubernetes
    kubectl create secret generic wiz-app-secrets \
    --from-literal=mongodb-uri="mongodb://taskuser:your-secure-password@<wiz-db-public-ip>:27017/taskdb" \
    --from-literal=secret-key="your-secret-key"
   ```

5. Deploy Kubernetes Resources:
   ```
    kubectl apply -f deployment.yaml
    kubectl apply -f service.yaml
   ```

6. Verify Deployment:
   ```
    kubectl get pods
    kubectl get services wiz-app
   ```

7. Access the Application:
Use the external IP from the LoadBalancer service to access your application in a web browser.

## Intended Misconfigurations

This infrastructure includes several intentional misconfigurations for demonstration purposes:

1. **Public Database**: The MongoDB instance is deployed in a public subnet, accessible via SSH from anywhere.
2. **Public Jumphost**: The jumphost allows SSH access from any IP address.
3. **Overly Permissive IAM Role**: The database EC2 instance has full EC2 permissions (`ec2:*`).
4. **Public S3 Bucket**: The S3 bucket for database backups is publicly readable.
5. **Unencrypted EC2 Instances**: EC2 instances are not using encrypted EBS volumes.
6. **Direct Internet Access**: Both the jumphost and database server have direct internet access.


## Notable Aspects

1. **Automatic DB Backups**: The database server is configured to perform daily backups to S3 at 2 AM.
2. **Custom EKS Node Naming**: EKS nodes are configured to start with the prefix "wiz-app".
3. **Public SSH Access**: Both the jumphost and database server are accessible via SSH from the internet.
4. **Terraform State**: Ensure proper management of Terraform state files, preferably using remote state storage.


## Security Considerations

- This infrastructure is designed for demonstration and should not be used in a production environment without significant security enhancements.
- The public SSH access to both the jumphost and database server represents a significant security risk.
- Rotate all credentials and keys regularly.
- Monitor AWS CloudTrail logs for unauthorized access attempts.
- Implement AWS Config rules to detect and alert on misconfigurations.

## Troubleshooting

1. **SSH Access Issues**: Ensure your IP is allowed in the security group and that you're using the correct key pair.
2. **EKS Cluster Access Issues**: Ensure your AWS CLI is configured correctly and you have the necessary IAM permissions.
3. **Database Connection Problems**: Check the security group rules and ensure the MongoDB service is running on the EC2 instance.
4. **S3 Backup Failures**: Verify the IAM role attached to the database EC2 instance has the correct S3 permissions.
5. **Kubernetes Deployment Issues**: Check pod logs with `kubectl logs <pod-name>` and describe pods with `kubectl describe pod <pod-name>` for more information.


## Cleanup

To avoid ongoing charges, destroy the infrastructure when it's no longer needed:

```
terraform destroy
```

Note: This will delete all resources created by this Terraform configuration, including the S3 bucket and its contents.

---

**IMPORTANT**: This infrastructure is intentionally insecure and is designed for educational purposes only. Do not deploy it in any production or sensitive environments. Always follow AWS security best practices in real-world scenarios.