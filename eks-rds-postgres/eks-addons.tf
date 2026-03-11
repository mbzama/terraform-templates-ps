# VPC CNI Addon
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"

  tags = {
    Name        = "vpc-cni"
    Environment = var.environment
  }
}

# CoreDNS Addon
resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"

  depends_on = [aws_eks_node_group.main]

  tags = {
    Name        = "coredns"
    Environment = var.environment
  }
}

# Kube-proxy Addon
resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"

  tags = {
    Name        = "kube-proxy"
    Environment = var.environment
  }
}
