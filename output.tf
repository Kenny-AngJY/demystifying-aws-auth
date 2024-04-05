output "vpc_id" {
  value = module.vpc[0].vpc_id
}

output "list_of_subnet_ids" {
  value = module.vpc[0].list_of_subnet_ids
}

output "endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.eks_cluster.certificate_authority[0].data
}