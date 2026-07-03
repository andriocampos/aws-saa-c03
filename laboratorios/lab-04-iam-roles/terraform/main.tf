# =============================================================================
# LAB 04 — IAM ROLES E POLÍTICAS
# =============================================================================
# O que este lab cria:
#   - Grupo IAM com política gerenciada pela AWS (ReadOnly)
#   - Política IAM customizada (S3 read+write em buckets específicos)
#   - IAM Role para EC2 (permite que instâncias acessem S3 sem credenciais)
#   - Instance Profile (wrapper da role para associar a EC2)
#
# Conceitos SAA-C03 praticados:
#   - Diferença entre AWS Managed Policies e Customer Managed Policies
#   - IAM Roles: identidade temporária assumida por serviços AWS
#   - Trust Policy: define QUEM pode assumir a role
#   - Permission Policy: define O QUE a role pode fazer
#   - Instance Profile: como uma EC2 usa uma IAM Role
#   - Princípio do menor privilégio: dar apenas as permissões necessárias
# =============================================================================

# -----------------------------------------------------------------------------
# GRUPO IAM
# Grupos facilitam o gerenciamento de permissões para múltiplos usuários.
# Você atribui permissões ao grupo, não a cada usuário individualmente.
# -----------------------------------------------------------------------------
resource "aws_iam_group" "developers" {
  name = "${var.project_name}-developers"
  path = "/study/"  # path opcional para organização
}

# Anexa política gerenciada pela AWS ao grupo
# AmazonS3ReadOnlyAccess = leitura em todos os buckets S3
resource "aws_iam_group_policy_attachment" "developers_s3_readonly" {
  group      = aws_iam_group.developers.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# -----------------------------------------------------------------------------
# POLÍTICA IAM CUSTOMIZADA
# Quando políticas gerenciadas pela AWS são muito permissivas,
# criamos políticas customizadas com escopo reduzido.
# Princípio do menor privilégio: só o que é necessário.
#
# Esta política permite leitura e escrita apenas em buckets com prefixo específico.
# -----------------------------------------------------------------------------
resource "aws_iam_policy" "s3_readwrite" {
  name        = "${var.project_name}-s3-readwrite-policy"
  description = "Read and write access to specific S3 buckets by prefix"
  path        = "/study/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListBucketsByPrefix"
        Effect = "Allow"
        Action = "s3:ListBucket"
        # ARN sem /* = acesso ao bucket em si (para listar objetos)
        Resource = "arn:aws:s3:::${var.bucket_name_prefix}*"
      },
      {
        Sid    = "ReadWriteObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",   # download
          "s3:PutObject",   # upload
          "s3:DeleteObject" # deleção (remova se não necessário)
        ]
        # ARN com /* = acesso aos objetos dentro do bucket
        Resource = "arn:aws:s3:::${var.bucket_name_prefix}*/*"
      }
    ]
  })

  tags = var.tags
}

# -----------------------------------------------------------------------------
# IAM ROLE PARA EC2
# Uma Role é uma identidade temporária — não tem credenciais permanentes.
# A EC2 "assume" a role e recebe credenciais temporárias automaticamente via STS.
# Isso elimina a necessidade de colocar access keys dentro da instância.
#
# Trust Policy (assume_role_policy):
#   Define QUEM pode assumir esta role.
#   Aqui: o serviço EC2 (ec2.amazonaws.com) pode assumir esta role.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ec2_s3_role" {
  name        = "${var.project_name}-ec2-s3-role"
  description = "Allows EC2 instances to access S3 without hardcoded credentials"
  path        = "/study/"

  # Trust Policy: apenas o serviço EC2 pode assumir esta role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEC2ToAssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"  # serviço que pode assumir a role
        }
        Action = "sts:AssumeRole"  # ação de assumir a role via STS
      }
    ]
  })

  tags = var.tags
}

# Anexa a política de S3 ReadOnly à role
# Permission Policy: define O QUE a role pode fazer após assumida
resource "aws_iam_role_policy_attachment" "ec2_s3_readonly" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# -----------------------------------------------------------------------------
# INSTANCE PROFILE
# Uma EC2 não usa uma IAM Role diretamente — usa um Instance Profile.
# O Instance Profile é um "container" para a role que pode ser associado a EC2.
# Na console AWS, isso é feito automaticamente.
# No Terraform/CLI, precisa ser criado explicitamente.
# -----------------------------------------------------------------------------
resource "aws_iam_instance_profile" "ec2_s3_profile" {
  name = "${var.project_name}-ec2-s3-profile"
  role = aws_iam_role.ec2_s3_role.name
  path = "/study/"

  tags = var.tags
}

# -----------------------------------------------------------------------------
# POLÍTICA DE DENY EXPLÍCITO (exemplo avançado)
# Demonstra que Deny explícito sempre prevalece sobre Allow.
# Esta política nega todas as ações fora da região us-east-1.
# Useful para: entender a lógica de avaliação de políticas no SAA-C03.
# -----------------------------------------------------------------------------
resource "aws_iam_policy" "deny_outside_region" {
  name        = "${var.project_name}-deny-outside-us-east-1"
  description = "Deny all actions outside us-east-1 (example of explicit deny)"
  path        = "/study/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyOutsideUsEast1"
        Effect = "Deny"  # Deny explícito prevalece sobre qualquer Allow
        Action = "*"
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = "us-east-1"
          }
        }
      }
    ]
  })

  tags = var.tags
}
