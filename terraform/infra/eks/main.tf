# BMAD Protocol - EKS Infrastructure
# Production-ready Amazon EKS cluster for BMAD deployment

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

# Local variables
locals {
  cluster_name = var.cluster_name
  region       = var.region
  
  tags = {
    Environment = var.environment
    Project     = "bmad-protocol"
    ManagedBy   = "terraform"
    Owner       = var.owner
  }
}

# Data sources
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "current" {}

# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway   = true
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  # EKS specific tags
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}

# EKS Module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access_cidrs = var.allowed_cidr_blocks

  vpc_id                   = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    bmad_system = {
      name = "${local.cluster_name}-system"
      
      instance_types = ["m6i.large"]
      ami_type       = "AL2_x86_64"
      
      min_size     = 2
      max_size     = 5
      desired_size = 3
      
      disk_size = 50
      disk_type = "gp3"
      
      k8s_labels = {
        "bmad.io/role" = "system"
        "bmad.io/node-group" = "system"
      }
      
      taints = [
        {
          key    = "bmad.io/system"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]
      
      tags = merge(local.tags, {
        Name = "${local.cluster_name}-system-node"
      })
    }
    
    bmad_executor = {
      name = "${local.cluster_name}-executor"
      
      instance_types = ["m6i.xlarge"]
      ami_type       = "AL2_x86_64"
      
      min_size     = 1
      max_size     = 20
      desired_size = 3
      
      disk_size = 100
      disk_type = "gp3"
      
      # Enable detailed monitoring
      enable_monitoring = true
      
      k8s_labels = {
        "bmad.io/role" = "executor"
        "bmad.io/firecracker" = "enabled"
        "bmad.io/node-group" = "executor"
      }
      
      tags = merge(local.tags, {
        Name = "${local.cluster_name}-executor-node"
      })
    }
    
    bmad_compute = {
      name = "${local.cluster_name}-compute"
      
      instance_types = ["m6i.large", "m6i.xlarge"]
      ami_type       = "AL2_x86_64"
      
      min_size     = 0
      max_size     = 50
      desired_size = 5
      
      disk_size = 50
      disk_type = "gp3"
      
      # Use spot instances for cost optimization
      capacity_type = "SPOT"
      
      k8s_labels = {
        "bmad.io/role" = "compute"
        "bmad.io/cost-optimized" = "true"
        "bmad.io/node-group" = "compute"
      }
      
      tags = merge(local.tags, {
        Name = "${local.cluster_name}-compute-node"
      })
    }
  }

  # EKS Add-ons
  cluster_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
    }
    aws-efs-csi-driver = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  tags = local.tags
}

# S3 Bucket for logs and artifacts
resource "aws_s3_bucket" "bmad_artifacts" {
  bucket = "${local.cluster_name}-artifacts-${random_id.bucket_suffix.hex}"

  tags = local.tags
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "bmad_artifacts" {
  bucket = aws_s3_bucket.bmad_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_encryption" "bmad_artifacts" {
  bucket = aws_s3_bucket.bmad_artifacts.id

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "bmad_artifacts" {
  bucket = aws_s3_bucket.bmad_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}