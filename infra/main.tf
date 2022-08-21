module "eks_blueprints" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v4.7.0"

  cluster_name    = local.name
  cluster_version = local.eks.cluster_version

  # EKS network config
  vpc_id                          = module.vpc.vpc_id
  private_subnet_ids              = module.vpc.private_subnets
  cluster_endpoint_private_access = true
  # terraform fails without vpn connection if it is set to false
  #   - apply with true when creating, then re-apply with false after vpn connection
  #   - likewise apply with true before destroying, followed by destroying
  cluster_endpoint_public_access = true

  cluster_additional_security_group_ids = [aws_security_group.eks_vpn_access.id]
  worker_additional_security_group_ids  = [aws_security_group.eks_vpn_access.id]
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols, recommended and required for Add-ons"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress, recommended outbound traffic for Node groups"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
    ingress_cluster_to_node_all_traffic = {
      description                   = "Cluster API to Nodegroup all traffic, can be restricted further eg, metrics-server 4443, spark-operator 8080, karpenter 8443 ..."
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  # Add karpenter.sh/discovery tag so that we can use this as securityGroupSelector in karpenter provisioner
  node_security_group_tags = {
    "karpenter.sh/discovery/${local.name}" = local.name
  }

  # EKS manage node groups
  managed_node_groups = {
    ondemand = {
      node_group_name = "managed-ondemand"
      instance_types  = ["m5.large"]
      subnet_ids      = module.vpc.private_subnets
      max_size        = 1
      min_size        = 1
      desired_size    = 1
      update_config = [{
        max_unavailable_percentage = 30
      }]
    }
  }

  # EMR on EKS
  enable_emr_on_eks = true
  emr_on_eks_teams = {
    analytics = {
      namespace               = "analytics"
      job_execution_role      = "analytics-job-execution-role"
      additional_iam_policies = [aws_iam_policy.emr_on_eks.arn]
    }
  }

  tags = local.tags
}

resource "aws_security_group" "eks_vpn_access" {
  name   = "${local.name}-eks-vpn-access"
  vpc_id = module.vpc.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "eks_vpn_inbound" {
  count                    = local.flag.vpn.to_create ? 1 : 0
  type                     = "ingress"
  description              = "VPN access"
  security_group_id        = aws_security_group.eks_vpn_access.id
  protocol                 = "-1"
  from_port                = 0
  to_port                  = 0
  source_security_group_id = aws_security_group.vpn[0].id
}

resource "aws_emrcontainers_virtual_cluster" "analytics" {
  name = "${module.eks_blueprints.eks_cluster_id}-analytics"

  container_provider {
    id   = module.eks_blueprints.eks_cluster_id
    type = "EKS"

    info {
      eks_info {
        namespace = "analytics"
      }
    }
  }
}

module "eks_blueprints_kubernetes_addons" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons?ref=v4.7.0"

  eks_cluster_id       = module.eks_blueprints.eks_cluster_id
  eks_cluster_endpoint = module.eks_blueprints.eks_cluster_endpoint
  eks_oidc_provider    = module.eks_blueprints.oidc_provider
  eks_cluster_version  = module.eks_blueprints.eks_cluster_version

  enable_karpenter                    = true
  enable_aws_node_termination_handler = true

  tags = local.tags
}

module "karpenter_launch_templates" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/launch-templates?ref=v4.7.0"

  eks_cluster_id = module.eks_blueprints.eks_cluster_id

  launch_template_config = {
    linux = {
      ami                    = data.aws_ami.eks.id
      launch_template_prefix = "karpenter"
      iam_instance_profile   = module.eks_blueprints.managed_node_group_iam_instance_profile_id[0]
      vpc_security_group_ids = [module.eks_blueprints.worker_node_security_group_id, aws_security_group.eks_vpn_access.id]
      block_device_mappings = [
        {
          device_name = "/dev/xvda"
          volume_type = "gp3"
          volume_size = 80
        }
      ]
    }
  }

  tags = merge(local.tags, { Name = "karpenter" })
}

# deploy spark provisioners for Karpenter autoscaler
data "kubectl_path_documents" "karpenter_provisioners" {
  pattern = "${path.module}/provisioners/spark*.yaml"
  vars = {
    az           = join(",", slice(local.vpc.azs, 0, 1))
    cluster_name = local.name
    vpc_name     = "${local.name}-vpc"
  }
}

resource "kubectl_manifest" "karpenter_provisioner" {
  for_each  = toset(data.kubectl_path_documents.karpenter_provisioners.documents)
  yaml_body = each.value

  depends_on = [module.eks_blueprints_kubernetes_addons]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.14"

  name = "${local.name}-vpc"
  cidr = local.vpc.cidr

  azs             = local.vpc.azs
  public_subnets  = [for k, v in local.vpc.azs : cidrsubnet(local.vpc.cidr, 3, k)]
  private_subnets = [for k, v in local.vpc.azs : cidrsubnet(local.vpc.cidr, 3, k + 3)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  create_igw           = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/elb"              = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/internal-elb"     = 1
  }

  tags = local.tags
}

resource "aws_iam_policy" "emr_on_eks" {
  name = "analytics-job-execution-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject",
        ]
        Resource = [
          aws_s3_bucket.data_bucket.arn,
          "${aws_s3_bucket.data_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:*"
        ]
      },
    ]
  })
}

resource "aws_s3_bucket" "data_bucket" {
  bucket = local.data_bucket.name

  tags = local.tags
}

resource "aws_s3_bucket_acl" "data_bucket" {
  bucket = aws_s3_bucket.data_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_bucket" {
  bucket = aws_s3_bucket.data_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
