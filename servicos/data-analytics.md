# Data Analytics na AWS — Guia Completo para SAA-C03

> Documento de estudo aprofundado cobrindo todos os serviços de analytics cobrados na certificação AWS Solutions Architect Associate (SAA-C03).

---

## 1. Visão Geral — Quando Usar Cada Serviço

### 1.1 Tabela Comparativa Geral

| Serviço | Tipo | Modelo | Caso de Uso Principal |
|---------|------|--------|----------------------|
| Amazon Athena | Query Engine | Serverless | SQL ad-hoc sobre dados no S3 |
| Amazon Redshift | Data Warehouse | Provisionado/Serverless | OLAP, relatórios complexos, petabytes |
| Amazon OpenSearch | Search & Analytics | Managed Cluster | Full-text search, log analytics |
| Amazon EMR | Big Data Processing | Managed Cluster | Hadoop, Spark, Hive, ETL pesado |
| Amazon QuickSight | Business Intelligence | Serverless | Dashboards, visualizações, relatórios |
| AWS Glue | ETL + Catalog | Serverless | Transformação de dados, metastore |
| AWS Lake Formation | Data Lake Management | Serverless | Governança, controle de acesso fino |
| Amazon MSK | Streaming | Managed/Serverless | Kafka managed, streaming de eventos |
| Amazon Managed Flink | Stream Processing | Serverless | Processamento real-time (SQL/Flink) |
| S3 Storage Lens | Storage Analytics | Serverless | Métricas de uso do S3 |
| S3 Express One Zone | High-Perf Storage | Serverless | Latência single-digit ms |

### 1.2 Diagrama de Decisão

```
┌─────────────────────────────────────────────────────────────────┐
│                    PRECISO ANALISAR DADOS?                        │
└─────────────────────────┬───────────────────────────────────────┘
                          │
            ┌─────────────┼─────────────────┐
            ▼             ▼                 ▼
    [Ad-hoc SQL?]   [Warehouse?]    [Real-time?]
            │             │                 │
            ▼             ▼                 ▼
        Athena        Redshift      Kinesis/MSK + Flink
            │             │                 │
            │             │                 ▼
            │             │         [Precisa Kafka?]
            │             │          Sim → MSK
            │             │          Não → Kinesis
            │             │
            ▼             ▼
    [Precisa ETL?]  [Query S3 externo?]
     Sim → Glue     Sim → Redshift Spectrum
            │
            ▼
    [Data Lake gov?]
     Sim → Lake Formation
```

### 1.3 Categorização por Tipo de Workload

| Workload | Serviços Recomendados |
|----------|----------------------|
| Batch Analytics | Athena, Redshift, EMR |
| Real-time Analytics | Kinesis, MSK, Flink, OpenSearch |
| ETL/Transformação | Glue, EMR |
| Visualização/BI | QuickSight |
| Search/Logs | OpenSearch |
| Governança | Lake Formation, Glue Catalog |

---

## 2. Amazon Athena

### 2.1 O que é

Amazon Athena é um serviço de **query interativa serverless** que permite analisar dados diretamente no Amazon S3 usando SQL padrão. Baseado no motor **Presto** (agora Trino), não requer infraestrutura para gerenciar.

### 2.2 Características Principais

- **Serverless**: sem servidores para provisionar ou gerenciar
- **SQL padrão**: compatível com ANSI SQL (Presto/Trino engine)
- **Schema-on-read**: define schema na hora da consulta
- **Integração nativa com AWS Glue Data Catalog**
- **Suporta dados encriptados** (SSE-S3, SSE-KMS, CSE-KMS)
- **Pay-per-query**: cobra por TB de dados escaneados

### 2.3 Formatos de Dados Suportados

| Formato | Tipo | Compressão | Performance | Observações |
|---------|------|-----------|-------------|-------------|
| **Parquet** | Columnar | Snappy, GZIP, LZO | ⭐⭐⭐⭐⭐ | Melhor para Athena |
| **ORC** | Columnar | Zlib, Snappy | ⭐⭐⭐⭐⭐ | Otimizado para Hive |
| **CSV** | Row-based | GZIP, BZIP2 | ⭐⭐ | Comum mas ineficiente |
| **JSON** | Semi-structured | GZIP | ⭐⭐ | Flexível mas lento |
| **Avro** | Row-based | Snappy, Deflate | ⭐⭐⭐ | Bom para streaming |
| **TSV** | Row-based | GZIP | ⭐⭐ | Similar ao CSV |

### 2.4 Otimização de Performance e Custo

```
┌─────────────────────────────────────────────────────────┐
│          ESTRATÉGIAS DE OTIMIZAÇÃO DO ATHENA             │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. FORMATO COLUMNAR (Parquet/ORC)                      │
│     → Reduz dados escaneados em até 99%                 │
│     → Athena lê apenas colunas necessárias              │
│                                                         │
│  2. PARTICIONAMENTO                                     │
│     → s3://bucket/table/year=2024/month=01/day=15/      │
│     → WHERE year=2024 AND month=01 → skip partitions    │
│     → Reduz drasticamente o scan                        │
│                                                         │
│  3. COMPRESSÃO                                          │
│     → Snappy (padrão para Parquet): rápido              │
│     → GZIP: melhor ratio, mais lento                    │
│     → LZ4/ZSTD: balanço velocidade/ratio                │
│                                                         │
│  4. TAMANHO DOS ARQUIVOS                                │
│     → Ideal: 128 MB a 512 MB por arquivo                │
│     → Evitar muitos arquivos pequenos (overhead)        │
│     → Usar Glue ETL para consolidar                     │
│                                                         │
│  5. BUCKETING                                           │
│     → Agrupa dados por hash de coluna                   │
│     → Útil para JOINs frequentes                        │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 2.5 Particionamento Detalhado

```sql
-- Exemplo de tabela particionada no Athena
CREATE EXTERNAL TABLE logs (
    request_id STRING,
    ip_address STRING,
    status_code INT,
    response_time DOUBLE
)
PARTITIONED BY (year INT, month INT, day INT)
STORED AS PARQUET
LOCATION 's3://my-bucket/logs/'
TBLPROPERTIES ('parquet.compression'='SNAPPY');

-- Estrutura no S3:
-- s3://my-bucket/logs/year=2024/month=01/day=01/file1.parquet
-- s3://my-bucket/logs/year=2024/month=01/day=02/file2.parquet

-- Query otimizada (escaneia apenas partição específica):
SELECT * FROM logs
WHERE year = 2024 AND month = 1 AND day = 15;
```

### 2.6 Federated Queries

- Permite consultar dados em **outras fontes** além do S3
- Usa **Lambda connectors** (data source connectors)
- Fontes suportadas: RDS, DynamoDB, Redshift, HBase, CloudWatch, DocumentDB, etc.
- O connector roda como função Lambda
- Resultados são retornados ao Athena para processamento

```
┌──────────┐     ┌──────────┐     ┌──────────────┐
│  Athena  │────▶│  Lambda  │────▶│  RDS/DynamoDB │
│  (SQL)   │◀────│ Connector│◀────│  /Redshift    │
└──────────┘     └──────────┘     └──────────────┘
      │
      ▼
┌──────────┐
│ S3 (dados│
│ nativos) │
└──────────┘
```

### 2.7 Integração com Glue Catalog

- Athena usa o **AWS Glue Data Catalog** como metastore
- Glue Crawlers descobrem schema automaticamente
- Databases e tables definidos no Glue ficam disponíveis no Athena
- Compartilhamento de metadados com EMR e Redshift Spectrum

### 2.8 Pricing

| Item | Custo |
|------|-------|
| Queries | **$5.00 por TB escaneado** |
| Dados em formato columnar | Reduz custo em até 30-90% |
| Queries canceladas | Cobrado pelo volume já escaneado |
| DDL (CREATE, ALTER) | Gratuito |
| Queries com falha | Gratuito |

### 2.9 Casos de Uso para a Prova

- Análise ad-hoc de logs no S3
- Queries serverless sem gerenciar infraestrutura
- Análise de dados de cost and usage reports (CUR)
- Integração com QuickSight para dashboards
- Consultas em dados no S3 com custo mínimo

---

## 3. Amazon Redshift

### 3.1 O que é

Amazon Redshift é um **data warehouse** columnar, totalmente gerenciado, projetado para **OLAP** (Online Analytical Processing). Otimizado para queries analíticas complexas sobre grandes volumes de dados (petabytes).

### 3.2 Arquitetura do Cluster

```
┌─────────────────────────────────────────────────────────────┐
│                    REDSHIFT CLUSTER                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐                                        │
│  │   LEADER NODE   │  ← Recebe queries, planeja execução    │
│  │                 │  ← Agrega resultados                   │
│  │  (SQL endpoint) │  ← Não armazena dados do usuário       │
│  └────────┬────────┘                                        │
│           │                                                 │
│     ┌─────┼─────┬─────────┐                                 │
│     ▼     ▼     ▼         ▼                                 │
│  ┌─────┐┌─────┐┌─────┐┌─────┐                              │
│  │Comp.││Comp.││Comp.││Comp.│  ← Executam queries          │
│  │Node ││Node ││Node ││Node │  ← Armazenam dados           │
│  │ 1   ││ 2   ││ 3   ││ 4   │  ← Processamento paralelo   │
│  └─────┘└─────┘└─────┘└─────┘                              │
│                                                             │
│  Cada compute node tem: CPU, memória, disco local           │
│  Dados distribuídos entre nodes (slices)                    │
└─────────────────────────────────────────────────────────────┘
```

### 3.3 Tipos de Nodes

| Tipo | Subtipo | Armazenamento | Uso |
|------|---------|---------------|-----|
| **RA3** | ra3.xlplus, ra3.4xlarge, ra3.16xlarge | Managed Storage (S3) | Recomendado (separa compute/storage) |
| **DC2** | dc2.large, dc2.8xlarge | SSD local | Datasets < 1TB, baixa latência |
| **DS2** | ds2.xlarge, ds2.8xlarge | HDD | Legacy, não recomendado |

### 3.4 Redshift Spectrum

- Permite consultar dados **diretamente no S3** sem carregá-los no Redshift
- Usa compute nodes dedicados do Spectrum (separados do cluster)
- Compartilha o **Glue Data Catalog** com Athena
- Ideal para dados "frios" ou pouco consultados
- Combina dados do cluster (quentes) com dados do S3 (frios)

```
┌──────────────┐         ┌──────────────────┐
│   Redshift   │         │    S3 (dados     │
│   Cluster    │────────▶│    externos)     │
│  (hot data)  │         │                  │
└──────┬───────┘         └────────┬─────────┘
       │                          │
       │    ┌─────────────────┐   │
       └───▶│    Redshift     │◀──┘
            │    Spectrum     │
            │  (processing)   │
            └─────────────────┘
```

### 3.5 Redshift Serverless

- Sem necessidade de provisionar/gerenciar clusters
- Auto-scaling de capacidade
- Paga por RPU (Redshift Processing Units) consumidos
- Ideal para workloads intermitentes ou imprevisíveis
- Mesma SQL syntax do Redshift provisionado

### 3.6 Enhanced VPC Routing

- **Força todo o tráfego** COPY/UNLOAD a passar pela VPC
- Sem Enhanced VPC Routing: dados trafegam pela internet pública
- Com Enhanced VPC Routing: dados passam por VPC endpoints, NAT, etc.
- Permite usar **VPC Flow Logs** para monitorar tráfego
- Necessário para compliance e segurança

### 3.7 Snapshots

| Característica | Automated | Manual |
|---------------|-----------|--------|
| Frequência | A cada 8h ou 5GB de mudanças | Sob demanda |
| Retenção | 1 a 35 dias (configurável) | Até ser deletado manualmente |
| Cross-region | Configurável | Sim, via copy |
| Custo | Incluído (dentro da retenção) | Cobrado separadamente |
| Restore | Novo cluster | Novo cluster |

### 3.8 Redshift vs RDS — OLAP vs OLTP

| Aspecto | Amazon Redshift (OLAP) | Amazon RDS (OLTP) |
|---------|----------------------|-------------------|
| **Propósito** | Análise, relatórios, BI | Transações, CRUD |
| **Storage** | Columnar | Row-based |
| **Queries** | Complexas, agregações | Simples, ponto |
| **Volume** | Petabytes | Terabytes |
| **Joins** | Otimizado para muitos JOINs | Poucos JOINs |
| **Concorrência** | Centenas de queries analíticas | Milhares de transações |
| **Latência** | Segundos (queries complexas) | Milissegundos |
| **Índices** | Zone maps, sort keys | B-tree, hash |
| **Caso de uso** | Data warehouse, BI | App backend, e-commerce |

### 3.9 Concurrency Scaling

- Adiciona **clusters temporários** automaticamente quando a demanda aumenta
- Escala leitura (queries) de forma transparente
- Cada cluster recebe **1 hora grátis por dia** de concurrency scaling
- Queries são roteadas automaticamente para clusters adicionais
- Sem mudança na aplicação

### 3.10 Outras Funcionalidades Importantes

- **Workload Management (WLM)**: prioriza queries por filas
- **Sort Keys**: ordenação física dos dados no disco (compound/interleaved)
- **Distribution Styles**: EVEN, KEY, ALL, AUTO
- **Columnar compression**: encoding automático por coluna
- **Materialized Views**: pré-computa resultados
- **Data Sharing**: compartilha dados entre clusters sem copiar

---

## 4. Amazon OpenSearch Service (ex-ElasticSearch)

### 4.1 O que é

Amazon OpenSearch Service é um serviço gerenciado para **busca, análise e visualização** de dados em tempo real. Sucessor do Amazon Elasticsearch Service, baseado no projeto open-source OpenSearch.

### 4.2 Características Principais

- **Full-text search**: busca textual com relevância
- **Log analytics**: análise de logs em tempo real
- **OpenSearch Dashboards** (ex-Kibana): visualização integrada
- **Managed cluster**: AWS gerencia patches, backups, monitoring
- **Multi-AZ**: alta disponibilidade (2 ou 3 AZs)
- **Encryption**: at-rest (KMS) e in-transit (TLS)
- **Fine-grained access control**: nível de índice, documento, campo

### 4.3 Arquitetura do Cluster

```
┌─────────────────────────────────────────────────────────┐
│              OPENSEARCH DOMAIN (CLUSTER)                  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │  Data Node  │  │  Data Node  │  │  Data Node  │    │
│  │    (AZ-a)   │  │    (AZ-b)   │  │    (AZ-c)   │    │
│  │  Primary    │  │  Replica    │  │  Replica    │    │
│  │  Shards     │  │  Shards     │  │  Shards     │    │
│  └─────────────┘  └─────────────┘  └─────────────┘    │
│                                                         │
│  ┌─────────────┐  ┌─────────────┐                      │
│  │ Master Node │  │ Master Node │  ← Dedicated master  │
│  │ (dedicated) │  │ (dedicated) │    nodes (3 recom.)  │
│  └─────────────┘  └─────────────┘                      │
│                                                         │
│  ┌─────────────────────────────────┐                    │
│  │   UltraWarm Nodes (opcional)    │  ← Dados mornos   │
│  │   (S3-backed, custo menor)      │    (read-only)    │
│  └─────────────────────────────────┘                    │
│                                                         │
│  ┌─────────────────────────────────┐                    │
│  │   Cold Storage (opcional)       │  ← Dados frios    │
│  │   (S3, custo mínimo)            │    (detach/attach)│
│  └─────────────────────────────────┘                    │
└─────────────────────────────────────────────────────────┘
```

### 4.4 Padrões de Integração (Muito Cobrados na Prova)

```
PADRÃO 1: CloudWatch Logs → OpenSearch
─────────────────────────────────────────
CloudWatch Logs → Subscription Filter → Lambda → OpenSearch
                                                      │
                                                      ▼
                                              OpenSearch Dashboards

PADRÃO 2: Kinesis → OpenSearch
─────────────────────────────────────────
Kinesis Data Streams → Kinesis Data Firehose → OpenSearch
        │
        └── (buffer, transform, delivery)

PADRÃO 3: DynamoDB → OpenSearch
─────────────────────────────────────────
DynamoDB → DynamoDB Streams → Lambda → OpenSearch

PADRÃO 4: S3 → OpenSearch
─────────────────────────────────────────
S3 → Event Notification → Lambda → OpenSearch
```

### 4.5 Multi-AZ e Alta Disponibilidade

| Configuração | AZs | Replicas | Uso |
|-------------|-----|----------|-----|
| Sem Multi-AZ | 1 | 0 | Dev/test |
| 2-AZ | 2 | 1 por shard | Produção básica |
| 3-AZ | 3 | 2 por shard | Produção crítica |

- **Dedicated master nodes**: mínimo 3 para quórum
- **Zone awareness**: distribui shards entre AZs
- **Automated snapshots**: para S3 (retenção 14 dias)

### 4.6 Casos de Uso para a Prova

- Busca textual em aplicações (e-commerce, documentos)
- Análise de logs (CloudWatch, aplicações, VPC Flow Logs)
- Monitoramento de segurança (SIEM)
- Observabilidade (traces, métricas, logs)
- **NÃO é substituto para data warehouse** (usar Redshift)

---

## 5. Amazon EMR (Elastic MapReduce)

### 5.1 O que é

Amazon EMR é um serviço gerenciado de **big data** que facilita a execução de frameworks como Apache Hadoop, Spark, Hive, HBase, Presto e Flink em clusters escaláveis.

### 5.2 Arquitetura do Cluster

```
┌─────────────────────────────────────────────────────────────┐
│                      EMR CLUSTER                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌───────────────────┐                                      │
│  │   MASTER NODE     │  ← Coordena o cluster               │
│  │   (Primary Node)  │  ← Executa YARN ResourceManager     │
│  │                   │  ← NameNode do HDFS                  │
│  │   [On-Demand]     │  ← NUNCA usar Spot (crítico)        │
│  └─────────┬─────────┘                                      │
│            │                                                │
│     ┌──────┼──────┐                                         │
│     ▼      ▼      ▼                                         │
│  ┌──────┐┌──────┐┌──────┐                                  │
│  │ CORE ││ CORE ││ CORE │  ← Armazenam dados (HDFS)       │
│  │ NODE ││ NODE ││ NODE │  ← Executam tasks                │
│  │      ││      ││      │  ← On-Demand (dados críticos)    │
│  └──────┘└──────┘└──────┘                                  │
│                                                             │
│  ┌──────┐┌──────┐┌──────┐┌──────┐                          │
│  │ TASK ││ TASK ││ TASK ││ TASK │  ← Apenas processamento  │
│  │ NODE ││ NODE ││ NODE ││ NODE │  ← SEM armazenamento     │
│  │      ││      ││      ││      │  ← IDEAL para Spot ⭐    │
│  └──────┘└──────┘└──────┘└──────┘                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 5.3 Tipos de Nodes

| Node Type | Função | Spot? | Quantidade |
|-----------|--------|-------|-----------|
| **Master (Primary)** | Coordena cluster, YARN, NameNode | ❌ Nunca | 1 (ou 3 para HA) |
| **Core** | HDFS + processamento | ⚠️ Com cuidado | 1+ |
| **Task** | Apenas processamento | ✅ Ideal | 0+ (auto-scaling) |

### 5.4 Instâncias Spot para Task Nodes

- **Task nodes são ideais para Spot** porque:
  - Não armazenam dados HDFS
  - Perda de um task node não causa perda de dados
  - Cluster continua funcionando com menos capacidade
  - Economia de até 90% vs On-Demand
- **Core nodes com Spot**: risco de perda de dados HDFS
- **Master node**: SEMPRE On-Demand

### 5.5 Modos de Implantação

| Modo | Descrição | Uso |
|------|-----------|-----|
| **Cluster (Long-running)** | Cluster sempre ativo | Workloads contínuos |
| **Step execution (Transient)** | Cluster encerra após steps | ETL batch, economia |

### 5.6 Storage Options

| Storage | Tipo | Persistência | Performance |
|---------|------|-------------|-------------|
| HDFS | Local ao cluster | Perde ao terminar | Alta (local) |
| EMRFS (S3) | Externo | Persistente | Boa (rede) |
| EBS | Block storage | Configurável | Alta |

### 5.7 Casos de Uso para a Prova

- Processamento de big data (Spark, MapReduce)
- ETL em grande escala
- Machine Learning (Spark MLlib)
- Análise de logs em grande volume
- Processamento de dados genômicos
- **Quando o cenário menciona Hadoop/Spark → EMR**
- **Quando menciona Spot instances para processamento → Task nodes**

---

## 6. Amazon QuickSight

### 6.1 O que é

Amazon QuickSight é um serviço de **Business Intelligence (BI) serverless** e escalável que permite criar dashboards interativos, relatórios e análises visuais.

### 6.2 Características Principais

- **Serverless**: sem infraestrutura para gerenciar
- **SPICE Engine**: Super-fast, Parallel, In-memory Calculation Engine
- **Pay-per-session**: cobra por sessão de uso
- **Machine Learning Insights**: detecção de anomalias, forecasting
- **Embedded analytics**: incorporar dashboards em aplicações
- **Multi-tenant**: suporta múltiplos namespaces

### 6.3 SPICE Engine

```
┌─────────────────────────────────────────────────────┐
│                 SPICE ENGINE                          │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌─────────────┐       ┌──────────────────┐        │
│  │ Data Source │──────▶│ SPICE (in-memory)│        │
│  │  (import)   │       │  - Columnar       │        │
│  └─────────────┘       │  - Compressed     │        │
│                         │  - Auto-replicated│        │
│  Capacidade:            │  - Super-fast     │        │
│  - Standard: 10GB/user  └────────┬─────────┘        │
│  - Enterprise: 10GB/user          │                  │
│                                   ▼                  │
│                          ┌───────────────┐           │
│                          │  Dashboards   │           │
│                          │  & Analyses   │           │
│                          └───────────────┘           │
└─────────────────────────────────────────────────────┘
```

### 6.4 Data Sources Suportados

| Categoria | Fontes |
|-----------|--------|
| **AWS** | Athena, Redshift, RDS, Aurora, S3, OpenSearch, Timestream |
| **On-premises** | SQL Server, MySQL, PostgreSQL (via Direct Connect) |
| **SaaS** | Salesforce, Jira, GitHub, Twitter |
| **Files** | CSV, TSV, JSON, Excel (upload para SPICE) |
| **Outros** | JDBC/ODBC genérico |

### 6.5 Modos de Acesso aos Dados

| Modo | Descrição | Quando Usar |
|------|-----------|-------------|
| **Import (SPICE)** | Dados copiados para memória | Melhor performance, dados não mudam frequentemente |
| **Direct Query** | Query em tempo real na fonte | Dados mudam constantemente, sem SPICE |

### 6.6 Segurança e Compartilhamento

- **Row-Level Security (RLS)**: restringe linhas por usuário/grupo
- **Column-Level Security (CLS)**: restringe colunas (Enterprise)
- **IAM + QuickSight users/groups**
- **VPC connectivity**: acessa fontes em VPCs privadas
- **Sharing**: dashboards compartilhados com usuários/grupos

### 6.7 Casos de Uso para a Prova

- Visualização de dados sobre Athena, Redshift, S3
- Dashboards serverless com custo por sessão
- Quando mencionar "BI" ou "dashboard" → QuickSight
- Embedded analytics em aplicações web
- ML Insights para detecção de anomalias em métricas

---

## 7. AWS Glue

### 7.1 O que é

AWS Glue é um serviço de **ETL (Extract, Transform, Load) serverless** que facilita a descoberta, preparação e combinação de dados para analytics, ML e desenvolvimento de aplicações.

### 7.2 Componentes do AWS Glue

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWS GLUE                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌────────────────────────────────────────┐                     │
│  │         GLUE DATA CATALOG              │  ← Metastore Central│
│  │  ┌──────────┐  ┌──────────┐           │                     │
│  │  │ Databases│  │  Tables  │           │  Usado por:         │
│  │  │          │  │ (schema) │           │  - Athena           │
│  │  └──────────┘  └──────────┘           │  - Redshift Spectrum│
│  │  ┌──────────┐  ┌──────────┐           │  - EMR              │
│  │  │Partitions│  │Connections│           │  - Lake Formation   │
│  │  └──────────┘  └──────────┘           │                     │
│  └────────────────────────────────────────┘                     │
│                                                                 │
│  ┌──────────────────┐   ┌──────────────────┐                   │
│  │   GLUE CRAWLERS  │   │   GLUE JOBS      │                   │
│  │                  │   │                  │                   │
│  │ - Conecta a data │   │ - Apache Spark   │                   │
│  │   sources        │   │ - Python Shell   │                   │
│  │ - Detecta schema │   │ - Scala/Python   │                   │
│  │ - Popula Catalog │   │ - Serverless     │                   │
│  │ - Agenda (cron)  │   │ - Auto-scaling   │                   │
│  └──────────────────┘   └──────────────────┘                   │
│                                                                 │
│  ┌──────────────────┐   ┌──────────────────┐                   │
│  │   GLUE STUDIO    │   │  GLUE DATABREW   │                   │
│  │                  │   │                  │                   │
│  │ - Visual ETL     │   │ - Data prep sem  │                   │
│  │ - Drag & drop    │   │   código         │                   │
│  │ - DAG editor     │   │ - 250+ transforms│                   │
│  │ - Monitoring     │   │ - Profiling      │                   │
│  └──────────────────┘   └──────────────────┘                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 7.3 Glue Data Catalog — Metastore Central

- **Repositório centralizado de metadados**
- Contém: databases, tables, schemas, partitions, connections
- **Compatível com Apache Hive metastore**
- Usado automaticamente por Athena, Redshift Spectrum, EMR
- **Uma conta AWS tem um Glue Data Catalog por região**
- Pode ser compartilhado cross-account via Resource Policies

### 7.4 Glue Crawlers

| Aspecto | Detalhe |
|---------|---------|
| Função | Descobre schema automaticamente |
| Fontes | S3, DynamoDB, JDBC (RDS, Redshift) |
| Output | Tabelas no Glue Data Catalog |
| Agendamento | Cron, on-demand, evento |
| Classificadores | JSON, CSV, Parquet, Avro, ORC, customizados |
| Partições | Detecta automaticamente |

### 7.5 Glue Jobs

- **Spark ETL**: processamento distribuído (Python/Scala)
- **Python Shell**: scripts leves, sem Spark
- **Streaming ETL**: processamento de streams (Kafka, Kinesis)
- **DPU (Data Processing Unit)**: unidade de capacidade (4 vCPU, 16GB RAM)
- **Job bookmarks**: evita reprocessar dados já processados
- **Auto-scaling**: ajusta DPUs automaticamente

### 7.6 Glue Studio

- Interface **visual drag-and-drop** para criar ETL jobs
- Gera código Spark automaticamente
- Editor de DAG (Directed Acyclic Graph)
- Monitoramento integrado de execuções
- Ideal para usuários não-técnicos

### 7.7 Glue DataBrew

- **Preparação de dados visual** sem escrever código
- 250+ transformações pré-construídas
- **Data profiling**: estatísticas, qualidade, distribuição
- Recipes (receitas) reutilizáveis
- Integra com S3, Redshift, RDS, Glue Catalog

### 7.8 Casos de Uso para a Prova

- **"Descoberta automática de schema"** → Glue Crawlers
- **"ETL serverless"** → Glue Jobs
- **"Catálogo central de metadados"** → Glue Data Catalog
- **"Converter CSV para Parquet"** → Glue ETL Job
- **"Preparar dados sem código"** → Glue DataBrew

---

## 8. AWS Lake Formation

### 8.1 O que é

AWS Lake Formation é um serviço que facilita a **construção, segurança e gerenciamento** de um data lake centralizado sobre o Amazon S3 em dias ao invés de meses.

### 8.2 Funcionalidades Principais

```
┌─────────────────────────────────────────────────────────────┐
│                   AWS LAKE FORMATION                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              DATA LAKE (Amazon S3)                   │    │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐  │    │
│  │  │ Raw     │ │ Cleaned │ │Curated  │ │Aggregated│  │    │
│  │  │ Zone    │ │ Zone    │ │ Zone    │ │ Zone    │  │    │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘  │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  ┌─────────────────────────────────────┐                    │
│  │     FINE-GRAINED ACCESS CONTROL     │                    │
│  │  - Table-level permissions          │                    │
│  │  - Column-level permissions         │                    │
│  │  - Row-level security (data filters)│                    │
│  │  - Cell-level security              │                    │
│  │  - Tag-based access control (LF-TBAC)│                   │
│  └─────────────────────────────────────┘                    │
│                                                             │
│  ┌─────────────────────────────────────┐                    │
│  │      BLUEPRINTS & WORKFLOWS         │                    │
│  │  - Ingestão automatizada            │                    │
│  │  - Database → Data Lake             │                    │
│  │  - Log → Data Lake                  │                    │
│  └─────────────────────────────────────┘                    │
│                                                             │
│  ┌─────────────────────────────────────┐                    │
│  │      CROSS-ACCOUNT SHARING          │                    │
│  │  - Compartilha tabelas/databases    │                    │
│  │  - Sem copiar dados                 │                    │
│  │  - Controle centralizado            │                    │
│  └─────────────────────────────────────┘                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 8.3 Fine-Grained Access Control

| Nível | Descrição | Exemplo |
|-------|-----------|---------|
| **Database** | Acesso ao database inteiro | Analista acessa db_vendas |
| **Table** | Acesso a tabelas específicas | Usuário vê apenas tabela_clientes |
| **Column** | Acesso a colunas específicas | Marketing não vê coluna CPF |
| **Row** | Filtro de linhas por condição | Regional vê apenas região Sul |
| **Cell** | Combinação de row + column | Mais restritivo possível |
| **Tag-based (LF-TBAC)** | Tags classificam recursos | Tag "PII=true" → acesso restrito |

### 8.4 Integração com Glue

- Lake Formation **usa o Glue Data Catalog** internamente
- Adiciona camada de **permissões** sobre o Catalog
- Glue Crawlers populam o Catalog, Lake Formation controla acesso
- Quando Lake Formation está ativo, permissões do Glue Catalog são gerenciadas por ele

### 8.5 Cross-Account Sharing

- Compartilha tabelas e databases entre contas AWS
- **Sem necessidade de copiar dados** (dados permanecem na conta origem)
- Usa **AWS RAM (Resource Access Manager)** ou grants diretos
- Conta consumidora cria resource link no seu Catalog local
- Permissões controladas centralmente na conta produtora

### 8.6 Lake Formation vs Glue vs S3 Policies

| Aspecto | Lake Formation | Glue Catalog | S3 Bucket Policy |
|---------|---------------|-------------|-----------------|
| Granularidade | Cell-level | Table-level | Prefix/object |
| Centralização | ✅ Centralizado | Parcial | ❌ Descentralizado |
| Cross-account | ✅ Nativo | Possível | Possível |
| Facilidade | ✅ Alto nível | Médio | Baixo nível |
| Row-level | ✅ Sim | ❌ Não | ❌ Não |

### 8.7 Casos de Uso para a Prova

- **"Data lake com controle de acesso fino"** → Lake Formation
- **"Compartilhar dados entre contas sem copiar"** → Lake Formation cross-account
- **"Restringir acesso por coluna/linha"** → Lake Formation fine-grained
- **"Construir data lake rapidamente"** → Lake Formation Blueprints
- **"Governança centralizada de data lake"** → Lake Formation

---

## 9. Amazon MSK (Managed Streaming for Apache Kafka)

### 9.1 O que é

Amazon MSK é um serviço **totalmente gerenciado** para executar Apache Kafka sem gerenciar infraestrutura. Mantém clusters Kafka altamente disponíveis.

### 9.2 Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                     MSK CLUSTER                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  VPC                                                        │
│  ┌───────────────────────────────────────────────────┐      │
│  │                                                   │      │
│  │   AZ-a            AZ-b            AZ-c           │      │
│  │  ┌─────────┐    ┌─────────┐    ┌─────────┐     │      │
│  │  │ Broker  │    │ Broker  │    │ Broker  │     │      │
│  │  │  Node 1 │    │  Node 2 │    │  Node 3 │     │      │
│  │  └─────────┘    └─────────┘    └─────────┘     │      │
│  │                                                   │      │
│  │  ┌─────────┐    ┌─────────┐    ┌─────────┐     │      │
│  │  │ZooKeeper│    │ZooKeeper│    │ZooKeeper│     │      │
│  │  │  Node   │    │  Node   │    │  Node   │     │      │
│  │  └─────────┘    └─────────┘    └─────────┘     │      │
│  │                                                   │      │
│  └───────────────────────────────────────────────────┘      │
│                                                             │
│  Storage: EBS (provisioned ou auto-expanding)               │
│  Replication: configurable (default 3 replicas)             │
│  Encryption: TLS in-transit, KMS at-rest                    │
└─────────────────────────────────────────────────────────────┘
```

### 9.3 MSK Serverless

- **Sem gerenciar capacidade** (brokers, storage)
- Auto-scaling automático
- Paga por throughput e storage utilizados
- Ideal para workloads variáveis ou imprevisíveis
- Compatível com Apache Kafka APIs

### 9.4 MSK Connect

- **Connectors gerenciados** para Apache Kafka Connect
- Conecta Kafka a fontes/destinos externos automaticamente
- Exemplos: S3 Sink, Elasticsearch Sink, Debezium Source (CDC)
- Auto-scaling de workers
- Sem gerenciar infraestrutura de Connect

### 9.5 MSK vs Kinesis Data Streams — Tabela Comparativa

| Aspecto | Amazon MSK | Kinesis Data Streams |
|---------|-----------|---------------------|
| **Protocolo** | Apache Kafka (open-source) | Proprietário AWS |
| **Message size** | 1 MB (default), até 10 MB | 1 MB (máximo) |
| **Retenção** | Ilimitada (EBS) | 1 a 365 dias |
| **Throughput** | Configurável por broker | Por shard (1 MB/s in, 2 MB/s out) |
| **Partições** | Topics + Partitions | Streams + Shards |
| **Consumers** | Consumer Groups (qualquer) | KCL, Lambda, Flink |
| **Ordering** | Por partition | Por shard |
| **Serverless** | MSK Serverless | On-demand mode |
| **Ecossistema** | Kafka Connect, Schema Registry | AWS integrations nativas |
| **Custo** | Broker instances + storage | Por shard-hora + PUT payload |
| **Multi-AZ** | 2 ou 3 AZs | 3 AZs (automático) |
| **Vendor lock-in** | Baixo (Kafka é open-source) | Alto (AWS proprietário) |
| **Quando usar** | Já usa Kafka, precisa migrar | Novo projeto, simples, integra AWS |

### 9.6 Casos de Uso para a Prova

- **"Migrar Kafka on-premises para AWS"** → MSK
- **"Streaming com Apache Kafka managed"** → MSK
- **"Conectar Kafka a S3/OpenSearch automaticamente"** → MSK Connect
- **"Streaming serverless com Kafka"** → MSK Serverless
- **"Streaming simples e nativo AWS"** → Kinesis Data Streams

---

## 10. Amazon Managed Service for Apache Flink (ex-Kinesis Data Analytics)

### 10.1 O que é

Serviço gerenciado para processar e analisar **dados de streaming em tempo real** usando Apache Flink. Anteriormente chamado Amazon Kinesis Data Analytics.

### 10.2 Modos de Operação

| Modo | Descrição | Quando Usar |
|------|-----------|-------------|
| **Apache Flink (Java/Scala/Python)** | Aplicação Flink completa | Lógica complexa, stateful processing |
| **Apache Flink Studio (Notebooks)** | Desenvolvimento interativo | Exploração, prototipagem |

### 10.3 Fontes e Destinos

```
        FONTES (Input)                    DESTINOS (Output)
┌──────────────────────┐          ┌──────────────────────────┐
│ - Kinesis Data       │          │ - Kinesis Data Streams   │
│   Streams            │          │ - Kinesis Data Firehose  │
│ - Amazon MSK         │──────────│ - Amazon S3              │
│ - Custom sources     │  Apache  │ - Amazon OpenSearch      │
│                      │  Flink   │ - DynamoDB               │
│                      │          │ - Custom sinks           │
└──────────────────────┘          └──────────────────────────┘
```

### 10.4 Características Principais

- **Serverless**: auto-scaling de KPUs (Kinesis Processing Units)
- **Exactly-once processing**: garantia de processamento (com checkpoints)
- **Stateful processing**: mantém estado entre eventos
- **Windowing**: tumbling, sliding, session windows
- **Checkpointing**: tolerância a falhas automática
- **Parallelism**: escalável horizontalmente

### 10.5 Casos de Uso

- Transformações em tempo real de streams
- Agregações em janelas de tempo (ex: contagem por minuto)
- Detecção de anomalias em real-time
- ETL streaming (enriquecimento de dados)
- Dashboards em tempo real

### 10.6 Casos de Uso para a Prova

- **"Processar streaming em tempo real com SQL"** → Managed Flink
- **"Análise real-time sobre Kinesis"** → Managed Flink
- **"Agregações em janelas de tempo"** → Managed Flink (windowing)
- **"Apache Flink managed"** → Amazon Managed Service for Apache Flink

---

## 11. Big Data Ingestion Pipeline — Arquitetura de Referência

### 11.1 Pipeline Completo (IoT → Analytics)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                  BIG DATA INGESTION PIPELINE                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  INGESTÃO          PROCESSAMENTO        ARMAZENAMENTO      CONSUMO     │
│                                                                         │
│  ┌──────┐         ┌──────────┐         ┌─────────┐      ┌──────────┐  │
│  │ IoT  │────────▶│ Kinesis  │────────▶│   S3    │─────▶│  Athena  │  │
│  │Devices│  MQTT   │  Data    │         │ (Raw)   │      │  (SQL)   │  │
│  └──────┘  via     │ Streams  │         └────┬────┘      └──────────┘  │
│            IoT     └────┬─────┘              │                         │
│            Core         │                    ▼                          │
│            Rule         │           ┌──────────────┐     ┌──────────┐  │
│                         │           │  Glue ETL    │────▶│ Redshift │  │
│                         │           │ (transform)  │     │(warehouse)│  │
│                         ▼           └──────┬───────┘     └──────────┘  │
│                   ┌───────────┐            │                           │
│                   │  Flink    │            ▼             ┌──────────┐  │
│                   │(real-time)│     ┌─────────────┐     │QuickSight│  │
│                   └─────┬─────┘     │ S3 (Curated)│────▶│   (BI)   │  │
│                         │           │  Parquet     │     └──────────┘  │
│                         ▼           └─────────────┘                    │
│                   ┌───────────┐                                        │
│                   │ OpenSearch│  ← Real-time dashboards                │
│                   │(monitoring)│                                        │
│                   └───────────┘                                        │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 11.2 Camadas da Arquitetura

| Camada | Serviços | Função |
|--------|----------|--------|
| **Ingestão** | IoT Core, Kinesis, MSK, Firehose | Capturar dados em tempo real |
| **Armazenamento Raw** | S3 (raw zone) | Armazenar dados brutos |
| **Processamento** | Glue ETL, EMR, Flink, Lambda | Transformar e enriquecer |
| **Armazenamento Curado** | S3 (curated zone, Parquet) | Dados prontos para análise |
| **Catalogação** | Glue Catalog, Lake Formation | Metadados e governança |
| **Consumo** | Athena, Redshift, QuickSight | Queries e visualizações |
| **Real-time** | OpenSearch, Flink | Monitoramento ao vivo |

### 11.3 Padrão Serverless Completo

```
IoT Core → Kinesis Data Streams → Kinesis Data Firehose → S3
                                         │
                                         ├── Transform: Lambda (leve)
                                         └── Formato: Parquet (via Firehose conversion)
                                                          │
                                                          ▼
                                              Glue Crawler (schema discovery)
                                                          │
                                                          ▼
                                              Glue Data Catalog (metastore)
                                                          │
                                              ┌───────────┼───────────┐
                                              ▼           ▼           ▼
                                          Athena     Redshift     QuickSight
                                                     Spectrum
```

### 11.4 Considerações de Design para a Prova

- **Serverless**: minimiza custo operacional
- **Firehose converte para Parquet**: otimiza queries Athena
- **S3 como data lake central**: durabilidade, custo baixo
- **Glue Catalog**: metastore compartilhado
- **Separação de zonas**: raw → cleaned → curated
- **Kinesis para real-time, S3 para batch**

---

## 12. S3 Storage Lens

### 12.1 O que é

Amazon S3 Storage Lens fornece **métricas e recomendações** sobre o uso e atividade de armazenamento do S3 em toda a organização.

### 12.2 Características

```
┌─────────────────────────────────────────────────────────┐
│                 S3 STORAGE LENS                           │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ESCOPO:                                                │
│  ┌─────────────────────────────────────────┐            │
│  │ Organization → Accounts → Regions →     │            │
│  │ Buckets → Prefixes                      │            │
│  └─────────────────────────────────────────┘            │
│                                                         │
│  MÉTRICAS:                                              │
│  ┌─────────────────┐  ┌──────────────────┐             │
│  │ Free Metrics    │  │ Advanced Metrics │             │
│  │ (28 métricas)   │  │ (35+ métricas)   │             │
│  │ - 14 dias hist. │  │ - 15 meses hist. │             │
│  │ - Summary       │  │ - Activity       │             │
│  │ - Data protect. │  │ - Prefix-level   │             │
│  │ - Storage class │  │ - Recommendations│             │
│  └─────────────────┘  │ - CloudWatch pub.│             │
│                        └──────────────────┘             │
│                                                         │
│  DASHBOARD:                                             │
│  - Default dashboard (gratuito, todas as contas)        │
│  - Custom dashboards (filtros específicos)              │
│  - Export para S3 (CSV, Parquet)                        │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 12.3 Tipos de Métricas

| Categoria | Exemplos | Tier |
|-----------|----------|------|
| **Summary** | Total storage, object count | Free |
| **Cost Optimization** | Incomplete multipart uploads, non-current versions | Free |
| **Data Protection** | Versioning, replication status | Free |
| **Access Management** | Bucket policy, ACLs | Free |
| **Activity** | GET/PUT requests, bytes downloaded | Advanced (pago) |
| **Detailed Status Codes** | 4xx, 5xx errors | Advanced (pago) |

### 12.4 Casos de Uso para a Prova

- **"Visibilidade do uso de S3 na organização"** → Storage Lens
- **"Recomendações de otimização de custo do S3"** → Storage Lens Advanced
- **"Métricas de S3 cross-account"** → Storage Lens Organization-level
- **"Identificar buckets sem versionamento"** → Storage Lens Data Protection

---

## 13. S3 Express One Zone

### 13.1 O que é

S3 Express One Zone é uma **storage class de altíssima performance** projetada para aplicações que exigem latência consistente de **milissegundos de um dígito** (single-digit milliseconds).

### 13.2 Características Principais

| Característica | Detalhe |
|---------------|---------|
| **Latência** | Single-digit milliseconds (< 10 ms) |
| **Throughput** | Até 10x mais rápido que S3 Standard |
| **Durabilidade** | 99.95% (single AZ — menor que Standard) |
| **AZs** | Single-AZ (dados em 1 AZ apenas) |
| **Bucket Type** | Directory Buckets (não general purpose) |
| **Naming** | bucket-name--az-id--x-s3 |
| **Acesso** | Via S3 API com endpoint zonal |
| **Autenticação** | CreateSession API (session-based) |
| **Custo Storage** | Mais caro que Standard |
| **Custo Requests** | 50% mais barato que Standard |

### 13.3 Directory Buckets vs General Purpose Buckets

| Aspecto | Directory Bucket (Express One Zone) | General Purpose Bucket |
|---------|-------------------------------------|----------------------|
| **Tipo** | Flat namespace com prefixos | Flat namespace |
| **Storage classes** | Apenas Express One Zone | Standard, IA, Glacier, etc. |
| **AZ** | Single AZ (específica) | Multi-AZ automático |
| **Naming** | nome--azid--x-s3 | nome (global) |
| **Versionamento** | Não suportado | Suportado |
| **Lifecycle** | Não suportado | Suportado |
| **Replicação** | Não suportado | Suportado |
| **Eventos** | Não suportado | Suportado |

### 13.4 Quando Usar

- ML training com dados frequentemente acessados
- Computação de alta performance (HPC)
- Analytics interativos com latência crítica
- Modelagem financeira em tempo real
- Processamento de mídia
- **Dados que precisam estar co-localizados com compute**

### 13.5 Casos de Uso para a Prova

- **"Latência de milissegundos no S3"** → S3 Express One Zone
- **"Armazenamento de altíssima performance no S3"** → S3 Express One Zone
- **"Directory buckets"** → S3 Express One Zone
- **"Single-AZ storage class"** → S3 Express One Zone (trade-off: durabilidade menor)
- **NÃO usar quando**: precisa de alta durabilidade multi-AZ, versionamento, lifecycle

---

## 14. Palavras-Chave da Prova SAA-C03 — Cenários e Respostas

### 14.1 Tabela de Cenários (Mínimo 20)

| # | Palavra-chave / Cenário na Prova | Resposta |
|---|----------------------------------|----------|
| 1 | "Consultar dados no S3 com SQL sem gerenciar servidores" | **Amazon Athena** |
| 2 | "Reduzir custo das queries Athena" | **Converter para Parquet + particionar + comprimir** |
| 3 | "Data warehouse para relatórios analíticos complexos" | **Amazon Redshift** |
| 4 | "Consultar dados no S3 a partir do Redshift sem copiar" | **Redshift Spectrum** |
| 5 | "Full-text search em aplicação web" | **Amazon OpenSearch** |
| 6 | "Analisar CloudWatch Logs com busca e dashboards" | **CloudWatch → OpenSearch** |
| 7 | "Processar big data com Hadoop/Spark" | **Amazon EMR** |
| 8 | "Usar Spot instances para processamento distribuído" | **EMR Task Nodes com Spot** |
| 9 | "Criar dashboards e visualizações serverless" | **Amazon QuickSight** |
| 10 | "ETL serverless para transformar dados" | **AWS Glue Jobs** |
| 11 | "Descobrir schema de dados no S3 automaticamente" | **AWS Glue Crawlers** |
| 12 | "Catálogo central de metadados para Athena e Redshift" | **AWS Glue Data Catalog** |
| 13 | "Data lake com controle de acesso por coluna" | **AWS Lake Formation** |
| 14 | "Compartilhar tabelas entre contas AWS sem copiar dados" | **Lake Formation cross-account** |
| 15 | "Streaming de dados com Apache Kafka gerenciado" | **Amazon MSK** |
| 16 | "Migrar Kafka on-premises para AWS" | **Amazon MSK** |
| 17 | "Processar streaming em tempo real com janelas de tempo" | **Amazon Managed Service for Apache Flink** |
| 18 | "Pipeline IoT → processamento → data lake → analytics" | **IoT Core → Kinesis → S3 → Glue → Athena** |
| 19 | "Métricas e recomendações de uso do S3 na organização" | **S3 Storage Lens** |
| 20 | "Armazenamento S3 com latência de milissegundos" | **S3 Express One Zone** |
| 21 | "OLAP vs OLTP" | **Redshift (OLAP) vs RDS/Aurora (OLTP)** |
| 22 | "Converter CSV para formato columnar no S3" | **AWS Glue ETL Job** ou **Kinesis Firehose com format conversion** |
| 23 | "Snapshots de Redshift cross-region para DR" | **Redshift cross-region snapshot copy** |
| 24 | "Monitorar tráfego de COPY/UNLOAD do Redshift" | **Enhanced VPC Routing + VPC Flow Logs** |
| 25 | "Dashboard BI in-memory com alta performance" | **QuickSight com SPICE** |
| 26 | "Limitar acesso a linhas de uma tabela no data lake" | **Lake Formation Row-Level Security** |
| 27 | "Kafka Connect gerenciado para sincronizar dados" | **MSK Connect** |
| 28 | "Queries federadas sobre RDS/DynamoDB via Athena" | **Athena Federated Queries (Lambda connectors)** |
| 29 | "Escalar Redshift automaticamente para picos de leitura" | **Redshift Concurrency Scaling** |
| 30 | "Preparar dados visualmente sem código" | **AWS Glue DataBrew** |

### 14.2 Dicas de Eliminação na Prova

```
┌─────────────────────────────────────────────────────────────────┐
│            DICAS DE ELIMINAÇÃO DE ALTERNATIVAS                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ❌ Se diz "serverless" → elimine opções com clusters fixos     │
│     (EC2, EMR sempre-ativo sem justificativa)                   │
│                                                                 │
│  ❌ Se diz "sem gerenciar infraestrutura" → elimine EMR,        │
│     Redshift provisionado (prefira Athena, Glue, QuickSight)   │
│                                                                 │
│  ❌ Se diz "real-time" → elimine Athena, Redshift (batch)       │
│     Prefira Kinesis, Flink, OpenSearch                          │
│                                                                 │
│  ❌ Se diz "search/busca textual" → elimine Athena, Redshift    │
│     Prefira OpenSearch                                          │
│                                                                 │
│  ❌ Se diz "data warehouse" → elimine Athena (ad-hoc queries)   │
│     Prefira Redshift                                            │
│                                                                 │
│  ❌ Se diz "menor custo operacional" → elimine EMR, Redshift    │
│     provisionado. Prefira Athena + Glue (serverless)            │
│                                                                 │
│  ❌ Se diz "petabytes + complex joins" → elimine Athena          │
│     Prefira Redshift                                            │
│                                                                 │
│  ✅ Se diz "ad-hoc" + "S3" → Athena                             │
│  ✅ Se diz "Kafka" → MSK                                        │
│  ✅ Se diz "Hadoop/Spark" → EMR                                  │
│  ✅ Se diz "ETL + metadata" → Glue                               │
│  ✅ Se diz "BI + dashboard" → QuickSight                         │
│  ✅ Se diz "data lake + governance" → Lake Formation             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 14.3 Combinações Frequentes na Prova

| Padrão | Arquitetura |
|--------|-------------|
| Log Analytics | CloudWatch Logs → Lambda → OpenSearch → Dashboards |
| Data Lake Analytics | S3 → Glue Crawler → Glue Catalog → Athena → QuickSight |
| Real-time + Batch | Kinesis → Firehose → S3 (batch) + Flink (real-time) |
| Data Warehouse | S3 → Glue ETL → Redshift (COPY) + Spectrum (cold data) |
| IoT Pipeline | IoT Core → Kinesis → Firehose → S3 → Glue → Athena |
| Migração Kafka | Kafka on-prem → MSK → MSK Connect → S3/OpenSearch |
| BI Pipeline | RDS → Glue ETL → S3 (Parquet) → Athena → QuickSight |
| Search Pattern | DynamoDB → Streams → Lambda → OpenSearch |

### 14.4 Resumo Final de Pricing para a Prova

| Serviço | Modelo de Preço | Otimização |
|---------|----------------|------------|
| **Athena** | $5/TB scanned | Parquet + partição + compressão |
| **Redshift** | Por node-hora (provisionado) ou RPU (serverless) | RA3 nodes, Concurrency Scaling |
| **OpenSearch** | Por instância-hora + storage | UltraWarm/Cold para dados antigos |
| **EMR** | EC2 instances + EMR fee | Spot para Task nodes |
| **QuickSight** | Por sessão (reader) ou por autor | SPICE para reduzir queries na fonte |
| **Glue** | DPU-hora (ETL), por request (Catalog) | Job bookmarks, right-size DPUs |
| **Lake Formation** | Sem custo adicional (paga S3 + Glue) | — |
| **MSK** | Broker-hora + storage + data transfer | MSK Serverless para variável |
| **Flink** | KPU-hora | Right-size parallelism |

---

## Referências e Recursos

- [AWS Well-Architected Framework — Analytics Lens](https://docs.aws.amazon.com/wellarchitected/latest/analytics-lens/)
- [AWS Documentation — Analytics Services](https://docs.aws.amazon.com/analytics/)
- [AWS Skill Builder — SAA-C03 Exam Prep](https://skillbuilder.aws/)
- [Whitepapers AWS — Big Data Analytics Options](https://docs.aws.amazon.com/whitepapers/latest/big-data-analytics-options/)

---

> **Última atualização**: Julho 2026 | Preparação SAA-C03
