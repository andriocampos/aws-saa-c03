# Lab 01 — VPC Básica

**Semana:** 02 | **Duração estimada:** 45 min | **Custo:** Free Tier

## Objetivo

Criar uma VPC do zero com subnets públicas e privadas, Internet Gateway e NAT Gateway, entendendo o fluxo de tráfego de cada tipo de subnet.

## Pré-requisitos

- Conta AWS com Free Tier ativo
- Acesso ao AWS Console
- Configurar alerta de billing (recomendado antes de qualquer lab)

## Arquitetura

```
Internet
    |
[IGW]
    |
VPC (10.0.0.0/16)
├── Subnet Pública  (10.0.1.0/24) — AZ-a
│   └── NAT Gateway
└── Subnet Privada (10.0.2.0/24) — AZ-a
    └── EC2 (acessa internet via NAT)
```

## Passo a Passo

### 1. Criar a VPC
- [ ] VPC → Create VPC
- Name: `lab-vpc`
- IPv4 CIDR: `10.0.0.0/16`
- Tenancy: Default

### 2. Criar Subnets
- [ ] Subnet pública: `lab-subnet-public`, AZ-a, CIDR `10.0.1.0/24`
- [ ] Subnet privada: `lab-subnet-private`, AZ-a, CIDR `10.0.2.0/24`
- [ ] Habilitar "Auto-assign public IPv4" na subnet pública

### 3. Criar e Anexar Internet Gateway
- [ ] Create Internet Gateway: `lab-igw`
- [ ] Attach to VPC: `lab-vpc`

### 4. Configurar Route Tables
- [ ] Route table pública: `lab-rt-public`
  - Adicionar rota `0.0.0.0/0` → `lab-igw`
  - Associar à `lab-subnet-public`
- [ ] Route table privada: `lab-rt-private`
  - Associar à `lab-subnet-private` (sem rota para internet ainda)

### 5. Criar NAT Gateway
- [ ] Create NAT Gateway na subnet pública
- [ ] Allocate Elastic IP
- [ ] Aguardar status "Available"
- [ ] Adicionar rota `0.0.0.0/0` → NAT Gateway na route table privada

### 6. Testar Conectividade
- [ ] Lançar EC2 na subnet pública (t2.micro, Amazon Linux 2)
- [ ] Lançar EC2 na subnet privada (t2.micro, Amazon Linux 2)
- [ ] SSH na instância pública via EC2 Instance Connect
- [ ] Da instância pública, SSH na privada (usando key pair)
- [ ] Da instância privada, testar `curl https://aws.amazon.com` (deve funcionar via NAT)

## Limpeza (importante para evitar custos)

- [ ] Terminar instâncias EC2
- [ ] Deletar NAT Gateway (gera custo por hora)
- [ ] Release Elastic IP
- [ ] Deletar VPC (remove subnets, route tables e IGW associados)

## Anotações do Lab

### O que funcionou como esperado


### Surpresas ou dificuldades


### Conceitos reforçados

