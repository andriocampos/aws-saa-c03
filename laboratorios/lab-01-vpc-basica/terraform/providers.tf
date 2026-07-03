# =============================================================================
# PROVIDERS — Lab 01 VPC Básica
# =============================================================================
# O provider define com qual nuvem o Terraform vai se comunicar.
# Boa prática: sempre fixe a versão do provider para evitar quebras inesperadas.
#
# Autenticação:
#   O provider AWS lê as credenciais automaticamente de:
#   1. ~/.aws/credentials (configurado via "aws configure")
#   2. Variáveis de ambiente AWS_ACCESS_KEY_ID e AWS_SECRET_ACCESS_KEY
#   3. IAM Role (quando rodando em EC2 ou ECS)
#   NUNCA coloque credenciais hardcoded aqui.
# =============================================================================

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # usa qualquer versão 5.x, mas não 6.x
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Tags padrão aplicadas a TODOS os recursos automaticamente pelo provider.
  # Complementa as tags individuais de cada recurso.
  default_tags {
    tags = {
      ManagedBy = "terraform"
      Project   = "aws-saa-c03"
    }
  }
}
