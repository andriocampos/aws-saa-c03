# =============================================================================
# VARIÁVEIS — Lab 04 IAM Roles e Políticas
# =============================================================================

variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefixo para nomear os recursos"
  type        = string
  default     = "lab04"
}

variable "bucket_name_prefix" {
  description = "Prefixo dos buckets S3 que a política customizada terá acesso. Exemplo: 'lab03-static-site'"
  type        = string
  default     = "lab03-static-site"
}

variable "tags" {
  description = "Tags aplicadas a todos os recursos"
  type        = map(string)
  default = {
    Project     = "aws-saa-c03"
    Lab         = "lab-04-iam-roles"
    Environment = "study"
    ManagedBy   = "terraform"
  }
}
