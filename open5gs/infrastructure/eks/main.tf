module "eks" {
  # aws-auth configmap
  manage_aws_auth_configmap = true

  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::018300759195:user/terraform"
      username = "terraform"
      groups   = ["system:masters"]
    }
  ]
  
  source  = "terraform-aws-modules/eks/aws"
  version = "18.20.5"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  # Per example here: https://github.com/aws-ia/terraform-aws-eks-blueprints/blob/main/examples/fully-private-eks-cluster/main.tf
  # When creating a new cluster, create it first as public and then change to private
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  cluster_addons = {
    aws-ebs-csi-driver = {
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = aws_iam_role.aws-ebs-csi-driver.arn
    }
  }

  enable_irsa = var.enable_irsa

  subnet_ids = var.private_subnets
  vpc_id     = var.vpc_id

  # eks_managed_node_group_defaults = {
  #   pre_bootstrap_user_data = local.ssm_userdata
  # }

  cluster_security_group_additional_rules = {
    ingress_node_to_cluster_tcp = {
      description                = "Allow all traffic from node across the cluster"
      protocol                   = "-1"
      from_port                  = 0
      to_port                    = 0
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  # Extend node-to-node security group rules
  node_security_group_additional_rules = {
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }

    ingress_cluster_to_node_tcp = {
      description                   = "Allow all traffic from the cluster to the node"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }

    ingress_all = {
      description = "Allow all traffic from the node to the node"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
  }

  eks_managed_node_groups = {
    default_node_group = {
      min_size     = 1
      max_size     = 4
      desired_size = 3

      instance_types = [var.node_instance_type]
      subnet_ids     = var.private_subnets
      vpc_id         = var.vpc_id
    }
  }
}

resource "aws_iam_policy" "policy" {
  description = "Policy for SSM"
  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:GetEncryptionConfiguration"
        ],
        "Resource" : "*"
      }
    ]
  })

  tags = var.tags
}

#IAM 
resource "aws_iam_role_policy_attachment" "additional" {
  for_each = module.eks.eks_managed_node_groups

  policy_arn = aws_iam_policy.policy.arn
  role       = each.value.iam_role_name
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "aws-ebs-csi-driver-trust-policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${module.eks.oidc_provider}"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "aws-ebs-csi-driver" {
  name               = "${var.cluster_name}-aws-ebs-csi-controller"
  assume_role_policy = data.aws_iam_policy_document.aws-ebs-csi-driver-trust-policy.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "caws-ebs-csi-driver" {
  role = aws_iam_role.aws-ebs-csi-driver.name
  # From this reference: https://docs.aws.amazon.com/eks/latest/userguide/csi-iam-role.html
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

