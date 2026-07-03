# Plano de Estudo — SAA-C03

> **Início:** 02/07/2026 | **Prova:** 15/09/2026 | **Duração:** 10 semanas

---

## Estimativa de Carga Total

| Atividade | Horas estimadas |
|-----------|----------------|
| Curso Stephane Maarek (vídeo + pausas/repetições) | ~40h |
| Leitura de documentação e FAQs | ~15h |
| Laboratórios práticos | ~10h |
| Simulados (8-10 exames completos de 65 questões) | ~18h |
| Revisão de erros e anotações | ~15h |
| **Total** | **~100h** |

### Distribuição Semanal

100h ÷ 10 semanas = **10h por semana (mínimo)**

| Dia | Mínimo | Recomendado | Como usar |
|-----|--------|-------------|-----------|
| Segunda a Sexta | 1h30/dia | 2h/dia | Teoria + anotações |
| Sábado | 3h | 4h | Lab prático ou simulado parcial |
| Domingo | 2h | 3h | Revisão da semana + simulado parcial |
| **Total semanal** | **~10h** | **~14h** | |

> **Mínimo absoluto:** 1h30/dia útil + 3h no fim de semana → dá para passar, mas sem folga.
> **Recomendado:** 2h/dia útil + 4h no fim de semana → chega nas semanas 9-10 com confiança.
>
> ⚠️ As semanas 07 (Segurança) e 09-10 (simulados intensivos) exigem mais tempo que as demais. Guarde energia para o sprint final.

---

## Estratégia Geral

- **Carga diária recomendada:** 2h nos dias de semana, 3-4h no fim de semana
- **Método:** Teoria → Prática (labs) → Revisão com simulados
- **Meta de simulados:** 80%+ de forma consistente antes de agendar
- **Ferramenta principal:** Tutorials Dojo (Jon Bonso) para simulados

### Como usar este plano

1. Assista as aulas do curso (Stephane Maarek - Udemy)
2. Faça anotações no arquivo `semanas/semana-XX/anotacoes.md`
3. Marque os itens do `checklist.md` conforme conclui
4. Pratique no AWS Free Tier com os labs em `laboratorios/`
5. Registre scores dos simulados em `simulados/registro.md`

---

## Semana 01 — 02/07 a 08/07 | IAM + EC2

**Objetivo:** Dominar identidade, acesso e computação básica

### IAM
- [ ] Usuários, grupos e roles
- [ ] Policies (inline vs managed)
- [ ] MFA e credential report
- [ ] IAM best practices
- [ ] Access Analyzer
- [ ] STS e AssumeRole

### EC2
- [ ] Tipos de instância (famílias e use cases)
- [ ] Purchasing options (On-Demand, Reserved, Spot, Savings Plans)
- [ ] AMIs (criação e uso)
- [ ] EBS (tipos: gp2, gp3, io1, io2, st1, sc1)
- [ ] Instance Store vs EBS
- [ ] Security Groups vs NACLs (preview)
- [ ] Elastic IP
- [ ] EC2 Instance Connect
- [ ] User Data scripts

**Labs:** `lab-04-iam-roles` | `lab-02-ec2-com-alb` (parte 1)

---

## Semana 02 — 09/07 a 15/07 | VPC + S3

**Objetivo:** Entender redes e armazenamento de objetos

### VPC
- [ ] CIDR, subnets públicas e privadas
- [ ] Internet Gateway e NAT Gateway
- [ ] Route Tables
- [ ] Security Groups vs NACLs (diferenças críticas)
- [ ] VPC Peering
- [ ] VPC Endpoints (Interface e Gateway)
- [ ] PrivateLink
- [ ] VPN Site-to-Site e Client VPN
- [ ] Direct Connect
- [ ] Transit Gateway
- [ ] Flow Logs

### S3
- [ ] Buckets, objetos e prefixos
- [ ] Storage classes (S3 Standard, IA, One Zone-IA, Glacier, Glacier Deep Archive, Intelligent-Tiering)
- [ ] Lifecycle policies
- [ ] Versioning e MFA Delete
- [ ] Replication (CRR e SRR)
- [ ] Bucket policies e ACLs
- [ ] Block Public Access
- [ ] Pre-signed URLs
- [ ] S3 Select e Glacier Select
- [ ] S3 Transfer Acceleration
- [ ] Multipart Upload
- [ ] Event Notifications
- [ ] S3 Object Lock (WORM)

**Labs:** `lab-01-vpc-basica` | `lab-03-s3-estatico`

---

## Semana 03 — 16/07 a 22/07 | Alta Disponibilidade

**Objetivo:** Arquitetar soluções escaláveis e tolerantes a falhas

### Elastic Load Balancing
- [ ] ALB (Application Load Balancer) — camada 7
- [ ] NLB (Network Load Balancer) — camada 4
- [ ] GLB (Gateway Load Balancer) — appliances
- [ ] Target Groups
- [ ] Stickiness e Cross-Zone Load Balancing
- [ ] Connection Draining

### Auto Scaling Groups
- [ ] Launch Templates vs Launch Configurations
- [ ] Scaling policies (Target Tracking, Step, Scheduled)
- [ ] Cooldown period
- [ ] Health checks
- [ ] Lifecycle Hooks

### Route 53
- [ ] Record types (A, AAAA, CNAME, Alias)
- [ ] Routing policies: Simple, Weighted, Latency, Failover, Geolocation, Geoproximity, Multi-Value
- [ ] Health Checks
- [ ] Private Hosted Zones

**Labs:** `lab-02-ec2-com-alb` (completo)

---

## Semana 04 — 23/07 a 29/07 | Bancos de Dados

**Objetivo:** Escolher o banco certo para cada cenário

### RDS
- [ ] Engines suportadas (MySQL, PostgreSQL, Oracle, SQL Server, MariaDB)
- [ ] Multi-AZ (failover automático)
- [ ] Read Replicas (performance, cross-region)
- [ ] Backups automáticos vs Snapshots
- [ ] RDS Proxy
- [ ] Encryption at rest e in transit
- [ ] IAM Authentication

### Aurora
- [ ] Aurora vs RDS (diferenças de arquitetura)
- [ ] Aurora Serverless v2
- [ ] Aurora Global Database
- [ ] Aurora Multi-Master
- [ ] Aurora Replicas

### ElastiCache
- [ ] Redis vs Memcached (quando usar cada)
- [ ] Caching strategies (Lazy Loading, Write-Through)
- [ ] Redis Cluster Mode

### Outros Bancos
- [ ] DynamoDB (preview — aprofunda na semana 5)
- [ ] Redshift (data warehouse)
- [ ] Neptune (grafo)
- [ ] DocumentDB (MongoDB compatível)
- [ ] Keyspaces (Cassandra compatível)
- [ ] Timestream (séries temporais)

**Labs:** `lab-05-rds-multi-az`

---

## Semana 05 — 30/07 a 05/08 | Serverless

**Objetivo:** Dominar arquiteturas sem servidor

### Lambda
- [ ] Execução, timeout e limites
- [ ] Triggers e event sources
- [ ] Layers
- [ ] Lambda@Edge vs CloudFront Functions
- [ ] Concurrency (reserved e provisioned)
- [ ] VPC Integration
- [ ] Environment variables e Secrets

### API Gateway
- [ ] REST API vs HTTP API vs WebSocket API
- [ ] Stages e deployments
- [ ] Throttling e usage plans
- [ ] Cache
- [ ] Integração com Lambda, HTTP, serviços AWS

### DynamoDB
- [ ] Partition key e Sort key
- [ ] RCU e WCU (cálculos)
- [ ] On-demand vs Provisioned capacity
- [ ] Indexes: GSI e LSI
- [ ] DynamoDB Streams
- [ ] DAX (cache)
- [ ] TTL
- [ ] Transactions
- [ ] Global Tables

### Outros Serverless
- [ ] Step Functions
- [ ] AppSync (GraphQL)
- [ ] Cognito (User Pools vs Identity Pools)

---

## Semana 06 — 06/08 a 12/08 | Integração + CDN

**Objetivo:** Desacoplar arquiteturas e acelerar entrega de conteúdo

### Mensageria e Eventos
- [ ] SQS (Standard vs FIFO)
- [ ] SQS — visibility timeout, DLQ, delay queue
- [ ] SNS (fan-out pattern)
- [ ] SNS + SQS fan-out
- [ ] EventBridge (regras, event buses, pipes)
- [ ] Kinesis Data Streams
- [ ] Kinesis Data Firehose
- [ ] MSK (Managed Kafka)

### CloudFront
- [ ] Origins (S3, ALB, Custom)
- [ ] Behaviors e cache policies
- [ ] OAC (Origin Access Control)
- [ ] Geo Restriction
- [ ] Signed URLs vs Signed Cookies
- [ ] CloudFront Functions vs Lambda@Edge

### Outros
- [ ] Global Accelerator (vs CloudFront)
- [ ] AppFlow
- [ ] DataSync

---

## Semana 07 — 13/08 a 19/08 | Segurança

**Objetivo:** Dominar o domínio de maior peso na prova (30%)

### Criptografia e Secrets
- [ ] KMS (CMK, AWS managed vs Customer managed)
- [ ] KMS — envelope encryption
- [ ] KMS — key policies e grants
- [ ] Secrets Manager vs SSM Parameter Store (diferenças críticas)
- [ ] ACM (Certificate Manager)
- [ ] CloudHSM

### Proteção e Compliance
- [ ] WAF (Web ACL, regras, rate limiting)
- [ ] Shield (Standard vs Advanced)
- [ ] GuardDuty
- [ ] Inspector
- [ ] Macie
- [ ] Security Hub
- [ ] Firewall Manager

### Identidade e Acesso Avançado
- [ ] AWS Organizations e SCPs
- [ ] AWS SSO / IAM Identity Center
- [ ] Resource Access Manager (RAM)
- [ ] Directory Service (AD Connector, Simple AD, Managed AD)

---

## Semana 08 — 20/08 a 26/08 | Monitoramento + Storage Avançado

**Objetivo:** Observabilidade e opções de armazenamento

### Monitoramento
- [ ] CloudWatch Metrics, Logs, Alarms
- [ ] CloudWatch Container Insights, Lambda Insights
- [ ] CloudWatch Dashboards
- [ ] CloudTrail (trilhas, eventos de dados vs gestão)
- [ ] AWS Config (rules e conformance packs)
- [ ] X-Ray
- [ ] EventBridge (integração com CloudTrail)
- [ ] Health Dashboard (Personal Health Dashboard)

### Storage Avançado
- [ ] EFS (NFS, performance modes, storage classes)
- [ ] FSx for Windows File Server
- [ ] FSx for Lustre
- [ ] FSx for NetApp ONTAP
- [ ] Storage Gateway (File, Volume, Tape)
- [ ] Snow Family (Snowcone, Snowball Edge, Snowmobile)
- [ ] AWS Backup

### Containers
- [ ] ECS (EC2 vs Fargate)
- [ ] EKS (overview)
- [ ] ECR
- [ ] App Runner

---

## Semana 09 — 27/08 a 02/09 | Revisão Geral + Simulados

**Objetivo:** Identificar e corrigir pontos fracos

### Atividades
- [ ] Simulado completo (65 questões) — Tutorials Dojo Exam 1
- [ ] Revisão dos erros do simulado 1
- [ ] Revisar serviços com menor confiança
- [ ] Simulado completo (65 questões) — Tutorials Dojo Exam 2
- [ ] Revisão dos erros do simulado 2
- [ ] Revisar domínio: Arquiteturas Seguras (30%)
- [ ] Revisar domínio: Arquiteturas Resilientes (26%)
- [ ] Reler anotações dos serviços core (IAM, EC2, VPC, S3, RDS)

### Meta da semana
Atingir **75%+** nos simulados

---

## Semana 10 — 03/09 a 09/09 | Sprint Final

**Objetivo:** Consolidar conhecimento e atingir 80%+

### Atividades
- [ ] Simulado completo — Tutorials Dojo Exam 3
- [ ] Revisão dos erros
- [ ] Simulado completo — Tutorials Dojo Exam 4
- [ ] Revisão dos erros
- [ ] Simulado completo — Tutorials Dojo Exam 5
- [ ] Flashcards dos serviços mais confusos
- [ ] Revisar diferenças críticas (lista abaixo)
- [ ] Revisão final dos 4 domínios

### Diferenças Críticas para Revisar
- [ ] Security Groups vs NACLs
- [ ] RDS Multi-AZ vs Read Replicas
- [ ] CloudFront vs Global Accelerator
- [ ] SQS vs SNS vs EventBridge vs Kinesis
- [ ] NAT Gateway vs NAT Instance
- [ ] S3 Standard-IA vs S3 One Zone-IA
- [ ] Secrets Manager vs SSM Parameter Store
- [ ] ALB vs NLB vs GLB
- [ ] EBS vs EFS vs Instance Store
- [ ] On-Demand vs Reserved vs Spot vs Savings Plans

### Meta da semana
Atingir **80%+** de forma consistente → Confirmar data da prova ✅

---

## Dias 10-15/09 — Revisão Leve

- Não estudar conteúdo novo
- Reler apenas anotações e checklists
- Um simulado no máximo no dia 13/09
- Descansar bem na véspera

---

## Métricas de Acompanhamento

| Semana | Horas Estudadas | Score Simulado | Confiança (1-5) |
|--------|-----------------|----------------|-----------------|
| 01 | | | |
| 02 | | | |
| 03 | | | |
| 04 | | | |
| 05 | | | |
| 06 | | | |
| 07 | | | |
| 08 | | | |
| 09 | | | |
| 10 | | | |
