module "vpn" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 6.5"
  count   = local.flag.vpn.to_create ? 1 : 0

  name = "${local.name}-vpn-asg"

  key_name            = local.flag.vpn.to_create ? aws_key_pair.key_pair[0].key_name : null
  vpc_zone_identifier = module.vpc.public_subnets
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1

  image_id                 = data.aws_ami.amazon_linux_2.id
  instance_type            = element([for s in local.vpn.spot_override : s.instance_type], 0)
  security_groups          = [aws_security_group.vpn[0].id]
  iam_instance_profile_arn = aws_iam_instance_profile.vpn[0].arn

  # Launch template
  create_launch_template = true
  update_default_version = true

  user_data = base64encode(join("\n", [
    "#cloud-config",
    yamlencode({
      # https://cloudinit.readthedocs.io/en/latest/topics/modules.html
      write_files : [
        {
          path : "/opt/vpn/bootstrap.sh",
          content : templatefile("${path.module}/scripts/bootstrap.sh", {
            aws_region     = local.region,
            allocation_id  = aws_eip.vpn[0].allocation_id,
            vpn_psk        = var.vpn_psk,
            admin_password = var.admin_password
          }),
          permissions : "0755",
        }
      ],
      runcmd : [
        ["/opt/vpn/bootstrap.sh"],
      ],
    })
  ]))

  # Mixed instances
  use_mixed_instances_policy = true
  mixed_instances_policy = {
    instances_distribution = {
      on_demand_base_capacity                  = local.flag.vpn.to_use_spot ? 0 : 1
      on_demand_percentage_above_base_capacity = local.flag.vpn.to_use_spot ? 0 : 100
      spot_allocation_strategy                 = "capacity-optimized"
    }
    override = local.vpn.spot_override
  }

  tags = local.tags
}

resource "aws_eip" "vpn" {
  count = local.flag.vpn.to_create ? 1 : 0
  tags  = local.tags
}

resource "aws_security_group" "vpn" {
  count       = local.flag.vpn.to_create ? 1 : 0
  name        = "${local.name}-vpn-sg"
  description = "Allow inbound traffic for SoftEther VPN"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.vpn.ingress_cidr]
  }

  ingress {
    from_port   = 500
    to_port     = 500
    protocol    = "udp"
    cidr_blocks = [local.vpn.ingress_cidr]
  }

  ingress {
    from_port   = 4500
    to_port     = 4500
    protocol    = "udp"
    cidr_blocks = [local.vpn.ingress_cidr]
  }

  ingress {
    from_port   = 1701
    to_port     = 1701
    protocol    = "tcp"
    cidr_blocks = [local.vpn.ingress_cidr]
  }

  ingress {
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = [local.vpn.ingress_cidr]
  }

  ingress {
    from_port   = 5555
    to_port     = 5555
    protocol    = "tcp"
    cidr_blocks = [local.vpn.ingress_cidr]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [local.vpn.ingress_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_iam_instance_profile" "vpn" {
  count = local.flag.vpn.to_create ? 1 : 0
  name  = "${local.name}-vpn-instance-profile"
  role  = aws_iam_role.vpn[0].name

  tags = local.tags
}

resource "aws_iam_role" "vpn" {
  count = local.flag.vpn.to_create ? 1 : 0
  name  = "${local.name}-vpn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name = "${local.name}-vpn-policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "ec2:AssociateAddress",
            "ec2:ModifyInstanceAttribute"
          ]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }

  tags = local.tags
}

resource "tls_private_key" "pk" {
  count     = local.flag.vpn.to_create ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "key_pair" {
  count      = local.flag.vpn.to_create ? 1 : 0
  key_name   = "${local.name}-vpn-key"
  public_key = tls_private_key.pk[0].public_key_openssh
}

resource "local_sensitive_file" "pem_file" {
  count           = local.flag.vpn.to_create ? 1 : 0
  filename        = pathexpand("${path.module}/key-pair/${local.name}-vpn-key.pem")
  file_permission = "0400"
  content         = tls_private_key.pk[0].private_key_pem
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
