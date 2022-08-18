variable "vpn_psk" {
  description = "IPsec Pre-Shared Key (https://cloud.google.com/network-connectivity/docs/vpn/how-to/generating-pre-shared-key)"
  type        = string
  sensitive   = true
}

variable "admin_password" {
  description = "SoftEther VPN admin password"
  type        = string
  sensitive   = true
}

locals {
  name             = basename(path.cwd)
  region           = data.aws_region.current.name
  environment      = "dev"
  local_ip_address = "${chomp(data.http.local_ip_address.response_body)}/32"

  flag = {
    vpn = {
      to_create        = true
      to_limit_ingress = true
      to_use_spot      = false
    }
    data_bucket = {
      to_create = false
    }
  }

  vpc = {
    cidr = "10.0.0.0/16"
    azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  }

  vpn = {
    admin_username = "master"
    ingress_cidr   = local.flag.vpn.to_limit_ingress ? local.local_ip_address : "0.0.0.0/0"
    spot_override = [
      { instance_type : "t3.nano" },
      { instance_type : "t3a.nano" },
    ]
  }

  data_bucket = {
    name = "${local.name}-data-${data.aws_caller_identity.current.account_id}-${local.region}"
  }

  tags = {
    Name        = local.name
    Environment = local.environment
  }
}
