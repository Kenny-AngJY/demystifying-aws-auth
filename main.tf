locals {
  name         = "explore-aws-auth"
  cluster_name = format("%s-%s", local.name, "eks-cluster")

  default_tags = {
    stack     = "explore-aws-auth"
    terraform = true
  }
}

module "vpc" {
  count          = var.create_vpc ? 1 : 0
  source         = "./modules/vpc"
  stack_name     = local.name
  vpc_cidr_block = "10.0.0.0/16"

  list_of_azs        = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
  list_of_cidr_range = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  default_tags = local.default_tags
}