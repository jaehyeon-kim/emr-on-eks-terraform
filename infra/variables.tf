locals {
  name        = basename(path.cwd) == "infra" ? basename(dirname(path.cwd)) : basename(path.cwd)
  region      = data.aws_region.current.name
  environment = "dev"

  vpc = {
    cidr = "10.0.0.0/16"
    azs  = slice(data.aws_availability_zones.available.names, 0, 3)
  }

  default_bucket = {
    name = "${local.name}-default-${data.aws_caller_identity.current.account_id}-${local.region}"
  }

  eks = {
    cluster_version = "1.22"
  }

  tags = {
    Name        = local.name
    Environment = local.environment
  }
}
