#### EMR studio
resource "aws_security_group" "emr_studio_workspace" {
  name   = "${local.name}-studio-workspace"
  vpc_id = module.vpc.vpc_id

  egress {
    description      = "required for emr studio workspace and cluster communication"
    from_port        = 18888
    to_port          = 18888
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.main.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  egress {
    description = "required for emr studio workspace and git communication"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.tags, {
    "for-use-with-amazon-emr-managed-policies" = "true"
  })
}

resource "aws_security_group" "emr_studio_engine" {
  name        = "${local.name}-studio-engine"
  description = "allows inbound traffic to clusters from attached emr studio workspaces"
  vpc_id      = module.vpc.vpc_id

  tags = merge(local.tags, {
    "for-use-with-amazon-emr-managed-policies" = "true"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "emr_studio_engine_inbound" {
  type                     = "ingress"
  security_group_id        = aws_security_group.emr_studio_engine.id
  protocol                 = "tcp"
  from_port                = 18888
  to_port                  = 18888
  source_security_group_id = aws_security_group.emr_studio_workspace.id
}

resource "aws_ec2_tag" "emr_studio_engine_inbound_tag" {
  resource_id = aws_security_group_rule.emr_studio_engine_inbound.id
  key         = "for-use-with-amazon-emr-managed-policies"
  value       = "true"
}

resource "aws_iam_role" "emr_studio_svc_role" {
  name = "${local.name}-studio-svc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "elasticmapreduce.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "emr_studio_svc_policy_att" {
  role       = aws_iam_role.emr_studio_svc_role.name
  policy_arn = aws_iam_policy.emr_studio_svc_policy.arn
}

resource "aws_iam_policy" "emr_studio_svc_policy" {
  name   = "${local.name}-studio-svc-policy"
  policy = data.aws_iam_policy_document.emr_studio_svc_policy.json

  tags = local.tags
}

data "aws_iam_policy_document" "emr_studio_svc_policy" {
  statement {
    sid = "AllowEMRReadOnlyActions"
    actions = [
      "elasticmapreduce:ListInstances",
      "elasticmapreduce:DescribeCluster",
      "elasticmapreduce:ListSteps"
    ]
    resources = ["*"]
  }
  statement {
    sid = "AllowEC2ENIActionsWithEMRTags"
    actions = [
      "ec2:CreateNetworkInterfacePermission",
      "ec2:DeleteNetworkInterface"
    ]
    resources = ["arn:aws:ec2:*:*:network-interface/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/for-use-with-amazon-emr-managed-policies"
      values   = ["true"]
    }
  }
  statement {
    sid     = "AllowEC2ENIAttributeAction"
    actions = ["ec2:ModifyNetworkInterfaceAttribute"]
    resources = [
      "arn:aws:ec2:*:*:instance/*",
      "arn:aws:ec2:*:*:network-interface/*",
      "arn:aws:ec2:*:*:security-group/*"
    ]
  }
  statement {
    sid = "AllowEC2SecurityGroupActionsWithEMRTags"
    actions = [
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:DeleteNetworkInterfacePermission"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/for-use-with-amazon-emr-managed-policies"
      values   = ["true"]
    }
  }
  statement {
    sid       = "AllowDefaultEC2SecurityGroupsCreationWithEMRTags"
    actions   = ["ec2:CreateSecurityGroup"]
    resources = ["arn:aws:ec2:*:*:security-group/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/for-use-with-amazon-emr-managed-policies"
      values   = ["true"]
    }
  }
  statement {
    sid       = "AllowDefaultEC2SecurityGroupsCreationInVPCWithEMRTags"
    actions   = ["ec2:CreateSecurityGroup"]
    resources = ["arn:aws:ec2:*:*:vpc/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/for-use-with-amazon-emr-managed-policies"
      values   = ["true"]
    }
  }
  statement {
    sid       = "AllowAddingEMRTagsDuringDefaultSecurityGroupCreation"
    actions   = ["ec2:CreateTags"]
    resources = ["arn:aws:ec2:*:*:security-group/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/for-use-with-amazon-emr-managed-policies"
      values   = ["true"]
    }
    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["CreateSecurityGroup"]
    }
  }
  statement {
    sid       = "AllowEC2ENICreationWithEMRTags"
    actions   = ["ec2:CreateNetworkInterface"]
    resources = ["arn:aws:ec2:*:*:network-interface/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/for-use-with-amazon-emr-managed-policies"
      values   = ["true"]
    }
  }
  statement {
    sid     = "AllowEC2ENICreationInSubnetAndSecurityGroupWithEMRTags"
    actions = ["ec2:CreateNetworkInterface"]
    resources = [
      "arn:aws:ec2:*:*:subnet/*",
      "arn:aws:ec2:*:*:security-group/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/for-use-with-amazon-emr-managed-policies"
      values   = ["true"]
    }
  }
  statement {
    sid       = "AllowAddingTagsDuringEC2ENICreation"
    actions   = ["ec2:CreateTags"]
    resources = ["arn:aws:ec2:*:*:network-interface/*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["CreateNetworkInterface"]
    }
  }
  statement {
    sid = "AllowEC2ReadOnlyActions"
    actions = [
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeTags",
      "ec2:DescribeInstances",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs"
    ]
    resources = ["*"]
  }
  statement {
    sid = "AllowS3ReadOnlyAccessToLogs"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:GetEncryptionConfiguration",
      "s3:ListBucket",
      "s3:DeleteObject",
    ]
    resources = [
      aws_s3_bucket.default_bucket.arn,
      "${aws_s3_bucket.default_bucket.arn}/*",
      "arn:aws:s3:::aws-logs-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.id}/elasticmapreduce/*"
    ]
  }
}

resource "aws_iam_role" "emr_studio_usr_role" {
  name = "${local.name}-studio-usr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "elasticmapreduce.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "emr_studio_usr_policy_att" {
  role       = aws_iam_role.emr_studio_usr_role.name
  policy_arn = aws_iam_policy.emr_studio_usr_policy.arn
}

resource "aws_iam_policy" "emr_studio_usr_policy" {
  name   = "${local.name}-studio-usr-policy"
  policy = data.aws_iam_policy_document.emr_studio_usr_policy.json

  tags = local.tags
}

data "aws_iam_policy_document" "emr_studio_usr_policy" {
  statement {
    sid = "AllowEMRBasicActions"
    actions = [
      "elasticmapreduce:CreateEditor",
      "elasticmapreduce:DescribeEditor",
      "elasticmapreduce:ListEditors",
      "elasticmapreduce:StartEditor",
      "elasticmapreduce:StopEditor",
      "elasticmapreduce:DeleteEditor",
      "elasticmapreduce:OpenEditorInConsole",
      "elasticmapreduce:AttachEditor",
      "elasticmapreduce:DetachEditor",
      "elasticmapreduce:CreateRepository",
      "elasticmapreduce:DescribeRepository",
      "elasticmapreduce:DeleteRepository",
      "elasticmapreduce:ListRepositories",
      "elasticmapreduce:LinkRepository",
      "elasticmapreduce:UnlinkRepository",
      "elasticmapreduce:DescribeCluster",
      "elasticmapreduce:ListInstanceGroups",
      "elasticmapreduce:ListBootstrapActions",
      "elasticmapreduce:ListClusters",
      "elasticmapreduce:ListSteps",
      "elasticmapreduce:CreatePersistentAppUI",
      "elasticmapreduce:DescribePersistentAppUI",
      "elasticmapreduce:GetPersistentAppUIPresignedURL"
    ]
    resources = ["*"]
  }
  statement {
    sid = "AllowEMRContainersBasicActions"
    actions = [
      "emr-containers:DescribeVirtualCluster",
      "emr-containers:ListVirtualClusters",
      "emr-containers:DescribeManagedEndpoint",
      "emr-containers:ListManagedEndpoints",
      "emr-containers:CreateAccessTokenForManagedEndpoint",
      "emr-containers:DescribeJobRun",
      "emr-containers:ListJobRuns"
    ]
    resources = ["*"]
  }
  statement {
    sid       = "AllowSecretManagerListSecrets"
    actions   = ["secretsmanager:ListSecrets"]
    resources = ["*"]
  }
  statement {
    sid       = "AllowSecretCreationWithEMRTagsAndEMRStudioPrefix"
    actions   = ["secretsmanager:CreateSecret"]
    resources = ["arn:aws:secretsmanager:*:*:secret:emr-studio-*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/for-use-with-amazon-emr-managed-policies"
      values   = ["true"]
    }
  }
  statement {
    sid       = "AllowAddingTagsOnSecretsWithEMRStudioPrefix"
    actions   = ["secretsmanager:TagResource"]
    resources = ["arn:aws:secretsmanager:*:*:secret:emr-studio-*"]
  }
  statement {
    sid = "AllowClusterTemplateRelatedIntermediateActions"
    actions = [
      "servicecatalog:DescribeProduct",
      "servicecatalog:DescribeProductView",
      "servicecatalog:DescribeProvisioningParameters",
      "servicecatalog:ProvisionProduct",
      "servicecatalog:SearchProducts",
      "servicecatalog:UpdateProvisionedProduct",
      "servicecatalog:ListProvisioningArtifacts",
      "servicecatalog:ListLaunchPaths",
      "servicecatalog:DescribeRecord",
      "cloudformation:DescribeStackResources"
    ]
    resources = ["*"]
  }
  statement {
    sid       = "AllowEMRCreateClusterAdvancedActions"
    actions   = ["elasticmapreduce:RunJobFlow"]
    resources = ["*"]
  }
  statement {
    sid     = "AllowPassingServiceRoleForWorkspaceCreation"
    actions = ["iam:PassRole"]
    resources = [
      aws_iam_role.emr_studio_svc_role.arn,
      "arn:aws:iam::*:role/EMR_DefaultRole",
      "arn:aws:iam::*:role/EMR_EC2_DefaultRole"
    ]
  }
  statement {
    sid = "AllowS3ListAndLocationPermissions"
    actions = [
      "s3:ListAllMyBuckets",
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = ["arn:aws:s3:::*"]
  }
  statement {
    sid = "AllowS3ReadOnlyAccessToLogs"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:GetEncryptionConfiguration",
      "s3:ListBucket",
      "s3:DeleteObject"
    ]
    resources = [
      "${aws_s3_bucket.default_bucket.arn}/*",
      "arn:aws:s3:::aws-logs-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.id}/elasticmapreduce/*"
    ]
  }
}

resource "aws_emr_studio" "demo" {
  auth_mode                   = "SSO"
  default_s3_location         = "s3://${aws_s3_bucket.default_bucket.id}/studio"
  engine_security_group_id    = aws_security_group.emr_studio_engine.id
  name                        = "demo"
  service_role                = aws_iam_role.emr_studio_svc_role.arn
  subnet_ids                  = module.vpc.private_subnets
  user_role                   = aws_iam_role.emr_studio_usr_role.arn
  vpc_id                      = module.vpc.vpc_id
  workspace_security_group_id = aws_security_group.emr_studio_workspace.id

  tags = local.tags
}

resource "aws_emr_studio_session_mapping" "demo" {
  studio_id          = aws_emr_studio.demo.id
  identity_type      = "USER"
  identity_id        = "example"
  session_policy_arn = aws_iam_policy.emr_studio_usr_policy.arn

  depends_on = [
    aws_emr_studio.demo
  ]
}

#### resources to set up EMR on EKS for EMR studio
# acm certificate
resource "tls_private_key" "emr_studio" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "emr_studio" {
  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.emr_studio.private_key_pem

  subject {
    common_name  = "*.emreksdemo.com"
    organization = "emr-eks-demo"
  }

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "emr_studio" {
  private_key      = tls_private_key.emr_studio.private_key_pem
  certificate_body = tls_self_signed_cert.emr_studio.cert_pem
}

# permission to manage security groups and to retrieve the ACM certificate and its metadata
resource "aws_iam_policy" "emr_studio_network" {
  name = "emr-studio-network-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "acm:DescribeCertificate"
        ]
        Resource = aws_acm_certificate.emr_studio.arn
      }
    ]
  })
}

# extra permission to managed node group
resource "aws_iam_policy" "s3_eks_policy" {
  name = "${local.name}-s3-eks-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject",
        ]
        Resource = [
          aws_s3_bucket.default_bucket.arn,
          "${aws_s3_bucket.default_bucket.arn}/*"
        ]
      }
    ]
  })
}
