# =============================================================================
# VARIÁVEIS — Lab 01 VPC Básica
# =============================================================================
# Boas práticas:
#   - Nunca hardcode valores sensíveis no main.tf
#   - Use variáveis para tudo que pode mudar entre ambientes
#   - Sempre documente cada variável com description
# =============================================================================

variable "aws_region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefixo usado para nomear todos os recursos do lab"
  type        = string
  default     = "lab01"
}

variable "vpc_cidr" {
  description = "CIDR block da VPC. /16 nos dá 65.536 endereços IPs disponíveis"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR da subnet pública. /24 nos dá 251 IPs utilizáveis (256 - 5 reservados pela AWS)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR da subnet privada"
  type        = string
  default     = "10.0.2.0/24"
}

variable "allowed_ssh_cidr" {
  description = <<-EOT
    CIDR permitido para acesso SSH à instância pública.
    Em produção, restrinja ao seu IP: "SEU_IP/32"
    Para lab temporário pode usar "0.0.0.0/0", mas nunca em produção.
  EOT
  type        = string
  default     = "0.0.0.0/0"
}

variable "tags" {
  description = "Tags aplicadas a todos os recursos. Boa prática para organização e controle de custos"
  type        = map(string)
  default = {
    Project     = "aws-saa-c03"
    Lab         = "lab-01-vpc-basica"
    Environment = "study"
    ManagedBy   = "terraform"
  }
}
