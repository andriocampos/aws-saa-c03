# Lab 02 — EC2 com ALB e Auto Scaling

**Semana:** 03 | **Duração estimada:** 60 min | **Custo:** Free Tier (atenção ao ALB ~$0.008/h)

## Objetivo

Criar um Application Load Balancer distribuindo tráfego entre instâncias EC2 em múltiplas AZs, com Auto Scaling Group respondendo automaticamente à carga.

## Arquitetura

```
Internet
    |
[ALB] — distribuição entre AZs
    |
Auto Scaling Group
├── EC2 (AZ-a) — t2.micro
└── EC2 (AZ-b) — t2.micro
```

## Passo a Passo

### 1. Criar Launch Template
- [ ] EC2 → Launch Templates → Create
- Name: `lab-lt-web`
- AMI: Amazon Linux 2023
- Instance type: t2.micro
- User Data (servidor HTTP simples):
```bash
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<h1>Servidor: $(hostname -f)</h1>" > /var/www/html/index.html
```

### 2. Criar Security Groups
- [ ] SG para ALB: `lab-sg-alb`
  - Inbound: HTTP (80) de `0.0.0.0/0`
- [ ] SG para EC2: `lab-sg-ec2`
  - Inbound: HTTP (80) apenas do `lab-sg-alb`

### 3. Criar Target Group
- [ ] EC2 → Target Groups → Create
- Target type: Instances
- Protocol: HTTP, Port: 80
- Health check path: `/`

### 4. Criar Application Load Balancer
- [ ] EC2 → Load Balancers → Create → Application Load Balancer
- Name: `lab-alb-web`
- Internet-facing
- Selecionar pelo menos 2 AZs com subnets públicas
- Security Group: `lab-sg-alb`
- Listener: HTTP:80 → Forward to Target Group

### 5. Criar Auto Scaling Group
- [ ] EC2 → Auto Scaling Groups → Create
- Launch template: `lab-lt-web`
- VPC e subnets: pelo menos 2 AZs
- Attach to Load Balancer: Target Group criado
- Desired: 2, Min: 1, Max: 4
- Scaling Policy: Target Tracking, CPU 50%

### 6. Testar
- [ ] Acessar DNS do ALB no browser
- [ ] Recarregar a página várias vezes — hostname deve mudar (round-robin)
- [ ] Simular carga com `stress` ou `yes > /dev/null &` para testar scale-out
- [ ] Verificar atividades do ASG no console

## Limpeza

- [ ] Deletar ASG (termina instâncias automaticamente)
- [ ] Deletar ALB e Target Group
- [ ] Deletar Launch Template
- [ ] Deletar Security Groups

## Anotações do Lab

### O que funcionou como esperado


### Surpresas ou dificuldades


### Conceitos reforçados

