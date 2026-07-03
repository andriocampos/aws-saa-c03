# =============================================================================
# LAB 01 — VPC BÁSICA
# =============================================================================
# O que este lab cria:
#   - 1 VPC com CIDR 10.0.0.0/16
#   - 1 Subnet pública  (10.0.1.0/24) na AZ-a
#   - 1 Subnet privada  (10.0.2.0/24) na AZ-a
#   - 1 Internet Gateway — permite acesso público à internet
#   - 1 NAT Gateway      — permite que a subnet privada acesse a internet (saída)
#   - 1 Elastic IP       — necessário para o NAT Gateway
#   - Route tables separadas para pública e privada
#   - Security Groups para EC2 pública e privada
#
# Conceitos SAA-C03 praticados:
#   - Diferença entre subnet pública e privada
#   - Papel do Internet Gateway vs NAT Gateway
#   - Security Groups (stateful)
#   - Route tables e associações
# =============================================================================

# -----------------------------------------------------------------------------
# VPC
# Uma VPC é uma rede virtual isolada dentro da AWS.
# O CIDR /16 nos dá 65.536 endereços IP para distribuir entre subnets.
# -----------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true  # permite que instâncias recebam nomes DNS públicos
  enable_dns_support   = true  # habilita resolução DNS dentro da VPC

  tags = merge(var.tags, {
    Name = "${var.project_name}-vpc"
  })
}

# -----------------------------------------------------------------------------
# INTERNET GATEWAY
# O IGW é o ponto de saída/entrada para tráfego público.
# Sem ele, nenhuma instância consegue se comunicar com a internet.
# Um IGW por VPC — é um recurso "2 em 1": entrada e saída.
# -----------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-igw"
  })
}

# -----------------------------------------------------------------------------
# SUBNET PÚBLICA
# Uma subnet é pública quando sua route table tem rota para o IGW.
# Instâncias aqui podem receber IP público e se comunicar com a internet.
# -----------------------------------------------------------------------------
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true  # instâncias nessa subnet recebem IP público automaticamente

  tags = merge(var.tags, {
    Name = "${var.project_name}-subnet-public"
    Type = "Public"
  })
}

# -----------------------------------------------------------------------------
# SUBNET PRIVADA
# Sem rota direta para o IGW — instâncias aqui NÃO são acessíveis da internet.
# Saída para internet (se necessário) é feita via NAT Gateway.
# -----------------------------------------------------------------------------
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "${var.aws_region}a"
  # map_public_ip_on_launch = false (padrão) — sem IP público

  tags = merge(var.tags, {
    Name = "${var.project_name}-subnet-private"
    Type = "Private"
  })
}

# -----------------------------------------------------------------------------
# ELASTIC IP para o NAT Gateway
# O NAT Gateway precisa de um IP público estático (Elastic IP).
# Este IP representa o endereço de saída de toda a subnet privada.
# -----------------------------------------------------------------------------
resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main] # IGW deve existir antes do EIP

  tags = merge(var.tags, {
    Name = "${var.project_name}-eip-nat"
  })
}

# -----------------------------------------------------------------------------
# NAT GATEWAY
# Permite que instâncias na subnet PRIVADA acessem a internet (saída apenas).
# Traduz o IP privado da instância para o Elastic IP público.
# Diferença crítica:
#   - IGW: tráfego de entrada E saída (subnet pública)
#   - NAT GW: apenas saída (subnet privada → internet)
# Importante: NAT Gateway gera custo por hora + por GB transferido.
# -----------------------------------------------------------------------------
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id  # NAT Gateway fica na subnet PÚBLICA

  depends_on = [aws_internet_gateway.main]

  tags = merge(var.tags, {
    Name = "${var.project_name}-nat-gw"
  })
}

# -----------------------------------------------------------------------------
# ROUTE TABLE — PÚBLICA
# Toda subnet pública precisa de uma rota para o IGW.
# "0.0.0.0/0" significa "qualquer destino não local vai por aqui".
# -----------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id  # tráfego externo → IGW
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-rt-public"
  })
}

# Associa a route table pública à subnet pública
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# ROUTE TABLE — PRIVADA
# Instâncias privadas precisam de saída para internet (ex: yum update, patches).
# A rota vai para o NAT Gateway, não diretamente para o IGW.
# -----------------------------------------------------------------------------
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id  # tráfego externo → NAT GW
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-rt-private"
  })
}

# Associa a route table privada à subnet privada
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# -----------------------------------------------------------------------------
# SECURITY GROUP — INSTÂNCIA PÚBLICA (Bastion)
# Security Groups são stateful: se você permite entrada na porta 22,
# a resposta de saída é permitida automaticamente.
# Diferente do NACL que é stateless e exige regras de entrada E saída.
# -----------------------------------------------------------------------------
resource "aws_security_group" "public_ec2" {
  name        = "${var.project_name}-sg-public-ec2"
  description = "Allow SSH inbound and all outbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from allowed CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]  # restrinja ao seu IP em produção
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # -1 = todos os protocolos
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-sg-public-ec2"
  })
}

# -----------------------------------------------------------------------------
# SECURITY GROUP — INSTÂNCIA PRIVADA
# Permite SSH apenas vindo do Security Group da instância pública (bastion).
# Referenciamos o SG diretamente (source_security_group_id) em vez de um CIDR
# — isso é mais seguro e não depende de IPs fixos.
# -----------------------------------------------------------------------------
resource "aws_security_group" "private_ec2" {
  name        = "${var.project_name}-sg-private-ec2"
  description = "Allow SSH from bastion only and all outbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "SSH from bastion security group only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.public_ec2.id]  # referência ao SG do bastion
  }

  egress {
    description = "Allow outbound via NAT Gateway"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-sg-private-ec2"
  })
}
