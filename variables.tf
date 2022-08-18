variable "vpn_psk" {
  description = "The IPsec Pre-Shared Key"
  type        = string
  sensitive   = true
}

variable "admin_password" {
  description = "SoftEther VPN admin / database master password"
  type        = string
  sensitive   = true
}

locals {
  name        = basename(path.cwd)
  region      = data.aws_region.current.name
  environment = "dev"

  vpc = {
    class_b = "100" # Class B of VPC (10.XXX.0.0/16)
  }

  vpn = {
    to_create        = true
    limit_ingress    = true
    use_spot         = false
    admin_username   = "master"
    local_id_address = "${chomp(data.http.local_ip_address.body)}/32"
    ingress_cidr     = local.vpn.limit_ingress ? local.vpn.local_ip_address : "0.0.0.0/0"
    spot_override = [
      { instance_type : "t3.nano" },
      { instance_type : "t3a.nano" },
    ]
  }

  data_bucket = {
    to_create   = true
    bucket_name = "${local.name}-data-${data.aws_caller_identity.current.account_id}-${local.region}"
  }

  tags = {
    Name        = local.name
    Environment = local.environment
  }
}
