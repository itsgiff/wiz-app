# Wiz-App Project Overview

## Project Description
Wiz-App is a three-tier web application infrastructure deployed on AWS, designed for educational purposes. It demonstrates both proper configurations and intentional misconfigurations to help users understand and learn about AWS security best practices and common pitfalls.

## File Structure
- main.tf: Main Terraform configuration file defining the AWS infrastructure
- variables.tf: Defines input variables for the Terraform configuration
- README.md: Project documentation including setup instructions and architecture overview
- deployment.yaml: Kubernetes deployment configuration for the application
- service.yaml: Kubernetes service configuration to expose the application
- generate-secrets.sh: Bash script to generate Kubernetes secrets for the application
- .gitignore: Specifies intentionally untracked files to ignore in Git

## Key Components
1. VPC: Custom VPC with public and private subnets across multiple Availability Zones
2. EC2 Instances:
   - Jumphost (wiz-jump): Public-facing instance for administrative access
   - Database Server (wiz-db): Hosts MongoDB in a public subnet
3. EKS Cluster: Kubernetes cluster for deploying the application tier
4. S3 Bucket: Stores database backups with public read access
5. Security Groups: Control network access to EC2 instances
6. IAM Roles: Manage permissions for EC2 instances and EKS cluster

## Intentional Misconfigurations
1. Public Database: MongoDB instance deployed in a public subnet, accessible via SSH from anywhere
2. Public Jumphost: Allows SSH access from any IP address
3. Overly Permissive IAM Role: Database EC2 instance has full EC2 permissions (ec2:*)
4. Public S3 Bucket: Database backups bucket is publicly readable
5. Unencrypted EC2 Instances: Not using encrypted EBS volumes
6. Direct Internet Access: Both jumphost and database server have direct internet access

## Deployment Process
1. Clone the repository
2. Initialize Terraform
3. Review and modify variables in variables.tf if needed
4. Plan the deployment using Terraform
5. Apply the Terraform configuration
6. Configure kubectl to interact with the EKS cluster
7. Run generate-secrets.sh to create Kubernetes secrets
8. Apply Kubernetes configurations (deployment.yaml and service.yaml)

## Known Issues or Limitations
- The infrastructure is intentionally insecure and not suitable for production use
- Public SSH access to both jumphost and database server poses significant security risks
- Terraform state files need to be managed carefully, preferably using remote state storage

## Future Plans
- Implement AWS Config rules to detect and alert on misconfigurations
- Add monitoring and logging solutions
- Create remediation scripts to fix intentional misconfigurations for learning purposes

## Additional Notes
- The project uses Tasky (https://github.com/jeffthorne/tasky) as the web application
- EKS nodes are configured to start with the prefix "wiz-app"
- Database server performs daily backups to S3 at 2 AM
- The infrastructure is designed to be easily deployable and destroyable for learning purposes