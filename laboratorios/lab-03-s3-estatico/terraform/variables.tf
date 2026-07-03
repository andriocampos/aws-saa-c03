# =============================================================================
# VARIÁVEIS — Lab 03 S3 Site Estático
# =============================================================================

variable "aws_region" {
  description = "Região AWS onde o bucket será criado"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = <<-EOT
    Nome do bucket S3. Deve ser único globalmente em toda a AWS.
    Boa prática: use um sufixo com seu nome ou número de conta.
    Exemplo: "lab03-static-site-andriocampos"
  EOT
  type        = string
}

variable "tags" {
  description = "Tags aplicadas a todos os recursos"
  type        = map(string)
  default = {
    Project     = "aws-saa-c03"
    Lab         = "lab-03-s3-estatico"
    Environment = "study"
    ManagedBy   = "terraform"
  }
}
