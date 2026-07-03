# =============================================================================
# LAB 02 — EC2 com ALB e AUTO SCALING GROUP
# =============================================================================
# O que este lab cria:
#   - VPC com 2 subnets públicas em AZs diferentes (obrigatório para ALB)
#   - Application Load Balancer (ALB) — distribui tráfego HTTP
#   - Target Group — grupo de instâncias EC2 que recebem o tráfego
#   - Launch Template — define a configuração das instâncias EC2
#   - Auto Scaling Group — mantém o número desejado de instâncias
#   - Scaling Policy — escala automaticamente baseado em CPU
#
# Conceitos SAA-C03 praticados:
#   - ALB opera na camada 7 (HTTP/HTTPS) — diferente do NLB (camada 4)
#   - Target Groups: registram instâncias e fazem health checks
#   - ASG garante alta disponibilidade e elasticidade
#   - Launch Template é preferível ao Launch Configuration (legado)
#   - Target Tracking Policy: mantém métrica em valor alvo (ex: CPU 50%)
# =============================================================================

# -----------------------------------------------------------------------------
# DATA SOURCE: busca a AMI mais recente do Amazon Linux 2023
# Data sources leem dados existentes na AWS sem criar recursos.
# Usar data source evita hardcode do ID da AMI (que muda por região).
# -----------------------------------------------------------------------------
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# DATA SOURCE: lista as AZs disponíveis na região configurada
data "aws_availability_zones" "available" {
  state = "available"
}

# -----------------------------------------------------------------------------
# VPC e SUBNETS
# O ALB exige subnets em pelo menos 2 AZs para garantir alta disponibilidade.
# Usamos count para criar múltiplas subnets a partir de uma lista de CIDRs.
# -----------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, { Name = "${var.project_name}-vpc" })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, { Name = "${var.project_name}-igw" })
}

# count cria N recursos de uma vez — aqui cria uma subnet por CIDR na lista
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-subnet-public-${count.index + 1}"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, { Name = "${var.project_name}-rt-public" })
}

# Associa a mesma route table a todas as subnets públicas
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# SECURITY GROUPS
# SG do ALB: aceita HTTP da internet
# SG do EC2: aceita HTTP apenas do ALB (referência por SG, não por CIDR)
# Isso é a prática correta — as instâncias ficam protegidas atrás do ALB.
# -----------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-sg-alb"
  description = "Allow HTTP inbound from internet to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.project_name}-sg-alb" })
}

resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-sg-ec2"
  description = "Allow HTTP from ALB security group only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]  # apenas tráfego vindo do ALB
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.project_name}-sg-ec2" })
}

# -----------------------------------------------------------------------------
# TARGET GROUP
# Define para onde o ALB vai encaminhar o tráfego e como verificar a saúde
# das instâncias (health check).
# Se uma instância falhar no health check, o ALB para de enviar tráfego a ela.
# -----------------------------------------------------------------------------
resource "aws_lb_target_group" "web" {
  name     = "${var.project_name}-tg-web"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/"          # endpoint verificado pelo ALB
    healthy_threshold   = 2            # 2 checks OK = instância saudável
    unhealthy_threshold = 3            # 3 checks falhos = instância unhealthy
    interval            = 30           # verifica a cada 30 segundos
    timeout             = 5            # timeout por verificação
    matcher             = "200"        # HTTP 200 = saudável
  }

  tags = merge(var.tags, { Name = "${var.project_name}-tg-web" })
}

# -----------------------------------------------------------------------------
# APPLICATION LOAD BALANCER (ALB)
# Opera na camada 7 (HTTP/HTTPS).
# Distribui tráfego entre instâncias saudáveis no Target Group.
# Precisa de pelo menos 2 subnets em AZs diferentes.
# -----------------------------------------------------------------------------
resource "aws_lb" "web" {
  name               = "${var.project_name}-alb-web"
  internal           = false           # internet-facing: aceita tráfego público
  load_balancer_type = "application"   # ALB (camada 7) — diferente de "network" (NLB)
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for s in aws_subnet.public : s.id]

  tags = merge(var.tags, { Name = "${var.project_name}-alb-web" })
}

# Listener: o ALB "escuta" na porta 80 e encaminha para o Target Group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# -----------------------------------------------------------------------------
# LAUNCH TEMPLATE
# Define a configuração das instâncias que o ASG vai criar.
# É a evolução do Launch Configuration (legado) — mais flexível.
# User Data: script executado na primeira inicialização da instância.
# -----------------------------------------------------------------------------
resource "aws_launch_template" "web" {
  name_prefix   = "${var.project_name}-lt-web-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2.id]
  }

  # User Data em base64 — instala e inicia o Apache, cria página com hostname
  # O hostname muda entre instâncias, permitindo ver o round-robin do ALB
  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Servidor: $(hostname -f)</h1><p>Lab 02 - ALB + ASG</p>" > /var/www/html/index.html
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, { Name = "${var.project_name}-web-instance" })
  }

  lifecycle {
    create_before_destroy = true  # cria nova versão antes de destruir a antiga
  }
}

# -----------------------------------------------------------------------------
# AUTO SCALING GROUP (ASG)
# Mantém o número desejado de instâncias e substitui instâncias com falha.
# Integrado ao ALB via Target Group: instâncias são registradas automaticamente.
# -----------------------------------------------------------------------------
resource "aws_autoscaling_group" "web" {
  name                = "${var.project_name}-asg-web"
  desired_capacity    = var.asg_desired
  min_size            = var.asg_min
  max_size            = var.asg_max
  vpc_zone_identifier = [for s in aws_subnet.public : s.id]  # distribui entre AZs

  # Vincula ao Target Group do ALB
  target_group_arns = [aws_lb_target_group.web.arn]

  # ELB health check: o ASG respeita o health check do ALB
  # (mais inteligente que EC2 health check que só verifica se a instância está rodando)
  health_check_type         = "ELB"
  health_check_grace_period = 300  # aguarda 5 min antes de checar nova instância

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"  # sempre usa a versão mais recente do launch template
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-web-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# SCALING POLICY — Target Tracking
# Mantém o uso de CPU próximo ao valor alvo (50%).
# Se CPU > 50%: o ASG adiciona instâncias (scale out).
# Se CPU < 50%: o ASG remove instâncias (scale in), respeitando o mínimo.
# É o tipo mais simples e recomendado para a maioria dos casos.
# -----------------------------------------------------------------------------
resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "${var.project_name}-policy-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target  # mantém CPU média em X%
  }
}
