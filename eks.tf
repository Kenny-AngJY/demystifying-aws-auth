resource "aws_eks_cluster" "eks_cluster" {
  name     = local.name
  role_arn = aws_iam_role.cluster_service_role.arn
  version  = "1.29"

  vpc_config {
    endpoint_private_access = false
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
    security_group_ids      = [aws_security_group.cluster.id]
    subnet_ids              = var.create_vpc ? module.vpc[0].list_of_subnet_ids : var.list_of_subnet_ids
  }

  ### InvalidParameterException: bootstrapClusterCreatorAdminPermissions must be true if cluster authentication mode is set to CONFIG_MAP
  access_config {
    authentication_mode                         = "CONFIG_MAP" # CONFIG_MAP | API | API_AND_CONFIG_MAP
    bootstrap_cluster_creator_admin_permissions = true
  }

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  dynamic "encryption_config" {
    for_each = var.kms_key_arn != "" ? [1] : []
    content {
      provider {
        key_arn = var.kms_key_arn
      }
      resources = ["secrets"]
    }
  }

  tags = local.default_tags

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.example-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.example-AmazonEKSVPCResourceController,
    aws_iam_role_policy_attachment.example-AmazonEKSServicePolicy
  ]
}

resource "aws_security_group" "cluster" {
  name        = format("%s-clustersecuritygroup", local.name)
  description = "Cluster security group"
  vpc_id      = var.create_vpc ? module.vpc[0].vpc_id : var.vpc_id
  tags        = local.default_tags
}

resource "aws_security_group_rule" "cluster" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node.id
  security_group_id        = aws_security_group.cluster.id
  description              = "Node groups to cluster API"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "cluster_service_role" {
  name               = "eks-cluster-example"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = local.default_tags
}

resource "aws_iam_policy" "cluster_encryption" {
  count       = var.kms_key_arn != "" ? 1 : 0
  name        = format("%s-ClusterEncryption", local.name)
  path        = "/"
  description = "Cluster encryption policy to allow cluster role to utilize CMK provided"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode(
    {
      Statement = [
        {
          Action = [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:ListGrants",
            "kms:DescribeKey",
          ]
          Effect   = "Allow"
          Resource = var.kms_key_arn
        },
      ]
      Version = "2012-10-17"
    }
  )
  tags = local.default_tags
}

resource "aws_iam_role_policy_attachment" "cluster_encryption" {
  count      = var.kms_key_arn != "" ? 1 : 0
  policy_arn = aws_iam_policy.cluster_encryption[0].arn
  role       = aws_iam_role.cluster_service_role.name
}
resource "aws_iam_role_policy_attachment" "example-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster_service_role.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.cluster_service_role.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster_service_role.name
}
### https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon
### Enable pod networking within your cluster.
resource "aws_eks_addon" "vpc-cni" {
  cluster_name  = aws_eks_cluster.eks_cluster.name
  addon_name    = "vpc-cni"
  addon_version = "v1.16.0-eksbuild.1"
}

### Enable service networking within your cluster.
resource "aws_eks_addon" "kube-proxy" {
  cluster_name  = aws_eks_cluster.eks_cluster.name
  addon_name    = "kube-proxy"
  addon_version = "v1.29.0-eksbuild.1"
}

## ---------------------------------------------------------------------------------------
## Node Group
## ---------------------------------------------------------------------------------------

resource "aws_iam_role" "node_group" {
  count = var.create_node_group ? 1 : 0
  name  = "eks-node-group-iam-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
  tags = local.default_tags
}

resource "aws_iam_role_policy_attachment" "node_group-AmazonEKSWorkerNodePolicy" {
  count      = var.create_node_group ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group[0].name
}

resource "aws_iam_role_policy_attachment" "node_group-AmazonEKS_CNI_Policy" {
  count      = var.create_node_group ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group[0].name
}

resource "aws_iam_role_policy_attachment" "node_group-AmazonEC2ContainerRegistryReadOnly" {
  count      = var.create_node_group ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group[0].name
}

data "aws_ssm_parameter" "eks_ami_release_version" {
  name = "/aws/service/eks/optimized-ami/${aws_eks_cluster.eks_cluster.version}/amazon-linux-2/recommended/release_version"
}

resource "aws_security_group" "node" {
  name        = format("%s-nodesecuritygroup", local.name)
  description = "Security group for all nodes in the cluster."
  vpc_id      = var.create_vpc ? module.vpc[0].vpc_id : var.vpc_id
  tags        = local.default_tags
}

resource "aws_security_group_rule" "node" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.node.id
  description       = "Node groups to cluster API"
}

resource "aws_eks_node_group" "managed_node_group" {
  count           = var.create_node_group ? 1 : 0
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "eks-node-group"
  version         = aws_eks_cluster.eks_cluster.version
  release_version = nonsensitive(data.aws_ssm_parameter.eks_ami_release_version.value)
  node_role_arn   = aws_iam_role.node_group[0].arn
  subnet_ids      = module.vpc[0].list_of_subnet_ids

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  capacity_type = "SPOT" # ON_DEMAND | SPOT

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.node_group-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_group-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_group-AmazonEC2ContainerRegistryReadOnly,
  ]

  tags = local.default_tags
}