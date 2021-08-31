data "aws_ami" "eks_gpu_worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-gpu-node-${var.cluster_version}-*"]
  }

  most_recent = true
  owners      = ["602401143452"] // The ID of the owner of the official AWS EKS AMIs.
}

# Encrypt all volumes by default
# resource "aws_kms_key" "eks" {
#   description             = "KMS key to encrypt all ebs"
#   deletion_window_in_days = 10
# }

# resource "aws_ebs_default_kms_key" "eks" {
#   key_arn = aws_kms_key.eks.arn
# }

# resource "aws_ebs_encryption_by_default" "eks" {
#   enabled = true
# }

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "16.2.0"
  cluster_version = var.cluster_version
  cluster_name    = var.cluster_name
  kubeconfig_name = var.cluster_name
  subnets         = var.subnets
  vpc_id          = var.vpc_id
  enable_irsa     = false

  map_users = concat(var.admin_arns, var.user_arns)

  tags = {
    Environment = var.environment
    Project     = var.project
  }

  workers_additional_policies = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess",
    "arn:aws:iam::aws:policy/AmazonRoute53FullAccess",
    "arn:aws:iam::aws:policy/AmazonRoute53AutoNamingFullAccess",
    "arn:aws:iam::aws:policy/AmazonElasticFileSystemFullAccess",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess",
  ]

  workers_group_defaults = {
    additional_userdata = "sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm && sudo systemctl enable amazon-ssm-agent && sudo systemctl start amazon-ssm-agent"
    bootstrap_extra_args = "--docker-config-json ${local.docker_config_json}"
  }

  # Note:
  #   If you add here worker groups with GPUs or some other custom resources make sure
  #   to start the node in ASG manually once or cluster autoscaler doesn't find the resources.
  #
  #   After that autoscaler is able to see the resources on that ASG.
  #
  worker_groups_launch_template = concat(local.common, local.cpu, local.gpu)
}

# OIDC cluster EKS settings
resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
  url             = module.eks.cluster_oidc_issuer_url
}

# resource "aws_eks_addon" "vpc_cni" {
#   count = var.addon_create_vpc_cni ? 1 : 0

#   cluster_name      = module.eks.cluster_id
#   addon_name        = "vpc-cni"
#   resolve_conflicts = "OVERWRITE"
#   addon_version     = var.addon_vpc_cni_version

#   tags = local.tags
# }

# resource "aws_eks_addon" "kube_proxy" {
#   count = var.addon_create_kube_proxy ? 1 : 0

#   cluster_name      = module.eks.cluster_id
#   addon_name        = "kube-proxy"
#   resolve_conflicts = "OVERWRITE"
#   addon_version     = var.addon_kube_proxy_version

#   tags = local.tags
# }

# resource "aws_eks_addon" "coredns" {
#   count = var.addon_create_coredns ? 1 : 0

#   cluster_name      = module.eks.cluster_id
#   addon_name        = "coredns"
#   resolve_conflicts = "OVERWRITE"
#   addon_version     = var.addon_coredns_version

#   tags = local.tags
# }
