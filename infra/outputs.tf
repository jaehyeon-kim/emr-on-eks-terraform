# VPC
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

# CIDR blocks
output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

# Subnets
output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

# NAT gateways
output "nat_public_ips" {
  description = "List of public Elastic IPs created for AWS NAT Gateway"
  value       = module.vpc.nat_public_ips
}

# AZs
output "azs" {
  description = "A list of availability zones specified as argument to this module"
  value       = module.vpc.azs
}

# default bucket
output "default_bucket_name" {
  description = "Data bucket name"
  value       = aws_s3_bucket.default_bucket.id
}

# EKS
output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = module.eks_blueprints.configure_kubectl
}

output "eks_cluster_arn" {
  description = "Amazon EKS Cluster Name"
  value       = module.eks_blueprints.eks_cluster_arn
}

output "managed_node_groups" {
  description = "Outputs from EKS Managed node groups"
  value       = module.eks_blueprints.managed_node_groups
}

output "emrcontainers_virtual_cluster_id" {
  description = "EMR Containers Virtual cluster ID"
  value       = aws_emrcontainers_virtual_cluster.analytics.id
}

output "emr_on_eks_role_arn" {
  description = "IAM execution role arn for EMR on EKS"
  value       = module.eks_blueprints.emr_on_eks_role_arn
}

# EMR Studio
output "aws_acm_certificate_emr_studio" {
  description = "ACM certificate ARN of EMR studio"
  value       = aws_acm_certificate.emr_studio.arn
}
