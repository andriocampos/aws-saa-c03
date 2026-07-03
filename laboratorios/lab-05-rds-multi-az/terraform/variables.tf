# =============================================================================
# VARIÁVEIS — Lab 05 RDS Multi-AZ
# =============================================================================

variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefixo para nomear os recursos"
  type        = string
  default     = "lab05"
}

variable "vpc_cidr" {
  description = "CIDR block da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "CIDRs das subnets privadas — RDS exige pelo menos 2 AZs no subnet group"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "db_name" {
  description = "Nome do banco de dados inicial criado na instância RDS"
  type        = string
  default     = "labdb"
}

variable "db_username" {
  description = "Username do administrador do banco de dados"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = <<-EOT
    Senha do administrador. NUNCA coloque a senha real aqui.
    Use terraform.tfvars (não commitado) ou variável de ambiente:
    export TF_VAR_db_password="SuaSenhaAqui"
  EOT
  type        = string
  sensitive   = true  # oculta o valor em logs e outputs do Terraform
}

variable "db_instance_class" {
  description = "Tipo da instância RDS. db.t3.micro está no Free Tier (sem Multi-AZ)"
  type        = string
  default     = "db.t3.micro"
}

variable "multi_az" {
  description = "Habilita Multi-AZ (standby em outra AZ para failover automático). Gera custo duplo."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags aplicadas a todos os recursos"
  type        = map(string)
  default = {
    Project     = "aws-saa-c03"
    Lab         = "lab-05-rds-multi-az"
    Environment = "study"
    ManagedBy   = "terraform"
  }
}
