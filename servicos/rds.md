# RDS — Relational Database Service (Guia Completo SAA-C03)

---

## 1. Conceitos Fundamentais

### 1.1 O que é o Amazon RDS?

O Amazon RDS (Relational Database Service) é um **serviço gerenciado** de banco de dados relacional.
Isso significa que a AWS assume a responsabilidade operacional de diversas tarefas administrativas,
permitindo que você foque na aplicação e nos dados.

### 1.2 Engines Suportadas

| Engine        | Versões Suportadas         | Observações                                      |
|---------------|----------------------------|--------------------------------------------------|
| MySQL         | 5.7, 8.0+                 | Engine mais popular, compatível com Aurora        |
| PostgreSQL    | 13, 14, 15, 16+           | Compatível com Aurora, suporta extensões          |
| MariaDB       | 10.4, 10.5, 10.6+         | Fork do MySQL, comunidade ativa                   |
| Oracle        | SE2, EE (BYOL ou License) | Suporta RAC apenas no RDS Custom                  |
| SQL Server    | Express, Web, Standard, EE | Licença incluída ou BYOL                          |
| IBM Db2       | 11.5+                     | Adicionado recentemente, BYOL                     |

### 1.3 O que a AWS Gerencia vs O que Você Gerencia

```
┌─────────────────────────────────────────────────────────────────┐
│                    RESPONSABILIDADE AWS                          │
├─────────────────────────────────────────────────────────────────┤
│  • Provisionamento de hardware                                  │
│  • Patching do sistema operacional                              │
│  • Patching do engine de banco de dados                         │
│  • Backups automáticos (dentro da janela configurada)            │
│  • Monitoramento básico (CloudWatch)                            │
│  • Failover automático (Multi-AZ)                               │
│  • Escalabilidade de storage (auto-scaling de disco)            │
│  • Manutenção de infraestrutura subjacente                      │
│  • Replicação de dados (Multi-AZ)                               │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                 RESPONSABILIDADE DO CLIENTE                      │
├─────────────────────────────────────────────────────────────────┤
│  • Schema do banco de dados (CREATE TABLE, índices)             │
│  • Otimização de queries                                        │
│  • Configuração de Security Groups                              │
│  • Configuração de parâmetros do DB (parameter groups)          │
│  • Gerenciamento de usuários e permissões do banco              │
│  • Configuração de SSL/TLS                                      │
│  • Definição de janelas de manutenção                           │
│  • Planejamento de capacidade (classe de instância)             │
└─────────────────────────────────────────────────────────────────┘
```

### 1.4 Por que NÃO há acesso SSH no RDS?

- O RDS é um serviço **gerenciado** — a AWS mantém o OS e a infraestrutura
- Você NÃO tem acesso ao sistema operacional subjacente
- Não pode instalar agentes, pacotes ou softwares customizados
- Exceção: **RDS Custom** (Oracle e SQL Server) permite acesso SSH ao OS
- Se precisa de controle total → use EC2 com banco instalado manualmente

### 1.5 Classes de Instância

| Família       | Uso                                    | Exemplo         |
|---------------|----------------------------------------|-----------------|
| db.t3/t4g     | Desenvolvimento, testes, burst         | db.t3.micro     |
| db.m5/m6g     | Uso geral, produção                    | db.m6g.large    |
| db.r5/r6g     | Otimizado para memória, caching        | db.r6g.xlarge   |
| db.x2g        | Memória extrema (SAP, Oracle)          | db.x2g.16xlarge |

### 1.6 Storage

- **gp2/gp3**: SSD de uso geral (até 64 TB)
- **io1/io2**: SSD provisionado IOPS (workloads I/O intensivos)
- **magnetic**: geração anterior (não recomendado)
- **Storage Auto Scaling**: aumenta automaticamente quando atinge threshold (padrão 10% livre)

---

## 2. Multi-AZ (Alta Disponibilidade)

### 2.1 Como Funciona

```
                    ┌─────────────────────┐
                    │    Aplicação         │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │  DNS Endpoint (RDS)  │
                    │  mydb.xxxxx.rds...   │
                    └──────────┬──────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                 │
    ┌─────────▼─────────┐     │     ┌───────────▼──────────┐
    │   AZ-a (PRIMARY)  │     │     │   AZ-b (STANDBY)     │
    │                    │     │     │                       │
    │  ┌──────────────┐  │     │     │  ┌───────────────┐   │
    │  │  DB Instance  │  │◄────────►│  │  DB Instance   │   │
    │  │  (Read/Write) │  │  SYNC    │  │  (NO traffic)  │   │
    │  └──────────────┘  │  REPL.   │  └───────────────┘   │
    └────────────────────┘           └──────────────────────┘
```

### 2.2 Características Principais

| Característica                  | Detalhe                                              |
|---------------------------------|------------------------------------------------------|
| Tipo de replicação              | **Síncrona** (cada write vai para ambas AZs)         |
| Tempo de failover               | **~1-2 minutos** (automático)                        |
| Standby serve tráfego?          | **NÃO** — somente espera para failover               |
| DNS endpoint muda?              | **NÃO** — mesmo endpoint, aponta para nova primary   |
| Requer mudança na aplicação?    | **NÃO** — transparente                               |
| Custo adicional                 | **~2x** (paga pela instância standby)                |
| Mesma região?                   | **SIM** — sempre na mesma região, AZs diferentes     |
| Pode ser Read Replica também?   | **SIM** — Read Replica pode ter Multi-AZ habilitado  |

### 2.3 Quando Ocorre Failover Automático?

- Falha na instância primária
- Falha na AZ da primária
- Perda de rede na primária
- Mudança de tipo de instância (manutenção)
- Patching do OS na primária
- **Manual Failover**: via "Reboot with Failover" no console

### 2.4 Multi-AZ DB Cluster (NOVO — importante para o exame)

```
    ┌──────────────────────────────────────────────────┐
    │              Multi-AZ DB Cluster                  │
    ├──────────────────────────────────────────────────┤
    │                                                   │
    │  ┌──────────┐   ┌──────────┐   ┌──────────┐    │
    │  │ AZ-a     │   │ AZ-b     │   │ AZ-c     │    │
    │  │ WRITER   │   │ READER   │   │ READER   │    │
    │  │ (Primary)│   │ (Standby)│   │ (Standby)│    │
    │  └────┬─────┘   └────┬─────┘   └────┬─────┘    │
    │       │               │               │          │
    │       └───────────────┼───────────────┘          │
    │          Replicação Semi-Síncrona                 │
    └──────────────────────────────────────────────────┘
    
    Endpoints:
    • Cluster Endpoint (Writer) → aponta para writer
    • Reader Endpoint → load balance entre readers
```

**Diferenças do Multi-AZ DB Cluster vs Multi-AZ clássico:**

| Aspecto                  | Multi-AZ Clássico        | Multi-AZ DB Cluster          |
|--------------------------|--------------------------|------------------------------|
| Instâncias               | 1 Primary + 1 Standby   | 1 Writer + 2 Readers         |
| Standby serve leitura?   | NÃO                     | SIM (readers atendem reads)  |
| Replicação               | Síncrona                | Semi-síncrona                |
| Failover time            | ~1-2 min                | ~35 segundos                 |
| Engines suportadas       | Todos                   | MySQL 8.0.28+, PostgreSQL 13+|
| AZs                      | 2                       | 3                            |

---

## 3. Read Replicas (Escalabilidade de Leitura)

### 3.1 Como Funciona

```
    ┌──────────────┐
    │  Aplicação   │
    │ (WRITES)     │────────────────┐
    └──────┬───────┘                │
           │                        │
    ┌──────▼───────┐                │
    │   PRIMARY    │                │
    │  (Writer)    │                │
    └──┬───┬───┬───┘                │
       │   │   │                    │
       │   │   │  ASYNC REPLICATION │
       │   │   │                    │
  ┌────▼┐ ┌▼────┐ ┌▼────┐          │
  │ RR1 │ │ RR2 │ │ RR3 │          │
  │(AZ-a)│ │(AZ-b)│ │(Outra│         │
  │     │ │     │ │Região)│         │
  └──▲──┘ └──▲──┘ └──▲───┘         │
     │       │       │              │
     └───────┼───────┘              │
             │                      │
    ┌────────▼────────┐             │
    │   Aplicação     │             │
    │   (READS)       │◄────────────┘
    └─────────────────┘
```

### 3.2 Características

| Característica                    | RDS Read Replica               | Aurora Read Replica        |
|-----------------------------------|--------------------------------|----------------------------|
| Máximo de réplicas                | **5**                          | **15**                     |
| Tipo de replicação                | Assíncrona                     | Assíncrona (ms de lag)     |
| Cross-Region                      | ✅ Sim                         | ✅ Sim                     |
| Promoção a standalone             | Manual                         | Automática (failover)      |
| Replica de Replica                | ✅ Sim (encadear)              | N/A (storage compartilhado)|
| Mesma engine necessária?          | Sim                            | Sim                        |

### 3.3 Custos de Rede — IMPORTANTE PARA O EXAME

```
┌──────────────────────────────────────────────────────────┐
│              CUSTOS DE TRANSFERÊNCIA                      │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  Same AZ:       GRATUITO (raro para RR)                  │
│  Cross-AZ:      GRATUITO (mesma região)                  │
│  Cross-Region:  COBRA transferência de dados             │
│                                                           │
│  Regra: Replicação na MESMA REGIÃO = FREE                │
│          Replicação CROSS-REGION = PAGA                   │
└──────────────────────────────────────────────────────────┘
```

### 3.4 Promoção de Read Replica

- Processo **manual** — você decide quando promover
- A réplica se torna uma instância **standalone** independente
- Perde a replicação com a primária original
- Casos de uso: DR (disaster recovery), separar workload de analytics
- Após promoção, pode configurar suas próprias Read Replicas e Multi-AZ

### 3.5 Replica de Replica (Chaining)

- Possível criar Read Replica de outra Read Replica
- Aumenta o lag de replicação (replication lag acumulado)
- Útil para reduzir carga na primária quando há muitas réplicas
- NÃO disponível para Aurora (storage compartilhado resolve isso)


---

## 4. Multi-AZ vs Read Replicas — Tabela Comparativa COMPLETA

| Critério                     | Multi-AZ                                  | Read Replicas                              |
|------------------------------|-------------------------------------------|--------------------------------------------|
| **Objetivo principal**       | Alta Disponibilidade (HA)                 | Escalabilidade de leitura                  |
| **Tipo de replicação**       | Síncrona                                  | Assíncrona                                 |
| **Lag de replicação**        | Zero (síncrono)                           | Possível (segundos a minutos)              |
| **Serve tráfego de leitura?**| NÃO (standby inativo)                    | SIM (aceita SELECTs)                       |
| **Serve tráfego de escrita?**| NÃO (somente primary)                    | NÃO (somente leitura)                     |
| **Failover automático?**     | SIM (~1-2 min)                            | NÃO (promoção manual)                     |
| **DNS endpoint muda?**       | NÃO (transparente)                       | SIM (novo endpoint após promoção)          |
| **Cross-Region?**            | NÃO (mesma região obrigatório)           | SIM (cross-region possível)                |
| **Quantidade**               | 1 standby (ou 2 readers no DB Cluster)   | Até 5 (RDS) ou 15 (Aurora)                |
| **Custo de rede**            | Não cobra (mesma região)                 | Free same-region, cobra cross-region       |
| **Backup vem do standby?**   | SIM (reduz impacto na primary)           | NÃO (backup vem da primary)               |
| **Pode ser combinado?**      | SIM (RR pode ter Multi-AZ)              | SIM (RR pode ter Multi-AZ)                |
| **Engines**                  | Todos                                    | Todos                                      |
| **Caso de uso**              | Produção crítica, zero downtime          | Relatórios, analytics, cache de leitura    |
| **Impacto na primary**       | Mínimo (I/O pode ter leve aumento)      | Mínimo (usa engine nativo de replicação)   |
| **Requer mudança na app?**   | NÃO                                      | SIM (precisa direcionar reads para RR)     |

### 4.1 Quando Usar Cada Um

```
┌─────────────────────────────────────────────────────────────┐
│  PERGUNTA DO EXAME                        │  RESPOSTA       │
├───────────────────────────────────────────┼─────────────────┤
│  "Alta disponibilidade"                   │  Multi-AZ       │
│  "Disaster recovery na mesma região"      │  Multi-AZ       │
│  "Failover automático"                    │  Multi-AZ       │
│  "Melhorar performance de leitura"        │  Read Replica   │
│  "Offload de queries de relatório"        │  Read Replica   │
│  "Replicar para outra região"             │  Read Replica   │
│  "HA + escalabilidade de leitura"         │  Ambos          │
│  "Failover < 35 seg + reads"             │  Multi-AZ Cluster│
└───────────────────────────────────────────┴─────────────────┘
```


---

## 5. Amazon Aurora — Em Profundidade

### 5.1 Arquitetura de Storage Distribuído

```
┌─────────────────────────────────────────────────────────────────┐
│                    AURORA STORAGE LAYER                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│    AZ-a              AZ-b              AZ-c                     │
│  ┌───────┐         ┌───────┐         ┌───────┐                 │
│  │Copy 1 │         │Copy 3 │         │Copy 5 │                 │
│  │Copy 2 │         │Copy 4 │         │Copy 6 │                 │
│  └───────┘         └───────┘         └───────┘                 │
│                                                                  │
│  Total: 6 cópias em 3 AZs (2 por AZ)                           │
│                                                                  │
│  QUORUM:                                                         │
│  • Writes: precisa de 4/6 cópias confirmarem (tolerância: 2)   │
│  • Reads:  precisa de 3/6 cópias (tolerância: 3)               │
│                                                                  │
│  TOLERÂNCIA A FALHAS:                                            │
│  • Pode perder 1 AZ inteira e continuar ESCREVENDO             │
│  • Pode perder 2 AZs inteiras e continuar LENDO                │
└─────────────────────────────────────────────────────────────────┘
```

### 5.2 Auto-Healing

- Storage é dividido em **segmentos de 10 GB**
- Se um segmento falha, Aurora automaticamente repara usando as outras cópias
- Não requer intervenção manual
- Background scrubbing detecta e corrige corrupção de dados

### 5.3 Endpoints do Aurora

```
┌─────────────────────────────────────────────────────────┐
│                    AURORA ENDPOINTS                      │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────────────┐                               │
│  │  Writer Endpoint     │ ─── Aponta para a instância   │
│  │  (Cluster Endpoint)  │     WRITER atual              │
│  └──────────────────────┘     (failover automático)     │
│                                                          │
│  ┌──────────────────────┐                               │
│  │  Reader Endpoint     │ ─── Load balancing entre      │
│  │                      │     TODAS as réplicas         │
│  └──────────────────────┘     (connection-level LB)     │
│                                                          │
│  ┌──────────────────────┐                               │
│  │  Custom Endpoint     │ ─── Subconjunto de instâncias │
│  │  (Opcional)          │     (ex: instâncias maiores   │
│  └──────────────────────┘      para analytics)          │
│                                                          │
│  ┌──────────────────────┐                               │
│  │  Instance Endpoint   │ ─── Cada instância individual │
│  │  (Cada instância)    │     (troubleshooting)         │
│  └──────────────────────┘                               │
└─────────────────────────────────────────────────────────┘
```

**IMPORTANTE**: O Reader Endpoint faz balanceamento a nível de CONEXÃO, não de query.
Se uma aplicação abre 1 conexão, todas as queries vão para a mesma réplica.

### 5.4 Aurora Replicas e Failover Priority

- Até **15 Aurora Replicas** na mesma região
- Failover é **automático** (diferente de Read Replicas do RDS)
- Priority Tiers: **0 (mais alta)** a **15 (mais baixa)**
- Em caso de failover, Aurora promove a réplica com:
  1. Menor tier (prioridade mais alta)
  2. Se empate: maior tamanho de instância
  3. Se empate: arbitrário

```
  Priority Tiers de Failover:
  
  Tier 0:  db.r6g.2xlarge  ← PROMOVIDA PRIMEIRO (prioridade máxima)
  Tier 1:  db.r6g.xlarge   ← Segunda opção
  Tier 2:  db.r6g.large    ← Terceira opção
  ...
  Tier 15: db.t3.medium    ← Última opção (menor prioridade)
```

### 5.5 Aurora Serverless v2

| Característica               | Detalhe                                          |
|------------------------------|--------------------------------------------------|
| Unidade de capacidade        | **ACU** (Aurora Capacity Unit) — 2 GB RAM/ACU    |
| Range de scaling             | 0.5 ACU até 128 ACUs                             |
| Tipo de scaling              | **Instantâneo** (não há cold start significativo)|
| Granularidade                | Incrementos de **0.5 ACU**                       |
| Billing                      | Por ACU-hora consumida (pay-per-use)             |
| Multi-AZ                     | SIM (cada instância pode ser serverless)         |
| Misturar com provisioned?    | SIM (cluster misto)                              |

**Casos de uso:**
- Workloads imprevisíveis ou intermitentes
- Desenvolvimento e testes
- Aplicações multi-tenant com picos variáveis
- Novos projetos sem histórico de carga

**Comparação Serverless v1 vs v2:**

| Aspecto               | Aurora Serverless v1        | Aurora Serverless v2         |
|-----------------------|-----------------------------|------------------------------|
| Scaling               | Pausável (pode ir a 0)     | Mín 0.5 ACU (não pausa)     |
| Velocidade scaling    | ~30 segundos               | Instantâneo                  |
| Multi-AZ              | Não                        | SIM                          |
| Read Replicas         | Não                        | SIM (até 15)                 |
| Global Database       | Não                        | SIM                          |
| Disponibilidade       | Limitado                   | Todas as regiões Aurora      |

### 5.6 Aurora Global Database

```
┌────────────────────────────────────────────────────────────────┐
│                  AURORA GLOBAL DATABASE                         │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  REGIÃO PRIMÁRIA (us-east-1)         REGIÃO SECUNDÁRIA         │
│  ┌─────────────────────┐            (eu-west-1)               │
│  │  Writer Cluster     │                                       │
│  │  + até 15 Replicas  │──── Replicação ────┐                 │
│  └─────────────────────┘    < 1 segundo      │                 │
│                                               ▼                 │
│                              ┌─────────────────────┐           │
│                              │  Reader Cluster      │           │
│                              │  + até 16 Replicas   │           │
│                              └─────────────────────┘           │
│                                                                 │
│  • Até 5 regiões secundárias                                   │
│  • Até 16 Read Replicas por região secundária                  │
│  • Replication lag típico: < 1 segundo                         │
│  • Failover cross-region: < 1 minuto (RPO ~1s)                │
│  • Use case: DR global, low-latency reads globais              │
└────────────────────────────────────────────────────────────────┘
```

**Promoção de região secundária:**
- RPO (Recovery Point Objective): tipicamente < 1 segundo
- RTO (Recovery Time Objective): tipicamente < 1 minuto
- Processo: promove região secundária a primária (manual ou planejado)

### 5.7 Aurora Multi-Master

- **Todas** as instâncias podem ler E escrever
- Proporciona **disponibilidade contínua** de escrita (write HA)
- Se um writer falha, outro writer continua aceitando writes imediatamente
- Sem necessidade de failover (zero downtime para escrita)
- Limitação: mesma região, até 4 instâncias writer
- **NOTA**: Feature com adoção limitada; Aurora DB Clusters tendem a ser preferidos

### 5.8 Aurora Backtrack

| Característica           | Detalhe                                             |
|--------------------------|-----------------------------------------------------|
| O que faz?               | "Volta no tempo" sem criar nova instância           |
| Engine suportada         | **MySQL-compatible Aurora APENAS**                  |
| Tempo máximo de backtrack| Até **72 horas**                                    |
| Precisa de restore?      | NÃO (in-place, mesma instância)                    |
| Downtime                 | Breve (segundos)                                   |
| Custo                    | Por registro de mudança armazenado                 |
| Deve ser habilitado      | Na criação do cluster (não pode habilitar depois)  |

**Caso de uso clássico:** desenvolvedor executou DELETE sem WHERE → Backtrack volta ao estado anterior.

### 5.9 Aurora Machine Learning (Aurora ML)

- Integração nativa com **SageMaker** e **Comprehend**
- Permite invocar modelos ML diretamente via SQL
- Casos de uso: detecção de fraude, análise de sentimento, recomendações
- Não requer experiência em ML — funciona com queries SQL

### 5.10 Aurora I/O-Optimized

| Característica               | Aurora Standard                | Aurora I/O-Optimized          |
|------------------------------|-------------------------------|-------------------------------|
| Custo de I/O                 | Paga por I/O request          | I/O incluído no preço         |
| Custo da instância           | Menor                         | ~30% maior                    |
| Ideal para                   | I/O moderado                  | Workloads I/O-intensivos      |
| Economia potencial           | —                             | Até 40% se I/O > 25% do custo|

**Regra para o exame:** Se o cenário menciona "custos de I/O muito altos" ou "workload I/O-intensivo" → Aurora I/O-Optimized.


---

## 6. Backups e Snapshots

### 6.1 Automated Backups

| Característica               | Detalhe                                              |
|------------------------------|------------------------------------------------------|
| Retenção                     | **1 a 35 dias** (padrão: 7 dias)                    |
| Point-in-Time Recovery       | Qualquer segundo dentro do período de retenção       |
| Janela de backup             | Configurável (evitar horários de pico)               |
| Impacto em performance       | Leve (snapshot vem do standby Multi-AZ se habilitado)|
| Desabilitar                  | Setar retenção = 0 (NÃO recomendado)               |
| Transaction logs             | A cada 5 minutos (permite PITR granular)            |
| Destino                      | S3 (gerenciado pela AWS, não visível para você)     |

### 6.2 Manual Snapshots

| Característica               | Detalhe                                              |
|------------------------------|------------------------------------------------------|
| Retenção                     | **Indefinida** (até você deletar)                   |
| Quando criar                 | Antes de operações arriscadas, migrações            |
| Custo                        | Pelo storage usado em S3                            |
| Cross-Region Copy            | ✅ SIM                                               |
| Cross-Account Share          | ✅ SIM (com KMS key sharing se encriptado)          |

### 6.3 Restore — PONTO CRÍTICO

```
┌─────────────────────────────────────────────────────────────┐
│  REGRA FUNDAMENTAL:                                          │
│                                                              │
│  Restaurar um backup ou snapshot SEMPRE cria uma             │
│  NOVA INSTÂNCIA RDS com um NOVO endpoint DNS.                │
│                                                              │
│  A instância original continua existindo.                    │
│  Você precisa atualizar sua aplicação para apontar           │
│  para o novo endpoint.                                       │
└─────────────────────────────────────────────────────────────┘
```

### 6.4 Copy Snapshot Cross-Region

- Permite copiar snapshot manual para outra região
- Caso de uso: **Disaster Recovery** cross-region
- Se o snapshot é encriptado, precisa especificar KMS key da região destino
- Automatize com AWS Backup ou Lambda + EventBridge

### 6.5 Share Snapshot Cross-Account

- Permite compartilhar snapshot manual com outras contas AWS
- Se encriptado: precisa compartilhar a KMS key (via key policy)
- Não pode compartilhar snapshot de instância com **default KMS key** — precisa usar CMK
- Conta destino copia o snapshot para sua própria conta antes de restaurar

---

## 7. Criptografia

### 7.1 Encryption at Rest

```
┌─────────────────────────────────────────────────────────────┐
│                    ENCRYPTION AT REST                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  • Usa AWS KMS (AES-256)                                    │
│  • DEVE ser habilitada na CRIAÇÃO da instância              │
│  • NÃO pode habilitar encryption em instância existente     │
│  • Se primary é encriptada → Replicas são encriptadas       │
│  • Se primary NÃO é encriptada → Replicas NÃO podem ser    │
│  • Abrange: storage, snapshots, backups, replicas           │
│                                                              │
│  Chaves suportadas:                                         │
│  • AWS managed key (aws/rds) — padrão                       │
│  • Customer managed key (CMK) — necessário para share       │
└─────────────────────────────────────────────────────────────┘
```

### 7.2 Encryption in Transit (SSL/TLS)

- Suportado por **todas** as engines
- Habilitado via parameter group (rds.force_ssl = 1 para PostgreSQL)
- Para MySQL: `REQUIRE SSL` no grant do usuário
- Certificados providos pela AWS (rds-ca-2019, rds-ca-rsa2048-g1, etc.)
- Pode forçar SSL para todas as conexões

### 7.3 Como Encriptar uma Instância NÃO Encriptada

```
  Passo a passo:

  1. Criar Snapshot da instância não-encriptada
          │
          ▼
  2. Copiar Snapshot COM encryption habilitada (especificar KMS key)
          │
          ▼
  3. Restaurar nova instância a partir do snapshot encriptado
          │
          ▼
  4. Migrar aplicação para novo endpoint
          │
          ▼
  5. Deletar instância antiga (quando confirmar que tudo funciona)
```

**IMPORTANTE para o exame:** Não existe botão "enable encryption" em instância existente.
O caminho é SEMPRE: snapshot → copy encrypted → restore.

---

## 8. RDS Proxy

### 8.1 O que é e Para que Serve

```
┌─────────────────────────────────────────────────────────────┐
│                       RDS PROXY                              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────┐  ┌────────┐  ┌────────┐                        │
│  │Lambda 1│  │Lambda 2│  │Lambda N│  (centenas/milhares)    │
│  └───┬────┘  └───┬────┘  └───┬────┘                        │
│      │           │           │                               │
│      └───────────┼───────────┘                               │
│                  │                                            │
│         ┌────────▼────────┐                                  │
│         │    RDS PROXY    │  ← Connection Pooling            │
│         │  (Fully Managed)│  ← Mantém pool de conexões      │
│         └────────┬────────┘                                  │
│                  │  (poucas conexões reais)                   │
│         ┌────────▼────────┐                                  │
│         │    RDS / Aurora  │                                  │
│         │    Database      │                                  │
│         └─────────────────┘                                  │
└─────────────────────────────────────────────────────────────┘
```

### 8.2 Características Principais

| Característica               | Detalhe                                              |
|------------------------------|------------------------------------------------------|
| Connection Pooling           | Reutiliza conexões, reduz overhead do DB             |
| Failover time                | Reduz em até **66%** (não drena conexões)            |
| IAM Authentication           | Suporta IAM auth para conexão                        |
| Secrets Manager              | Integra com Secrets Manager para credenciais         |
| Multi-AZ                     | Automaticamente distribui em múltiplas AZs           |
| VPC only                     | Acessível **APENAS** dentro da VPC (nunca público)   |
| Engines suportadas           | MySQL, PostgreSQL, MariaDB, SQL Server               |
| Enforce IAM Auth             | Pode forçar que TODAS conexões usem IAM              |

### 8.3 Padrão Lambda + RDS Proxy

**Problema:** Lambda pode criar centenas/milhares de conexões simultâneas ao DB.
Cada invocação Lambda abre uma nova conexão → exaure `max_connections` do banco.

**Solução:** RDS Proxy mantém um pool de conexões. Lambdas se conectam ao Proxy,
que multiplica logicamente as conexões em poucas conexões físicas ao DB.

**Para o exame:** Se a questão menciona "Lambda + RDS" e problema de conexões → RDS Proxy.

### 8.4 Benefícios para Failover

- Durante failover Multi-AZ, RDS Proxy mantém as conexões abertas
- Aplicação não percebe o failover (transparente)
- Reduz tempo de indisponibilidade de ~1-2min para ~30-40 segundos

---

## 9. IAM Database Authentication

### 9.1 Como Funciona

```
┌─────────────────────────────────────────────────────────────┐
│              IAM DATABASE AUTHENTICATION                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Aplicação chama AWS API para gerar token                │
│     (generate-db-auth-token)                                │
│                                                              │
│  2. Recebe token temporário (válido por 15 minutos)         │
│                                                              │
│  3. Usa token como "senha" na conexão ao banco              │
│                                                              │
│  Benefícios:                                                 │
│  • Sem senha hardcoded no banco ou na aplicação             │
│  • Credenciais gerenciadas pelo IAM                         │
│  • Auditoria via CloudTrail                                 │
│  • Token expira em 15 minutos (rotação automática)          │
│                                                              │
│  Engines suportadas:                                         │
│  • MySQL                                                     │
│  • PostgreSQL                                                │
│  • MariaDB                                                   │
│                                                              │
│  NÃO suportado: Oracle, SQL Server                          │
└─────────────────────────────────────────────────────────────┘
```

### 9.2 Quando Usar (para o exame)

- "Autenticação sem senha" → IAM Database Authentication
- "Rotação automática de credenciais" → IAM Auth ou Secrets Manager
- "Integrar com IAM roles" → IAM Database Authentication
- "EC2 instance profile conectando ao RDS" → IAM Auth


---

## 10. RDS Custom

### 10.1 O que é

| Característica               | Detalhe                                              |
|------------------------------|------------------------------------------------------|
| Engines suportadas           | **Oracle** e **SQL Server** APENAS                  |
| Acesso ao OS                 | ✅ SIM — SSH, RDP                                    |
| Customizações                | Instalar patches, agentes, softwares customizados   |
| Gerenciamento da AWS         | Parcial (infra, mas não OS completo)                |
| Automação pausa              | Recomendado: pausar automação antes de customizar   |

### 10.2 RDS Custom vs RDS vs EC2

```
┌──────────────────────────────────────────────────────────────┐
│  Nível de Controle vs Gerenciamento                          │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  EC2 + DB manual    ████████████████████████  Controle total │
│  RDS Custom         █████████████████         Controle médio │
│  RDS Standard       ████████                  Controle baixo │
│  Aurora Serverless  ████                      Mínimo         │
│                                                               │
│  ◄─── Mais gerenciamento AWS ───── Menos gerenciamento ───►  │
└──────────────────────────────────────────────────────────────┘
```

### 10.3 Quando Usar (para o exame)

- "Oracle com patches customizados"
- "SQL Server com software de terceiros no OS"
- "Precisa de acesso SSH ao banco RDS"
- "Instalar agentes de monitoramento no OS do banco"

---

## 11. RDS Event Notifications

### 11.1 Tipos de Eventos

| Categoria de Evento    | Exemplos                                             |
|------------------------|------------------------------------------------------|
| DB Instance            | Failover, criação, deleção, mudança de estado        |
| DB Cluster             | Failover Aurora, criação de cluster                  |
| DB Snapshot            | Criação concluída, cópia concluída                   |
| DB Parameter Group     | Modificação de parâmetros                            |
| DB Security Group      | Mudanças em SGs                                      |
| DB Cluster Snapshot    | Snapshot de cluster concluído                        |

### 11.2 Integração com SNS e EventBridge

```
┌──────────┐         ┌──────────┐         ┌──────────────┐
│   RDS    │────────►│   SNS    │────────►│  Email/SMS   │
│  Events  │         │  Topic   │         │  Lambda      │
└──────────┘         └──────────┘         │  SQS         │
                                           └──────────────┘

┌──────────┐         ┌──────────────┐     ┌──────────────┐
│   RDS    │────────►│  EventBridge │────►│  Lambda      │
│  Events  │         │  (Rules)     │     │  Step Func.  │
└──────────┘         └──────────────┘     │  SNS/SQS     │
                                           └──────────────┘
```

**IMPORTANTE:** RDS Event Notifications informam sobre **eventos operacionais** (DB criada, failover),
NÃO sobre dados dentro do banco (não é trigger de INSERT/UPDATE).

---

## 12. Enhanced Monitoring vs CloudWatch

### 12.1 Comparação

| Característica               | CloudWatch Padrão            | Enhanced Monitoring           |
|------------------------------|------------------------------|-------------------------------|
| Fonte dos dados              | Hypervisor                   | Agente no OS da instância    |
| Granularidade                | 1 minuto (ou 5 min free)    | **1, 5, 10, 15, 30 ou 60s** |
| Métricas de OS               | NÃO                         | SIM                          |
| CPU breakdown                | Total CPU apenas             | User, System, I/O Wait, etc |
| Memória livre                | NÃO nativamente             | SIM (Free/Total memory)     |
| Processos                    | NÃO                         | SIM (top processes)         |
| File system usage            | NÃO                         | SIM                          |
| Custo adicional              | Incluído                    | Paga por dados enviados ao CW|
| Destino dos dados            | CloudWatch Metrics           | CloudWatch Logs              |

### 12.2 Quando Usar Enhanced Monitoring

- "Identificar se o CPU alto é de user space ou kernel"
- "Ver memória livre do OS"
- "Granularidade de 1 segundo"
- "Identificar processos consumindo recursos"

---

## 13. Performance Insights

### 13.1 O que é

- Ferramenta visual para identificar **gargalos de performance** no banco
- Mostra **load** do banco comparado com capacidade (vCPUs)
- Identifica **top SQL statements** consumindo recursos
- Identifica **top wait events** (lock, I/O, CPU)
- Disponível para RDS e Aurora

### 13.2 Componentes

```
┌─────────────────────────────────────────────────────────────┐
│               PERFORMANCE INSIGHTS                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  DB Load = Active Sessions (média de sessões ativas)        │
│                                                              │
│  Se DB Load > vCPUs → banco está saturado                   │
│                                                              │
│  Dimensões de análise:                                      │
│  • Top SQL: queries mais pesadas                            │
│  • Top Waits: o que está causando espera                    │
│  • Top Hosts: quais hosts conectados geram mais carga       │
│  • Top Users: quais usuários do DB geram mais carga         │
│  • Top Databases: qual schema está mais carregado           │
│                                                              │
│  Retenção:                                                  │
│  • Free Tier: 7 dias                                        │
│  • Paid: até 2 anos                                         │
└─────────────────────────────────────────────────────────────┘
```

### 13.3 Para o Exame

- "Identificar queries lentas" → Performance Insights
- "SQL que consome mais CPU" → Performance Insights
- "Lock contention no banco" → Performance Insights (Top Waits)

---

## 14. Outros Serviços de Banco de Dados AWS (Breve)

### 14.1 Tabela Comparativa

| Serviço          | Tipo                | Modelo      | Caso de Uso Principal                     |
|------------------|---------------------|-------------|-------------------------------------------|
| **RDS**          | Relacional          | Provisioned | OLTP, aplicações tradicionais             |
| **Aurora**       | Relacional          | Prov/Sless  | OLTP de alta performance e HA             |
| **Redshift**     | Data Warehouse      | Columnar    | OLAP, analytics, BI                       |
| **DynamoDB**     | Key-Value/Document  | Serverless  | Milhões de requests/s, low latency        |
| **Neptune**      | Grafos              | Managed     | Redes sociais, fraud detection, knowledge |
| **DocumentDB**   | Documentos          | Managed     | Compatível MongoDB, JSON workloads        |
| **Keyspaces**    | Wide Column         | Serverless  | Compatível Apache Cassandra               |
| **Timestream**   | Séries Temporais    | Serverless  | IoT, métricas, eventos temporais          |
| **QLDB**         | Ledger              | Serverless  | Imutável, auditoria, histórico completo   |
| **ElastiCache**  | In-Memory           | Managed     | Cache, sessões, leaderboards              |
| **MemoryDB**     | In-Memory           | Managed     | Redis durável, primary database           |

### 14.2 Redshift — Detalhes Relevantes

- **OLAP** (Online Analytical Processing) — NÃO é OLTP
- Storage **columnar** (otimizado para analytics)
- Baseado em PostgreSQL (mas não é PostgreSQL)
- **Redshift Spectrum**: consulta dados diretamente no S3 sem carregar no Redshift
- Cluster: Leader Node + Compute Nodes
- **Redshift Serverless**: sem gerenciar clusters
- Não é Multi-AZ nativo (snapshots para DR)

### 14.3 Neptune — Banco de Grafos

- Otimizado para queries de **relacionamento** (traversals)
- Suporta **Gremlin** (Apache TinkerPop) e **SPARQL** (W3C)
- Casos de uso: redes sociais, detecção de fraude, knowledge graphs, recommendation engines
- Alta disponibilidade: 6 cópias em 3 AZs (similar Aurora)

### 14.4 DocumentDB — Compatível MongoDB

- API compatível com **MongoDB** (não é MongoDB)
- Gerenciado pela AWS, storage similar ao Aurora
- Para migrar de MongoDB on-premises → DocumentDB
- Escala automaticamente em incrementos de 10 GB até 128 TB

### 14.5 Keyspaces — Compatível Cassandra

- Compatível com **Apache Cassandra** (CQL)
- Serverless, escala automaticamente
- Tabelas replicadas em 3 AZs
- Para migrar de Cassandra on-premises → Keyspaces

### 14.6 Timestream — Séries Temporais

- Otimizado para dados **temporais** (timestamp-based)
- 1000x mais rápido que bancos relacionais para time-series
- Armazena dados recentes em memória, históricos em storage magnético
- Casos de uso: IoT, DevOps metrics, application monitoring

### 14.7 QLDB — Quantum Ledger Database

- Banco de dados **imutável** e verificável criptograficamente
- Histórico completo de todas as mudanças (append-only journal)
- **Não é descentralizado** (diferente de blockchain — é centralizado na AWS)
- Casos de uso: auditoria financeira, supply chain, registros legais
- Se a questão menciona "imutável" + "centralizado" → QLDB
- Se menciona "descentralizado" + "blockchain" → Amazon Managed Blockchain

---

## 15. Palavras-Chave da Prova SAA-C03 — Cenários e Respostas

### 15.1 Mapa de Cenários (Mínimo 20)

| # | Cenário / Palavra-Chave na Questão                                          | Resposta                                           |
|---|-----------------------------------------------------------------------------|---------------------------------------------------|
| 1 | "Alta disponibilidade para RDS"                                             | Multi-AZ                                          |
| 2 | "Failover automático, mínimo downtime"                                      | Multi-AZ (ou Multi-AZ DB Cluster para <35s)       |
| 3 | "Melhorar performance de leitura"                                           | Read Replicas                                     |
| 4 | "Offload de queries de relatório/analytics"                                 | Read Replicas (ou Redshift para OLAP pesado)      |
| 5 | "Replicação cross-region para DR"                                           | Read Replica Cross-Region (ou Aurora Global DB)   |
| 6 | "Latência < 1s para leitura cross-region"                                   | Aurora Global Database                            |
| 7 | "Failover cross-region < 1 minuto"                                          | Aurora Global Database (promover região)          |
| 8 | "Lambda com muitas conexões ao banco"                                       | RDS Proxy                                         |
| 9 | "Reduzir tempo de failover Multi-AZ"                                        | RDS Proxy (reduz 66%)                             |
| 10| "Autenticação sem senha no banco, integrar com IAM"                         | IAM Database Authentication                       |
| 11| "Banco relacional serverless, carga imprevisível"                           | Aurora Serverless v2                              |
| 12| "Voltar no tempo sem criar nova instância"                                  | Aurora Backtrack                                  |
| 13| "Encriptar banco existente não-encriptado"                                  | Snapshot → Copy encrypted → Restore              |
| 14| "Banco com acesso SSH, instalar patches Oracle"                             | RDS Custom                                        |
| 15| "Compartilhar snapshot com outra conta"                                     | Copy Snapshot cross-account + CMK sharing         |
| 16| "DR cross-region com banco relacional"                                      | Read Replica cross-region OU Aurora Global DB     |
| 17| "Analytics pesado, petabytes, columnar"                                     | Redshift                                          |
| 18| "Banco de grafos, rede social, fraud detection"                             | Neptune                                           |
| 19| "Migrar MongoDB para AWS"                                                   | DocumentDB                                        |
| 20| "Dados imutáveis, auditoria, ledger centralizado"                           | QLDB                                              |
| 21| "Séries temporais, IoT, métricas"                                           | Timestream                                        |
| 22| "Migrar Cassandra para AWS"                                                 | Keyspaces                                         |
| 23| "Storage auto-healing, 6 cópias, 3 AZs"                                    | Aurora                                            |
| 24| "5x performance do MySQL com HA automático"                                 | Aurora                                            |
| 25| "Connection pooling, Secrets Manager, VPC only"                             | RDS Proxy                                         |
| 26| "Custo previsível de I/O, workload I/O-intensivo"                           | Aurora I/O-Optimized                              |
| 27| "Failover < 35 segundos + readers servindo tráfego"                         | Multi-AZ DB Cluster                               |
| 28| "Consultar dados no S3 sem carregar no data warehouse"                      | Redshift Spectrum                                 |
| 29| "Read Replica para outra região, custo de rede"                             | Cross-Region cobra transferência; same-region free|
| 30| "Monitoramento com granularidade de 1 segundo, métricas OS"                 | Enhanced Monitoring                               |
| 31| "Identificar SQL lento, top queries"                                        | Performance Insights                              |
| 32| "Escalar reads para 15 réplicas com failover automático"                    | Aurora (até 15 replicas com auto-failover)        |

### 15.2 Dicas Rápidas para o Exame

```
┌─────────────────────────────────────────────────────────────────┐
│                    DICAS RÁPIDAS SAA-C03                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Multi-AZ = HA (disponibilidade)                             │
│     Read Replica = Performance (escalabilidade)                  │
│     NUNCA confunda os dois!                                      │
│                                                                  │
│  2. Aurora > RDS em quase todos os cenários de prova            │
│     (mais réplicas, mais rápido, storage distribuído)            │
│                                                                  │
│  3. Restore SEMPRE cria nova instância (novo endpoint)          │
│     Exceção: Aurora Backtrack (in-place)                         │
│                                                                  │
│  4. Encryption at rest: SOMENTE na criação                      │
│     Para encriptar existente: snapshot → copy → restore          │
│                                                                  │
│  5. RDS Proxy: Lambda + banco = SEMPRE mencionar Proxy          │
│                                                                  │
│  6. Aurora Global DB: cross-region < 1s lag                     │
│     Read Replica cross-region: lag pode ser maior               │
│                                                                  │
│  7. RDS Custom: Oracle/SQL Server + precisa de SSH              │
│                                                                  │
│  8. IAM Auth: MySQL, PostgreSQL, MariaDB (NÃO Oracle/MSSQL)    │
│                                                                  │
│  9. Reader Endpoint Aurora: balanceia CONEXÃO, não QUERY        │
│                                                                  │
│  10. Multi-AZ DB Cluster: failover ~35s + readers ativos        │
│      Multi-AZ clássico: failover ~1-2min + standby inativo      │
│                                                                  │
│  11. Para OLAP → Redshift (nunca RDS/Aurora)                    │
│                                                                  │
│  12. Custo de rede Read Replica:                                │
│      same-region = FREE | cross-region = PAGA                    │
│                                                                  │
│  13. Aurora Serverless v2: instantâneo, 0.5-128 ACUs            │
│      v1: pausável a zero mas com cold start de 30s              │
│                                                                  │
│  14. Enhanced Monitoring: métricas de OS (memory, processes)    │
│      CloudWatch padrão: métricas de hypervisor (CPU, disk)      │
│                                                                  │
│  15. Performance Insights: identifica SQL + wait events         │
│      (não confundir com CloudWatch)                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## Resumo Visual — Árvore de Decisão

```
                        Precisa de banco relacional na AWS?
                                     │
                          ┌──────────┼──────────┐
                          │          │          │
                        SIM        Talvez       NÃO
                          │          │          │
                          │          │          └─► DynamoDB, Neptune,
                          │          │              DocumentDB, etc.
                          │          │
                   Precisa de controle     Serverless?
                   total do OS?               │
                          │             ┌─────┴─────┐
                    ┌─────┴─────┐       SIM        NÃO
                    SIM        NÃO      │           │
                    │           │        │           │
                    ▼           │        ▼           ▼
               RDS Custom      │    Aurora       RDS / Aurora
               ou EC2          │    Serverless   Provisioned
                               │    v2
                               │
                        Precisa de alta
                        performance + HA?
                               │
                    ┌──────────┴──────────┐
                    SIM                   NÃO
                    │                      │
                    ▼                      ▼
                  Aurora              RDS Standard
              (até 15 replicas,      (MySQL, PostgreSQL,
               storage distribuído,   MariaDB, Oracle,
               auto-failover)         SQL Server, Db2)
```

---

*Documento atualizado em julho/2026 para a certificação AWS Solutions Architect Associate (SAA-C03).*
*Total de tópicos cobertos: 15 seções com profundidade adequada para o exame.*
