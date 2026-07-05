# EC2 — Elastic Compute Cloud

> Serviço de **computação redimensionável** na nuvem. Permite provisionar servidores virtuais (instâncias) com controle total sobre sistema operacional, rede e armazenamento. É o serviço mais cobrado no exame SAA-C03.

---

## 1. Famílias de Instância

As instâncias EC2 são agrupadas em famílias otimizadas para diferentes cargas de trabalho. A nomenclatura segue o padrão:

```
Exemplo: m5.xlarge

  m   → família (General Purpose)
  5   → geração
  .   → separador
  xlarge → tamanho (vCPUs + memória)
```

### Tabela Completa de Famílias

| Família | Otimização | Casos de Uso | Exemplos de Tipo |
|---------|-----------|--------------|------------------|
| **M** (General Purpose) | CPU + Memória balanceados | App servers, backend, microserviços, pequenos bancos | m5.large, m6i.xlarge, m7g.2xlarge |
| **T** (Burstable) | CPU com burst credits | Dev/test, sites pequenos, CI/CD, microserviços leves | t3.micro, t3.medium, t4g.small |
| **C** (Compute) | CPU de alta performance | HPC, encoding de vídeo, game servers, ML inference, batch | c5.4xlarge, c6i.8xlarge, c7g.large |
| **R** (Memory) | Memória otimizada | Redis, Memcached, bancos in-memory, real-time big data | r5.2xlarge, r6i.4xlarge, r7g.xlarge |
| **X** (Memory Extreme) | Memória muito alta (até 4 TB) | SAP HANA, bancos in-memory de grande porte | x1.32xlarge, x2idn.24xlarge |
| **z** (High Frequency) | Alta frequência de clock (até 4.5 GHz) | EDA, gaming, single-threaded apps, bancos licenciados | z1d.xlarge, z1d.6xlarge |
| **I** (Storage/IO) | NVMe local de alta IOPS | NoSQL (Cassandra, MongoDB), data warehousing, OLTP | i3.xlarge, i3en.large, i4i.8xlarge |
| **D** (Dense Storage) | HDD local de alta densidade | MapReduce, HDFS, data lakes distribuídos, Kafka | d2.xlarge, d3.8xlarge |
| **H** (HDD Throughput) | HDD throughput sequencial alto | MapReduce, HDFS, sistemas de arquivos distribuídos | h1.2xlarge, h1.16xlarge |
| **G** (Graphics) | GPU para gráficos | Streaming de jogos, rendering 3D, visualização | g4dn.xlarge, g5.2xlarge |
| **P** (GPU Compute) | GPU para computação | Deep learning training, HPC, inferência em escala | p3.2xlarge, p4d.24xlarge, p5.48xlarge |
| **Mac** | macOS nativo | Build/test de apps iOS/macOS, CI/CD Apple | mac1.metal, mac2.metal |
| **Inf** | Inferência ML (Inferentia) | ML inference de baixo custo | inf1.xlarge, inf2.xlarge |
| **Trn** | Training ML (Trainium) | Deep learning training | trn1.2xlarge, trn1n.32xlarge |

### Detalhes por Família

**T (Burstable) — Burst Credits:**
```
┌─────────────────────────────────────────────────────┐
│  CPU Credits (T3/T4g)                                │
│                                                     │
│  - Instância acumula credits quando CPU < baseline  │
│  - Consome credits quando CPU > baseline            │
│  - Se credits acabarem → limited ou unlimited mode  │
│                                                     │
│  T3 Unlimited (default): cobra por uso extra        │
│  T3 Standard: throttle para baseline se sem credits │
│                                                     │
│  Baseline por tipo:                                 │
│    t3.micro  = 10% de 1 vCPU                       │
│    t3.small  = 20% de 1 vCPU                       │
│    t3.medium = 20% de 2 vCPUs                      │
│    t3.large  = 30% de 2 vCPUs                      │
└─────────────────────────────────────────────────────┘
```

> ⚠️ **Na prova:** Se perguntarem sobre workload com picos irregulares e custo baixo → **T3/T4g**. Se o workload é constantemente alto → use C ou M.

**Mac — Regras Especiais:**
- Dedicated Host obrigatório (mínimo 24h de alocação)
- macOS Ventura, Sonoma para builds nativos Apple
- Usado para CI/CD de aplicações iOS/iPadOS/macOS

---

## 2. Opções de Compra (Pricing Models)

### Visão Geral Comparativa

| Modelo | Desconto | Compromisso | Flexibilidade | Caso de Uso |
|--------|----------|-------------|---------------|-------------|
| **On-Demand** | 0% | Nenhum | Total | Workloads imprevisíveis, testes |
| **Reserved (Standard)** | até 72% | 1 ou 3 anos | Tipo+AZ fixos | Workloads estáveis 24/7 |
| **Reserved (Convertible)** | até 66% | 1 ou 3 anos | Pode trocar família/OS/tenancy | Workloads estáveis com evolução |
| **Savings Plans (Compute)** | até 66% | 1 ou 3 anos | Qualquer família/região/OS/tenancy | Uso diversificado de compute |
| **Savings Plans (EC2 Instance)** | até 72% | 1 ou 3 anos | Família+Região fixos, tamanho flexível | Uso concentrado em uma família |
| **Spot** | até 90% | Nenhum | Pode ser interrompido | Batch, CI/CD, big data, tolerante a falha |
| **Dedicated Host** | Sob demanda ou Reserved | Varia | Hardware dedicado completo | Licenças por socket/core (BYOL) |
| **Dedicated Instance** | Prêmio sobre On-Demand | Nenhum | Hardware isolado | Compliance que exige isolamento |
| **Capacity Reservation** | 0% (paga On-Demand) | Nenhum | Garante capacidade na AZ | DR, lançamentos, picos planejados |

### 2.1 On-Demand

- Cobrança por **segundo** (mínimo 60 segundos) para Linux/Ubuntu
- Cobrança por **hora** para Windows e outras distros comerciais
- Sem compromisso, sem pagamento antecipado
- Maior custo por hora, mas zero risco

### 2.2 Reserved Instances (RI)

```
┌──────────────────────────────────────────────────────────────┐
│               Reserved Instances                              │
│                                                              │
│  Standard RI:                                                │
│    - Tipo, AZ, plataforma fixos                             │
│    - Pode vender no Marketplace                             │
│    - Desconto até 72%                                       │
│                                                              │
│  Convertible RI:                                            │
│    - Pode trocar família, OS, tenancy, tamanho              │
│    - NÃO pode vender no Marketplace                         │
│    - Desconto até 66%                                       │
│                                                              │
│  Opções de pagamento (ambos):                               │
│    ┌────────────────┬──────────────┬───────────────────┐    │
│    │ All Upfront    │ Maior desc.  │ Paga tudo adiant. │    │
│    │ Partial Upfr.  │ Desconto med.│ Parte adiant.     │    │
│    │ No Upfront     │ Menor desc.  │ Paga mensal       │    │
│    └────────────────┴──────────────┴───────────────────┘    │
│                                                              │
│  Escopo:                                                    │
│    - Regional: aplica em qualquer AZ da região              │
│    - Zonal: garante capacidade em AZ específica             │
└──────────────────────────────────────────────────────────────┘
```

### 2.3 Savings Plans

| Tipo | Compromisso | Flexível em | Fixo em |
|------|-------------|-------------|---------|
| **Compute Savings Plan** | $/hora por 1 ou 3 anos | Família, região, OS, tenancy, compute service (EC2, Fargate, Lambda) | Nada |
| **EC2 Instance Savings Plan** | $/hora por 1 ou 3 anos | Tamanho da instância, OS, tenancy | Família + Região |

> 📝 **Na prova:** "Maior flexibilidade com desconto" → Compute Savings Plan. "Maior desconto possível sem flexibilidade" → EC2 Instance SP ou Standard RI All Upfront 3 anos.

### 2.4 Spot Instances

- **Desconto:** até 90% vs On-Demand
- **Interrupção:** AWS pode reclamar com aviso de **2 minutos**
- **Spot Request:** define preço máximo, quantidade, tipo de request (one-time vs persistent)
- **Spot Fleet:** conjunto de Spot + opcionalmente On-Demand para atingir capacidade desejada

**Estratégias do Spot Fleet:**

| Estratégia | Comportamento |
|-----------|---------------|
| `lowestPrice` | Aloca nas pools com menor preço (padrão) |
| `diversified` | Distribui entre múltiplas pools (maior disponibilidade) |
| `capacityOptimized` | Escolhe pools com maior capacidade disponível |
| `priceCapacityOptimized` | Balanceia preço + capacidade (RECOMENDADO) |

**Interrupção Spot — Opções:**
- **Stop:** instância é parada (pode ser retomada depois)
- **Terminate:** instância é terminada
- **Hibernate:** estado é salvo em EBS (retomada rápida)

> ⚠️ **Spot Block (DESCONTINUADO):** permitia reservar Spot por 1-6 horas sem interrupção. Não está mais disponível, mas pode aparecer na prova como distrator.

### 2.5 Dedicated Host vs Dedicated Instance

| Aspecto | Dedicated Host | Dedicated Instance |
|---------|---------------|-------------------|
| **Hardware** | Servidor físico inteiro para você | Hardware isolado, mas AWS gerencia |
| **Visibilidade** | Sockets, cores, host ID visíveis | Sem visibilidade do hardware |
| **Licenciamento** | ✅ BYOL por socket/core | ❌ Não suporta BYOL |
| **Controle de placement** | ✅ Controla onde instância roda | ❌ AWS decide |
| **Custo** | Mais caro (reserva host inteiro) | Prêmio sobre On-Demand |
| **Compliance** | Regulatório que exige server dedicado | Isolamento suficiente |

> 🎯 **Na prova:** "Licenças por socket/core" ou "BYOL" → **Dedicated Host** sempre.

### 2.6 Capacity Reservations

- Reserva capacidade On-Demand em AZ específica
- **Não dá desconto** — cobra preço On-Demand (tenha ou não instâncias rodando)
- Pode combinar com Savings Plans ou RI regional para ter desconto + garantia de capacidade
- Ideal para: DR, eventos planejados, garantir disponibilidade

---

## 3. EBS — Elastic Block Store

> Armazenamento em bloco persistente para instâncias EC2. Volumes EBS persistem independentemente do ciclo de vida da instância.

### Características Fundamentais

- **Network-attached:** conectado via rede (não é local)
- **AZ-locked:** volume preso a uma AZ (para mover → snapshot → restore em outra AZ)
- **Uma instância por vez** (exceto Multi-Attach em io1/io2)
- **Provisionado em tamanho e performance**
- **Pode ser redimensionado** sem downtime (tamanho e tipo)
- **Backup:** via Snapshots (armazenados no S3, incremental)

### 3.1 Tipos de Volume EBS — Comparação Detalhada

| Tipo | Categoria | IOPS Máx | Throughput Máx | Tamanho | Boot? | Caso de Uso |
|------|-----------|----------|----------------|---------|-------|-------------|
| **gp3** | SSD General | 16.000 | 1.000 MB/s | 1 GB–16 TB | ✅ | Boot volumes, apps gerais, dev/test |
| **gp2** | SSD General | 16.000 | 250 MB/s | 1 GB–16 TB | ✅ | Boot volumes (legado, preferir gp3) |
| **io2 Block Express** | SSD Provisioned | 256.000 | 4.000 MB/s | 4 GB–64 TB | ✅ | Maior performance, bancos mission-critical |
| **io2** | SSD Provisioned | 64.000 | 1.000 MB/s | 4 GB–16 TB | ✅ | Bancos de dados críticos (Oracle, SQL Server) |
| **io1** | SSD Provisioned | 64.000 | 1.000 MB/s | 4 GB–16 TB | ✅ | Bancos de dados (legado, preferir io2) |
| **st1** | HDD Throughput | 500 | 500 MB/s | 125 GB–16 TB | ❌ | Big data, data warehouse, logs |
| **sc1** | HDD Cold | 250 | 250 MB/s | 125 GB–16 TB | ❌ | Arquivos acessados raramente, backup |

### 3.2 gp2 — Burst Credits

```
┌─────────────────────────────────────────────────────────────┐
│  gp2 IOPS = 3 IOPS por GB (mínimo 100, máximo 16.000)      │
│                                                             │
│  Volumes < 1 TB:                                           │
│    - Baseline: 3 × tamanho_GB IOPS                         │
│    - Burst: até 3.000 IOPS                                 │
│    - Credit bucket: 5.4 milhões de I/O credits             │
│    - Recarrega quando abaixo do baseline                   │
│                                                             │
│  Volumes ≥ 1 TB (3.334+ GB):                               │
│    - Baseline ≥ 10.000 IOPS                                │
│    - NÃO precisa de burst (baseline já alto)               │
│                                                             │
│  Volume de 5.334 GB+ → 16.000 IOPS (máximo)               │
│                                                             │
│  ⚠️ gp2 NÃO permite configurar IOPS separado do tamanho   │
└─────────────────────────────────────────────────────────────┘
```

### 3.3 gp3 — Customização Independente

- **Baseline:** 3.000 IOPS + 125 MB/s throughput (incluído no preço)
- **Pode provisionar até:** 16.000 IOPS + 1.000 MB/s (custo adicional)
- **IOPS e throughput são independentes do tamanho**
- **20% mais barato** que gp2 no preço base
- **Migração:** pode mudar de gp2 para gp3 sem downtime (modify volume)

> 🎯 **Na prova:** "Volume de boot com melhor custo-benefício" → **gp3**. "Precisa de mais de 16.000 IOPS" → **io2/io2 Block Express**.

### 3.4 io2 Block Express

- Disponível em instâncias **Nitro** (R5b, X2idn, etc.)
- **Sub-millisecond latency**
- Até **256.000 IOPS** com razão de 1.000 IOPS:1 GB
- Até **4.000 MB/s** throughput
- Volume de até **64 TB**
- **64.000 IOPS** por volume padrão io2 (sem Block Express)

### 3.5 Multi-Attach

- **Apenas io1/io2** (não funciona com gp2/gp3/st1/sc1)
- Até **16 instâncias** na mesma AZ podem conectar ao mesmo volume
- Cada instância tem permissão de leitura e escrita completa
- **Cluster-aware filesystem** necessário (não ext4 — usar GFS2 ou similar)
- Caso de uso: aplicações de alta disponibilidade com shared storage na mesma AZ

### 3.6 Encryption (Criptografia)

```
┌────────────────────────────────────────────────────────────────┐
│  EBS Encryption                                                │
│                                                                │
│  - Usa AWS KMS (chave padrão aws/ebs ou CMK)                 │
│  - Criptografa: dados em repouso, em trânsito, snapshots     │
│  - Impacto mínimo de latência                                 │
│  - Transparent para a instância (handled pelo host Nitro)     │
│                                                                │
│  Regras de cópia:                                             │
│  ┌──────────────────────────────┬───────────────────────────┐ │
│  │ Snapshot não-criptografado   │ → Copy com encryption ON  │ │
│  │                              │   → Volume criptografado  │ │
│  ├──────────────────────────────┼───────────────────────────┤ │
│  │ Snapshot criptografado       │ → Volume será SEMPRE      │ │
│  │                              │   criptografado            │ │
│  ├──────────────────────────────┼───────────────────────────┤ │
│  │ Volume NÃO criptografado     │ → Não pode ativar direto  │ │
│  │ (já existente)               │   → Snapshot → Copy com   │ │
│  │                              │   encrypt → Novo volume   │ │
│  └──────────────────────────────┴───────────────────────────┘ │
│                                                                │
│  Default Encryption:                                          │
│  - Pode ativar por região → todos os novos volumes/snapshots  │
│    são criptografados automaticamente                         │
│  - Configuração na conta (Settings → EBS encryption)          │
└────────────────────────────────────────────────────────────────┘
```

### 3.7 Snapshots

- **Incrementais:** apenas blocos alterados são salvos
- **Armazenados no S3** (gerenciado pela AWS, não visível no seu bucket)
- **Podem ser copiados cross-region** (útil para DR)
- **Podem ser compartilhados** com outras contas
- **Snapshot de volume criptografado** → snapshot criptografado
- **Não precisa desanexar** volume para snapshot (recomendado para consistência)

**Data Lifecycle Manager (DLM):**
- Automatiza criação, retenção e exclusão de snapshots
- Policies baseadas em tags
- Schedules (ex: snapshot diário, reter por 7 dias)
- Cross-account copy

**Fast Snapshot Restore (FSR):**
- Elimina latência de inicialização ao criar volume de snapshot
- Volume fica com performance total imediatamente (sem warm-up)
- **Caro!** — cobrado por AZ por hora
- Útil para: ambientes que escalam rápido, boot volumes de AMIs

**Recycle Bin:**
- Protege snapshots e AMIs contra exclusão acidental
- Define retention rules (1 dia a 1 ano)
- Snapshots deletados vão para Recycle Bin ao invés de sumir

### 3.8 Delete on Termination

- **Root volume:** Delete on Termination = **habilitado** por padrão
- **Volumes adicionais:** Delete on Termination = **desabilitado** por padrão
- Pode ser alterado na criação da instância ou via API
- **Na prova:** "Dados perdidos ao terminar instância" → verificar flag DeleteOnTermination

---

## 4. Instance Store (Armazenamento Efêmero)

> Discos **fisicamente conectados** ao host da instância. Performance extrema, mas dados são **perdidos** quando a instância para, termina ou o hardware falha.

### Características

| Aspecto | Instance Store |
|---------|---------------|
| **Performance** | Até **milhões de IOPS** (NVMe local) |
| **Persistência** | ❌ EFÊMERO — dados perdidos ao stop/terminate/hardware failure |
| **Custo** | Incluído no preço da instância |
| **Resizing** | Não pode mudar após launch |
| **Backup** | Responsabilidade do usuário (replicar para EBS/S3) |
| **Casos de uso** | Buffer, cache, scratch data, dados temporários |

### Quando usar Instance Store

- ✅ Cache de aplicação (Redis local, temp files)
- ✅ Buffer de processamento (dados intermediários de ETL)
- ✅ Bancos que replicam nativamente (Cassandra, HDFS)
- ✅ Qualquer workload que tolera perda de dados locais
- ❌ NÃO usar para dados que não podem ser perdidos

### IOPS por família

| Instância | IOPS Sequencial | IOPS Random |
|-----------|----------------|-------------|
| i3.16xlarge | 16 GB/s throughput | 3.3M IOPS |
| i3en.24xlarge | 16 GB/s throughput | 2M IOPS |
| d3en.12xlarge | 6.2 GB/s throughput | HDD-based |

> 🎯 **Na prova:** "IOPS mais alto possível" ou "milhões de IOPS" → **Instance Store** (i3/i3en). "Precisa persistir dados" → EBS io2 Block Express.

---

## 5. AMIs — Amazon Machine Images

> Template que contém SO, aplicações e configurações para lançar instâncias EC2.

### Tipos de AMI

| Tipo | Quem mantém | Custo | Exemplo |
|------|------------|-------|---------|
| **AWS-provided** | AWS | Grátis (paga só compute) | Amazon Linux 2023, Ubuntu |
| **Marketplace** | Vendors | Pode ter custo de licença | FortiGate, RHEL, SAP |
| **Community** | Comunidade | Grátis | Custom Linux builds |
| **Custom (própria)** | Você | Custo do snapshot S3 | Golden AMI corporativa |

### Criação de AMI

```
┌─────────────────────────────────────────────────┐
│  Fluxo de criação de AMI                        │
│                                                 │
│  1. Launch instância EC2                        │
│  2. Customizar (instalar software, configs)     │
│  3. Parar instância (recomendado para           │
│     consistência do filesystem)                 │
│  4. Criar AMI (Create Image)                    │
│  5. AMI = metadata + EBS Snapshots             │
│  6. AMI fica disponível na região de origem     │
│                                                 │
│  Para outra região:                             │
│  7. Copy AMI → seleciona região destino         │
│     (copia snapshots para região destino)       │
└─────────────────────────────────────────────────┘
```

### Golden AMI Pattern

- AMI pré-configurada com: SO hardened, patches, agents, software base
- Reduz tempo de boot (não precisa instalar tudo via User Data)
- Versionada e testada antes de deploy
- Combinada com User Data para config dinâmica (ex: registrar em cluster)
- **Na prova:** "Reduzir tempo de launch" ou "boot mais rápido" → Golden AMI

### AMI Cross-Region e Cross-Account

- **Copy cross-region:** copia AMI + snapshots para outra região
- **Compartilhar:** pode compartilhar AMI com contas específicas ou tornar pública
- **AMI criptografada compartilhada:** precisa compartilhar também a CMK KMS
- **Não pode copiar** AMI de marketplace (precisa lançar nova na região destino)

---

## 6. Security Groups

> Firewall virtual **stateful** que controla tráfego de entrada (inbound) e saída (outbound) no nível da **instância** (ENI).

### Características Fundamentais

| Aspecto | Security Group |
|---------|---------------|
| **Nível** | Interface de rede (ENI) |
| **Tipo** | Stateful (resposta automática) |
| **Regras** | Apenas ALLOW (sem regras Deny) |
| **Default inbound** | Tudo negado (deny implícito) |
| **Default outbound** | Tudo permitido (allow all) |
| **Limite** | Até 5 SGs por ENI |
| **Avaliação** | TODAS as regras são avaliadas (não há ordem) |

### Stateful vs Stateless

```
┌─────────────────────────────────────────────────────────┐
│  SECURITY GROUP (Stateful)                              │
│                                                         │
│  Inbound: Allow TCP 80 from 0.0.0.0/0                  │
│  Outbound: (nenhuma regra necessária para resposta)     │
│                                                         │
│  → Requisição HTTP entra na porta 80 ✅                 │
│  → Resposta SAI automaticamente ✅ (stateful)           │
├─────────────────────────────────────────────────────────┤
│  NACL (Stateless) — para comparação                     │
│                                                         │
│  Inbound: Allow TCP 80                                  │
│  Outbound: PRECISA de regra para ephemeral ports        │
│                                                         │
│  → Requisição HTTP entra na porta 80 ✅                 │
│  → Resposta BLOQUEADA se não houver regra outbound ❌   │
└─────────────────────────────────────────────────────────┘
```

### Estrutura de uma Regra

| Campo | Descrição | Exemplo |
|-------|-----------|---------|
| **Protocol** | TCP, UDP, ICMP ou All | TCP |
| **Port Range** | Porta única ou range | 443 ou 1024-65535 |
| **Source/Dest** | IP (CIDR), outro SG, ou Prefix List | 10.0.0.0/16, sg-abc123 |
| **Description** | Texto descritivo (opcional) | "HTTPS from ALB" |

### Referência entre Security Groups (SG Chaining)

```
┌──────────────┐        ┌──────────────┐        ┌──────────────┐
│   ALB        │        │  App Server  │        │  Database    │
│  sg-alb      │───────▶│  sg-app      │───────▶│  sg-db       │
│              │        │              │        │              │
│ Inbound:     │        │ Inbound:     │        │ Inbound:     │
│ 443 from     │        │ 8080 from    │        │ 3306 from    │
│ 0.0.0.0/0   │        │ sg-alb       │        │ sg-app       │
└──────────────┘        └──────────────┘        └──────────────┘

Vantagens do SG chaining:
- Não precisa atualizar IPs quando instâncias mudam
- Acoplamento lógico ao invés de IPs fixos
- Escalável com Auto Scaling (novas instâncias herdam SG)
```

> 📝 **Na prova:** "Permitir acesso de instâncias de um grupo para outro sem IPs fixos" → referenciar Security Group como source.

### Regras Importantes para o Exame

- SG é **por região e VPC** (não global)
- Mudanças são aplicadas **imediatamente**
- Instância pode ter **múltiplos SGs** (regras são unidas)
- **Não pode bloquear** um IP específico com SG (use NACL para deny)
- Time-out no acesso = geralmente regra de **inbound** faltando
- Connection refused = app respondeu, não é SG (é a app)

---

## 7. Elastic IP

> Endereço IPv4 **estático** e público que você aloca na sua conta. Pode ser associado/desassociado de instâncias.

### Características e Limites

| Aspecto | Detalhes |
|---------|---------|
| **Limite padrão** | 5 por região (soft limit, pode pedir aumento) |
| **Cobrança** | Grátis se associado a instância running. **Cobra se ocioso** (alocado mas não associado) |
| **Remap** | Pode mover entre instâncias rapidamente (failover manual) |
| **IPv4 only** | Não existe Elastic IP para IPv6 |

### Quando usar vs Alternativas

| Cenário | Solução Recomendada |
|---------|-------------------|
| IP fixo para um servidor | Elastic IP |
| Alta disponibilidade de app | Load Balancer (ALB/NLB) |
| DNS para instância | Route 53 com DNS name do EC2 |
| IP fixo para múltiplos servidores | NLB com static IP por AZ |
| Comunicação entre VPCs | VPC Peering / Transit Gateway |

> ⚠️ **Na prova:** O uso de Elastic IP geralmente indica arquitetura ruim. Prefira Load Balancer ou DNS. Se a prova fala em "IP fixo necessário para whitelist" → Elastic IP ou NLB.

---

## 8. ENI vs ENA vs EFA

### Comparação

| Componente | O que é | Bandwidth | Caso de Uso |
|-----------|---------|-----------|-------------|
| **ENI** (Elastic Network Interface) | Interface de rede virtual básica | Até 100 Gbps | Todas as instâncias, multi-homing, failover |
| **ENA** (Elastic Network Adapter) | Driver de rede de alta performance | Até 100 Gbps | Enhanced networking, reduz latência |
| **EFA** (Elastic Fabric Adapter) | Interface para HPC com bypass do kernel | Até 400 Gbps | HPC, MPI, ML distribuído, tightly-coupled |

### ENI — Elastic Network Interface

- Interface virtual de rede que toda instância tem (no mínimo 1)
- Atributos: IP privado principal, IPs privados secundários, Elastic IP, MAC address, Security Groups
- **Pode criar ENI independente** e anexar/desanexar de instâncias
- **Caso de uso:** failover de rede (mover ENI entre instâncias), management network separada
- **Bound to AZ:** ENI é presa a uma AZ

### ENA — Enhanced Networking

- Usa **SR-IOV** (Single Root I/O Virtualization) para performance de rede
- Maior bandwidth, maior PPS (packets per second), menor latência
- **Sem custo adicional** (suportado na maioria das instâncias modernas)
- Habilitado automaticamente em instâncias Nitro
- Requer driver ENA no SO

### EFA — Elastic Fabric Adapter

- ENA + capacidade de **OS-bypass** (kernel bypass)
- Permite comunicação direta entre instâncias sem passar pelo OS
- Suporta **MPI** (Message Passing Interface) e **NCCL** para ML distribuído
- **Apenas Linux** (Windows não suporta OS-bypass)
- Caso de uso: treinamento de modelos de ML em múltiplas GPUs, simulações HPC

```
┌─────────────────────────────────────────────────────┐
│  Hierarquia de Networking EC2                       │
│                                                     │
│  ENI (básico) → toda instância tem                  │
│    └── ENA (enhanced) → SR-IOV, high bandwidth     │
│          └── EFA (fabric) → OS-bypass, HPC/ML      │
│                                                     │
│  Na prova:                                         │
│  "High Performance Computing" → EFA                 │
│  "Enhanced networking" → ENA (SR-IOV)              │
│  "Failover de IP entre instâncias" → ENI           │
└─────────────────────────────────────────────────────┘
```

---

## 9. Placement Groups

> Estratégias de posicionamento de instâncias no hardware físico da AWS.

### Comparação dos Três Tipos

| Tipo | Distribuição | Limite | Latência | Caso de Uso |
|------|-------------|--------|----------|-------------|
| **Cluster** | Todas na mesma AZ, mesmo rack | Sem limite explícito | Ultra-baixa (< 1ms) | HPC, MPI, aplicações tightly-coupled |
| **Spread** | Hardware distinto por instância | **7 instâncias por AZ** | Normal | Apps críticas, isolamento de falha |
| **Partition** | Grupos em racks distintos | **7 partições por AZ**, sem limite de instâncias por partição | Normal | Hadoop, Kafka, Cassandra, HDFS |

### Cluster Placement Group

```
┌─────────── Rack Único (mesma AZ) ───────────┐
│                                              │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐       │
│  │ i1 │ │ i2 │ │ i3 │ │ i4 │ │ i5 │       │
│  └────┘ └────┘ └────┘ └────┘ └────┘       │
│                                              │
│  ✅ Latência ultra-baixa (10 Gbps entre nós) │
│  ✅ Ideal para HPC com MPI                   │
│  ❌ Se rack falha, TUDO falha                │
│  ❌ Só uma AZ                               │
└──────────────────────────────────────────────┘
```

- Usar instâncias do **mesmo tipo** (melhor chance de placement)
- Lançar **todas de uma vez** (evitar insufficient capacity)
- Enhanced Networking recomendado

### Spread Placement Group

```
┌──── AZ-a ────┐  ┌──── AZ-b ────┐  ┌──── AZ-c ────┐
│              │  │              │  │              │
│ Rack1  Rack2 │  │ Rack3  Rack4 │  │ Rack5  Rack6 │
│ ┌──┐  ┌──┐  │  │ ┌──┐  ┌──┐  │  │ ┌──┐  ┌──┐  │
│ │i1│  │i2│  │  │ │i3│  │i4│  │  │ │i5│  │i6│  │
│ └──┘  └──┘  │  │ └──┘  └──┘  │  │ └──┘  └──┘  │
└──────────────┘  └──────────────┘  └──────────────┘

✅ Cada instância em hardware separado
✅ Multi-AZ
❌ Máximo 7 instâncias por AZ (21 em 3 AZs)
```

- Ideal para aplicações onde cada instância **deve** sobreviver a falha de hardware
- Exemplo: cluster de bancos de dados primário com 3 nós em 3 AZs

### Partition Placement Group

```
┌──────────── AZ-a ─────────────────────────────┐
│                                                │
│ Partition 1 (Rack A)  │  Partition 2 (Rack B)  │
│ ┌──┐ ┌──┐ ┌──┐      │  ┌──┐ ┌──┐ ┌──┐      │
│ │i1│ │i2│ │i3│      │  │i4│ │i5│ │i6│      │
│ └──┘ └──┘ └──┘      │  └──┘ └──┘ └──┘      │
│                       │                        │
└───────────────────────┴────────────────────────┘

✅ Partições isoladas em racks distintos
✅ Sem limite de instâncias por partição
✅ Até 7 partições por AZ
✅ Instância sabe em qual partição está (metadata)
```

- Ideal para sistemas distribuídos que são **partition-aware** (sabem distribuir réplicas entre partições)
- HDFS coloca réplicas em partições diferentes
- Cassandra distribui nós entre partições

> 🎯 **Na prova:** "Reduzir latência entre instâncias" → **Cluster**. "Isolamento de hardware por instância" → **Spread**. "Big data distribuído (Hadoop, Cassandra)" → **Partition**.

---

## 10. EC2 Hibernate

> Permite "congelar" o estado da instância (RAM) em disco e retomar exatamente de onde parou.

### Como Funciona

```
┌─────────────────────────────────────────────────────────────┐
│  Hibernate Flow                                              │
│                                                             │
│  1. Comando de Hibernate                                    │
│  2. SO recebe sinal ACPI Sleep                              │
│  3. Conteúdo da RAM é gravado no root EBS volume            │
│  4. Instância entra em estado "stopped"                     │
│  5. ─── tempo passa ───                                     │
│  6. Start da instância                                      │
│  7. EBS root volume é restaurado                            │
│  8. RAM é recarregada do EBS                                │
│  9. Processos continuam de onde pararam                     │
│  10. Instância retém: Instance ID, IP privado, EBS, ENI    │
└─────────────────────────────────────────────────────────────┘
```

### Requisitos e Limitações

| Requisito | Detalhe |
|-----------|---------|
| **Root volume** | DEVE ser EBS (não Instance Store) |
| **Criptografia** | Root volume DEVE ser **criptografado** |
| **RAM** | Máximo **150 GB** |
| **Famílias** | Suportado nas famílias C, M, R, T (entre outras) |
| **Tempo máximo** | Hibernado por no máximo **60 dias** |
| **SO** | Amazon Linux 2, Ubuntu, Windows |
| **On-Demand/RI** | Sim |
| **Spot** | Sim (hibernate em interrupção) |
| **Bare metal** | Não suportado |

### Quando Usar Hibernate

- ✅ Aplicações com boot longo (carregar estado em memória)
- ✅ Salvar estado de processamento para continuar depois
- ✅ Instâncias Spot (hibernate ao invés de terminate na interrupção)
- ❌ NÃO usar para instâncias que precisam ficar paradas > 60 dias

> 📝 **Na prova:** "Boot mais rápido preservando estado em memória" + "root volume EBS criptografado" → **Hibernate**.

---

## 11. User Data e Instance Metadata

### 11.1 User Data

- Script executado **apenas na primeira inicialização** (boot) da instância
- Roda como **root** (sem sudo necessário)
- Usado para: instalar pacotes, baixar código, configurar serviços
- Limite: **16 KB** (para scripts maiores, baixar de S3)
- **Não é criptografado** — não colocar segredos (usar Secrets Manager ou Parameter Store)

```bash
#!/bin/bash
# Exemplo de User Data
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<h1>Hello from $(hostname)</h1>" > /var/www/html/index.html
```

### 11.2 Instance Metadata (IMDS)

- Endpoint para a instância consultar informações sobre si mesma
- URL: `http://169.254.169.254/latest/meta-data/`
- Dados disponíveis: instance-id, ami-id, hostname, public-ip, security-groups, IAM role credentials

**IMDSv1 vs IMDSv2:**

| Aspecto | IMDSv1 | IMDSv2 |
|---------|--------|--------|
| **Método** | GET simples | PUT para obter token, depois GET com token |
| **Segurança** | Vulnerável a SSRF | Protegido contra SSRF |
| **Header** | Nenhum necessário | `X-aws-ec2-metadata-token` obrigatório |
| **TTL** | — | Token com TTL configurável |
| **Recomendação** | ❌ Evitar | ✅ **Usar sempre** |

```bash
# IMDSv1 (inseguro - não recomendado)
curl http://169.254.169.254/latest/meta-data/instance-id

# IMDSv2 (seguro - recomendado)
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id
```

**Forçar IMDSv2 (desativar v1):**
- Na criação: `--metadata-options HttpTokens=required`
- Pode aplicar via **SCP** na Organization para forçar em toda a conta

> 🎯 **Na prova:** "Proteger contra SSRF" ou "Segurança do metadata" → **IMDSv2** (HttpTokens=required). "Instância precisa saber seu IP/ID" → Instance Metadata.

---

## 12. Métodos de Conexão

### Comparação

| Método | Porta | Agent | IAM Auth | Logging | Bastion Necessário |
|--------|-------|-------|----------|---------|-------------------|
| **SSH** | 22 (TCP) | Não | Key pair | Manual | Sim (se privada) |
| **EC2 Instance Connect** | 22 (TCP) | Não | ✅ IAM | CloudTrail | Não (usa IP AWS) |
| **Session Manager (SSM)** | Nenhuma | SSM Agent | ✅ IAM | CloudTrail + S3/CW | **Não** |

### SSH Tradicional

- Requer **key pair** (chave privada local)
- Requer **porta 22** aberta no Security Group
- Requer **IP público** ou acesso via bastion/VPN
- Gerenciamento de chaves é operacionalmente custoso

### EC2 Instance Connect

- Push de chave pública temporária via API da AWS
- Funciona pelo **Console AWS** (browser) ou CLI
- Requer porta 22 aberta (mas source pode ser range de IPs da AWS)
- Chave é válida por **60 segundos**
- Apenas **Amazon Linux 2** e **Ubuntu** (nativamente)

### Session Manager (AWS Systems Manager)

```
┌─────────────────────────────────────────────────────────────┐
│  Session Manager — Arquitetura                               │
│                                                             │
│  ┌──────────┐    HTTPS     ┌──────────────┐    ┌────────┐ │
│  │ Usuário  │──────────────│ SSM Service  │────│ EC2    │ │
│  │ (Console │    (443)     │              │    │(Agent) │ │
│  │  ou CLI) │              └──────────────┘    └────────┘ │
│  └──────────┘                                              │
│                                                             │
│  ✅ Sem porta 22 aberta                                     │
│  ✅ Sem key pair necessário                                  │
│  ✅ Sem bastion host necessário                             │
│  ✅ Sem IP público necessário (via VPC endpoint)            │
│  ✅ Logging completo (CloudTrail, S3, CloudWatch)           │
│  ✅ Controle via IAM policies                               │
│  ✅ Port forwarding suportado                               │
│                                                             │
│  Requisitos:                                               │
│  - SSM Agent instalado (pré-instalado em Amazon Linux 2)   │
│  - IAM Role com policy AmazonSSMManagedInstanceCore        │
│  - Acesso ao SSM service (internet ou VPC endpoint)        │
└─────────────────────────────────────────────────────────────┘
```

> 🎯 **Na prova:** "Acesso sem abrir porta 22" ou "sem bastion host" ou "auditar sessões" → **Session Manager**. "Sem IP público e sem internet" → Session Manager + VPC Endpoint.

---

## 13. Nitro System e Nitro Enclaves

### Nitro System

> Plataforma de virtualização de nova geração da AWS que fornece performance quase bare-metal.

| Componente | Função |
|-----------|--------|
| **Nitro Cards** | Offload de I/O (rede, EBS, storage) para hardware dedicado |
| **Nitro Security Chip** | Hardware root of trust, protege firmware |
| **Nitro Hypervisor** | Hypervisor leve — quase toda capacidade vai para a instância |

**Benefícios do Nitro:**
- ✅ Performance de rede e EBS muito superior (100 Gbps, io2 Block Express)
- ✅ Enhanced Networking (ENA) automático
- ✅ Suporta EBS encryption sem impacto de performance
- ✅ Instâncias bare metal disponíveis
- ✅ Necessário para funcionalidades avançadas (io2 Block Express, EFA)

**Instâncias Nitro:** C5, M5, R5, T3, C6i, M6i, R6i, C7g, e todas as gerações 5+ são Nitro.

### Nitro Enclaves

> Ambientes de computação isolados dentro de uma instância EC2 para processar dados altamente sensíveis.

```
┌─────────────────────────────────────────────────────────┐
│  EC2 Instance                                           │
│                                                         │
│  ┌───────────────────────────────────────────────────┐ │
│  │  Parent Instance                                   │ │
│  │  (app principal, SO, rede)                        │ │
│  └────────────────────────┬──────────────────────────┘ │
│                           │ vsock (canal local)         │
│  ┌────────────────────────▼──────────────────────────┐ │
│  │  Nitro Enclave                                     │ │
│  │                                                   │ │
│  │  - Sem rede                                       │ │
│  │  - Sem storage persistente                        │ │
│  │  - Sem acesso do admin/root                       │ │
│  │  - Memória e CPU isolados                         │ │
│  │  - Attestation criptográfica                      │ │
│  │                                                   │ │
│  │  Casos de uso:                                    │ │
│  │  - Processar PII (CPF, cartões)                   │ │
│  │  - Operações com chaves privadas                  │ │
│  │  - Multi-party computation                        │ │
│  │  - DRM / proteção de conteúdo                     │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

- Integração com **AWS KMS** — Enclave pode acessar CMK via attestation
- Usa **Cryptographic Attestation** para provar integridade do código
- **Nenhum** usuário (nem root) pode acessar o Enclave via SSH ou console

> 📝 **Na prova:** "Processar dados sensíveis com isolamento total" ou "nem admin pode acessar dados em processamento" → **Nitro Enclaves**.

---

## 14. Billing — Estados da Instância e Cobrança

### Estados e Cobrança

| Estado | Cobra EC2? | Cobra EBS? | Cobra Elastic IP? |
|--------|:---:|:---:|:---:|
| **Running** | ✅ Sim | ✅ Sim | Não (associado) |
| **Stopped** | ❌ Não | ✅ Sim | ✅ Sim (se não associado a running) |
| **Terminated** | ❌ Não | ❌ (deletado se Delete on Termination) | ✅ Sim (se alocado sem associação) |
| **Hibernated** | ❌ Não (similar a stopped) | ✅ Sim (RAM salva no EBS) | ✅ Sim |
| **Pending** | ❌ Não | ✅ Sim | — |
| **Stopping** | ❌ Não | ✅ Sim | — |

### Regras de Cobrança Detalhadas

```
┌─────────────────────────────────────────────────────────────┐
│  Cobrança EC2                                                │
│                                                             │
│  Compute (instância):                                       │
│  - Linux/Ubuntu: por SEGUNDO (mínimo 60 segundos)           │
│  - Windows/RHEL/SUSE: por HORA (hora cheia)                 │
│  - Dedicated Host: por hora do host (independente de uso)   │
│                                                             │
│  EBS:                                                       │
│  - Cobrado por GB-mês provisionado (mesmo sem uso)          │
│  - IOPS provisionadas (io1/io2): cobrado por IOPS-mês      │
│  - Throughput provisionado (gp3 além do base): cobrado      │
│  - Snapshots: por GB-mês armazenado                         │
│                                                             │
│  Rede:                                                      │
│  - Data Transfer IN: grátis                                 │
│  - Data Transfer OUT: cobrado por GB                        │
│  - Mesma AZ: grátis (IP privado)                           │
│  - Entre AZs: cobra nos dois lados ($0.01/GB cada)         │
│  - Para internet: cobra egress                              │
│                                                             │
│  Elastic IP:                                                │
│  - Associado + instância running: GRÁTIS                    │
│  - Ocioso (não associado ou instância stopped): COBRA       │
│  - Mais de 1 EIP por instância: cobra adicional             │
└─────────────────────────────────────────────────────────────┘
```

### Otimização de Custos — Estratégias

| Estratégia | Economia | Quando usar |
|-----------|----------|-------------|
| Right-sizing | 20-40% | Instâncias subutilizadas (usar AWS Compute Optimizer) |
| Reservas/SP | até 72% | Workloads estáveis 24/7 |
| Spot | até 90% | Batch, CI/CD, processamento tolerante a falha |
| Scheduling | 50-70% | Dev/test (desligar noites/fins de semana) |
| Graviton (ARM) | 20-40% | Workloads compatíveis com ARM (M7g, C7g, R7g) |

> 🎯 **Na prova:** "Instância parada ainda cobrando" → EBS volume + Elastic IP. "Reduzir custos sem perder disponibilidade" → Reserved/Savings Plans. "Custo zero quando parada" → terminar + AMI (relançar quando necessário).

---

## 15. Palavras-chave da Prova SAA-C03

| Cenário na Prova | Resposta |
|-----------------|----------|
| "Maior performance de IOPS possível para banco de dados" | io2 Block Express (256K IOPS) ou Instance Store (milhões IOPS se efêmero OK) |
| "Custo mais baixo para workload tolerante a interrupção" | Spot Instances |
| "Licenciamento por socket/core" ou "BYOL" | Dedicated Host |
| "Workload estável 24/7, menor custo possível" | Reserved Instance Standard 3 anos All Upfront |
| "Flexibilidade para trocar família mantendo desconto" | Convertible RI ou Compute Savings Plan |
| "Boot rápido preservando estado em memória" | EC2 Hibernate (root EBS criptografado) |
| "HPC com baixa latência entre nós" | Cluster Placement Group + EFA |
| "Isolamento de hardware por instância, alta disponibilidade" | Spread Placement Group |
| "Kafka / Cassandra / HDFS distribuído" | Partition Placement Group |
| "Acesso sem porta 22 aberta, com auditoria" | AWS Systems Manager Session Manager |
| "Proteger metadata contra SSRF" | IMDSv2 (HttpTokens=required) |
| "Processar dados sensíveis com isolamento total do admin" | Nitro Enclaves |
| "Mover volume EBS para outra região" | Snapshot → Copy cross-region → Create volume |
| "EBS com criptografia em volume existente não criptografado" | Snapshot → Copy com encryption → Create volume → Replace |
| "Múltiplas instâncias acessando mesmo volume" | EBS Multi-Attach (io1/io2, mesma AZ) |
| "Storage temporário com milhões de IOPS" | Instance Store (i3/i3en) |
| "Reduzir tempo de boot de instâncias" | Golden AMI |
| "Garantir capacidade na AZ para DR" | Capacity Reservation (+ RI/SP para desconto) |
| "Instância com CPU burst para dev/test" | T3/T4g (burstable) |
| "Network performance para ML distribuído" | EFA (Elastic Fabric Adapter) |
| "IP fixo necessário para firewall externo whitelist" | Elastic IP ou NLB (IP estático por AZ) |
| "Failover rápido de IP entre instâncias" | Elastic IP remap ou ENI move |
| "Volume de boot custo-efetivo" | gp3 (mais barato que gp2, IOPS ajustável) |
| "SG permite entrada mas conexão timeout" | Verificar se regra inbound está correta |
| "Connection refused na porta" | Aplicação não está rodando (não é SG) |
| "Compartilhar AMI criptografada cross-account" | Compartilhar AMI + compartilhar CMK KMS |
| "Auto Scaling perdendo dados ao terminar instância" | EBS Delete on Termination = false ou usar EFS |
| "Data warehouse com throughput sequencial alto" | st1 (Throughput Optimized HDD) |
| "Backup automatizado de volumes EBS" | Data Lifecycle Manager (DLM) |
| "Volume com performance imediata de snapshot" | Fast Snapshot Restore (FSR) |

---

## 16. Resumo Visual — Decisão de Storage

```
┌─────────────────────────────────────────────────────────────────┐
│              Qual storage EC2 usar?                              │
│                                                                 │
│  Precisa persistir dados?                                       │
│  ├── NÃO → Instance Store (milhões IOPS, efêmero)             │
│  └── SIM ↓                                                     │
│                                                                 │
│  Qual padrão de acesso?                                        │
│  ├── Random I/O (banco de dados, apps) → SSD                  │
│  │   ├── < 16K IOPS? → gp3 (melhor custo-benefício)          │
│  │   ├── 16K–64K IOPS? → io2                                  │
│  │   └── > 64K IOPS? → io2 Block Express (até 256K)           │
│  │                                                              │
│  └── Sequential I/O (big data, logs) → HDD                    │
│      ├── Acesso frequente? → st1 (500 MB/s)                   │
│      └── Acesso raro? → sc1 (250 MB/s, mais barato)           │
│                                                                 │
│  Precisa Multi-Attach? → APENAS io1/io2 (mesma AZ)            │
│  Precisa compartilhar entre AZs? → EFS (não é EBS)            │
└─────────────────────────────────────────────────────────────────┘
```

---

## 17. Resumo Visual — Decisão de Compra

```
┌─────────────────────────────────────────────────────────────────┐
│              Qual modelo de compra usar?                         │
│                                                                 │
│  Workload é previsível e constante?                             │
│  ├── SIM: Reserved/Savings Plan                                │
│  │   ├── Sabe a família e região? → EC2 Instance SP ou Std RI │
│  │   ├── Pode mudar família/região? → Compute SP              │
│  │   └── Pode mudar durante contrato? → Convertible RI        │
│  │                                                              │
│  └── NÃO: Workload variável                                   │
│      ├── Tolerante a interrupção? → Spot (até 90% off)        │
│      │   └── Fleet diversificado? → Spot Fleet                 │
│      └── Não tolerante? → On-Demand                           │
│                                                                 │
│  Precisa de hardware dedicado?                                  │
│  ├── Licença por socket/core? → Dedicated Host                 │
│  └── Apenas isolamento? → Dedicated Instance                   │
│                                                                 │
│  Precisa garantir capacidade?                                   │
│  └── Capacity Reservation + RI/SP para desconto               │
└─────────────────────────────────────────────────────────────────┘
```
