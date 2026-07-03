# Lab 05 — RDS com Multi-AZ e Read Replica

**Semana:** 04 | **Duração estimada:** 60 min | **Custo:** ~$0.02/h (instância db.t3.micro, Free Tier elegível)

## Objetivo

Criar um RDS MySQL com Multi-AZ, adicionar uma Read Replica e observar o comportamento de failover.

## Atenção ao Custo

RDS Multi-AZ implica 2 instâncias. Após o lab, **deletar imediatamente** para evitar custos.

## Passo a Passo

### 1. Criar Subnet Group
- [ ] RDS → Subnet Groups → Create
  - Name: `lab-rds-subnet-group`
  - VPC: selecionar VPC com subnets em pelo menos 2 AZs
  - Adicionar subnets privadas de 2 AZs

### 2. Criar Security Group para RDS
- [ ] EC2 → Security Groups → Create
  - Name: `lab-sg-rds`
  - Inbound: MySQL/Aurora (3306) do Security Group da aplicação (ou seu IP)

### 3. Criar Instância RDS MySQL
- [ ] RDS → Databases → Create Database
  - Engine: MySQL
  - Template: Free tier (desabilita Multi-AZ, use Dev/Test para habilitar)
  - DB identifier: `lab-mysql-db`
  - Master username: `admin`
  - Master password: (anotar com segurança)
  - DB instance class: db.t3.micro
  - **Multi-AZ deployment: Yes** (Standby instance)
  - Subnet group: `lab-rds-subnet-group`
  - Security Group: `lab-sg-rds`
  - Initial database name: `labdb`
  - Backups: 1 dia de retenção

### 4. Conectar ao RDS
- [ ] Lançar EC2 na mesma VPC (como bastion)
- [ ] Instalar cliente MySQL: `sudo yum install -y mysql`
- [ ] Conectar:
```bash
mysql -h SEU-RDS-ENDPOINT -u admin -p labdb
```
- [ ] Criar tabela de teste:
```sql
CREATE TABLE teste (id INT AUTO_INCREMENT PRIMARY KEY, nome VARCHAR(50), criado_em TIMESTAMP DEFAULT NOW());
INSERT INTO teste (nome) VALUES ('registro 1'), ('registro 2');
SELECT * FROM teste;
```

### 5. Criar Read Replica
- [ ] RDS → Databases → Selecionar instância → Actions → Create read replica
  - Identifier: `lab-mysql-replica`
  - Region: mesma região (ou cross-region para testar)
- [ ] Aguardar ficar Available
- [ ] Conectar na Read Replica (endpoint diferente) e verificar dados replicados

### 6. Testar Failover (Multi-AZ)
- [ ] RDS → Databases → Selecionar instância → Actions → Reboot with failover
- [ ] Observar o tempo de failover (~60-120 segundos)
- [ ] Verificar que o endpoint permanece o mesmo após failover

### 7. Observar no Console
- [ ] Verificar Events do RDS durante o failover
- [ ] Notar que a AZ da instância primária mudou

## Limpeza
- [ ] Deletar Read Replica (sem snapshot final)
- [ ] Deletar instância principal (sem snapshot final para evitar custo)
- [ ] Deletar Subnet Group
- [ ] Terminar EC2 bastion

## Anotações do Lab

### Tempo de failover observado


### Diferença de endpoint antes e após failover


### Conceitos reforçados

