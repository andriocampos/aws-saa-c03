# Diferenças Críticas — SAA-C03

> Este é o arquivo mais importante para revisar antes da prova.
> Estude estas tabelas até conseguir responder de memória.

---

## 1. COMPUTAÇÃO

### Security Groups vs NACLs

| | Security Group | NACL |
|-|---------------|------|
| Nível de aplicação | Instância (ENI) | Subnet |
| Stateful | ✅ Sim | ❌ Não (stateless) |
| Regras de resposta | Automáticas | Devem ser criadas explicitamente |
| Tipos de regra | Apenas Allow | Allow e Deny |
| Avaliação das regras | Todas as regras avaliadas | Ordem numérica (primeiro match) |
| Default | Nega tudo (inbound), permite tudo (outbound) | Permite tudo (inbound e outbound) |

### EC2 Purchasing Options

| Tipo | Desconto | Comprometimento | Quando usar |
|------|----------|----------------|-------------|
| On-Demand | — | Nenhum | Imprevisível, curto prazo |
| Reserved (Standard) | até 72% | 1 ou 3 anos | Workload estável e previsível |
| Reserved (Convertible) | até 66% | 1 ou 3 anos | Workload previsível mas pode mudar tipo |
| Savings Plans | até 66% | 1 ou 3 anos ($/h) | Flexível por tipo e região |
| Spot | até 90% | Nenhum (pode ser interrompido) | Tolerante a falhas: batch, CI/CD, ML |
| Dedicated Host | variável | On-demand ou 1/3 anos | Licenças por socket/core, compliance |

---

## 2. STORAGE

### EBS vs EFS vs S3 vs Instance Store

| | EBS | EFS | S3 | Instance Store |
|-|-----|-----|----|----------------|
| Tipo | Block | File (NFS) | Object | Block |
| Multi-attach | ❌ (exceto io1/io2 na mesma AZ) | ✅ | ✅ | ❌ |
| Persist após terminate | ✅ (configurável) | ✅ | ✅ | ❌ |
| Multi-AZ nativo | ❌ | ✅ | ✅ | ❌ |
| Casos de uso | Boot, banco de dados | Compartilhado entre servidores | Objetos, backups, data lake | Cache temporário, alta I/O |

### S3 Storage Classes

| Classe | AZs | Retrieval | Min dias | Quando usar |
|--------|-----|-----------|----------|-------------|
| Standard | 3+ | Imediato | — | Acesso frequente |
| Standard-IA | 3+ | Imediato | 30 dias | Infrequente, precisa de resiliência |
| One Zone-IA | 1 | Imediato | 30 dias | Infrequente, pode recriar se perder |
| Intelligent-Tiering | 3+ | Imediato/min/h | — | Padrão de acesso desconhecido |
| Glacier Instant Retrieval | 3+ | Milissegundos | 90 dias | Arquivos, acesso trimestral |
| Glacier Flexible Retrieval | 3+ | Minutos-horas | 90 dias | Backups de longo prazo |
| Glacier Deep Archive | 3+ | Até 12 horas | 180 dias | Retenção regulatória 7-10 anos |

---

## 3. BANCO DE DADOS

### RDS Multi-AZ vs Read Replicas

| | Multi-AZ | Read Replica |
|-|----------|--------------|
| Objetivo | Alta disponibilidade | Performance de leitura |
| Replicação | Síncrona | Assíncrona |
| Standby serve leitura | ❌ Não | ✅ Sim |
| Failover | Automático (~1-2 min) | Manual (promoção) |
| Cross-region | ❌ | ✅ |
| Endpoint | Único (não muda no failover) | Endpoint separado |
| Custo | 2x a instância | Por instância adicional |

### Redis vs Memcached

| | Redis | Memcached |
|-|-------|-----------|
| Persistência | ✅ | ❌ |
| Multi-AZ / Failover | ✅ | ❌ |
| Replicação | ✅ | ❌ |
| Sorted Sets, Pub/Sub | ✅ | ❌ |
| Multithreaded | ❌ | ✅ |
| Quando usar | Sessões, leaderboard, pub/sub | Cache simples de alta performance |

### Quando usar SQL vs NoSQL

| Situação | Use |
|----------|-----|
| Estrutura de dados definida, joins, transações ACID | RDS |
| Escala massiva, baixa latência, flexibilidade de schema | DynamoDB |
| Analytics, data warehouse | Redshift |
| Grafos e relacionamentos complexos | Neptune |

---

## 4. REDE

### NAT Gateway vs NAT Instance

| | NAT Gateway | NAT Instance |
|-|-------------|--------------|
| Gerenciado pela AWS | ✅ | ❌ |
| Alta disponibilidade | ✅ Automática por AZ | ❌ Manual (script) |
| Bandwidth | Até 100 Gbps | Limitado ao tipo EC2 |
| Custo | Maior | Menor |
| Security Groups | ❌ Não aplica | ✅ Aplica |
| Uso recomendado | Produção | Lab/desenvolvimento |

### VPC Peering vs Transit Gateway

| | VPC Peering | Transit Gateway |
|-|-------------|-----------------|
| Modelo | 1:1 (ponto a ponto) | Hub-and-spoke |
| Transitivo | ❌ Não | ✅ Sim |
| Máximo de VPCs | Complexo em escala | Milhares |
| Cross-account | ✅ | ✅ |
| Cross-region | ✅ | ✅ |
| Quando usar | Poucas VPCs, baixo volume | Muitas VPCs, rede centralizada |

### CloudFront vs Global Accelerator

| | CloudFront | Global Accelerator |
|-|------------|-------------------|
| Função | CDN (cache de conteúdo) | Roteamento de rede |
| Cache | ✅ | ❌ |
| Protocolo | HTTP/HTTPS | TCP/UDP |
| IP fixo | ❌ | ✅ 2 Anycast IPs |
| Failover | Por origin health check | Automático (~30s) |
| Quando usar | Sites, APIs, assets | Jogos, VoIP, apps não-HTTP |

### VPN vs Direct Connect

| | Site-to-Site VPN | Direct Connect |
|-|-----------------|----------------|
| Velocidade de setup | Minutos | Semanas/meses |
| Latência | Variável (internet) | Consistente e baixa |
| Bandwidth | Limitado (~1.25 Gbps) | 1 Gbps a 100 Gbps |
| Custo | Menor | Maior |
| Criptografia | ✅ IPSec | ❌ (opcional MACsec) |
| Quando usar | Backup de DR, setup rápido | Produção, alta performance |

---

## 5. MENSAGERIA

### SQS vs SNS vs EventBridge vs Kinesis

| | SQS | SNS | EventBridge | Kinesis Data Streams |
|-|-----|-----|-------------|---------------------|
| Modelo | Queue (pull) | Pub/Sub (push) | Event Bus (push) | Streaming (pull) |
| Consumers | 1 por mensagem | N subscribers | N targets | N consumers independentes |
| Ordering | FIFO (com FIFO queue) | ❌ | ❌ | Por shard |
| Persistência | Até 14 dias | Não | Não | 1-365 dias |
| Replay | ❌ | ❌ | ❌ | ✅ |
| Quando usar | Desacoplamento, filas | Notificações, fan-out | Eventos AWS, automação | Streaming, analytics |

---

## 6. SEGURANÇA

### Secrets Manager vs SSM Parameter Store

| | Secrets Manager | SSM Parameter Store |
|-|----------------|---------------------|
| Custo | ~$0.40/segredo/mês | Gratuito (Standard) |
| Rotação automática | ✅ Nativa | ❌ Via Lambda custom |
| Integração com RDS | ✅ Nativa | ❌ |
| Hierarquia de parâmetros | ❌ | ✅ (paths com /) |
| Quando usar | Credenciais de banco, API keys com rotação | Configurações, feature flags, parâmetros gerais |

### WAF vs Shield

| | WAF | Shield Standard | Shield Advanced |
|-|-----|----------------|-----------------|
| Protege contra | Ataques L7 (SQLi, XSS, rate limiting) | DDoS L3/L4 | DDoS L3/L4/L7 |
| Custo | Pago por Web ACL + regra | Gratuito (automático) | $3.000/mês |
| Recursos | ALB, API GW, CloudFront | Todos automaticamente | CloudFront, Route 53, ALB, EC2 |

---

## 7. SERVERLESS

### Lambda vs ECS Fargate vs EC2

| | Lambda | ECS Fargate | EC2 |
|-|--------|-------------|-----|
| Duração máxima | 15 min | Ilimitada | Ilimitada |
| Gerencia infra | ❌ | ❌ | ✅ |
| Custo | Por invocação | Por CPU/memória/hora | Por hora |
| Cold start | ✅ Existe | Menor | ❌ |
| Quando usar | Funções curtas, event-driven | Containers sem gerenciar infra | Controle total, workloads pesados |

---

## 8. PALAVRAS-CHAVE DA PROVA

| Palavra-chave | Pense em... |
|---------------|------------|
| "sem gerenciar servidores" | Lambda, Fargate, DynamoDB, Aurora Serverless, S3 |
| "menor latência possível" | ElastiCache, DAX, Placement Group Cluster, Global Accelerator |
| "alta disponibilidade" | Multi-AZ, ASG com múltiplas AZs, Aurora Global |
| "mais econômico" | Reserved Instances, Spot, S3 Glacier, One Zone-IA |
| "acesso compartilhado entre instâncias" | EFS, S3 |
| "comunicação entre VPCs" | VPC Peering (poucas), Transit Gateway (muitas) |
| "acesso privado a S3 sem internet" | VPC Gateway Endpoint |
| "acesso privado a outros serviços AWS" | VPC Interface Endpoint (PrivateLink) |
| "failover automático de banco" | RDS Multi-AZ |
| "escalar leitura do banco" | RDS Read Replica |
| "IP fixo global" | Global Accelerator |
| "conteúdo cacheado próximo ao usuário" | CloudFront |
| "rotação automática de credenciais" | Secrets Manager |
| "auditoria de API calls" | CloudTrail |
| "conformidade e histórico de configuração" | AWS Config |
| "processar mensagens em paralelo" | SNS fan-out + SQS |
| "replay de eventos" | Kinesis Data Streams |
| "migração de dados offline (> 1 semana pela internet)" | Snow Family |
| "compartilhamento de arquivos entre Windows servers" | FSx for Windows |
| "sistema de arquivos para HPC/ML" | FSx for Lustre |
| "proteção contra DDoS" | Shield + WAF |
| "detectar ameaças com ML" | GuardDuty |
| "descobrir dados sensíveis no S3" | Macie |
| "análise de vulnerabilidades em EC2/Lambda" | Inspector |
