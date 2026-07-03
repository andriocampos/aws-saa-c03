# =============================================================================
# VARIÁVEIS — Lab 02 EC2 com ALB e Auto Scaling
# =============================================================================

variable "aws_region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefixo usado para nomear todos os recursos do lab"
  type        = string
  default     = "lab02"
}

variable "vpc_cidr" {
  description = "CIDR block da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs das subnets públicas — usamos 2 AZs para garantir alta disponibilidade do ALB"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "instance_type" {
  description = "Tipo da instância EC2. t2.micro está no Free Tier"
  type        = string
  default     = "t2.micro"
}

variable "asg_desired" {
  description = "Número desejado de instâncias no Auto Scaling Group"
  type        = number
  default     = 2
}

variable "asg_min" {
  description = "Número mínimo de instâncias no ASG"
  type        = number
  default     = 1
}

variable "asg_max" {
  description = "Número máximo de instâncias no ASG"
  type        = number
  default     = 4
}

variable "cpu_target" {
  description = "Percentual de CPU alvo para o Target Tracking Scaling Policy"
  type        = number
  default     = 50
}

variable "tags" {
  description = "Tags aplicadas a todos os recursos"
  type        = map(string)
  default = {
    Project     = "aws-saa-c03"
    Lab         = "lab-02-ec2-com-alb"
    Environment = "study"
    ManagedBy   = "terraform"
  }
}
