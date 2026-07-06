# Solution Architectures - AWS SAA-C03

> Guia expandido de arquiteturas de soluções para a certificação AWS Solutions Architect Associate (SAA-C03).
> Cobre patterns de eventos, caching, segurança de rede, HPC, alta disponibilidade, Well-Architected Framework,
> Trusted Advisor e arquiteturas clássicas/serverless.

---

## 1. Event Processing in AWS

### 1.1 Visão Geral dos Serviços de Mensageria/Eventos

| Serviço | Tipo | Modelo | Retenção | Ordering |
|---------|------|--------|----------|----------|
| SQS | Queue | Pull (polling) | 1-14 dias | FIFO opcional |
| SNS | Pub/Sub | Push | Sem retenção | Não garantida |
| EventBridge | Event Bus | Push (rules) | Replay até 90 dias | Não garantida |
| Kinesis Data Streams | Streaming | Pull (consumers) | 1-365 dias | Por shard |

### 1.2 Patterns de Processamento de Eventos

#### Pattern 1: Fan-Out (SNS + SQS)

```
                          ┌──────────┐    ┌──────────────┐
                          │  SQS Q1  │───▶│ Consumer A   │
                          └──────────┘    └──────────────┘
                         ╱
┌──────────┐   ┌───────┐╱ ┌──────────┐    ┌──────────────┐
│ Producer │──▶│  SNS  │──│  SQS Q2  │───▶│ Consumer B   │
└──────────┘   └───────┘╲ └──────────┘    └──────────────┘
                         ╲
                          ┌──────────┐    ┌──────────────┐
                          │  SQS Q3  │───▶│ Consumer C   │
                          └──────────┘    └──────────────┘
```

**Quando usar:**
- Uma mensagem precisa ser processada por múltiplos consumers independentes
- Cada consumer processa no seu próprio ritmo (buffered pelo SQS)
- Garante que nenhuma mensagem é perdida (SQS retém)
- Cross-region delivery com SNS

**Exemplo real:** Upload de imagem no S3 → SNS notifica → SQS para thumbnail, SQS para metadata, SQS para ML processing

#### Pattern 2: Queue Processing (SQS Standard/FIFO)

```
┌──────────┐    ┌─────────────┐    ┌──────────────────┐
│ Producer │───▶│  SQS Queue  │───▶│  Consumer (EC2/  │
│          │    │             │    │  Lambda/ECS)     │
└──────────┘    │ - Retry     │    └──────────────────┘
                │ - DLQ       │             │
                │ - Visibility│             │ (falha)
                └─────────────┘             ▼
                       ▲            ┌──────────────┐
                       └────────────│     DLQ      │
                                    └──────────────┘
```

**Quando usar:**
- Desacoplamento entre produtor e consumidor
- Processamento assíncrono com retry automático
- Rate limiting / buffering de picos de carga
- Ordering garantida (FIFO) para transações financeiras

**Configurações importantes:**
- `VisibilityTimeout`: tempo que mensagem fica invisível após ser lida
- `DelaySeconds`: atraso antes da mensagem ficar disponível
- `MaxReceiveCount`: tentativas antes de ir para DLQ
- `MessageRetentionPeriod`: 1 min a 14 dias

#### Pattern 3: Streaming em Tempo Real (Kinesis Data Streams)

```
┌──────────┐    ┌─────────────────────────────────┐
│Producer 1│──┐ │     Kinesis Data Streams         │
└──────────┘  │ │                                  │
              │ │  Shard 1: [msg1][msg3][msg5]──────│───▶ Consumer Group A
┌──────────┐  ├▶│  Shard 2: [msg2][msg4][msg6]──────│───▶ Consumer Group A
│Producer 2│──┤ │  Shard 3: [msg7][msg8][msg9]──────│───▶ Consumer Group A
└──────────┘  │ │                                  │
              │ └─────────────────────────────────┘
┌──────────┐  │          │              │
│Producer 3│──┘          ▼              ▼
└──────────┘     ┌──────────┐   ┌──────────────┐
                 │  Kinesis │   │   Kinesis    │
                 │ Firehose │   │  Analytics   │
                 └──────────┘   └──────────────┘
                      │
                      ▼
              ┌──────────────┐
              │ S3 / Redshift│
              └──────────────┘
```

**Quando usar:**
- Dados em tempo real (logs, clicks, IoT, métricas)
- Ordering garantida dentro de cada shard (partition key)
- Múltiplos consumers leem o mesmo dado (replay)
- Throughput: 1 MB/s por shard (in) e 2 MB/s por shard (out)
- Enhanced Fan-Out: 2 MB/s por consumer por shard

**Kinesis vs SQS:**
- Kinesis: ordering por shard, replay, múltiplos consumers simultâneos
- SQS: delete após processamento, sem ordering (standard), scaling automático

#### Pattern 4: Event-Driven (EventBridge)

```
┌──────────────┐     ┌─────────────────────────────────────────┐
│ AWS Services │────▶│                                         │
│ (S3, EC2...) │     │         EventBridge Event Bus           │
└──────────────┘     │                                         │
                     │  ┌─────────┐  ┌─────────┐  ┌────────┐  │
┌──────────────┐     │  │ Rule 1  │  │ Rule 2  │  │ Rule 3 │  │
│ Custom Apps  │────▶│  │if src=S3│  │if EC2   │  │schedule│  │
└──────────────┘     │  └────┬────┘  └────┬────┘  └───┬────┘  │
                     │       │            │            │        │
┌──────────────┐     └───────┼────────────┼────────────┼───────┘
│ SaaS (Zendesk│             │            │            │
│  Datadog...) │             ▼            ▼            ▼
└──────────────┘      ┌──────────┐ ┌──────────┐ ┌──────────┐
                      │  Lambda  │ │   SNS    │ │Step Func │
                      └──────────┘ └──────────┘ └──────────┘
```

**Quando usar:**
- Reagir a eventos de serviços AWS (nativo)
- Integração com SaaS partners (Zendesk, Datadog, Auth0)
- Scheduling (cron expressions) — substitui CloudWatch Events
- Content-based filtering com regras JSON
- Schema Registry para descoberta de eventos
- Archive e Replay de eventos (até 90 dias)

**EventBridge vs SNS:**
- EventBridge: filtering avançado (JSON patterns), mais targets, schema discovery
- SNS: maior throughput, mais simples, FIFO support

### 1.3 S3 Event Notifications

```
┌────────┐  Event    ┌─────────────────────────────────┐
│   S3   │─────────▶│  Destinos possíveis:             │
│ Bucket │           │  • SNS Topic                     │
└────────┘           │  • SQS Queue                     │
  Events:            │  • Lambda Function               │
  - s3:ObjectCreated │  • EventBridge (ALL events)      │
  - s3:ObjectRemoved └─────────────────────────────────┘
  - s3:ObjectRestore
  - s3:Replication
```

**Dica de prova:** Se a questão menciona "reagir a QUALQUER evento S3 com filtering avançado" → EventBridge.
Se menciona apenas "reagir a upload" → SNS/SQS/Lambda direto é suficiente.

### 1.4 Intercept API Calls (CloudTrail + EventBridge)

```
┌──────────┐    ┌────────────┐    ┌─────────────┐    ┌──────────┐
│ API Call │───▶│ CloudTrail │───▶│ EventBridge │───▶│  Lambda  │
│(qualquer)│    │            │    │   Rule      │    │  (alert) │
└──────────┘    └────────────┘    └─────────────┘    └──────────┘
```

**Caso de uso:** Detectar DeleteTable no DynamoDB → alertar via SNS

---


## 2. Caching Strategies in AWS

### 2.1 Diagrama de Camadas de Cache

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        CAMADAS DE CACHE                                  │
│                                                                         │
│  Cliente                                                                │
│    │                                                                    │
│    ▼                                                                    │
│  ┌──────────────────┐  Cache de edge (CDN)                              │
│  │   CloudFront     │  TTL: segundos a dias                             │
│  │   (Edge Cache)   │  Cache-Control / Expires headers                  │
│  └────────┬─────────┘                                                   │
│           │ Cache MISS                                                   │
│           ▼                                                              │
│  ┌──────────────────┐  Cache de API responses                           │
│  │   API Gateway    │  TTL: 300s default (0-3600s)                      │
│  │   (Stage Cache)  │  Per-method / per-resource                        │
│  └────────┬─────────┘                                                   │
│           │ Cache MISS                                                   │
│           ▼                                                              │
│  ┌──────────────────┐  Cache de aplicação                               │
│  │  Application     │  Session store, computed results                  │
│  │  (ElastiCache)   │  Redis: persistence, replication, Pub/Sub        │
│  │  Redis/Memcached │  Memcached: multi-threaded, simpler              │
│  └────────┬─────────┘                                                   │
│           │ Cache MISS                                                   │
│           ▼                                                              │
│  ┌──────────────────┐  Cache de queries DynamoDB                        │
│  │      DAX         │  Microseconds latency                             │
│  │  (DynamoDB Accel)│  Item cache + Query cache                         │
│  └────────┬─────────┘                                                   │
│           │ Cache MISS                                                   │
│           ▼                                                              │
│  ┌──────────────────┐                                                   │
│  │   Database       │  RDS Read Replicas (eventual consistency)         │
│  │  (RDS/DynamoDB/  │  Aurora Reader Endpoints                          │
│  │   Aurora)        │  DynamoDB (sem cache = ms latency)                │
│  └──────────────────┘                                                   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.2 CloudFront Caching

- **Cache behaviors:** Definidos por path pattern (`/images/*`, `/api/*`)
- **TTL controls:** `min TTL`, `max TTL`, `default TTL`
- **Cache keys:** Headers, cookies, query strings incluídos na cache key
- **Cache Policy vs Origin Request Policy:**
  - Cache Policy: define o que faz parte da cache key
  - Origin Request Policy: define o que é encaminhado para a origin (sem afetar cache key)
- **Invalidation:** `CreateInvalidation` para forçar purge (custo por request)
- **Regional Edge Caches:** Camada intermediária entre Edge Locations e Origin

### 2.3 API Gateway Caching

- Habilitado por stage
- TTL: 0 a 3600 segundos (default 300s)
- Cache capacity: 0.5 GB a 237 GB
- Pode ser invalidado pelo client com header `Cache-Control: max-age=0` (requer IAM policy)
- **Custo:** Cobrado por hora pela capacidade provisionada
- **Dica de prova:** "Reduzir chamadas ao backend sem alterar código" → API Gateway Cache

### 2.4 ElastiCache Strategies

#### Lazy Loading (Cache-Aside)

```
┌────────┐  1. Read    ┌────────────┐
│  App   │────────────▶│ ElastiCache│
│        │◀────────────│            │
└────┬───┘  2. Miss    └────────────┘
     │
     │ 3. Read from DB
     ▼
┌────────────┐
│     DB     │
└────────────┘
     │
     │ 4. App writes to cache
     ▼
┌────────────┐
│ ElastiCache│ (atualizado)
└────────────┘
```

- **Prós:** Só cacheia dados requisitados, resiliente a falhas de cache
- **Contras:** Cache miss = 3 round trips, dados podem ficar stale

#### Write-Through

```
┌────────┐  1. Write   ┌────────────┐
│  App   │────────────▶│ ElastiCache│ (atualizado imediatamente)
│        │             └────────────┘
└────┬───┘
     │ 2. Write to DB
     ▼
┌────────────┐
│     DB     │
└────────────┘
```

- **Prós:** Dados sempre atualizados no cache, read latency baixa
- **Contras:** Write penalty (2 writes), cache churn (dados que nunca serão lidos)
- **Combinação ideal:** Write-Through + TTL para evitar cache churn

### 2.5 DAX (DynamoDB Accelerator)

- Cache **transparente** para DynamoDB (drop-in replacement no SDK)
- **Item Cache:** Resultados de GetItem/BatchGetItem
- **Query Cache:** Resultados de Query/Scan
- Latência de microsegundos (vs milissegundos do DynamoDB)
- Multi-AZ (mínimo 3 nodes recomendado para produção)
- **Quando NÃO usar:** Write-heavy workloads, queries que precisam de strong consistency

### 2.6 Comparativo Redis vs Memcached

| Feature | Redis | Memcached |
|---------|-------|-----------|
| Persistence | Sim (AOF, RDB) | Não |
| Replication | Sim (Read Replicas) | Não |
| Multi-AZ | Sim (failover) | Não |
| Data structures | Rich (sets, sorted sets, hashes) | Key-value simples |
| Pub/Sub | Sim | Não |
| Multi-threaded | Não (single-threaded) | Sim |
| Partitioning | Cluster mode | Sim (auto-discovery) |
| Backup/Restore | Sim | Não |

**Dica de prova:**
- "Session store com replicação" → Redis
- "Simple caching com multi-threading" → Memcached
- "Leaderboards / ranking" → Redis (sorted sets)

---

## 3. Blocking an IP Address

### 3.1 Diagrama Completo de Opções

```
┌─────────────────────────────────────────────────────────────────────┐
│                   CAMADAS DE BLOQUEIO DE IP                          │
│                                                                     │
│  Internet                                                           │
│     │                                                               │
│     ▼                                                               │
│  ┌────────────────────────────────────────┐                         │
│  │ AWS WAF (Web Application Firewall)     │ ◀── IP Set Rules        │
│  │ • IP Set (até 10.000 IPs por set)      │     Rate-based Rules    │
│  │ • Rate-based rules (DDoS)              │     Geo-match           │
│  │ • Geo-match (bloquear países)          │                         │
│  │ • Associado a: CloudFront, ALB, API GW │                         │
│  └────────────────┬───────────────────────┘                         │
│                   │                                                  │
│                   ▼                                                  │
│  ┌────────────────────────────────────────┐                         │
│  │ CloudFront                             │                         │
│  │ • Geo-Restriction (whitelist/blacklist)│                         │
│  │ • Signed URLs / Signed Cookies         │                         │
│  │ • Origin Access Control (OAC)          │                         │
│  └────────────────┬───────────────────────┘                         │
│                   │                                                  │
│                   ▼                                                  │
│  ┌────────────────────────────────────────┐                         │
│  │ Network ACL (NACL)                     │ ◀── Stateless           │
│  │ • Subnet level                         │     DENY rules (IP)     │
│  │ • Inbound E Outbound rules             │     Processamento por   │
│  │ • Rules numeradas (menor = prioridade) │     número de regra     │
│  │ • DENY explícito possível              │                         │
│  └────────────────┬───────────────────────┘                         │
│                   │                                                  │
│                   ▼                                                  │
│  ┌────────────────────────────────────────┐                         │
│  │ Security Group                         │ ◀── Stateful            │
│  │ • Instance/ENI level                   │     Só ALLOW rules      │
│  │ • Apenas ALLOW (sem DENY)              │     NÃO bloqueia IP     │
│  │ • ⚠️ NÃO pode bloquear IP específico   │     específico!         │
│  └────────────────────────────────────────┘                         │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 3.2 Cenários de Bloqueio por Camada

#### Cenário A: EC2 Instance sem ALB

```
┌────────┐    ┌───────┐    ┌─────┐    ┌─────┐
│Atacante│───▶│ NACL  │───▶│ SG  │───▶│ EC2 │
└────────┘    │(DENY) │    │     │    └─────┘
              └───────┘    └─────┘
              ✅ Pode       ❌ Não pode
              bloquear      bloquear
```

**Solução:** NACL com regra DENY para o IP do atacante

#### Cenário B: ALB + EC2

```
┌────────┐    ┌─────┐    ┌───────┐    ┌─────┐    ┌───────┐    ┌─────┐
│Atacante│───▶│ WAF │───▶│ NACL  │───▶│ ALB │───▶│ NACL  │───▶│ EC2 │
└────────┘    │     │    │(subnet│    │     │    │(subnet│    └─────┘
              └─────┘    │ ALB)  │    └─────┘    │ EC2)  │
              ✅          ✅                       │       │
                                                  └───────┘
```

**Solução ideal:** WAF associado ao ALB (mais fácil de gerenciar, IP sets)

#### Cenário C: CloudFront + ALB

```
┌────────┐    ┌─────┐    ┌────────────┐    ┌─────┐    ┌─────┐
│Atacante│───▶│ WAF │───▶│ CloudFront │───▶│ ALB │───▶│ EC2 │
└────────┘    │(CF) │    │            │    │     │    └─────┘
              └─────┘    └────────────┘    └─────┘
              ✅ IP Set
              ✅ Geo-Restriction no CF
```

**⚠️ Importante:** Quando CloudFront está na frente, o NACL no ALB vê o IP do CloudFront (não do cliente).
Portanto, NACL não funciona para bloquear o IP real do cliente neste cenário.
**Solução:** WAF no CloudFront com IP Set rule.

### 3.3 Comparativo de Mecanismos

| Mecanismo | Camada | Pode DENY? | Granularidade | Custo |
|-----------|--------|-----------|---------------|-------|
| Security Group | Instance | ❌ Só ALLOW | IP/CIDR/SG ref | Grátis |
| NACL | Subnet | ✅ DENY + ALLOW | IP/CIDR | Grátis |
| WAF | L7 (HTTP) | ✅ Block/Allow/Count | IP/Geo/Rate/Pattern | ~$5/ACL + por request |
| CloudFront Geo | Edge | ✅ (por país) | País (ISO) | Incluído no CF |
| AWS Shield | L3/L4 | ✅ (auto DDoS) | DDoS patterns | Standard=grátis, Advanced=$3k/mês |

### 3.4 Dicas de Prova

- "Bloquear IP específico" + "sem ALB/CloudFront" → **NACL**
- "Bloquear IP específico" + "com ALB" → **WAF no ALB**
- "Bloquear IP específico" + "com CloudFront" → **WAF no CloudFront**
- "Bloquear país inteiro" → **CloudFront Geo-Restriction** ou **WAF Geo-match**
- "Rate limiting" → **WAF Rate-based rule**
- "Security Group pode bloquear IP?" → **NÃO** (só permite, não nega)

---


## 4. High Performance Computing (HPC) on AWS

### 4.1 Visão Geral da Arquitetura HPC

```
┌─────────────────────────────────────────────────────────────────────┐
│                    HPC Architecture on AWS                           │
│                                                                     │
│  ┌─────────────────┐    ┌──────────────────────────────────────┐    │
│  │   Data Transfer  │    │        Compute                       │    │
│  │                  │    │                                      │    │
│  │ • Direct Connect │    │  ┌────────────────────────────────┐  │    │
│  │ • Snowball/Edge  │    │  │   EC2 Cluster Placement Group  │  │    │
│  │ • DataSync       │    │  │   ┌────┐ ┌────┐ ┌────┐ ┌────┐ │  │    │
│  │ • S3 Transfer    │    │  │   │EC2 │ │EC2 │ │EC2 │ │EC2 │ │  │    │
│  │   Acceleration   │    │  │   │ENA │ │ENA │ │EFA │ │EFA │ │  │    │
│  └─────────────────┘    │  │   └────┘ └────┘ └────┘ └────┘ │  │    │
│                          │  └────────────────────────────────┘  │    │
│  ┌─────────────────┐    │                                      │    │
│  │   Storage        │    │  • GPU instances (P4d, P5)          │    │
│  │                  │    │  • Spot Instances para custo         │    │
│  │ • FSx for Lustre │    │  • AWS Batch para orchestração      │    │
│  │ • EBS io2       │    │  • ParallelCluster para scheduler   │    │
│  │ • S3 (data lake)│    └──────────────────────────────────────┘    │
│  └─────────────────┘                                                │
│                          ┌──────────────────────────────────────┐    │
│  ┌─────────────────┐    │        Networking                     │    │
│  │  Orchestration   │    │                                      │    │
│  │                  │    │  • ENA: Enhanced Networking (100Gbps) │    │
│  │ • AWS Batch      │    │  • EFA: Elastic Fabric Adapter        │    │
│  │ • ParallelCluster│    │  • Placement Group: Cluster           │    │
│  │ • Step Functions │    └──────────────────────────────────────┘    │
│  └─────────────────┘                                                │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 Enhanced Networking

#### ENA (Elastic Network Adapter)
- Suporta até **100 Gbps** de bandwidth
- Usa SR-IOV (Single Root I/O Virtualization) — bypass do hypervisor
- Menor latência, maior PPS (packets per second)
- Habilitado por padrão nas instâncias modernas (C5, M5, R5+)
- Sem custo adicional

#### EFA (Elastic Fabric Adapter)
- **ENA + OS-bypass** para comunicação inter-node
- Suporta **MPI (Message Passing Interface)** — padrão HPC
- Latência consistente e ultra-baixa entre instâncias
- Bypass do kernel do OS para comunicação node-to-node
- **Apenas Linux** (não suporta Windows)
- Ideal para: simulações climáticas, dinâmica de fluidos, machine learning distribuído

### 4.3 Placement Groups - Cluster

```
┌─────────────────────────────────────────┐
│         Single AZ - Same Rack           │
│                                         │
│  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐   │
│  │ EC2 │──│ EC2 │──│ EC2 │──│ EC2 │   │
│  │     │  │     │  │     │  │     │   │
│  └─────┘  └─────┘  └─────┘  └─────┘   │
│     10 Gbps+ entre instâncias           │
│     Latência < 1ms                      │
│                                         │
│  ⚠️ Risco: se rack falhar, TUDO falha    │
└─────────────────────────────────────────┘
```

- **Cluster:** Todas na mesma AZ, mesmo rack → mínima latência
- **Spread:** Máximo 7 instâncias por AZ, racks diferentes → HA
- **Partition:** Grupos em racks diferentes → big data (HDFS, Kafka)

### 4.4 FSx for Lustre + S3

```
┌────────────┐     ┌─────────────────────┐     ┌──────────┐
│   S3       │◀───▶│   FSx for Lustre    │◀───▶│  EC2     │
│ (data lake)│     │                     │     │ (compute)│
└────────────┘     │ • POSIX compliant   │     └──────────┘
                   │ • 100s GB/s throughput│
  Lazy loading     │ • Sub-ms latency     │     POSIX mount
  from S3          │ • Scratch: temp HPC  │
                   │ • Persistent: long   │
  Write-back       │   term storage       │
  to S3            └─────────────────────┘
```

- **Scratch:** Dados temporários, alta performance, sem replicação (HPC jobs)
- **Persistent:** Dados de longa duração, replicado na mesma AZ
- Integração nativa com S3: lazy loading (lê do S3 sob demanda) e write-back
- Performance: centenas de GB/s, milhões de IOPS

### 4.5 AWS Batch

- **Managed service** para execução de batch jobs em escala
- Provisiona automaticamente EC2/Spot instances com base na queue
- Define `Job Definitions` (Docker containers), `Job Queues`, `Compute Environments`
- Suporta multi-node parallel jobs (MPI)
- **Batch vs Lambda:**
  - Lambda: 15 min timeout, runtime limitado, serverless
  - Batch: sem time limit, qualquer runtime (Docker), managed EC2/Spot

### 4.6 AWS ParallelCluster

- **Open-source cluster management tool** para HPC
- Configuração via texto simples (YAML)
- Cria automaticamente: VPC, subnets, head node, compute nodes
- Suporta schedulers: Slurm, AWS Batch
- Integra com EFA, FSx for Lustre, S3
- Automates: scaling de compute nodes, placement groups

### 4.7 Data Transfer para HPC

| Método | Use Case | Throughput |
|--------|----------|-----------|
| Direct Connect | Conexão dedicada on-prem → AWS | 1-100 Gbps |
| Snowball Edge | Migração massiva offline | PBs |
| DataSync | Sincronização contínua | Até 10 Gbps |
| S3 Transfer Acceleration | Upload global → S3 | Edge locations |

---

## 5. EC2 Instance High Availability

### 5.1 Pattern 1: ASG 1:1:1 com Elastic IP Swap

```
┌─────────────────────────────────────────────────────────────────┐
│                    ASG (min:1, max:1, desired:1)                  │
│                                                                  │
│  ┌──────────────────┐                                           │
│  │   AZ-a           │    ┌──────────────┐                       │
│  │   ┌─────────┐    │    │  Elastic IP  │                       │
│  │   │   EC2   │◀───┼────│  (estático)  │                       │
│  │   │ (active)│    │    └──────────────┘                       │
│  │   └─────────┘    │           ▲                               │
│  └──────────────────┘           │                               │
│                                 │ Lambda swap                    │
│  ┌──────────────────┐           │                               │
│  │   AZ-b           │    ┌─────────────┐    ┌───────────────┐   │
│  │   ┌─────────┐    │    │ EventBridge │◀───│ ASG Lifecycle │   │
│  │   │   EC2   │◀───┼────│   Rule      │    │    Hook       │   │
│  │   │  (new)  │    │    └─────────────┘    └───────────────┘   │
│  │   └─────────┘    │                                           │
│  └──────────────────┘                                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Como funciona:**
1. ASG com min=1, max=1, desired=1 em Multi-AZ
2. Se instância falha, ASG lança nova instância (pode ser outra AZ)
3. EventBridge detecta evento de launch do ASG
4. Lambda é trigada e associa o Elastic IP à nova instância
5. Tempo de failover: ~1-2 minutos

**Quando usar:**
- Aplicação que PRECISA de IP fixo (ex: integração com parceiros que fazem whitelist de IP)
- Não pode usar Load Balancer
- Custo mínimo (single instance)

### 5.2 Pattern 2: ASG com ALB (Mais Comum)

```
┌────────────────────────────────────────────────────────────────────┐
│                                                                    │
│  ┌───────────┐    ┌──────────────────────────────────────────┐     │
│  │  Route53  │───▶│              ALB                          │     │
│  │  (alias)  │    │  (Cross-Zone Load Balancing)              │     │
│  └───────────┘    └──────┬────────────────┬──────────────────┘     │
│                          │                │                         │
│              ┌───────────┴──┐     ┌───────┴──────────┐             │
│              │    AZ-a      │     │      AZ-b        │             │
│              │  ┌────────┐  │     │  ┌────────┐      │             │
│              │  │  EC2   │  │     │  │  EC2   │      │             │
│              │  └────────┘  │     │  └────────┘      │             │
│              │  ┌────────┐  │     │  ┌────────┐      │             │
│              │  │  EC2   │  │     │  │  EC2   │      │             │
│              │  └────────┘  │     │  └────────┘      │             │
│              └──────────────┘     └──────────────────┘             │
│                                                                    │
│              ASG: min=2, max=6, desired=2                           │
│              Health Checks: ELB type (não EC2 type)                 │
│              Scaling: Target Tracking (CPU 70%)                     │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

**Best practices:**
- Health check type = ELB (mais preciso que EC2 status check)
- Cross-Zone Load Balancing habilitado (distribui uniformemente)
- Connection Draining / Deregistration Delay (default 300s)
- Scaling policies: Target Tracking > Step > Simple
- Cooldown period para evitar flapping

### 5.3 Pattern 3: Multi-AZ Stateful (com EFS/EBS)

```
Para aplicações que precisam de storage compartilhado:

     ┌──────────┐         ┌──────────┐
     │  AZ-a    │         │  AZ-b    │
     │ ┌──────┐ │         │ ┌──────┐ │
     │ │ EC2  │ │         │ │ EC2  │ │
     │ └──┬───┘ │         │ └──┬───┘ │
     │    │     │         │    │     │
     └────┼─────┘         └────┼─────┘
          │                    │
          └────────┬───────────┘
                   │
            ┌──────┴──────┐
            │    EFS      │  (Multi-AZ, NFS)
            │  (shared)   │
            └─────────────┘
```

**EBS vs EFS para HA:**
- **EBS:** Single-AZ, precisa de snapshot + restore para outra AZ (mais lento)
- **EFS:** Multi-AZ nativo, mount em múltiplas instâncias simultaneamente
- **EBS Multi-Attach:** Apenas io1/io2, mesma AZ, até 16 instâncias

### 5.4 Resumo de Patterns HA

| Pattern | Failover Time | Custo | Complexidade | IP Fixo? |
|---------|--------------|-------|-------------|----------|
| ASG 1:1:1 + EIP | 1-2 min | Baixo | Médio | Sim |
| ASG + ALB | Seconds (health check) | Médio | Baixo | Não (DNS) |
| ASG Multi-AZ + EFS | Seconds | Alto | Baixo | Não |
| Multi-Region + Route53 | Depends on TTL | Muito alto | Alto | Não |

---


## 6. AWS Well-Architected Framework

### 6.1 Os 6 Pilares

```
┌─────────────────────────────────────────────────────────────────────┐
│              AWS WELL-ARCHITECTED FRAMEWORK                          │
│                                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                │
│  │ Operational │  │  Security   │  │ Reliability │                │
│  │ Excellence  │  │             │  │             │                │
│  │             │  │ • IAM       │  │ • Multi-AZ  │                │
│  │ • IaC       │  │ • Encrypt  │  │ • Auto-scale│                │
│  │ • CI/CD     │  │ • VPC      │  │ • Backup    │                │
│  │ • Runbooks  │  │ • Logging  │  │ • DR        │                │
│  └─────────────┘  └─────────────┘  └─────────────┘                │
│                                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌───────────────┐              │
│  │ Performance │  │    Cost     │  │Sustainability │              │
│  │ Efficiency  │  │Optimization │  │               │              │
│  │             │  │             │  │ • Right-size  │              │
│  │ • Caching   │  │ • Reserved │  │ • Efficient   │              │
│  │ • CDN       │  │ • Spot     │  │   code        │              │
│  │ • Right-size│  │ • Right-   │  │ • Managed     │              │
│  │ • Serverless│  │   sizing   │  │   services    │              │
│  └─────────────┘  └─────────────┘  └───────────────┘              │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 6.2 Pilar 1: Operational Excellence

**Princípio:** Executar e monitorar sistemas para entregar valor de negócio e melhorar continuamente.

**Princípios de design:**
- Perform operations as code (IaC — CloudFormation, CDK, Terraform)
- Make frequent, small, reversible changes
- Refine operations procedures frequently
- Anticipate failure (chaos engineering)
- Learn from all operational failures (post-mortems)

**Serviços-chave:**
- CloudFormation / CDK (IaC)
- AWS Config (compliance)
- CloudWatch (monitoring, alarms, dashboards)
- CloudTrail (audit)
- X-Ray (tracing)
- Systems Manager (operations)

### 6.3 Pilar 2: Security

**Princípio:** Proteger dados, sistemas e ativos usando controles de segurança em cloud.

**Princípios de design:**
- Implement a strong identity foundation (least privilege)
- Enable traceability (logging everything)
- Apply security at all layers (defense in depth)
- Automate security best practices
- Protect data in transit and at rest
- Keep people away from data
- Prepare for security events (incident response)

**Serviços-chave:**
- IAM (identity, policies, roles)
- AWS Organizations + SCPs
- KMS / CloudHSM (encryption)
- WAF, Shield (perimeter)
- VPC, Security Groups, NACLs (network)
- GuardDuty, Inspector, Macie (detection)
- CloudTrail (audit trail)

### 6.4 Pilar 3: Reliability

**Princípio:** Garantir que um workload execute sua função pretendida corretamente e consistentemente.

**Princípios de design:**
- Automatically recover from failure
- Test recovery procedures
- Scale horizontally to increase aggregate workload availability
- Stop guessing capacity (auto-scaling)
- Manage change in automation

**Serviços-chave:**
- Auto Scaling Groups
- Multi-AZ deployments (RDS, ElastiCache, etc.)
- Route 53 (DNS failover)
- S3 (11 9's durability)
- Backup (AWS Backup)
- CloudFormation (infrastructure recovery)

### 6.5 Pilar 4: Performance Efficiency

**Princípio:** Usar recursos de computação eficientemente para atender requisitos e manter eficiência conforme demanda muda.

**Princípios de design:**
- Democratize advanced technologies (managed services)
- Go global in minutes (CloudFront, Global Accelerator)
- Use serverless architectures
- Experiment more often
- Consider mechanical sympathy (use the right tool for the job)

**Serviços-chave:**
- CloudFront (CDN)
- ElastiCache / DAX (caching)
- Auto Scaling (right-sizing dinâmico)
- Lambda (serverless compute)
- RDS Read Replicas, Aurora (database performance)
- EBS optimized instances

### 6.6 Pilar 5: Cost Optimization

**Princípio:** Evitar gastos desnecessários.

**Princípios de design:**
- Implement Cloud Financial Management
- Adopt a consumption model (pay for what you use)
- Measure overall efficiency
- Stop spending money on undifferentiated heavy lifting (managed services)
- Analyze and attribute expenditure

**Serviços-chave:**
- Reserved Instances / Savings Plans
- Spot Instances
- S3 Intelligent-Tiering / Lifecycle policies
- AWS Budgets + Cost Explorer
- Compute Optimizer
- Right-sizing recommendations (Trusted Advisor)

### 6.7 Pilar 6: Sustainability

**Princípio:** Minimizar os impactos ambientais dos workloads na cloud.

**Princípios de design:**
- Understand your impact
- Establish sustainability goals
- Maximize utilization (right-sizing)
- Anticipate and adopt new, more efficient offerings
- Use managed services (shared infrastructure)
- Reduce the downstream impact of cloud workloads

**Serviços-chave:**
- EC2 Auto Scaling (evitar over-provisioning)
- Serverless (Lambda, Fargate) — recursos sob demanda
- S3 Intelligent-Tiering (storage eficiente)
- Graviton instances (melhor performance/watt)
- Read Replicas (reduzir load no primário)

---

## 7. AWS Well-Architected Tool

### 7.1 O que é

- Serviço **gratuito** no console AWS
- Permite fazer **reviews** de workloads contra os 6 pilares
- Baseado nas melhores práticas do Well-Architected Framework
- Gera relatório com **High Risk Issues (HRI)** e **Medium Risk Issues (MRI)**

### 7.2 Como Usar

```
┌────────────────────────────────────────────────────────────────┐
│                Well-Architected Tool - Workflow                  │
│                                                                 │
│  1. Define Workload                                             │
│     │ (nome, descrição, environment, AWS account IDs)           │
│     ▼                                                           │
│  2. Selecionar Lenses                                           │
│     │ • AWS Well-Architected (padrão)                           │
│     │ • Serverless Lens                                         │
│     │ • SaaS Lens                                               │
│     │ • Custom Lenses                                           │
│     ▼                                                           │
│  3. Responder perguntas por pilar                               │
│     │ (questões sobre design decisions do workload)             │
│     ▼                                                           │
│  4. Revisar resultados                                          │
│     │ • HRI (High Risk Issues)                                  │
│     │ • MRI (Medium Risk Issues)                                │
│     │ • Improvement Plan                                        │
│     ▼                                                           │
│  5. Aplicar melhorias                                           │
│     │ • Priorizar por impacto                                   │
│     │ • Milestone para track progress                           │
│     ▼                                                           │
│  6. Repetir periodicamente                                      │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

### 7.3 Features Importantes

- **Milestones:** Snapshots do estado do workload em pontos no tempo
- **Improvement Plan:** Lista priorizada de ações de melhoria
- **Custom Lenses:** Criar lenses específicas para sua organização
- **Sharing:** Compartilhar workloads com outras contas AWS
- **Integração com Trusted Advisor:** Recomendações complementares

---

## 8. AWS Trusted Advisor

### 8.1 As 5 Categorias

```
┌─────────────────────────────────────────────────────────────────┐
│                    TRUSTED ADVISOR                                │
│                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │    Cost     │  │ Performance │  │  Security   │             │
│  │Optimization │  │             │  │             │             │
│  │             │  │ • EC2 over- │  │ • SG open   │             │
│  │ • Idle EC2  │  │   provisioned│  │   ports     │             │
│  │ • Unused   │  │ • CloudFront│  │ • IAM usage │             │
│  │   EBS/EIP  │  │   optimization│ │ • MFA root │             │
│  │ • Reserved │  │ • EC2 to EBS│  │ • S3 public│             │
│  │   Instance │  │   throughput │  │   buckets  │             │
│  │   utiliz.  │  │             │  │ • RDS public│             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│                                                                  │
│  ┌─────────────┐  ┌──────────────┐                              │
│  │   Fault     │  │   Service    │                              │
│  │ Tolerance   │  │   Limits     │                              │
│  │             │  │              │                              │
│  │ • RDS Multi-│  │ • VPC limits │                              │
│  │   AZ        │  │ • EC2 limits│                              │
│  │ • ASG Multi-│  │ • IAM limits│                              │
│  │   AZ        │  │ • EBS limits│                              │
│  │ • EBS       │  │             │                              │
│  │   snapshots │  │ (80% usage  │                              │
│  │ • Route53   │  │  = warning) │                              │
│  │   failover  │  │             │                              │
│  └─────────────┘  └──────────────┘                              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 8.2 Checks por Nível de Suporte

| Nível de Suporte | Checks Disponíveis |
|------------------|--------------------|
| **Basic / Developer** | 7 Core checks apenas: |
| | • S3 Bucket Permissions (public) |
| | • Security Groups (unrestricted ports) |
| | • IAM Use (ao menos 1 IAM user) |
| | • MFA on Root Account |
| | • EBS Public Snapshots |
| | • RDS Public Snapshots |
| | • Service Limits |
| **Business / Enterprise** | FULL set de checks (115+): |
| | • Todas as 5 categorias completas |
| | • API access (programmatic) |
| | • CloudWatch integration |
| | • Ability to set refresh intervals |
| | • AWS Support API para automate responses |

### 8.3 Integração com EventBridge

```
┌───────────────┐    ┌─────────────┐    ┌──────────┐    ┌──────────┐
│Trusted Advisor│───▶│ EventBridge │───▶│  Lambda  │───▶│  Slack/  │
│  (check fail) │    │    Rule     │    │ (notify) │    │  SNS     │
└───────────────┘    └─────────────┘    └──────────┘    └──────────┘
```

- Requer **Business ou Enterprise Support**
- Pode automatizar respostas a findings (ex: fechar security group aberta)
- Refresh: manual ou a cada 24h (Business+: a cada 5 min via API)

### 8.4 Dicas de Prova

- "Verificar se há security groups com portas abertas para 0.0.0.0/0" → Trusted Advisor (disponível em ALL tiers)
- "Ver todas as recomendações de custo" → Trusted Advisor (requer Business/Enterprise)
- "API access para Trusted Advisor" → Business/Enterprise Support Plan
- "Service Limits approaching" → Trusted Advisor (disponível em ALL tiers)

---


## 9. Classic Solutions Architectures

### 9.1 WhatsTheTime.com — Stateless Web App

**Requisito:** Aplicação que mostra o horário atual. Precisa escalar e ser altamente disponível.

#### Evolução da Arquitetura:

```
Versão Final (Production-Ready):

┌────────────┐     ┌───────────────────────────────────────────────────┐
│  Route 53  │     │                                                   │
│  (Alias    │     │           Application Load Balancer               │
│   Record)  │────▶│       (Multi-AZ, Health Checks)                   │
└────────────┘     └────────┬──────────────────────┬───────────────────┘
                            │                      │
                ┌───────────┴──────┐   ┌───────────┴──────┐
                │      AZ-a        │   │      AZ-b        │
                │                  │   │                  │
                │  ┌────────────┐  │   │  ┌────────────┐  │
                │  │    EC2     │  │   │  │    EC2     │  │
                │  │ (t3.micro) │  │   │  │ (t3.micro) │  │
                │  └────────────┘  │   │  └────────────┘  │
                │  ┌────────────┐  │   │  ┌────────────┐  │
                │  │    EC2     │  │   │  │    EC2     │  │
                │  │ (reserved) │  │   │  │ (reserved) │  │
                │  └────────────┘  │   │  └────────────┘  │
                │                  │   │                  │
                └──────────────────┘   └──────────────────┘
                                                   
                       ASG: min=2, max=5, desired=2
                       Scaling: Target Tracking CPU 40%
```

**Decisões de arquitetura:**
1. **Route 53 Alias** → ALB: Sem custo de DNS query, failover automático
2. **Multi-AZ ALB:** Distribui carga entre AZs
3. **ASG Multi-AZ:** Garante que instâncias sejam repostas automaticamente
4. **Reserved Instances** para baseline + On-Demand para picos
5. **Stateless:** Não precisa de session, cada request é independente

**Lições aprendidas:**
- Começar com single EC2 → adicionar ELB → adicionar ASG → Multi-AZ
- Security Groups: ALB aceita HTTP/HTTPS de 0.0.0.0/0, EC2 aceita apenas do ALB SG
- Health checks no ALB detectam instâncias unhealthy

### 9.2 MyClothes.com — Stateful Web App

**Requisito:** E-commerce com carrinho de compras. Sessão do usuário deve persistir.

```
┌────────────────────────────────────────────────────────────────────┐
│                                                                    │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────────────┐     │
│  │  Route53 │───▶│   ALB    │───▶│  ASG (Multi-AZ)          │     │
│  └──────────┘    │          │    │  ┌─────┐ ┌─────┐ ┌─────┐│     │
│                  │          │    │  │EC2-1│ │EC2-2│ │EC2-3││     │
│                  └──────────┘    │  └──┬──┘ └──┬──┘ └──┬──┘│     │
│                                  └─────┼───────┼───────┼────┘     │
│                                        │       │       │          │
│                                        ▼       ▼       ▼          │
│                                  ┌─────────────────────────┐      │
│  Opção 1: Sticky Sessions        │     ElastiCache Redis    │      │
│  (ELB Stickiness)                │     (Session Store)      │      │
│  ❌ Não escala bem               │                          │      │
│  ❌ Se instância morre,          │  • Write session on login│      │
│     sessão é perdida             │  • Read session on each  │      │
│                                  │    request               │      │
│  Opção 2: ElastiCache ✅         │  • TTL para expirar      │      │
│  (Recomendado)                   │    sessões inativas      │      │
│  ✅ Stateless EC2 instances      └─────────────────────────┘      │
│  ✅ Sessão sobrevive failover                                      │
│  ✅ Escala horizontalmente                  │                      │
│                                             ▼                      │
│                                  ┌─────────────────────────┐      │
│                                  │   RDS Multi-AZ          │      │
│                                  │   (MySQL/PostgreSQL)     │      │
│                                  │                          │      │
│                                  │  • Write-through cache   │      │
│                                  │  • Read Replicas para    │      │
│                                  │    offload reads         │      │
│                                  └─────────────────────────┘      │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

**Write-Through Caching Pattern:**
1. App recebe write request
2. Escreve no RDS E no ElastiCache simultaneamente
3. Próximo read vem do cache (hit) → latência baixa
4. Se cache miss → lê do RDS → popula cache (lazy loading fallback)

**Decisões de arquitetura:**
- **Sticky Sessions:** Rápido de implementar mas anti-pattern para HA
- **ElastiCache Sessions:** Instâncias EC2 ficam stateless, sessão centralizada
- **RDS Multi-AZ:** Failover automático em ~30s, standby síncrono
- **Security:** ElastiCache no private subnet, SG permite apenas EC2 SG

### 9.3 MyWordPress.com — Fully Scalable WordPress

**Requisito:** WordPress com media uploads compartilhados entre todas as instâncias.

```
┌────────────────────────────────────────────────────────────────────────┐
│                                                                        │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────────────────┐     │
│  │  Route53 │───▶│   ALB    │───▶│   ASG (Multi-AZ)              │     │
│  └──────────┘    └──────────┘    │                              │     │
│                                  │   ┌──────┐  ┌──────┐        │     │
│                                  │   │ EC2  │  │ EC2  │        │     │
│                                  │   │ (WP) │  │ (WP) │        │     │
│                                  │   └──┬───┘  └──┬───┘        │     │
│                                  └──────┼─────────┼─────────────┘     │
│                                         │         │                    │
│                          ┌──────────────┼─────────┼──────────────┐    │
│                          │              ▼         ▼              │    │
│                          │     ┌──────────────────────┐          │    │
│                          │     │      EFS             │          │    │
│                          │     │  (Shared Storage)    │          │    │
│                          │     │                      │          │    │
│                          │     │  /wp-content/uploads │          │    │
│                          │     │  /wp-content/themes  │          │    │
│                          │     │  /wp-content/plugins │          │    │
│                          │     └──────────────────────┘          │    │
│                          │                                       │    │
│                          │          Shared NFS Mount              │    │
│                          └───────────────────────────────────────┘    │
│                                                                        │
│                          ┌───────────────────────────────────────┐    │
│                          │        Aurora MySQL Multi-AZ           │    │
│                          │                                       │    │
│                          │   Writer ──────── Reader (replica)    │    │
│                          │   (AZ-a)           (AZ-b)             │    │
│                          │                                       │    │
│                          │   • Auto-scaling readers              │    │
│                          │   • Automatic failover                │    │
│                          │   • Storage auto-grows (10GB→128TB)   │    │
│                          └───────────────────────────────────────┘    │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

**Por que EFS e não EBS?**
- EBS: attached a UMA instância (single-AZ), não compartilha
- EFS: mount em MÚLTIPLAS instâncias, Multi-AZ, cresce automaticamente
- WordPress precisa que uploads estejam disponíveis em TODAS as instâncias

**Por que Aurora e não RDS MySQL?**
- 5x performance do MySQL
- Storage auto-scaling (até 128 TB)
- Até 15 read replicas (vs 5 no RDS)
- Automatic failover mais rápido
- Backtrack (voltar no tempo sem restore)

### 9.4 Instantiating Applications Quickly

```
┌─────────────────────────────────────────────────────────────────┐
│            ESTRATÉGIAS PARA BOOT RÁPIDO                          │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ 1. Golden AMI                                            │    │
│  │    • Pré-instalar: OS, app, dependencies, configs        │    │
│  │    • Boot time: segundos (vs minutos com User Data)      │    │
│  │    • Ideal para: ASG que precisa escalar rápido          │    │
│  │    • Manter atualizado: pipeline de build de AMI         │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ 2. User Data                                             │    │
│  │    • Script executado no PRIMEIRO boot                   │    │
│  │    • Instalar packages, baixar código, configurar        │    │
│  │    • Boot time: minutos (depende do script)              │    │
│  │    • Ideal para: configurações dinâmicas + Golden AMI    │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ 3. Hybrid: Golden AMI + User Data                        │    │
│  │    • AMI com software base instalado                     │    │
│  │    • User Data apenas para configuração final            │    │
│  │    • Melhor trade-off: boot rápido + flexibilidade       │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ 4. ElastiCache Warming                                   │    │
│  │    • Pré-popular cache antes de receber tráfego          │    │
│  │    • Evitar "cold start" → thundering herd               │    │
│  │    • Script que lê dados do DB e popula o cache          │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ 5. RDS Restore from Snapshot                             │    │
│  │    • Criar DB a partir de snapshot (vs insert dados)     │    │
│  │    • Muito mais rápido que restore lógico                │    │
│  │    • Ideal para: ambientes de teste, DR                  │    │
│  │    • Snapshot → new DB ready in minutes                  │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Dica de prova:** "Reduzir tempo de boot de instâncias no ASG" → **Golden AMI**
**Dica de prova:** "Pré-configurar dados no novo ambiente" → **RDS Snapshot + ElastiCache warming**

---


## 10. Serverless Architectures

### 10.1 MyTodoList — Serverless REST API

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    MyTodoList - Serverless Architecture                   │
│                                                                         │
│  ┌──────────┐    ┌──────────────┐    ┌────────────┐    ┌─────────────┐ │
│  │  Mobile  │    │   Amazon     │    │    API     │    │   Lambda    │ │
│  │  Client  │───▶│   Cognito    │───▶│  Gateway   │───▶│  Functions  │ │
│  └──────────┘    │              │    │            │    │             │ │
│                  │ • User Pool  │    │ • REST API │    │ • CRUD ops  │ │
│                  │ • Sign-up    │    │ • Auth via │    │ • Node.js/  │ │
│                  │ • Sign-in    │    │   Cognito  │    │   Python    │ │
│                  │ • JWT tokens │    │   Authorizer│   │ • IAM Role  │ │
│                  └──────────────┘    └────────────┘    └──────┬──────┘ │
│                                                               │        │
│                                                               ▼        │
│                                                      ┌──────────────┐  │
│                                                      │  DynamoDB    │  │
│                                                      │              │  │
│                                                      │ • Table:Todos│  │
│                                                      │ • PK: user_id│  │
│                                                      │ • SK: todo_id│  │
│                                                      │ • GSI: by    │  │
│                                                      │   status     │  │
│                                                      └──────────────┘  │
│                                                                         │
│  Fluxo de autenticação:                                                 │
│  1. Client → Cognito: sign-in (email/password)                         │
│  2. Cognito → Client: JWT token (id_token + access_token)              │
│  3. Client → API GW: request com Authorization: Bearer <token>         │
│  4. API GW → Cognito Authorizer: valida token                          │
│  5. API GW → Lambda: invoca com user context                           │
│  6. Lambda → DynamoDB: query com user_id da claim do token             │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

**Componentes e decisões:**
- **Cognito User Pool:** Gerencia usuários, MFA, password policies
- **API Gateway:** Throttling, caching, API keys, usage plans
- **Lambda:** Pay-per-request, auto-scales, 0-1000 concurrent (default)
- **DynamoDB:** Single-digit ms latency, auto-scaling, pay-per-request mode
- **Sem servidor para gerenciar:** Zero administração de infraestrutura

### 10.2 MyBlog.com — Serverless Website

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    MyBlog.com - Serverless Blog                          │
│                                                                         │
│                         ┌───────────────────┐                           │
│                         │    CloudFront      │                           │
│                         │    Distribution    │                           │
│                         └─────┬─────────┬───┘                           │
│                               │         │                               │
│               Static Content  │         │  API Requests                  │
│               (/index.html,   │         │  (/api/*)                      │
│                /css, /js)     │         │                               │
│                               ▼         ▼                               │
│                    ┌──────────────┐   ┌──────────────┐                  │
│                    │  S3 Bucket   │   │ API Gateway  │                  │
│                    │  (Static     │   │ (REST API)   │                  │
│                    │   Website    │   └──────┬───────┘                  │
│                    │   Hosting)   │          │                           │
│                    │              │          ▼                           │
│                    │ • OAC para   │   ┌──────────────┐                  │
│                    │   CloudFront │   │   Lambda     │                  │
│                    │ • Versioning │   │              │                  │
│                    └──────────────┘   │ • GET posts  │                  │
│                                      │ • POST post  │                  │
│                                      │ • Comments   │                  │
│                                      └──────┬───────┘                  │
│                                             │                           │
│                              ┌──────────────┼──────────────┐           │
│                              ▼              ▼              ▼           │
│                     ┌─────────────┐  ┌──────────┐  ┌──────────────┐   │
│                     │  DynamoDB   │  │  Aurora   │  │     S3       │   │
│                     │  (comments, │  │ Serverless│  │  (images,    │   │
│                     │   likes)    │  │  (posts)  │  │   media)     │   │
│                     └─────────────┘  └──────────┘  └──────────────┘   │
│                                                                         │
│  Otimizações:                                                           │
│  • CloudFront cache: TTL alto para static, baixo para API              │
│  • S3 + OAC: bucket privado, apenas CloudFront acessa                  │
│  • DAX na frente do DynamoDB para reads frequentes                     │
│  • Aurora Serverless: escala para zero quando sem tráfego              │
│  • Lambda@Edge: SEO, redirects, A/B testing                            │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

**Padrão Global com DynamoDB Global Tables:**
```
┌────────────┐         ┌────────────┐
│  Region A  │◀───────▶│  Region B  │
│ DynamoDB   │  Active-│ DynamoDB   │
│ Table      │  Active │ Table      │
│            │  Replic.│            │
└────────────┘         └────────────┘
```

### 10.3 Microservices Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│              Microservices - Serverless Pattern                          │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                      API Gateway                                 │    │
│  │  /users/*        /orders/*        /payments/*     /notifications │    │
│  └────┬─────────────────┬──────────────────┬────────────────┬──────┘    │
│       │                 │                  │                │           │
│       ▼                 ▼                  ▼                ▼           │
│  ┌─────────┐      ┌─────────┐       ┌─────────┐     ┌─────────┐      │
│  │ Lambda  │      │ Lambda  │       │ Lambda  │     │ Lambda  │      │
│  │ (Users) │      │(Orders) │       │(Payment)│     │(Notify) │      │
│  └────┬────┘      └────┬────┘       └────┬────┘     └────┬────┘      │
│       │                 │                  │                │           │
│       ▼                 ▼                  ▼                │           │
│  ┌─────────┐      ┌─────────┐       ┌─────────┐           │           │
│  │DynamoDB │      │DynamoDB │       │DynamoDB │           │           │
│  │ (Users) │      │(Orders) │       │(Payments│           │           │
│  └─────────┘      └────┬────┘       └─────────┘           │           │
│                         │                                   │           │
│                         │  Event                            │           │
│                         ▼                                   │           │
│                    ┌─────────┐                              │           │
│                    │   SNS   │──────────────────────────────┘           │
│                    │ (Order  │                                          │
│                    │ Created)│─────────┐                                │
│                    └─────────┘         │                                │
│                                       ▼                                │
│                                  ┌─────────┐                           │
│                                  │   SQS   │    (buffer para           │
│                                  │ (email  │     processamento         │
│                                  │  queue) │     assíncrono)           │
│                                  └────┬────┘                           │
│                                       │                                │
│                                       ▼                                │
│                                  ┌─────────┐                           │
│                                  │ Lambda  │                           │
│                                  │ (Send   │                           │
│                                  │  Email) │                           │
│                                  └─────────┘                           │
│                                                                         │
│  Patterns de Decoupling:                                                │
│  • Síncrono: API GW → Lambda → Lambda (via SDK invoke)                 │
│  • Assíncrono: Lambda → SNS → SQS → Lambda                            │
│  • Event Sourcing: DynamoDB Streams → Lambda                           │
│  • Choreography: EventBridge rules entre serviços                      │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

**Princípios de Microservices na AWS:**
1. **Cada serviço tem seu próprio data store** (database per service)
2. **Comunicação assíncrona** via SNS/SQS (preferível a síncrona)
3. **API Gateway** como single entry point (API composition)
4. **Event-driven:** DynamoDB Streams / EventBridge para reagir a mudanças
5. **Circuit Breaker:** SQS DLQ para lidar com falhas downstream
6. **Observability:** X-Ray para tracing distribuído entre serviços

### 10.4 Comparativo: Serverless vs Traditional

| Aspecto | Serverless | Traditional (EC2) |
|---------|-----------|-------------------|
| Scaling | Automático (0 → N) | Manual ou ASG (min → max) |
| Custo | Pay-per-use | Pay-per-hour (mesmo idle) |
| Ops | Zero gerenciamento | Patching, monitoring, scaling |
| Cold Start | Sim (ms a seconds) | Não (always running) |
| Timeout | 15 min (Lambda) | Ilimitado |
| State | Stateless (por design) | Stateful possível |
| VPC | Opcional (Lambda) | Obrigatório |

---

## 11. Palavras-Chave da Prova SAA-C03

### Cenários e Respostas Rápidas

| # | Palavra-chave / Cenário na Prova | Resposta |
|---|----------------------------------|----------|
| 1 | "Desacoplar componentes" / "asynchronous processing" | **SQS** (standard ou FIFO conforme ordering) |
| 2 | "Fan-out" / "uma mensagem para múltiplos destinos" | **SNS + SQS** (fan-out pattern) |
| 3 | "Real-time streaming" / "milhões de registros por segundo" | **Kinesis Data Streams** |
| 4 | "Reagir a eventos AWS" / "schedule" / "cron" | **EventBridge** |
| 5 | "Reduzir latência global" / "conteúdo estático" | **CloudFront** |
| 6 | "Bloquear IP" + "com ALB ou CloudFront" | **WAF** (IP Set rule) |
| 7 | "Bloquear IP" + "sem ALB" (EC2 diretamente) | **NACL** (DENY rule) |
| 8 | "Session persistence" / "stateless EC2" | **ElastiCache Redis** (session store) |
| 9 | "DynamoDB latência microsegundos" | **DAX** |
| 10 | "WordPress com shared storage" / "múltiplas EC2 precisam acessar mesmos arquivos" | **EFS** |
| 11 | "HPC" / "MPI" / "inter-node communication" | **EFA** (Elastic Fabric Adapter) + Cluster Placement Group |
| 12 | "EC2 com IP fixo" + "alta disponibilidade" | **ASG 1:1:1** + Elastic IP swap via Lambda |
| 13 | "Serverless REST API com autenticação" | **API Gateway + Lambda + Cognito + DynamoDB** |
| 14 | "Static website com custom domain e HTTPS" | **S3 + CloudFront + ACM + Route53** |
| 15 | "Reduzir boot time do ASG" / "instanciar rapidamente" | **Golden AMI** |
| 16 | "Cost optimization" / "idle resources" / "unused EBS" | **Trusted Advisor** (requer Business Support para full checks) |
| 17 | "Review workload against best practices" | **Well-Architected Tool** |
| 18 | "Rate limiting" / "proteção contra DDoS na camada 7" | **WAF rate-based rule** |
| 19 | "Bloquear país inteiro" | **CloudFront Geo-Restriction** ou **WAF Geo-match** |
| 20 | "Database Multi-AZ com failover automático" | **RDS Multi-AZ** (synchronous standby) |
| 21 | "Read-heavy workload" / "offload reads from DB" | **RDS Read Replicas** ou **ElastiCache** |
| 22 | "Serverless database que escala para zero" | **Aurora Serverless** |
| 23 | "Processamento de batch jobs em escala" | **AWS Batch** |
| 24 | "HPC cluster scheduling" / "Slurm on AWS" | **ParallelCluster** |
| 25 | "High-throughput parallel filesystem" | **FSx for Lustre** (+ S3 integration) |

### Padrões Frequentes de Questões

**Pattern: "Most cost-effective"**
- Considerar: Spot Instances, Reserved Instances, Savings Plans
- Serverless (Lambda) para workloads intermitentes
- S3 lifecycle policies para storage

**Pattern: "Least operational overhead"**
- Preferir managed services: Aurora vs RDS vs EC2+MySQL
- Serverless: Lambda > Fargate > ECS on EC2 > EC2
- Managed cache: ElastiCache > cache self-managed

**Pattern: "Minimize latency"**
- CloudFront para edge caching
- Global Accelerator para TCP/UDP
- ElastiCache/DAX para database reads
- Placement Group Cluster para inter-node

**Pattern: "Highly available"**
- Multi-AZ (mínimo 2 AZs)
- Auto Scaling Group
- RDS Multi-AZ + Read Replicas (cross-region para DR)
- S3 (11 9's durability, cross-region replication)

**Pattern: "Decouple"**
- SQS entre componentes
- SNS para fan-out
- EventBridge para event-driven
- Step Functions para orchestration

**Pattern: "Secure"**
- Encryption at rest: KMS (SSE-S3, SSE-KMS, SSE-C)
- Encryption in transit: TLS/SSL, HTTPS
- Access: IAM policies, resource policies, VPC endpoints
- Network: Private subnets, NACLs, Security Groups, VPN/Direct Connect

---

## Referências Rápidas

### Tempos de Failover

| Serviço | Failover Time | Mecanismo |
|---------|--------------|-----------|
| RDS Multi-AZ | ~30-60s | DNS failover para standby |
| Aurora | ~30s | Promove replica |
| ElastiCache Redis | ~30s | Multi-AZ com failover |
| ALB + ASG | Health check interval | Replace unhealthy |
| Route 53 | TTL dependent | Health check failover |
| DynamoDB Global Tables | Seconds | Active-Active replication |

### Limites Importantes para a Prova

| Recurso | Limite |
|---------|--------|
| Lambda timeout | 15 minutos |
| Lambda memory | 128 MB - 10 GB |
| SQS message size | 256 KB (extended: 2 GB com S3) |
| SQS retention | 1 min - 14 dias (default 4 dias) |
| SNS message size | 256 KB |
| API Gateway timeout | 29 segundos |
| API Gateway payload | 10 MB |
| CloudFront file size | 30 GB (single file) |
| S3 object size | 5 TB (multipart > 100 MB) |
| DynamoDB item size | 400 KB |
| EFS | Sem limite (petabytes) |
| EBS gp3 | 16 TB por volume |

---

> **Última atualização:** Julho 2026
> **Exam Guide:** AWS SAA-C03
> **Domínios cobertos:** Design Resilient Architectures, Design High-Performing Architectures,
> Design Secure Architectures, Design Cost-Optimized Architectures
