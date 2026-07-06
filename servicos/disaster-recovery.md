# Disaster Recovery & Migrations — AWS SAA-C03

> Guia expandido e aprofundado para a certificação AWS Solutions Architect Associate (SAA-C03).
> Cobre estratégias de DR, serviços de migração, transferência de dados e cenários de prova.

---

## 1. Conceitos Fundamentais de Disaster Recovery

### 1.1 O que é Disaster Recovery (DR)?

Disaster Recovery é o conjunto de políticas, ferramentas e procedimentos para recuperar
sistemas de TI críticos após um desastre (falha de hardware, desastre natural, erro humano,
ataque cibernético). Na AWS, DR envolve replicar workloads entre Regiões ou entre
on-premises e a nuvem.

### 1.2 RPO — Recovery Point Objective

**RPO** define a quantidade máxima de dados que a organização aceita perder, medida em tempo.

- RPO de 1 hora → backups a cada 1 hora; perda máxima = 1h de dados
- RPO de 0 (zero) → replicação síncrona, sem perda de dados
- Quanto MENOR o RPO, MAIOR o custo (mais frequência de backup/replicação)

### 1.3 RTO — Recovery Time Objective

**RTO** define o tempo máximo aceitável para restaurar o serviço após um desastre.

- RTO de 4 horas → sistema deve estar operacional em até 4h após o incidente
- RTO de 0 → failover instantâneo (Multi-Site / Active-Active)
- Quanto MENOR o RTO, MAIOR o custo (infraestrutura standby necessária)

### 1.4 Diagrama RPO vs RTO

```
                        DESASTRE
                           │
   ◄──────── RPO ─────────┤────────── RTO ──────────►
                           │
   ┌───────────────────────┼───────────────────────────┐
   │                       │                           │
   │   Último backup/      │      Sistema              │
   │   ponto de            │      restaurado           │
   │   replicação          │      e operacional        │
   │                       │                           │
   └───────────────────────┼───────────────────────────┘
                           │
   ◄─── Dados perdidos ───►◄─── Tempo de inatividade ──►
        (data loss)              (downtime)

   EXEMPLO PRÁTICO:
   ─────────────────────────────────────────────────────────
   Backup às 10:00  │  Desastre às 11:30  │  Restaurado às 13:30
                    │                     │
   RPO = 1h30min   │                     │  RTO = 2h
   (dados entre    │                     │  (tempo para
    10:00-11:30    │                     │   restaurar)
    perdidos)      │                     │
```

### 1.5 Relação Custo vs RPO/RTO

```
   Custo ($)
     │
     │                                    ★ Multi-Site
     │                                 ╱   (Active-Active)
     │                              ╱
     │                           ╱
     │                    ★ Warm Standby
     │                 ╱
     │              ╱
     │        ★ Pilot Light
     │      ╱
     │   ╱
     │★ Backup & Restore
     │
     └──────────────────────────────────────── RPO/RTO (menor →)
       Alto RPO/RTO                    Baixo RPO/RTO
       (horas)                         (segundos/minutos)
```

---

## 2. As 4 Estratégias de Disaster Recovery

### 2.1 Tabela Comparativa Completa

```
┌──────────────────┬─────────────┬─────────────┬──────────┬──────────────┬─────────────────────────────────┐
│ Estratégia       │ RPO         │ RTO         │ Custo    │ Complexidade │ Exemplo de Arquitetura          │
├──────────────────┼─────────────┼─────────────┼──────────┼──────────────┼─────────────────────────────────┤
│ Backup & Restore │ Horas       │ Horas       │ $        │ Baixa        │ S3 cross-region + snapshots     │
│                  │ (última     │ (restaurar  │ (só      │              │ EBS/RDS. Restore sob demanda.   │
│                  │  cópia)     │  do zero)   │ storage) │              │                                 │
├──────────────────┼─────────────┼─────────────┼──────────┼──────────────┼─────────────────────────────────┤
│ Pilot Light      │ Minutos     │ 10min-1h    │ $$       │ Média        │ Core DB (RDS Multi-AZ) ativo   │
│                  │ (replicação │ (scale up   │          │              │ na DR region. EC2/App servers   │
│                  │  contínua   │  app tier)  │          │              │ desligados, AMIs prontas.       │
│                  │  do DB)     │             │          │              │                                 │
├──────────────────┼─────────────┼─────────────┼──────────┼──────────────┼─────────────────────────────────┤
│ Warm Standby     │ Segundos-   │ Minutos     │ $$$      │ Média-Alta   │ Ambiente completo rodando em    │
│                  │ Minutos     │ (scale up)  │          │              │ escala REDUZIDA. ASG min=1,     │
│                  │             │             │          │              │ RDS read replica, Route53       │
│                  │             │             │          │              │ failover.                       │
├──────────────────┼─────────────┼─────────────┼──────────┼──────────────┼─────────────────────────────────┤
│ Multi-Site /     │ ~Zero       │ ~Zero       │ $$$$     │ Alta         │ Full-scale em 2+ regiões.       │
│ Active-Active    │ (replicação │ (instantâ-  │ (2x      │              │ Route53 weighted/latency,       │
│                  │  síncrona)  │  neo)       │ infra)   │              │ DynamoDB Global Tables,         │
│                  │             │             │          │              │ Aurora Global Database.          │
└──────────────────┴─────────────┴─────────────┴──────────┴──────────────┴─────────────────────────────────┘
```

### 2.2 Estratégia 1 — Backup & Restore

**Conceito:** Apenas backups são mantidos na região de DR. Nenhuma infraestrutura ativa.
Após desastre, tudo é provisionado do zero a partir dos backups.

**Características:**
- Menor custo (paga apenas armazenamento)
- Maior RPO e RTO (horas)
- Ideal para ambientes não-críticos ou dev/test
- Usa: S3, EBS Snapshots, RDS Snapshots, AMIs, AWS Backup

**Diagrama ASCII — Backup & Restore:**

```
   REGIÃO PRIMÁRIA (us-east-1)              REGIÃO DR (us-west-2)
   ┌─────────────────────────┐              ┌─────────────────────────┐
   │                         │              │                         │
   │  ┌─────┐  ┌─────────┐  │   Backup     │  ┌─────────────────┐   │
   │  │ EC2 │  │  RDS DB  │──┼─────────────►│  │  S3 (backups)   │   │
   │  └─────┘  └─────────┘  │   Snapshots   │  ├─────────────────┤   │
   │  ┌─────┐               │   & AMIs      │  │ EBS Snapshots   │   │
   │  │ EBS │───────────────►│──────────────►│  │ RDS Snapshots   │   │
   │  └─────┘               │              │  │ AMIs            │   │
   │                         │              │  └─────────────────┘   │
   └─────────────────────────┘              │                         │
                                            │  (Sem compute ativo)    │
                                            └─────────────────────────┘

   APÓS DESASTRE → Provisionar EC2, RDS, etc. a partir dos backups (horas)
```

### 2.3 Estratégia 2 — Pilot Light

**Conceito:** O "núcleo" do sistema (geralmente o banco de dados) permanece ativo
e sincronizado na região de DR. Servidores de aplicação ficam pré-configurados
(AMIs) mas DESLIGADOS.

**Características:**
- Custo moderado (DB ativo + storage)
- RPO baixo para dados (replicação contínua)
- RTO de minutos a ~1 hora (ligar servers + scale)
- Similar a pilot light de um forno a gás: chama mínima sempre acesa

**Diagrama ASCII — Pilot Light:**

```
   REGIÃO PRIMÁRIA (us-east-1)              REGIÃO DR (us-west-2)
   ┌─────────────────────────┐              ┌─────────────────────────┐
   │                         │              │                         │
   │  ┌─────────┐           │              │  ┌─────────────────┐   │
   │  │ App     │           │              │  │ AMIs prontas    │   │
   │  │ Servers │           │              │  │ (EC2 DESLIGADO) │   │
   │  │ (EC2)   │           │              │  └─────────────────┘   │
   │  └─────────┘           │              │                         │
   │       │                │              │  ┌─────────────────┐   │
   │       ▼                │  Replicação  │  │                 │   │
   │  ┌─────────┐          │  contínua    │  │  RDS Read       │   │
   │  │  RDS    │──────────────────────────►  │  Replica        │   │
   │  │  Master │          │              │  │  (ATIVO)        │   │
   │  └─────────┘          │              │  └─────────────────┘   │
   │                         │              │                         │
   └─────────────────────────┘              └─────────────────────────┘

   APÓS DESASTRE → Promover replica, lançar EC2 a partir de AMIs, ajustar DNS
```


### 2.4 Estratégia 3 — Warm Standby

**Conceito:** Um ambiente COMPLETO e funcional roda na região de DR, porém em
escala REDUZIDA (menor capacidade). Após desastre, escala-se para produção.

**Características:**
- Custo mais elevado (ambiente funcional, só que menor)
- RPO de segundos a minutos
- RTO de minutos (apenas scale up via ASG)
- Business-critical workloads que toleram minutos de downtime
- Route53 health checks + failover routing

**Diagrama ASCII — Warm Standby:**

```
   REGIÃO PRIMÁRIA (us-east-1)              REGIÃO DR (us-west-2)
   ┌─────────────────────────┐              ┌─────────────────────────┐
   │                         │              │                         │
   │  ┌───────────────────┐  │              │  ┌───────────────────┐  │
   │  │  ALB              │  │              │  │  ALB              │  │
   │  └────────┬──────────┘  │              │  └────────┬──────────┘  │
   │           │             │              │           │             │
   │  ┌────────▼──────────┐  │              │  ┌────────▼──────────┐  │
   │  │  ASG (min=4)      │  │              │  │  ASG (min=1)      │  │
   │  │  ┌──┐┌──┐┌──┐┌──┐│  │              │  │  ┌──┐            │  │
   │  │  │EC│││EC│││EC│││EC││  │              │  │  │EC│            │  │
   │  │  └──┘└──┘└──┘└──┘│  │              │  │  └──┘            │  │
   │  └───────────────────┘  │              │  └───────────────────┘  │
   │           │             │              │           │             │
   │  ┌────────▼──────────┐  │  Replicação  │  ┌────────▼──────────┐  │
   │  │ RDS Multi-AZ      │──┼──────────────►  │ RDS Read Replica  │  │
   │  │ (Master)          │  │              │  │ (pode ser promov.)│  │
   │  └───────────────────┘  │              │  └───────────────────┘  │
   │                         │              │                         │
   └─────────────────────────┘              └─────────────────────────┘
          ▲                                          ▲
          │          Route53 Failover                 │
          └──────────── (active) ────────────────────┘
                                    (passive/standby)

   APÓS DESASTRE → Route53 failover, ASG scale up para min=4, promote replica
```

### 2.5 Estratégia 4 — Multi-Site / Active-Active

**Conceito:** Infraestrutura COMPLETA e em FULL SCALE em duas ou mais regiões.
Ambas servem tráfego simultaneamente. Failover é instantâneo.

**Características:**
- Custo MÁXIMO (2x infraestrutura ou mais)
- RPO ≈ 0 (replicação síncrona ou near-sync)
- RTO ≈ 0 (failover instantâneo pelo Route53)
- Requer dados replicados: Aurora Global, DynamoDB Global Tables, S3 CRR
- Complexidade alta: consistência eventual, conflict resolution

**Diagrama ASCII — Multi-Site / Active-Active:**

```
                         ┌───────────────────┐
                         │    Route53        │
                         │  Latency-based /  │
                         │  Weighted routing │
                         └────────┬──────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    ▼                             ▼
   REGIÃO 1 (us-east-1)              REGIÃO 2 (eu-west-1)
   ┌─────────────────────────┐      ┌─────────────────────────┐
   │  ┌───────────────────┐  │      │  ┌───────────────────┐  │
   │  │  ALB              │  │      │  │  ALB              │  │
   │  └────────┬──────────┘  │      │  └────────┬──────────┘  │
   │  ┌────────▼──────────┐  │      │  ┌────────▼──────────┐  │
   │  │  ASG (min=4)      │  │      │  │  ASG (min=4)      │  │
   │  │  Full Production  │  │      │  │  Full Production  │  │
   │  └───────────────────┘  │      │  └───────────────────┘  │
   │           │             │      │           │             │
   │  ┌────────▼──────────┐  │      │  ┌────────▼──────────┐  │
   │  │ Aurora Global DB  │◄─┼──────┼─►│ Aurora Global DB  │  │
   │  │ (Writer)          │  │ sync │  │ (Reader → Writer) │  │
   │  └───────────────────┘  │      │  └───────────────────┘  │
   │                         │      │                         │
   │  ┌───────────────────┐  │      │  ┌───────────────────┐  │
   │  │ DynamoDB Global   │◄─┼──────┼─►│ DynamoDB Global   │  │
   │  │ Table             │  │      │  │ Table             │  │
   │  └───────────────────┘  │      │  └───────────────────┘  │
   └─────────────────────────┘      └─────────────────────────┘

   AMBAS as regiões servem tráfego simultaneamente.
   Se uma falha → Route53 redireciona 100% para a outra (sem downtime).
```

---

## 3. AWS Elastic Disaster Recovery (AWS DRS)

### 3.1 Visão Geral

- **Nome anterior:** CloudEndure Disaster Recovery (substituído pelo DRS)
- **Objetivo:** Replicação contínua de servidores (on-premises, outras clouds, ou EC2)
  para a AWS para fins de DR
- **Tipo:** Block-level replication (nível de bloco de disco)
- **RPO:** Segundos (replicação contínua)
- **RTO:** Minutos (launch de instâncias a partir dos dados replicados)

### 3.2 Como Funciona

1. **Instalar o agente** (AWS Replication Agent) nos servidores de origem
2. O agente replica continuamente os discos para a **Staging Area** na AWS
3. A Staging Area usa **instâncias de baixo custo** (t3.small) e volumes EBS baratos
4. Em caso de DR: lançar instâncias de **produção** a partir dos dados replicados
5. Drill (teste): pode fazer testes periódicos sem impactar produção

### 3.3 Arquitetura do DRS

```
   ORIGEM (On-Premises / Outra Cloud)          AWS REGION (DR)
   ┌──────────────────────────┐      ┌─────────────────────────────────────┐
   │                          │      │                                     │
   │  ┌────────────────────┐  │      │  STAGING AREA          RECOVERY    │
   │  │ Servidor Origem 1  │  │      │  ┌──────────────┐   ┌────────────┐│
   │  │ [AWS Replication   │──┼──────┼─►│ t3.small     │──►│ Prod-size  ││
   │  │  Agent instalado]  │  │  TCP │  │ + EBS (dados)│   │ EC2        ││
   │  └────────────────────┘  │  443 │  └──────────────┘   │ (launch)   ││
   │                          │      │                      └────────────┘│
   │  ┌────────────────────┐  │      │  ┌──────────────┐   ┌────────────┐│
   │  │ Servidor Origem 2  │──┼──────┼─►│ t3.small     │──►│ Prod-size  ││
   │  │ [Agent]            │  │      │  │ + EBS        │   │ EC2        ││
   │  └────────────────────┘  │      │  └──────────────┘   └────────────┘│
   │                          │      │                                     │
   └──────────────────────────┘      │  Replicação contínua │ Launch em   │
                                     │  (custo baixo)       │ minutos     │
                                     └─────────────────────────────────────┘
```

### 3.4 Características Importantes para a Prova

| Característica | Detalhe |
|---|---|
| Substituiu | CloudEndure Disaster Recovery |
| Replicação | Contínua, nível de bloco |
| Staging | Instâncias baratas (t3.small) para manter custo baixo |
| Failback | Suportado (replicar de volta para origem após recuperação) |
| SOs suportados | Windows, Linux (várias distros) |
| Fontes | Físicos, VMware, Hyper-V, AWS, Azure, GCP |
| Testes (Drills) | Sem impacto na replicação; pode testar a qualquer momento |
| Rede | Replica via TCP 443 (sem VPN obrigatória, mas recomendada) |
| Point-in-time | Pode recuperar de um ponto específico no tempo |

---

## 4. AWS Database Migration Service (DMS)

### 4.1 Visão Geral

O AWS DMS permite migrar bancos de dados de forma segura para a AWS com
tempo de inatividade mínimo. O banco de origem permanece operacional durante
a migração.

### 4.2 Componentes Principais

```
   ┌────────────────┐       ┌───────────────────────────┐       ┌────────────────┐
   │                │       │   REPLICATION INSTANCE    │       │                │
   │   SOURCE       │       │   (EC2 gerenciado)        │       │   TARGET       │
   │   ENDPOINT     │──────►│                           │──────►│   ENDPOINT     │
   │                │       │   - Runs migration tasks  │       │                │
   │  (on-prem DB,  │       │   - Multi-AZ for HA       │       │  (RDS, Aurora, │
   │   RDS, etc.)   │       │   - Escalável              │       │   Redshift,    │
   │                │       │                           │       │   DynamoDB,    │
   └────────────────┘       └───────────────────────────┘       │   S3, etc.)    │
                                                                 └────────────────┘
```

### 4.3 Tipos de Migração

| Tipo | Descrição | Precisa do SCT? |
|---|---|---|
| **Homogênea** | Mesmo engine (Oracle → Oracle, MySQL → MySQL) | NÃO |
| **Heterogênea** | Engines diferentes (Oracle → PostgreSQL, SQL Server → Aurora) | SIM |

### 4.4 Schema Conversion Tool (SCT)

- Converte schema de um engine para outro (DDL, stored procedures, views, etc.)
- Necessário APENAS para migrações **heterogêneas**
- Não é necessário para: MySQL → Aurora MySQL (mesmo engine family)
- Exemplos de uso: Oracle → PostgreSQL, SQL Server → Aurora MySQL

### 4.5 Change Data Capture (CDC)

- Permite **replicação contínua** após a carga inicial (full load)
- Captura mudanças no banco de origem e aplica no destino em tempo real
- Minimiza downtime: apenas um curto cutover ao final
- Tipos de task no DMS:
  1. **Full Load** — migra todos os dados existentes
  2. **Full Load + CDC** — migra tudo e depois replica mudanças
  3. **CDC only** — apenas captura mudanças (dados já migrados por outro meio)

### 4.6 Multi-AZ no DMS

- Replication Instance pode ser configurada como Multi-AZ
- Provê HA para a própria instância de replicação
- Standby replica em outra AZ; failover automático
- Recomendado para migrações de produção

### 4.7 Sources e Targets Suportados

**Sources (origens):**
- On-premises e EC2: Oracle, SQL Server, MySQL, MariaDB, PostgreSQL, MongoDB, SAP ASE, DB2
- AWS: RDS (todos os engines), Aurora, S3, DocumentDB

**Targets (destinos):**
- RDS (todos os engines), Aurora, Redshift, DynamoDB, S3
- OpenSearch Service, Kinesis Data Streams, Apache Kafka
- DocumentDB, Neptune, Redis (ElastiCache)

### 4.8 Dicas para a Prova

- DMS = migração de banco com **mínimo downtime**
- SCT = necessário quando engines são **diferentes**
- CDC = replicação **contínua** para manter origem e destino sincronizados
- Multi-AZ na replication instance = **HA do processo de migração** (não do banco)


---

## 5. RDS & Aurora Migrations

### 5.1 Migração para RDS MySQL / Aurora MySQL

| Método | Descrição | Quando Usar |
|---|---|---|
| **mysqldump** | Export/import via dump SQL | Bancos pequenos (<10GB), simples |
| **Percona XtraBackup** | Backup físico, mais rápido | Bancos maiores MySQL/MariaDB |
| **DMS** | Replicação contínua | Mínimo downtime, produção |
| **Aurora Read Replica** | Criar replica de RDS MySQL → promover | Migrar RDS MySQL para Aurora |

### 5.2 Migração para RDS PostgreSQL / Aurora PostgreSQL

| Método | Descrição | Quando Usar |
|---|---|---|
| **pg_dump / pg_restore** | Export/import nativo | Bancos pequenos/médios |
| **DMS** | Migração com CDC | Mínimo downtime |
| **Aurora Read Replica** | Replica de RDS PostgreSQL | Migrar RDS PG para Aurora PG |

### 5.3 Migrar de RDS MySQL para Aurora MySQL

**Opção 1: Snapshot**
1. Criar snapshot do RDS MySQL
2. Restaurar snapshot como Aurora MySQL cluster
3. Downtime = tempo de restore (pode ser significativo)

**Opção 2: Aurora Read Replica (recomendada)**
1. Criar Aurora Read Replica a partir do RDS MySQL
2. Replicação acontece automaticamente
3. Quando sincronizado → promover a Aurora replica
4. Downtime mínimo (apenas tempo de promoção)

```
   ┌──────────────────┐         ┌──────────────────────┐
   │  RDS MySQL       │         │  Aurora MySQL         │
   │  (Origem)        │────────►│  Read Replica         │
   │                  │  async  │                       │
   └──────────────────┘  replic │  (depois promover     │
                                │   para standalone)    │
                                └──────────────────────┘
```

### 5.4 Importar Dados Externos para Aurora

- **S3 → Aurora MySQL:** usar `LOAD DATA FROM S3` (dados em CSV/Parquet no S3)
- **S3 → Aurora PostgreSQL:** usar extensão `aws_s3` com `table_import_from_s3`
- **Percona XtraBackup → S3 → Aurora MySQL:** restaurar backup físico via S3

### 5.5 Aurora Global Database para DR

- Replicação cross-region com lag < 1 segundo
- Até 5 regiões secundárias
- Promote region em < 1 minuto (RTO)
- RPO ≈ 1 segundo (replicação assíncrona baseada em storage)
- Não usa binlog → replicação no nível de storage (mais eficiente)

---

## 6. On-Premises Strategies com AWS

### 6.1 VM Import/Export

- Importar VMs existentes (VMware, Hyper-V, Citrix) como AMIs na AWS
- Exportar EC2 instances de volta como VMs
- Suporta: VMDK, VHD, OVA
- Caso de uso: migração lift-and-shift de VMs individuais, DR

### 6.2 AWS Application Discovery Service

Coleta informações sobre servidores on-premises para planejamento de migração.

| Modo | Como funciona | Dados coletados |
|---|---|---|
| **Agentless** (via Connector) | Conecta ao vCenter; não instala nada nos hosts | CPU, memória, disco, rede (métricas básicas) |
| **Agent-based** | Instala agente em cada servidor | Tudo do agentless + processos, conexões de rede, dependências |

- Dados enviados para **AWS Migration Hub**
- Ajuda a mapear dependências entre servidores
- Essencial para planejar ondas de migração (migration waves)

### 6.3 AWS Server Migration Service (SMS) — DESCONTINUADO

- **Substituído pelo AWS Application Migration Service (MGN)**
- Migrava VMs incrementalmente para a AWS
- Criava AMIs automaticamente
- Não usar para novos projetos — questões de prova podem mencionar como legado

### 6.4 Comparação: SMS vs MGN

| Aspecto | SMS (legado) | MGN (atual) |
|---|---|---|
| Replicação | Incremental (snapshots periódicos) | Contínua (block-level) |
| Agente | Connector no vCenter | Agente leve no servidor |
| RPO | Horas (entre snapshots) | Segundos/minutos |
| Fontes | Apenas VMs (VMware, Hyper-V) | Físicos, VMs, outras clouds |
| Status | Descontinuado | Serviço ativo e recomendado |

---

## 7. AWS Application Migration Service (MGN)

### 7.1 Visão Geral

- **Serviço recomendado** para migração lift-and-shift para AWS
- Substitui o AWS Server Migration Service (SMS)
- Baseado na tecnologia do CloudEndure Migration
- Replicação contínua no nível de bloco
- Suporta: servidores físicos, VMs (VMware, Hyper-V), outras clouds (Azure, GCP)

### 7.2 Processo de Migração com MGN

```
   ┌─────────────────────────────────────────────────────────────────────────────┐
   │                    FLUXO DE MIGRAÇÃO COM MGN                                │
   └─────────────────────────────────────────────────────────────────────────────┘

   1. INSTALAR AGENTE         2. REPLICAÇÃO           3. TESTING        4. CUTOVER
   ┌──────────────┐          ┌──────────────┐       ┌──────────────┐   ┌──────────┐
   │ Instalar AWS │          │ Replicação   │       │ Launch test  │   │ Launch   │
   │ Replication  │─────────►│ contínua dos │──────►│ instances    │──►│ prod     │
   │ Agent no     │          │ discos para  │       │ (validar)    │   │ cutover  │
   │ servidor     │          │ staging area │       │              │   │ instance │
   └──────────────┘          └──────────────┘       └──────────────┘   └──────────┘
                                    │
                                    ▼
                             ┌──────────────┐
                             │ Staging Area │
                             │ (t3.small +  │
                             │  EBS disks)  │
                             └──────────────┘
```

### 7.3 Fases Detalhadas

1. **Instalar agente:** AWS Replication Agent em cada servidor de origem
2. **Replicação contínua:** Dados replicados para staging area (instâncias baratas)
3. **Launch Settings:** Configurar tipo de instância, subnet, SG para produção
4. **Test:** Lançar instâncias de teste para validar funcionalidade
5. **Cutover:** Lançar instâncias de produção, redirecionar tráfego, desativar origem

### 7.4 Diferença entre MGN e DRS

| Aspecto | MGN | DRS |
|---|---|---|
| Propósito | **Migração** (lift-and-shift) | **Disaster Recovery** |
| Uso | One-time migration | Proteção contínua |
| Após conclusão | Descomissionar origem | Origem continua ativa |
| Failback | N/A | Suportado |
| Teste | Validar antes do cutover | Drills periódicos |

---

## 8. AWS Backup

### 8.1 Visão Geral

Serviço centralizado e gerenciado para automatizar backups de recursos AWS.

### 8.2 Componentes

| Componente | Descrição |
|---|---|
| **Backup Plan** | Define frequência, retenção, janela de backup |
| **Backup Vault** | Container lógico onde os backups são armazenados |
| **Backup Rule** | Regra dentro do plan (frequência, lifecycle, copy to region) |
| **Recovery Point** | Um backup individual de um recurso |

### 8.3 Serviços Suportados

- Amazon EC2 (AMIs)
- Amazon EBS (snapshots)
- Amazon RDS (todos os engines)
- Amazon Aurora
- Amazon DynamoDB
- Amazon EFS
- Amazon FSx (Lustre, Windows File Server, NetApp ONTAP, OpenZFS)
- AWS Storage Gateway (Volume Gateway)
- Amazon S3
- Amazon DocumentDB
- Amazon Neptune
- Amazon Redshift
- VMware workloads on-premises

### 8.4 Cross-Region & Cross-Account Backup

- **Cross-Region:** copiar backups para outra região (DR)
- **Cross-Account:** copiar backups para outra conta AWS (proteção contra comprometimento de conta)
- Configurado via Backup Plan rules ou AWS Organizations policies

### 8.5 AWS Backup Vault Lock (WORM)

- **WORM** = Write Once, Read Many
- Impede que QUALQUER pessoa (incluindo root) delete os backups
- Dois modos:
  - **Governance mode:** admins com permissões especiais podem remover
  - **Compliance mode:** NINGUÉM pode deletar até o fim da retenção (nem root, nem AWS)
- Proteção contra: ransomware, deleção acidental, insiders maliciosos
- Similar ao S3 Object Lock

### 8.6 Diagrama — AWS Backup Cross-Region/Account

```
   CONTA PRODUÇÃO (Account A)                    CONTA DR (Account B)
   ┌─────────────────────────────┐              ┌─────────────────────────────┐
   │  Region us-east-1           │              │  Region eu-west-1           │
   │  ┌───────────────────────┐  │  Cross-      │  ┌───────────────────────┐  │
   │  │ Backup Vault          │──┼──Region ─────┼─►│ Backup Vault (copy)   │  │
   │  │ ┌─────┐ ┌─────┐      │  │  + Cross-    │  │ ┌─────┐ ┌─────┐      │  │
   │  │ │ EBS │ │ RDS │      │  │  Account     │  │ │ EBS │ │ RDS │      │  │
   │  │ └─────┘ └─────┘      │  │              │  │ └─────┘ └─────┘      │  │
   │  │ ┌─────┐ ┌─────┐      │  │              │  │                       │  │
   │  │ │ EFS │ │DynDB│      │  │              │  │  Vault Lock (WORM)    │  │
   │  │ └─────┘ └─────┘      │  │              │  │  ativado              │  │
   │  └───────────────────────┘  │              │  └───────────────────────┘  │
   └─────────────────────────────┘              └─────────────────────────────┘
```


---

## 9. Transferência de Grandes Datasets

### 9.1 Tabela de Decisão

```
┌────────────────────┬───────────────┬──────────────┬─────────────┬──────────────────────────────────┐
│ Serviço            │ Volume Dados  │ Prazo        │ Conectivid. │ Caso de Uso                      │
├────────────────────┼───────────────┼──────────────┼─────────────┼──────────────────────────────────┤
│ AWS Snowcone       │ 8-14 TB       │ Dias/semanas │ Offline     │ Edge computing + dados pequenos  │
│ AWS Snowball Edge  │ 80 TB/device  │ Dias/semanas │ Offline     │ Migração em lote, edge compute   │
│ AWS Snowmobile     │ 100 PB        │ Semanas      │ Offline     │ Migração massiva de datacenter   │
├────────────────────┼───────────────┼──────────────┼─────────────┼──────────────────────────────────┤
│ AWS DataSync       │ Qualquer      │ Horas-dias   │ Online      │ Sincronização NFS/SMB → S3/EFS   │
│                    │               │              │ (agente)    │ Transferência agendada           │
├────────────────────┼───────────────┼──────────────┼─────────────┼──────────────────────────────────┤
│ AWS Transfer       │ Qualquer      │ Contínuo     │ Online      │ SFTP/FTPS/FTP → S3/EFS           │
│ Family             │               │              │             │ Parceiros externos (B2B)         │
├────────────────────┼───────────────┼──────────────┼─────────────┼──────────────────────────────────┤
│ Direct Connect     │ Qualquer      │ Contínuo     │ Online      │ Link dedicado 1/10/100 Gbps      │
│                    │ (stream)      │              │ (dedicada)  │ Latência consistente, alto BW    │
├────────────────────┼───────────────┼──────────────┼─────────────┼──────────────────────────────────┤
│ S3 Transfer        │ Qualquer      │ Contínuo     │ Online      │ Upload acelerado de longas       │
│ Acceleration       │               │              │ (internet)  │ distâncias via edge locations    │
├────────────────────┼───────────────┼──────────────┼─────────────┼──────────────────────────────────┤
│ VPN (Site-to-Site) │ Qualquer      │ Contínuo     │ Online      │ Criptografado sobre internet,    │
│                    │ (limitado)    │              │ (internet)  │ bandwidth limitado (~1.25 Gbps)  │
└────────────────────┴───────────────┴──────────────┴─────────────┴──────────────────────────────────┘
```

### 9.2 Regra Prática para Snow Family

**Cálculo de tempo de transferência pela rede:**
- 100 TB de dados
- Link de 1 Gbps = ~12 dias para transferir (sem overhead)
- Link de 100 Mbps = ~120 dias!

**Regra:** Se a transferência pela rede levar > 1 semana → considerar Snow Family

### 9.3 AWS DataSync — Detalhes

- **Agente:** instalado on-premises (VM no vSphere/Hyper-V/KVM)
- **Protocolos de origem:** NFS, SMB, HDFS, Object Storage (S3-compatible)
- **Destinos:** S3, EFS, FSx
- **Funcionalidades:**
  - Scheduling (agendar transferências)
  - Bandwidth throttling (limitar banda)
  - Data integrity validation (verificação automática)
  - Encryption in-transit (TLS)
  - Incremental transfers (apenas deltas)
- **Pode transferir entre serviços AWS** (EFS → EFS, S3 → S3 cross-region)
- **NÃO é contínuo** — executa tasks agendadas (diferente de replicação em tempo real)

### 9.4 AWS Transfer Family

- Serviço gerenciado para SFTP, FTPS, FTP, AS2
- Armazena em S3 ou EFS
- Caso de uso: parceiros de negócios que usam protocolos tradicionais
- Integra com: AD, LDAP, custom authentication (API Gateway + Lambda)
- Não requer mudança nos clientes existentes (mesmos protocolos)

### 9.5 Diagrama — Escolha do Serviço de Transferência

```
   ┌─────────────────────────────────────────────────────────────────┐
   │          DECISÃO: COMO TRANSFERIR DADOS PARA AWS?               │
   └─────────────────────────────────────────────────────────────────┘

   Dados > 10 TB e prazo curto?
        │
        ├── SIM → Snow Family (Snowball Edge / Snowmobile)
        │
        └── NÃO
             │
             ├── Precisa de link dedicado e consistente?
             │       │
             │       └── SIM → Direct Connect
             │
             ├── Transferência de file servers (NFS/SMB)?
             │       │
             │       └── SIM → DataSync
             │
             ├── Parceiros externos usando SFTP/FTP?
             │       │
             │       └── SIM → Transfer Family
             │
             └── Upload de objetos de longa distância?
                     │
                     └── SIM → S3 Transfer Acceleration
```

---

## 10. VMware Cloud on AWS

### 10.1 Visão Geral

- Parceria entre VMware e AWS
- Roda VMware vSphere, vSAN, NSX **nativamente** em bare-metal AWS
- Gerenciado pelo VMware (mesmo vCenter de sempre)
- Casos de uso PARA A PROVA:

### 10.2 Quando Usar (Cenários de Prova)

| Cenário | Por que VMware Cloud on AWS? |
|---|---|
| Migrar vSphere workloads para AWS | Sem re-platforming, mesmo stack VMware |
| DR para datacenter VMware | DR com ferramentas VMware (SRM/vSphere Replication) |
| Estender datacenter para cloud | Hybrid cloud com vMotion bidirecional |
| Modernizar gradualmente | Rodar VMs enquanto migra apps para containers/serverless |
| Consolidar datacenters | Reduzir footprint on-premises |

### 10.3 Características Técnicas

- Bare metal EC2 dedicado (i3.metal ou i3en.metal)
- Integração nativa com serviços AWS (S3, RDS, Lambda, etc.)
- vMotion entre on-premises e AWS (migração live)
- Mínimo de 2 hosts por cluster (até 16)
- Storage: vSAN (all-flash)

### 10.4 Diagrama — VMware Cloud on AWS

```
   ON-PREMISES DATACENTER                   AWS
   ┌─────────────────────┐                 ┌──────────────────────────────┐
   │  VMware vSphere      │                 │  VMware Cloud on AWS          │
   │  ┌────────────────┐  │                 │  ┌────────────────────────┐  │
   │  │  vCenter       │  │   vMotion /     │  │  SDDC (vCenter)        │  │
   │  │  ESXi Hosts    │◄─┼───Hybrid Link──►│  │  ESXi on Bare Metal   │  │
   │  │  vSAN          │  │                 │  │  vSAN                  │  │
   │  │  NSX           │  │                 │  │  NSX                   │  │
   │  └────────────────┘  │                 │  └──────────┬─────────────┘  │
   │                       │                 │             │                │
   └─────────────────────┘                 │             ▼                │
                                            │  ┌──────────────────────┐   │
                                            │  │ AWS Services:        │   │
                                            │  │ S3, RDS, Lambda,     │   │
                                            │  │ ELB, Redshift, etc.  │   │
                                            │  └──────────────────────┘   │
                                            └──────────────────────────────┘
```

---

## 11. Resumo Comparativo — Todos os Serviços de Migração

```
┌─────────────────────────┬─────────────────────────────────────────────────────────┐
│ Serviço                 │ Propósito Principal                                     │
├─────────────────────────┼─────────────────────────────────────────────────────────┤
│ DMS                     │ Migrar BANCOS DE DADOS com mínimo downtime              │
│ SCT                     │ Converter schema entre engines diferentes               │
│ MGN                     │ Migrar SERVIDORES (lift-and-shift)                      │
│ DRS                     │ Disaster Recovery contínuo de servidores                │
│ SMS (legado)            │ Migrar VMs → AMIs (substituído pelo MGN)               │
│ DataSync                │ Sincronizar FILE SYSTEMS (NFS/SMB → S3/EFS)            │
│ Snow Family             │ Transferência OFFLINE de grandes volumes                │
│ Transfer Family         │ SFTP/FTP gerenciado para parceiros                     │
│ VM Import/Export        │ Converter VMs ↔ AMIs                                   │
│ Application Discovery   │ Descobrir e mapear servidores on-premises              │
│ AWS Backup              │ Backup centralizado multi-serviço                      │
│ VMware Cloud on AWS     │ Rodar VMware nativamente na AWS                        │
└─────────────────────────┴─────────────────────────────────────────────────────────┘
```

---

## 12. Palavras-Chave da Prova SAA-C03 — Cenários e Respostas

> Quando a questão mencionar... → Pense em...

| # | Cenário / Palavra-chave na questão | Resposta / Serviço |
|---|---|---|
| 1 | "Migrar banco de dados com mínimo downtime" | **DMS** com CDC |
| 2 | "Converter schema de Oracle para PostgreSQL" | **SCT** + DMS |
| 3 | "Replicação contínua de servidores para DR" | **AWS DRS** (Elastic Disaster Recovery) |
| 4 | "Migrar servidores lift-and-shift para AWS" | **MGN** (Application Migration Service) |
| 5 | "Substituiu o CloudEndure" | **AWS DRS** (para DR) ou **MGN** (para migração) |
| 6 | "Substituiu o SMS" | **MGN** |
| 7 | "Backup centralizado, cross-region, cross-account" | **AWS Backup** |
| 8 | "Proteção contra deleção de backups (WORM)" | **AWS Backup Vault Lock** (Compliance mode) |
| 9 | "Transferir 50 TB com prazo de 1 semana" | **Snowball Edge** |
| 10 | "Transferir 100 PB de datacenter" | **Snowmobile** |
| 11 | "Sincronizar NFS on-premises com S3" | **DataSync** |
| 12 | "SFTP para parceiros externos depositarem arquivos" | **AWS Transfer Family** |
| 13 | "Menor custo de DR, aceita horas de downtime" | **Backup & Restore** |
| 14 | "DR com RTO de minutos, manter DB sincronizado" | **Pilot Light** |
| 15 | "DR com ambiente funcional em escala reduzida" | **Warm Standby** |
| 16 | "Zero downtime, ambas regiões servem tráfego" | **Multi-Site / Active-Active** |
| 17 | "Migrar RDS MySQL para Aurora com mínimo downtime" | **Aurora Read Replica** (promote) |
| 18 | "Descobrir dependências entre servidores on-prem" | **Application Discovery Service** (agent-based) |
| 19 | "Manter workloads VMware na AWS" | **VMware Cloud on AWS** |
| 20 | "DR para ambiente vSphere" | **VMware Cloud on AWS** ou **DRS** |
| 21 | "RPO de segundos com failover cross-region" | **Aurora Global Database** |
| 22 | "DynamoDB multi-region active-active" | **DynamoDB Global Tables** |
| 23 | "S3 replicação cross-region" | **S3 Cross-Region Replication (CRR)** |
| 24 | "Link dedicado de alta bandwidth para AWS" | **Direct Connect** |
| 25 | "Migração contínua de banco sem parar produção" | **DMS com CDC** (Full Load + CDC) |
| 26 | "Staging area com instâncias baratas para DR" | **AWS DRS** (t3.small na staging) |
| 27 | "Importar VM como AMI na AWS" | **VM Import/Export** |
| 28 | "Testar DR sem impactar produção" | **AWS DRS** (drill/test) |
| 29 | "Banco de dados heterogêneo: Oracle → Aurora" | **SCT** (schema) + **DMS** (dados) |
| 30 | "Backup de EFS, DynamoDB, RDS em um só lugar" | **AWS Backup** |

---

## 13. Dicas Finais para a Prova

### 13.1 Armadilhas Comuns

1. **DMS vs DataSync:** DMS = bancos de dados. DataSync = file systems (NFS/SMB/HDFS).
2. **MGN vs DRS:** MGN = migração (one-time). DRS = DR contínuo (proteção permanente).
3. **SCT:** Só é necessário para migrações HETEROGÊNEAS (engines diferentes).
4. **SMS:** É LEGADO — sempre que aparecer, a resposta certa provavelmente é MGN.
5. **Snowball vs DataSync:** Snowball = offline, grandes volumes. DataSync = online, incremental.
6. **Vault Lock Compliance mode:** NEM ROOT pode deletar. Governança mode = admins podem.
7. **Aurora Global vs RDS Multi-AZ:** Global = cross-REGION DR. Multi-AZ = HA dentro de UMA região.

### 13.2 Padrões de Resposta por Requisito

| Requisito do Cenário | Solução |
|---|---|
| "Cost-effective DR" | Backup & Restore |
| "Minimize data loss" (baixo RPO) | Replicação contínua (DRS, Aurora Global) |
| "Minimize downtime" (baixo RTO) | Warm Standby ou Multi-Site |
| "Comply with regulations" (imutabilidade) | Backup Vault Lock Compliance |
| "Hybrid cloud VMware" | VMware Cloud on AWS |
| "Large-scale migration" (muitos servers) | MGN + Migration Hub |
| "Continuous replication of database changes" | DMS com CDC |

### 13.3 Fórmula de Decisão para DR

```
   ┌─────────────────────────────────────────────────────────────┐
   │              ESCOLHA A ESTRATÉGIA DE DR                      │
   └─────────────────────────────────────────────────────────────┘

   Budget baixo + RPO/RTO tolerante (horas)?
        → Backup & Restore

   Budget moderado + RPO baixo para dados + RTO ~30min?
        → Pilot Light

   Budget bom + RPO/RTO de minutos?
        → Warm Standby

   Budget alto + RPO/RTO zero + ambas regiões ativas?
        → Multi-Site / Active-Active
```

---

## 14. Referências de Serviços Relacionados

| Serviço | Relação com DR/Migration |
|---|---|
| **Route53** | DNS failover entre regiões (health checks) |
| **CloudFormation** | Infra-as-Code para provisionar rapidamente em outra região |
| **Global Accelerator** | Roteamento de tráfego com failover automático |
| **S3 CRR** | Replicação cross-region de objetos S3 |
| **Aurora Global Database** | DB relacional cross-region com <1s lag |
| **DynamoDB Global Tables** | NoSQL multi-region active-active |
| **ElastiCache Global Datastore** | Cache Redis cross-region |
| **EBS Snapshots** | Copiar entre regiões para DR |
| **RDS Read Replicas** | Cross-region para failover manual |
| **AWS Organizations** | Políticas de backup cross-account |

---

*Documento atualizado para o exame SAA-C03. Revisão: Julho 2026.*
