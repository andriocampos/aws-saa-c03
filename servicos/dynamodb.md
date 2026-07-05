# DynamoDB — Guia Completo para AWS SAA-C03

---

## 1. Conceitos Fundamentais

### 1.1 O que é o DynamoDB

O Amazon DynamoDB é um banco de dados NoSQL **serverless**, totalmente gerenciado pela AWS,
projetado para aplicações que exigem latência consistente de **single-digit milliseconds**
em qualquer escala.

### 1.2 Características Principais

| Característica          | Descrição                                                    |
|-------------------------|--------------------------------------------------------------|
| Tipo                    | NoSQL (key-value e document)                                 |
| Gerenciamento           | Serverless — sem provisionar servidores                      |
| Disponibilidade         | Multi-AZ automático (3 AZs) — sem configuração              |
| Latência                | Single-digit millisecond (< 10ms)                            |
| Tamanho máximo do item  | 400 KB                                                       |
| Schema                  | Schemaless — apenas PK (e SK) são definidos na criação       |
| Escalabilidade          | Horizontal — particionamento automático                      |
| Criptografia            | Em repouso (AES-256) por padrão                              |
| Integração IAM          | Controle de acesso fino por item/atributo                    |

### 1.3 Modelo de Dados

```
┌─────────────────────────────────────────────────────────────────┐
│                         TABELA DynamoDB                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐   ┌─────────────────┐                     │
│  │  Partition Key   │   │    Sort Key      │  ← Primary Key     │
│  │  (Hash Key)      │   │  (Range Key)     │    (PK + SK)       │
│  │  OBRIGATÓRIA     │   │  OPCIONAL        │                     │
│  └─────────────────┘   └─────────────────┘                     │
│                                                                 │
│  Item 1: { PK: "user#1", SK: "order#001", attr1, attr2... }    │
│  Item 2: { PK: "user#1", SK: "order#002", attr1, attr3... }    │
│  Item 3: { PK: "user#2", SK: "order#003", attr1, attr4... }    │
│                                                                 │
│  ⚠️  Cada item pode ter atributos DIFERENTES (schemaless)       │
│  ⚠️  Tamanho máximo por item: 400 KB                            │
└─────────────────────────────────────────────────────────────────┘
```

### 1.4 Tipos de Primary Key

| Tipo                    | Composição       | Unicidade                              |
|-------------------------|------------------|----------------------------------------|
| Simple Primary Key      | Partition Key    | PK deve ser única por item             |
| Composite Primary Key   | PK + Sort Key    | Combinação PK+SK deve ser única        |

### 1.5 Armazenamento Interno — Multi-AZ

```
         ┌──────────────────────────────────────────────┐
         │           Região AWS (ex: us-east-1)         │
         │                                              │
         │   ┌──────┐     ┌──────┐     ┌──────┐        │
         │   │ AZ-a │     │ AZ-b │     │ AZ-c │        │
         │   │      │     │      │     │      │        │
         │   │ Rep1 │◄───►│ Rep2 │◄───►│ Rep3 │        │
         │   │      │     │      │     │      │        │
         │   └──────┘     └──────┘     └──────┘        │
         │                                              │
         │   Replicação síncrona entre 3 AZs            │
         │   ✅ Alta disponibilidade automática          │
         │   ✅ Sem configuração adicional               │
         └──────────────────────────────────────────────┘
```

---

## 2. Partition Key Design

### 2.1 Como o DynamoDB Particiona os Dados

O DynamoDB usa uma **função hash** sobre a Partition Key para determinar em qual partição
física o item será armazenado. Cada partição suporta:
- **3.000 RCU** (Read Capacity Units)
- **1.000 WCU** (Write Capacity Units)
- **10 GB** de dados

### 2.2 Hot Partition Problem

Quando muitos itens compartilham a mesma Partition Key, todo o tráfego de leitura/escrita
se concentra em uma única partição, causando **throttling**.

```
  ❌ DESIGN RUIM — Hot Partition
  ┌─────────────────────────────────────────┐
  │  PK = "2026-07-04"  (data do dia)       │
  │  → 90% do tráfego vai para 1 partição   │
  │  → Throttling e ProvisionedThroughput   │
  │    ExceededException                     │
  └─────────────────────────────────────────┘

  ✅ DESIGN BOM — Distribuição Uniforme
  ┌─────────────────────────────────────────┐
  │  PK = "user#12345"  (user ID)           │
  │  → Tráfego distribuído entre partições  │
  │  → Sem throttling                        │
  └─────────────────────────────────────────┘
```

### 2.3 Estratégias para Evitar Hot Partitions

| Estratégia                      | Exemplo                                          |
|---------------------------------|--------------------------------------------------|
| Alta cardinalidade na PK        | user_id, device_id, session_id                   |
| Composite key com sufixo random | `date#2026-07-04_shard#3`                        |
| Write sharding                  | Adicionar sufixo aleatório (0-9) à PK           |
| Composite key com sort key      | PK=customer_id, SK=order_timestamp               |

### 2.4 Composite Keys — Modelagem Avançada

```
  Exemplo: E-commerce — Pedidos por Cliente
  ┌─────────────────────────────────────────────────┐
  │ PK (Partition Key)  │ SK (Sort Key)     │ Attrs │
  ├─────────────────────┼───────────────────┼───────┤
  │ CUSTOMER#001        │ ORDER#2026-01-15  │ ...   │
  │ CUSTOMER#001        │ ORDER#2026-03-20  │ ...   │
  │ CUSTOMER#001        │ PROFILE           │ ...   │
  │ CUSTOMER#002        │ ORDER#2026-02-10  │ ...   │
  └─────────────────────┴───────────────────┴───────┘

  → Query por PK = "CUSTOMER#001" retorna TODOS os itens do cliente
  → Query por PK = "CUSTOMER#001" AND SK begins_with "ORDER#"
    retorna apenas pedidos
```

---

## 3. Capacity Modes

### 3.1 Provisioned Mode

- Você define **RCU** (leitura) e **WCU** (escrita) antecipadamente
- Pode habilitar **Auto Scaling** para ajustar automaticamente
- **Mais barato** para tráfego previsível e estável
- Burst capacity: DynamoDB mantém um "crédito" de até 300 segundos de throughput não usado
- Se exceder: `ProvisionedThroughputExceededException`

### 3.2 On-Demand Mode

- DynamoDB escala automaticamente conforme a demanda
- Paga **por request** (leitura/escrita)
- Mais caro por operação, mas sem throttling
- Ideal para tráfego imprevisível, novos workloads, spiky traffic
- Pode atingir até o **dobro do pico anterior** instantaneamente

### 3.3 Tabela Comparativa Detalhada

| Aspecto                  | Provisioned                          | On-Demand                        |
|--------------------------|--------------------------------------|----------------------------------|
| Configuração             | Define RCU/WCU manualmente           | Nenhuma — automático             |
| Auto Scaling             | Disponível (com target utilization)  | Nativo                           |
| Custo                    | Menor (previsível)                   | Maior (por request)              |
| Throttling               | Possível se exceder capacidade       | Improvável (escala automática)   |
| Burst capacity           | 300 segundos de crédito              | N/A — sempre escala              |
| Reserved Capacity        | ✅ Disponível (1 ou 3 anos)          | ❌ Não disponível                |
| Ideal para               | Tráfego previsível e estável         | Tráfego imprevisível/novo        |
| Free tier                | 25 RCU + 25 WCU                      | Não incluído                     |

### 3.4 Switching entre Modos

- Pode alternar entre Provisioned e On-Demand
- **Cooldown de 24 horas** entre mudanças
- De Provisioned → On-Demand: imediato
- De On-Demand → Provisioned: imediato, mas define RCU/WCU iniciais

---

## 4. Cálculos de RCU e WCU — DETALHADO

### 4.1 Fórmulas

```
┌───────────────────────────────────────────────────────────────────────┐
│                        FÓRMULAS DE LEITURA (RCU)                      │
├───────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  Tamanho efetivo = ⌈ tamanho_item / 4KB ⌉  (arredonda para cima)     │
│                                                                       │
│  Strongly Consistent:    RCU = nº_leituras × ⌈ item / 4KB ⌉          │
│  Eventually Consistent:  RCU = (nº_leituras × ⌈ item / 4KB ⌉) / 2    │
│  Transactional:          RCU = nº_leituras × ⌈ item / 4KB ⌉ × 2      │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────┐
│                        FÓRMULAS DE ESCRITA (WCU)                      │
├───────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  Tamanho efetivo = ⌈ tamanho_item / 1KB ⌉  (arredonda para cima)     │
│                                                                       │
│  Normal:          WCU = nº_escritas × ⌈ item / 1KB ⌉                  │
│  Transactional:   WCU = nº_escritas × ⌈ item / 1KB ⌉ × 2             │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
```

### 4.2 Exemplos de Cálculo — Leitura (RCU)

**Exemplo 1:** 10 leituras/segundo, item de 4KB, strongly consistent
```
RCU = 10 × ⌈4/4⌉ = 10 × 1 = 10 RCU
```

**Exemplo 2:** 10 leituras/segundo, item de 4KB, eventually consistent
```
RCU = (10 × ⌈4/4⌉) / 2 = 10 / 2 = 5 RCU
```

**Exemplo 3:** 10 leituras/segundo, item de 6KB, strongly consistent
```
RCU = 10 × ⌈6/4⌉ = 10 × 2 = 20 RCU
```

**Exemplo 4:** 10 leituras/segundo, item de 6KB, eventually consistent
```
RCU = (10 × ⌈6/4⌉) / 2 = (10 × 2) / 2 = 10 RCU
```

**Exemplo 5:** 5 leituras/segundo, item de 12KB, transactional
```
RCU = 5 × ⌈12/4⌉ × 2 = 5 × 3 × 2 = 30 RCU
```

**Exemplo 6:** 20 leituras/segundo, item de 3KB, strongly consistent
```
RCU = 20 × ⌈3/4⌉ = 20 × 1 = 20 RCU  (3KB arredonda para 4KB)
```

### 4.3 Exemplos de Cálculo — Escrita (WCU)

**Exemplo 1:** 5 escritas/segundo, item de 1KB
```
WCU = 5 × ⌈1/1⌉ = 5 × 1 = 5 WCU
```

**Exemplo 2:** 5 escritas/segundo, item de 4.5KB
```
WCU = 5 × ⌈4.5/1⌉ = 5 × 5 = 25 WCU
```

**Exemplo 3:** 10 escritas/segundo, item de 2KB, transactional
```
WCU = 10 × ⌈2/1⌉ × 2 = 10 × 2 × 2 = 40 WCU
```

**Exemplo 4:** 8 escritas/segundo, item de 0.5KB
```
WCU = 8 × ⌈0.5/1⌉ = 8 × 1 = 8 WCU  (0.5KB arredonda para 1KB)
```

### 4.4 Resumo Rápido de Custos por Tipo de Operação

| Operação                  | Custo em Capacity Units        |
|---------------------------|--------------------------------|
| Read Strongly Consistent  | 1 RCU por 4KB                  |
| Read Eventually Consistent| 0.5 RCU por 4KB                |
| Read Transactional        | 2 RCU por 4KB                  |
| Write Normal              | 1 WCU por 1KB                  |
| Write Transactional       | 2 WCU por 1KB                  |


---

## 5. Indexes — GSI e LSI

### 5.1 Visão Geral

Indexes permitem consultar dados por atributos diferentes da Primary Key da tabela base.

### 5.2 Tabela Comparativa COMPLETA

| Aspecto                    | GSI (Global Secondary Index)           | LSI (Local Secondary Index)            |
|----------------------------|----------------------------------------|----------------------------------------|
| Nome completo              | Global Secondary Index                 | Local Secondary Index                  |
| Partition Key              | **Diferente** da tabela base           | **Mesma** da tabela base               |
| Sort Key                   | Qualquer atributo (opcional)           | **Diferente** da tabela base (obrig.)  |
| Criação                    | A qualquer momento (tabela existente)  | **Apenas na criação** da tabela        |
| Consistência de leitura    | **Apenas** Eventually Consistent       | Strongly OU Eventually Consistent      |
| Throughput                 | **Próprio** (RCU/WCU separados)        | Compartilha com tabela base            |
| Projeção de atributos      | ALL, KEYS_ONLY, INCLUDE                | ALL, KEYS_ONLY, INCLUDE                |
| Limite por tabela          | 20 GSIs                                | 5 LSIs                                 |
| Tamanho limite             | Sem limite                             | 10 GB por partition key value          |
| Sparse Index               | ✅ Sim (itens sem o atributo da PK     | ✅ Sim (itens sem o atributo do SK     |
|                            | do GSI não são indexados)              | do LSI não são indexados)              |
| Impacto em writes          | Consome WCU do GSI (separado)          | Consome WCU da tabela base             |
| Backfill                   | Sim (dados existentes são indexados)   | N/A (criado com a tabela)              |

### 5.3 Diagrama — GSI vs LSI

```
  TABELA BASE: PK = user_id, SK = order_date
  ┌──────────────────────────────────────────────────┐
  │ user_id (PK)  │ order_date (SK) │ product │ city │
  ├────────────────┼─────────────────┼─────────┼──────┤
  │ user#1         │ 2026-01-15      │ Laptop  │ SP   │
  │ user#1         │ 2026-03-20      │ Mouse   │ RJ   │
  │ user#2         │ 2026-02-10      │ Teclado │ SP   │
  └────────────────┴─────────────────┴─────────┴──────┘

  GSI: PK = city, SK = order_date
  (nova forma de consultar — por cidade)
  ┌────────────────────────────────────────────┐
  │ city (PK) │ order_date (SK) │ user_id      │
  ├───────────┼─────────────────┼──────────────┤
  │ RJ        │ 2026-03-20      │ user#1       │
  │ SP        │ 2026-01-15      │ user#1       │
  │ SP        │ 2026-02-10      │ user#2       │
  └───────────┴─────────────────┴──────────────┘

  LSI: PK = user_id (mesma), SK = product
  (mesma partition key, sort key diferente)
  ┌──────────────────────────────────────────────┐
  │ user_id (PK) │ product (SK) │ order_date     │
  ├──────────────┼──────────────┼────────────────┤
  │ user#1       │ Laptop       │ 2026-01-15     │
  │ user#1       │ Mouse        │ 2026-03-20     │
  │ user#2       │ Teclado      │ 2026-02-10     │
  └──────────────┴──────────────┴────────────────┘
```

### 5.4 Quando Usar Cada Index

| Cenário                                            | Use           |
|----------------------------------------------------|---------------|
| Preciso consultar por atributo totalmente diferente | **GSI**       |
| Preciso de strongly consistent reads no index      | **LSI**       |
| Tabela já existe e preciso de novo padrão de query | **GSI**       |
| Quero ordenar por outro atributo na mesma PK       | **LSI**       |
| Preciso de throughput independente                  | **GSI**       |
| Collection size < 10GB por PK value                | **LSI** (ok)  |

### 5.5 Sparse Index (Conceito Importante)

Um **sparse index** ocorre quando o atributo usado como chave do index não existe em
todos os itens. Apenas itens que **possuem** o atributo são incluídos no index.

**Use case:** Index apenas para itens com status "PENDENTE" — cria um GSI com
PK = status. Itens finalizados (sem atributo "status") não aparecem no index.

### 5.6 Throttling em GSI

⚠️ **Importante para a prova:** Se um GSI sofre throttling (WCU do GSI esgotado),
a **tabela base também** sofre throttling nas escritas, pois o DynamoDB precisa
manter o GSI sincronizado.

---

## 6. DynamoDB Streams

### 6.1 Conceitos

- Captura **sequência ordenada** de modificações nos itens (INSERT, MODIFY, REMOVE)
- Dados mantidos por **24 horas** (retenção)
- Cada registro no stream é chamado de **stream record**
- Stream records são organizados em **shards**
- Processamento garante ordem **por item** (não entre itens diferentes)

### 6.2 Stream View Types

| View Type              | Conteúdo do Stream Record                            |
|------------------------|------------------------------------------------------|
| KEYS_ONLY             | Apenas PK e SK do item modificado                    |
| NEW_IMAGE             | Item completo APÓS a modificação                     |
| OLD_IMAGE             | Item completo ANTES da modificação                   |
| NEW_AND_OLD_IMAGES    | Item ANTES e DEPOIS da modificação                   |

### 6.3 Diagrama — DynamoDB Streams + Lambda

```
  ┌─────────────┐       ┌─────────────────┐       ┌─────────────────┐
  │  Aplicação  │──────►│   DynamoDB      │──────►│  DynamoDB       │
  │  (write)    │       │   Table         │       │  Stream         │
  └─────────────┘       └─────────────────┘       └────────┬────────┘
                                                           │
                                                           ▼
                                                  ┌─────────────────┐
                                                  │  AWS Lambda     │
                                                  │  (trigger)      │
                                                  └────────┬────────┘
                                                           │
                              ┌─────────────────┬──────────┼──────────┐
                              ▼                 ▼          ▼          ▼
                        ┌──────────┐    ┌────────────┐ ┌───────┐ ┌──────┐
                        │   SNS    │    │ Elasticsearch│ │  SQS  │ │ S3   │
                        │ (notify) │    │ (search)    │ │(queue)│ │(arch)│
                        └──────────┘    └────────────┘ └───────┘ └──────┘
```

### 6.4 Use Cases para DynamoDB Streams

| Use Case                          | Descrição                                         |
|-----------------------------------|---------------------------------------------------|
| Replicação cross-region           | Base para Global Tables                           |
| Trigger de notificações           | Lambda envia email/SMS quando item muda           |
| Auditoria e compliance            | Registrar todas as alterações em log              |
| Agregações em tempo real          | Calcular totais, contadores em outra tabela       |
| Sincronizar com ElasticSearch     | Indexar dados para full-text search               |
| Materializar views                | Manter tabelas derivadas atualizadas              |

### 6.5 Streams vs Kinesis Data Streams para DynamoDB

| Aspecto                  | DynamoDB Streams          | Kinesis Data Streams         |
|--------------------------|---------------------------|------------------------------|
| Retenção                 | 24 horas                  | Até 365 dias                 |
| Consumers               | Até 2 simultâneos         | Até 5 (enhanced fan-out)     |
| Integração Lambda        | ✅ Nativa                  | ✅ Nativa                    |
| Custo                    | Incluído (read requests)  | Por shard-hour + PUT         |
| Ordering                 | Por item                  | Por shard                    |

---

## 7. DAX — DynamoDB Accelerator

### 7.1 O que é

DAX é um cache **in-memory** totalmente gerenciado, compatível com a API do DynamoDB,
que reduz a latência de leitura de **milissegundos para microssegundos**.

### 7.2 Arquitetura

```
  ┌──────────────┐         ┌────────────────────────────┐
  │  Aplicação   │────────►│       DAX Cluster          │
  │              │         │  ┌──────┐ ┌──────┐ ┌──────┐│
  │  (mesma API  │         │  │Node 1│ │Node 2│ │Node 3││
  │   DynamoDB)  │         │  │Primary│ │Replica│ │Replica│
  │              │         │  └──────┘ └──────┘ └──────┘│
  └──────────────┘         └────────────┬───────────────┘
                                        │ Cache Miss
                                        ▼
                           ┌────────────────────────────┐
                           │       DynamoDB Table       │
                           └────────────────────────────┘
```

### 7.3 Características

| Característica            | Detalhe                                              |
|---------------------------|------------------------------------------------------|
| Latência                  | Microssegundos (μs)                                  |
| Compatibilidade           | API 100% compatível com DynamoDB (drop-in)           |
| Tipo de cache             | Write-through (escritas vão para DynamoDB e cache)   |
| TTL padrão item cache     | 5 minutos (configurável)                             |
| TTL padrão query cache    | 1 minuto (configurável)                              |
| Cluster                   | 1 a 11 nodes (Primary + Replicas)                    |
| Multi-AZ                  | ✅ Recomendado (nodes em AZs diferentes)             |
| Criptografia              | Em trânsito e em repouso                             |
| VPC                       | Roda dentro da VPC do cliente                        |

### 7.4 Quando Usar DAX

✅ **Use DAX quando:**
- Aplicação requer latência de microssegundos
- Leituras repetitivas nos mesmos itens (hot keys)
- Read-intensive workload
- Eventually consistent reads são aceitáveis

### 7.5 Quando NÃO Usar DAX

❌ **NÃO use DAX quando:**
- Aplicação requer **strongly consistent reads** (DAX só retorna eventually consistent)
- Workload é predominantemente de **escrita** (write-intensive)
- Poucos reads repetitivos (cache miss constante)
- Aplicação já usa seu próprio cache (ElastiCache)

### 7.6 DAX vs ElastiCache

| Aspecto              | DAX                              | ElastiCache                        |
|----------------------|----------------------------------|------------------------------------|
| Integração           | Específico para DynamoDB         | Genérico (qualquer banco/API)      |
| API                  | Mesma API DynamoDB               | Redis/Memcached API                |
| Mudança no código    | Mínima (trocar endpoint)         | Significativa (lógica de cache)    |
| Tipo de dados        | Itens e queries DynamoDB         | Qualquer estrutura de dados        |
| Consistência         | Eventually consistent apenas     | Depende da implementação           |

---

## 8. Global Tables

### 8.1 Conceitos

- Replicação **multi-region**, **multi-master** (active-active)
- Leitura e escrita em **qualquer região** participante
- Replicação assíncrona (tipicamente < 1 segundo)
- Resolução de conflitos: **last-writer-wins** (baseado em timestamp)

### 8.2 Pré-requisitos

- **DynamoDB Streams** deve estar habilitado (NEW_AND_OLD_IMAGES)
- Tabela deve estar vazia OU usar a mesma estrutura em todas as réplicas
- Capacity mode: On-Demand OU Provisioned com Auto Scaling

### 8.3 Diagrama — Global Tables

```
         ┌──────────────────────────────────────────────────────────┐
         │                    GLOBAL TABLE                           │
         │                                                          │
         │  ┌───────────────┐         ┌───────────────┐            │
         │  │  us-east-1    │◄───────►│  eu-west-1    │            │
         │  │  (replica)    │         │  (replica)    │            │
         │  │               │         │               │            │
         │  │  Read ✅       │         │  Read ✅       │            │
         │  │  Write ✅      │         │  Write ✅      │            │
         │  └───────┬───────┘         └───────┬───────┘            │
         │          │                         │                    │
         │          └─────────┬───────────────┘                    │
         │                    │                                    │
         │          ┌─────────▼───────┐                            │
         │          │  ap-southeast-1 │                            │
         │          │  (replica)      │                            │
         │          │                 │                            │
         │          │  Read ✅         │                            │
         │          │  Write ✅        │                            │
         │          └─────────────────┘                            │
         │                                                          │
         │  Resolução de conflitos: LAST-WRITER-WINS               │
         │  Replicação: assíncrona (< 1 segundo tipicamente)       │
         └──────────────────────────────────────────────────────────┘
```

### 8.4 Consistency Model

| Leitura na mesma região da escrita | Eventually consistent (padrão) ou strongly consistent |
| Leitura em região diferente        | Eventually consistent APENAS                          |

### 8.5 Use Cases

- Aplicações globais com baixa latência para usuários em múltiplas regiões
- Disaster recovery com RPO (Recovery Point Objective) quase zero
- Migração ativa de tráfego entre regiões


---

## 9. TTL — Time to Live

### 9.1 Como Funciona

- Define um **atributo** no item contendo um timestamp em **epoch (Unix time)**
- Quando o timestamp expira, o DynamoDB marca o item para deleção
- Deleção é **assíncrona** — pode levar até **48 horas** após expiração
- **Sem custo de WCU** para deleções por TTL (gratuito)

### 9.2 Comportamento

```
  ┌─────────────────────────────────────────────────────────┐
  │  Item: { PK: "session#abc", expireAt: 1751673600 }      │
  │                                                         │
  │  timestamp atual > expireAt?                            │
  │       │                                                 │
  │       ├── NÃO → Item permanece na tabela               │
  │       │                                                 │
  │       └── SIM → Item marcado para deleção              │
  │                  (pode aparecer em queries por até 48h) │
  │                  → Deleção efetiva (sem custo WCU)      │
  │                  → Se Streams habilitado: registro com  │
  │                    userIdentity.type = "Service" e      │
  │                    userIdentity.principalId = "TTL"     │
  └─────────────────────────────────────────────────────────┘
```

### 9.3 Pontos Importantes para a Prova

| Ponto                                  | Detalhe                                    |
|----------------------------------------|--------------------------------------------|
| Formato do atributo                    | Epoch time (Number) em segundos            |
| Custo de deleção                       | **ZERO** (não consome WCU)                 |
| Tempo para deleção efetiva             | Até 48 horas após expiração                |
| Item aparece em Scan/Query após expiry?| **SIM**, até ser deletado de fato          |
| Streams captura deleção TTL?           | ✅ SIM (com identificação "Service/TTL")   |
| Filtrar itens expirados manualmente    | Use filter: expireAt > current_time        |

### 9.4 Use Cases

- Sessões de usuário (expirar após 30 minutos de inatividade)
- Tokens temporários
- Carrinhos de compra abandonados
- Dados regulatórios com prazo de retenção definido
- Logs temporários

---

## 10. Transactions

### 10.1 Conceitos

O DynamoDB suporta **transações ACID** (Atomicidade, Consistência, Isolamento, Durabilidade)
em múltiplos itens e até múltiplas tabelas na mesma região.

### 10.2 APIs Transacionais

| API                   | Descrição                                              |
|-----------------------|--------------------------------------------------------|
| TransactWriteItems    | Até **100 itens** ou **4 MB** — tudo ou nada           |
| TransactGetItems      | Até **100 itens** ou **4 MB** — leitura atômica        |

### 10.3 Operações Suportadas em TransactWriteItems

- `Put` — inserir item
- `Update` — atualizar item
- `Delete` — deletar item
- `ConditionCheck` — validar condição sem modificar

### 10.4 Custo

| Operação              | Custo                                                  |
|-----------------------|--------------------------------------------------------|
| Leitura transacional  | **2× RCU** por 4KB (dobro de strongly consistent)     |
| Escrita transacional  | **2× WCU** por 1KB (dobro de escrita normal)           |

### 10.5 Limites

- Máximo **100 itens** por transação
- Máximo **4 MB** de dados por transação
- Não pode ter o **mesmo item** em múltiplas operações na mesma transação
- Escopo: **mesma região** e **mesma conta**

### 10.6 Use Cases

- Transferência bancária (débito + crédito atomicamente)
- Gerenciamento de inventário (decrementar estoque + criar pedido)
- Manter consistência entre tabelas relacionadas
- Validações de negócio antes de escrita (ConditionCheck)

---

## 11. Conditional Writes e Optimistic Locking

### 11.1 Conditional Writes

Permitem que uma operação de escrita só execute se uma **condição** for verdadeira.
Se a condição falhar, a operação retorna `ConditionalCheckFailedException`.

```
  Exemplo: Só atualizar se status = "PENDENTE"
  ┌──────────────────────────────────────────────────────┐
  │  UpdateItem:                                         │
  │    Key: { PK: "order#123" }                          │
  │    UpdateExpression: SET status = "PROCESSANDO"      │
  │    ConditionExpression: status = "PENDENTE"          │
  │                                                      │
  │  → Se status != "PENDENTE": ConditionalCheckFailed   │
  │  → Se status == "PENDENTE": atualização executada    │
  └──────────────────────────────────────────────────────┘
```

### 11.2 Optimistic Locking com Version Number

Padrão para evitar **conflitos de escrita concorrente** sem locks pessimistas:

1. Cada item possui um atributo `version` (número inteiro)
2. Ao ler o item, a aplicação obtém a versão atual
3. Ao escrever, inclui condição: `version = versão_lida`
4. Se outra escrita ocorreu entre a leitura e a escrita, a condição falha
5. Aplicação pode fazer retry com a nova versão

```
  ┌──────────────────────────────────────────────────────────┐
  │  Passo 1: GET item → { PK: "prod#1", qty: 10, ver: 3 }  │
  │                                                          │
  │  Passo 2: UPDATE item                                    │
  │    SET qty = 9, ver = 4                                  │
  │    CONDITION: ver = 3                                    │
  │                                                          │
  │  → Se ver ainda é 3: ✅ Sucesso (atualiza para ver=4)    │
  │  → Se ver já mudou:  ❌ Falha → retry com nova versão    │
  └──────────────────────────────────────────────────────────┘
```

### 11.3 Comparação: Optimistic vs Pessimistic Locking

| Aspecto              | Optimistic Locking (DynamoDB)    | Pessimistic Locking (RDS)      |
|----------------------|----------------------------------|--------------------------------|
| Mecanismo            | Version number + conditional     | Lock explícito (SELECT FOR UP) |
| Conflitos            | Detecta no momento da escrita    | Previne (bloqueia reads)       |
| Performance          | Melhor (sem bloqueio)            | Pior (contenção)               |
| Ideal para           | Baixa contenção                  | Alta contenção                 |

---

## 12. Batch Operations

### 12.1 BatchWriteItem

| Aspecto                  | Detalhe                                               |
|--------------------------|-------------------------------------------------------|
| Operações                | Put e Delete (NÃO suporta Update)                     |
| Máximo de itens          | **25 itens** por chamada                              |
| Máximo de dados          | **16 MB** por chamada                                 |
| Paralelismo              | Operações são executadas em **paralelo**              |
| Atomicidade              | **NÃO** é atômico — itens individuais podem falhar    |
| Itens que falharam       | Retornados em `UnprocessedItems`                      |
| Retry                    | Aplicação deve fazer retry com exponential backoff    |

### 12.2 BatchGetItem

| Aspecto                  | Detalhe                                               |
|--------------------------|-------------------------------------------------------|
| Máximo de itens          | **100 itens** por chamada                             |
| Máximo de dados          | **16 MB** por chamada                                 |
| Paralelismo              | Leituras executadas em **paralelo**                   |
| Consistência             | Configurável por tabela (strongly ou eventually)      |
| Itens que falharam       | Retornados em `UnprocessedKeys`                       |
| Projeção                 | Pode especificar atributos a retornar                 |

### 12.3 Tratamento de UnprocessedItems

```
  ┌─────────────────────────────────────────────────────────┐
  │  1. Chamar BatchWriteItem com 25 itens                  │
  │  2. Resposta inclui UnprocessedItems (ex: 3 itens)      │
  │  3. Esperar com exponential backoff                     │
  │  4. Retry APENAS com os 3 itens não processados         │
  │  5. Repetir até UnprocessedItems estar vazio            │
  └─────────────────────────────────────────────────────────┘
```

### 12.4 Batch vs Transaction

| Aspecto              | Batch Operations                 | Transactions                   |
|----------------------|----------------------------------|--------------------------------|
| Atomicidade          | ❌ Não (itens individuais)       | ✅ Sim (tudo ou nada)          |
| Custo                | Normal (1× WCU/RCU)             | Dobro (2× WCU/RCU)            |
| Limite de itens      | 25 (write) / 100 (read)         | 100 (write e read)            |
| Use case             | Bulk operations sem atomicidade  | Operações que requerem ACID    |

---

## 13. PartiQL

### 13.1 O que é

PartiQL é uma linguagem de consulta **SQL-compatible** para DynamoDB.
Permite usar sintaxe familiar de SQL para operações CRUD.

### 13.2 Operações Suportadas

```sql
-- SELECT (Query/Scan)
SELECT * FROM "MusicTable" WHERE Artist = 'Beatles'

-- INSERT (PutItem)
INSERT INTO "MusicTable" VALUE {'Artist': 'Beatles', 'Song': 'Yesterday'}

-- UPDATE (UpdateItem)
UPDATE "MusicTable" SET Rating = 5 WHERE Artist = 'Beatles' AND Song = 'Yesterday'

-- DELETE (DeleteItem)
DELETE FROM "MusicTable" WHERE Artist = 'Beatles' AND Song = 'Yesterday'
```

### 13.3 Pontos Importantes

| Ponto                         | Detalhe                                            |
|-------------------------------|---------------------------------------------------|
| Suporte a transactions        | ✅ Sim (via BEGIN TRANSACTION / COMMIT)            |
| Suporte a batch               | ✅ Sim (múltiplos statements)                      |
| Console AWS                   | ✅ Disponível no console do DynamoDB               |
| Performance                   | Mesma do API nativa (traduzido internamente)       |
| Substitui API nativa?         | NÃO — é uma camada de conveniência                |


---

## 14. Point-in-Time Recovery (PITR)

### 14.1 Conceitos

- Permite restaurar a tabela para **qualquer ponto no tempo** nos últimos **35 dias**
- Proteção contínua contra escritas ou deleções acidentais
- Deve ser **habilitado explicitamente** (não vem ativado por padrão)
- Restauração cria uma **nova tabela** (não sobrescreve a existente)

### 14.2 Características

| Aspecto                    | Detalhe                                              |
|----------------------------|------------------------------------------------------|
| Janela de recuperação      | Últimos **35 dias**                                  |
| Granularidade              | Qualquer segundo dentro da janela                    |
| Resultado                  | Nova tabela com dados do ponto escolhido             |
| GSI e LSI                  | Restaurados junto com a tabela                       |
| Streams                    | NÃO restaura configuração de Streams                 |
| TTL settings               | NÃO restaura configuração de TTL                     |
| Auto Scaling               | NÃO restaura configuração de Auto Scaling            |
| Tags                       | NÃO restaura tags                                    |
| Criptografia               | Pode escolher nova chave KMS na restauração          |
| Tempo de restauração       | Variável (depende do tamanho da tabela)              |

### 14.3 PITR vs Backup On-Demand

| Aspecto              | PITR                              | Backup On-Demand                   |
|----------------------|-----------------------------------|------------------------------------|
| Janela               | 35 dias contínuos                 | Indefinido (manual)                |
| Granularidade        | Qualquer segundo                  | Momento exato do backup            |
| Ativação             | Deve habilitar antes              | Criado sob demanda                 |
| Custo                | Por GB armazenado continuamente   | Por GB do backup                   |
| Impacto performance  | Zero                              | Zero                               |

---

## 15. Backup e Export

### 15.1 On-Demand Backups

- Backup completo da tabela a qualquer momento
- **Sem impacto** na performance ou latência da tabela
- Retido até ser explicitamente deletado (sem expiração)
- Gerenciado via **AWS Backup** para políticas centralizadas
- Restauração cria nova tabela

### 15.2 Export to S3

| Aspecto                    | Detalhe                                              |
|----------------------------|------------------------------------------------------|
| Formato                    | DynamoDB JSON ou Amazon Ion                          |
| Destino                    | Bucket S3 (mesma conta ou cross-account)             |
| Impacto na tabela          | **Zero** — usa PITR snapshot                         |
| Requisito                  | PITR deve estar habilitado                           |
| Uso comum                  | Analytics com Athena, ETL, data lake                 |
| Frequência                 | Pode ser exportado a qualquer momento                |
| Export incremental          | ✅ Disponível (apenas mudanças)                      |

### 15.3 Import from S3

- Importar dados de S3 para uma **nova tabela** DynamoDB
- Formatos: CSV, DynamoDB JSON, Amazon Ion
- Não afeta tabelas existentes
- Ideal para migração e carga inicial

### 15.4 Diagrama — Estratégia de Backup Completa

```
  ┌─────────────────────────────────────────────────────────────┐
  │                  ESTRATÉGIA DE BACKUP                        │
  │                                                             │
  │  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
  │  │   PITR       │    │  On-Demand   │    │  Export S3   │  │
  │  │              │    │  Backup      │    │              │  │
  │  │  Contínuo    │    │  Manual ou   │    │  Para        │  │
  │  │  35 dias     │    │  AWS Backup  │    │  analytics   │  │
  │  │  Qualquer    │    │  Retenção    │    │  Athena      │  │
  │  │  segundo     │    │  ilimitada   │    │  Data Lake   │  │
  │  └──────────────┘    └──────────────┘    └──────────────┘  │
  │                                                             │
  │  Todos: ZERO impacto na performance da tabela              │
  └─────────────────────────────────────────────────────────────┘
```

---

## 16. DynamoDB vs RDS — Quando Usar Cada

### 16.1 Tabela Comparativa Completa

| Aspecto                    | DynamoDB                             | RDS (Relacional)                    |
|----------------------------|--------------------------------------|--------------------------------------|
| Modelo de dados            | NoSQL (key-value / document)         | Relacional (tabelas com schema)      |
| Schema                     | Schemaless (flexível)                | Schema rígido (DDL definido)         |
| Escalabilidade             | Horizontal (automática)              | Vertical (scale-up) + read replicas  |
| Latência                   | Single-digit ms (μs com DAX)        | Depende da query (ms a segundos)     |
| Joins                      | ❌ Não suporta                       | ✅ SQL Joins nativos                 |
| Transactions               | ✅ ACID (limite 100 itens/4MB)       | ✅ ACID (sem limite prático)         |
| Disponibilidade            | Multi-AZ automático (3 AZs)         | Multi-AZ opcional (failover)         |
| Gerenciamento              | Serverless (zero admin)              | Semi-gerenciado (patches, backups)   |
| Preço                      | Pay-per-request ou provisioned       | Por instância (hora) + storage       |
| Query language             | API proprietária / PartiQL           | SQL completo                         |
| Ideal para                 | Acesso por chave, alta escala, IoT   | Queries complexas, reports, joins    |
| Item/Row size              | Máx 400KB                            | Depende do engine (MB+)             |
| Índices                    | GSI (20) + LSI (5)                   | Ilimitados (B-tree, etc.)           |
| Backup                     | PITR (35d) + On-Demand              | Automated backups + snapshots        |
| Replicação global          | Global Tables (multi-master)         | Cross-region read replicas           |

### 16.2 Quando Usar DynamoDB

✅ Use DynamoDB quando:
- Acesso predominantemente por chave (key-value lookups)
- Necessidade de latência previsível em qualquer escala
- Workload com picos imprevisíveis (On-Demand mode)
- Dados semi-estruturados ou com schema variável
- IoT, gaming, sessões de usuário, carrinhos de compra
- Aplicações serverless (Lambda + API Gateway + DynamoDB)
- Necessidade de replicação multi-region multi-master

### 16.3 Quando Usar RDS

✅ Use RDS quando:
- Queries complexas com JOINs entre múltiplas tabelas
- Relatórios e agregações SQL complexas
- Dados altamente relacionais com integridade referencial
- Aplicações legadas que dependem de SQL
- Necessidade de transactions complexas (centenas de rows)
- Schema bem definido e estável

### 16.4 Cenários da Prova — DynamoDB vs RDS

| Cenário                                                    | Resposta    |
|------------------------------------------------------------|-------------|
| "millisecond latency at any scale"                         | DynamoDB    |
| "complex SQL queries with joins"                           | RDS         |
| "serverless database, no admin"                            | DynamoDB    |
| "session storage for web app"                              | DynamoDB    |
| "reporting with complex aggregations"                      | RDS/Redshift|
| "schema changes frequently"                                | DynamoDB    |
| "referential integrity between tables"                     | RDS         |
| "multi-region active-active writes"                        | DynamoDB    |
| "IoT data ingestion millions of events/sec"               | DynamoDB    |

---

## 17. Palavras-Chave da Prova SAA-C03

### Cenários e Respostas para Identificação Rápida

| # | Palavra-chave / Cenário na Prova                                        | Resposta / Serviço                          |
|---|-------------------------------------------------------------------------|---------------------------------------------|
| 1 | "serverless NoSQL database"                                             | **DynamoDB**                                |
| 2 | "single-digit millisecond latency"                                      | **DynamoDB**                                |
| 3 | "microsecond latency for reads"                                         | **DynamoDB + DAX**                          |
| 4 | "cache for DynamoDB, API compatible"                                    | **DAX**                                     |
| 5 | "multi-region active-active database"                                   | **DynamoDB Global Tables**                  |
| 6 | "last-writer-wins conflict resolution"                                  | **DynamoDB Global Tables**                  |
| 7 | "automatically delete expired items"                                    | **DynamoDB TTL**                            |
| 8 | "stream of changes from database table"                                 | **DynamoDB Streams**                        |
| 9 | "trigger Lambda on database changes"                                    | **DynamoDB Streams + Lambda**               |
| 10| "ACID transactions on NoSQL"                                            | **DynamoDB Transactions**                   |
| 11| "unpredictable traffic, no throttling"                                  | **DynamoDB On-Demand mode**                 |
| 12| "cost-effective for steady traffic"                                     | **DynamoDB Provisioned + Auto Scaling**     |
| 13| "query by non-key attribute"                                            | **GSI (Global Secondary Index)**            |
| 14| "strongly consistent read on secondary index"                           | **LSI (Local Secondary Index)**             |
| 15| "restore table to any point in last 35 days"                            | **DynamoDB PITR**                           |
| 16| "export DynamoDB data for analytics"                                    | **Export to S3 + Athena**                   |
| 17| "session management, shopping cart"                                     | **DynamoDB + TTL**                          |
| 18| "hot partition, uneven distribution"                                    | **Redesign Partition Key** (alta cardinalidade) |
| 19| "optimistic locking without blocking"                                   | **Conditional Writes + version number**     |
| 20| "SQL syntax on DynamoDB"                                                | **PartiQL**                                 |
| 21| "read-heavy workload, reduce DynamoDB costs"                            | **DAX** (cache reduces RCU)                 |
| 22| "key-value store, schema flexibility"                                   | **DynamoDB**                                |
| 23| "cross-region disaster recovery, near-zero RPO"                         | **DynamoDB Global Tables**                  |
| 24| "bulk load data into DynamoDB"                                          | **BatchWriteItem** ou **Import from S3**    |
| 25| "400KB item size limit"                                                 | **DynamoDB** (armazenar referência, dados grandes no S3) |

---

## 18. Resumo de Limites Importantes

| Recurso                          | Limite                                       |
|----------------------------------|----------------------------------------------|
| Tamanho máximo do item           | 400 KB                                       |
| Partition Key value              | Máx 2048 bytes                               |
| Sort Key value                   | Máx 1024 bytes                               |
| GSI por tabela                   | 20                                           |
| LSI por tabela                   | 5                                            |
| Itens por transação              | 100                                          |
| Dados por transação              | 4 MB                                         |
| BatchWriteItem                   | 25 itens / 16 MB                             |
| BatchGetItem                     | 100 itens / 16 MB                            |
| Partição: RCU                    | 3.000 RCU por partição                       |
| Partição: WCU                    | 1.000 WCU por partição                       |
| Partição: dados                  | 10 GB por partição                           |
| LSI: dados por PK value          | 10 GB                                        |
| PITR: janela                     | 35 dias                                      |
| Streams: retenção                | 24 horas                                     |
| TTL: tempo para deleção          | Até 48 horas após expiração                  |
| Global Tables: regiões           | Qualquer região AWS suportada                |
| DAX: nodes por cluster           | 1 a 11                                       |
| Cooldown switching capacity mode | 24 horas                                     |

---

## 19. Dicas Finais para a Prova

1. **DynamoDB = NoSQL serverless** — sempre que a prova mencionar "managed NoSQL",
   "key-value", ou "serverless database" com baixa latência → DynamoDB

2. **DAX ≠ ElastiCache** — DAX é específico para DynamoDB (API compatível, drop-in);
   ElastiCache é genérico e requer mudança significativa no código

3. **GSI vs LSI** — se a prova diz "criar index após tabela existir" → GSI;
   se diz "strongly consistent no index" → LSI

4. **Cálculos de RCU/WCU** — memorize: 4KB para RCU, 1KB para WCU, sempre
   arredondar para cima, transacional = 2×

5. **Global Tables** — sempre que a prova mencionar "multi-region writes" ou
   "active-active across regions" → Global Tables

6. **TTL** — sem custo de WCU, epoch timestamp, até 48h para deleção efetiva

7. **Streams** — retenção 24h, integração com Lambda, base para Global Tables

8. **PITR** — 35 dias, restaura para nova tabela, deve ser habilitado antes

9. **On-Demand vs Provisioned** — tráfego imprevisível = On-Demand;
   tráfego estável + custo menor = Provisioned com Auto Scaling

10. **Item > 400KB** — armazenar dados grandes no S3, guardar referência no DynamoDB

