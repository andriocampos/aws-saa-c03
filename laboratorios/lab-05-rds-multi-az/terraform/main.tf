# =============================================================================
# LAB 05 — RDS MySQL COM MULTI-AZ
# =============================================================================
# O que este lab cria:
#   - VPC com subnets privadas em 2 AZs (RDS não deve ficar em subnet pública)
#   - DB Subnet Group — define em quais subnets o RDS pode ser provisionado
#   - Security Group para o RDS — restringe acesso à porta 3306
#   - Instância RDS MySQL com Multi-AZ habilitado
#   - Read Replica da instância principal
#
# Conceitos SAA-C03 praticados:
#   - Multi-AZ: replicação SÍNCRONA para standby em outra AZ (alta disponibilidade)
#   - Read Replica: replicação ASSÍNCRONA para leitura (performance)
#   - Multi-AZ ≠ Read Replica — diferença crítica na prova
#   - Failover automático no Multi-AZ: o endpoint não muda, apenas o CNAME resolve
#   - Automated Backups: habilitados com retention_period > 0
#   - Encryption at rest: snapshot_identifier + storage_encrypted
#   - O standby do Multi-AZ NÃO serve tráfego de leitura
# =============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

# -----------------------------------------------------------------------------
# VPC E SUBNETS PRIVADAS
# RDS deve ficar em subnets PRIVADAS — não exposto à internet diretamente.
# O acesso é feito por uma aplicação ou bastion host na mesma VPC.
# -----------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, { Name = "${var.project_name}-vpc" })
}

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(var.tags, {
    Name = "${var.project_name}-subnet-private-${count.index + 1}"
  })
}

# -----------------------------------------------------------------------------
# DB SUBNET GROUP
# O RDS Subnet Group define em quais subnets a instância pode ser criada.
# Exige subnets em pelo menos 2 AZs — obrigatório mesmo sem Multi-AZ.
# O Multi-AZ usa 2 AZs: uma para a primária e outra para o standby.
# -----------------------------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-db-subnet-group"
  description = "Subnet group for RDS Multi-AZ lab - private subnets in 2 AZs"
  subnet_ids  = [for s in aws_subnet.private : s.id]

  tags = merge(var.tags, { Name = "${var.project_name}-db-subnet-group" })
}

# -----------------------------------------------------------------------------
# SECURITY GROUP PARA RDS
# Permite MySQL (3306) apenas de dentro da VPC.
# Em produção, restrinja ao Security Group da aplicação.
# Usar CIDR da VPC é aceitável para lab, mas SG reference é mais seguro.
# -----------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-sg-rds"
  description = "Allow MySQL inbound from within VPC only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "MySQL from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]  # apenas de dentro da VPC
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.project_name}-sg-rds" })
}

# -----------------------------------------------------------------------------
# INSTÂNCIA RDS MYSQL COM MULTI-AZ
#
# MULTI-AZ:
#   - Replicação SÍNCRONA para instância standby em outra AZ
#   - Failover AUTOMÁTICO em caso de falha (~1-2 minutos)
#   - O endpoint do banco NÃO muda — apenas o CNAME do DNS é atualizado
#   - O standby NÃO serve tráfego de leitura (diferente de Read Replica)
#   - Objetivo: DISPONIBILIDADE
#
# AUTOMATED BACKUPS:
#   - backup_retention_period > 0 habilita backups automáticos
#   - Permite Point-in-Time Recovery (PITR)
#   - Obrigatório para criar Read Replicas
#
# ATENÇÃO AO CUSTO:
#   - Multi-AZ cria 2 instâncias (primária + standby) → custo dobrado
#   - Delete este lab imediatamente após o estudo
#   - skip_final_snapshot = true evita snapshot ao deletar (para lab)
# -----------------------------------------------------------------------------
resource "aws_db_instance" "primary" {
  identifier = "${var.project_name}-mysql-primary"

  # Engine
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.db_instance_class

  # Storage
  allocated_storage     = 20    # GB mínimo para MySQL
  max_allocated_storage = 100   # auto scaling de storage até 100GB
  storage_type          = "gp2"
  storage_encrypted     = true  # criptografia at-rest com KMS (boa prática)

  # Credenciais
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Rede
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false  # nunca expor RDS publicamente

  # Alta Disponibilidade
  multi_az = var.multi_az  # habilita standby em outra AZ

  # Backups (necessário para Read Replica)
  backup_retention_period = 7           # 7 dias de backups automáticos
  backup_window           = "03:00-04:00"  # janela de backup (UTC)
  maintenance_window      = "Mon:04:00-Mon:05:00"  # janela de manutenção

  # Monitoramento
  monitoring_interval = 0  # 0 = desabilitado (para economizar no lab)

  # Comportamento ao deletar
  deletion_protection       = false  # permite deletar (lab apenas)
  skip_final_snapshot       = true   # não cria snapshot ao deletar (lab)
  delete_automated_backups  = true   # limpa backups ao deletar (lab)

  tags = merge(var.tags, { Name = "${var.project_name}-mysql-primary" })
}

# -----------------------------------------------------------------------------
# READ REPLICA
#
# READ REPLICA:
#   - Replicação ASSÍNCRONA a partir da instância primária
#   - Serve tráfego de LEITURA (alivia a primária)
#   - Pode ser promovida a instância standalone (operação manual)
#   - Pode ser em região diferente (Cross-Region Read Replica)
#   - Objetivo: PERFORMANCE de leitura
#
# DIFERENÇA CRÍTICA para prova:
#   Multi-AZ = disponibilidade, failover automático, standby sem leitura
#   Read Replica = performance, leitura, promoção manual
# -----------------------------------------------------------------------------
resource "aws_db_instance" "replica" {
  identifier = "${var.project_name}-mysql-replica"

  # Read Replica: aponta para a instância primária
  replicate_source_db = aws_db_instance.primary.identifier

  instance_class = var.db_instance_class
  storage_type   = "gp2"

  # Read Replicas herdam configurações da primária (engine, storage, credentials)
  # Não definimos db_name, username, password aqui

  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Read Replica não precisa de backup próprio
  backup_retention_period = 0
  skip_final_snapshot     = true
  delete_automated_backups = true

  tags = merge(var.tags, { Name = "${var.project_name}-mysql-replica" })
}
