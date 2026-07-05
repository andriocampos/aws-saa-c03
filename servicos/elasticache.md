# Amazon ElastiCache — Guia Aprofundado para AWS SAA-C03

---

## 1. Conceitos Fundamentais

### 1.1 O que é Amazon ElastiCache?

Amazon ElastiCache é um serviço **gerenciado** de cache in-memory na AWS que oferece
latência de **sub-milissegundo** para aplicações. Ele elimina a complexidade de implantar,
operar e escalar datastores in-memory, permitindo que desenvolvedores foquem na lógica
de aplicação.

### 1.2 Características Principais

- **Totalmente gerenciado:** patching, monitoramento, failover e backups automáticos
- **Sub-millisecond latency:** tempo de resposta inferior a 1ms para leituras
- **Escalável:** suporta milhões de requisições por segundo
- **Alta disponibilidade:** Multi-AZ com failover automático (Redis)
- **Seguro:** VPC, Security Groups, encryption in-transit e at-rest

### 1.3 Engines Disponíveis

O ElastiCache suporta duas engines:

```
┌─────────────────────────────────────────────────────┐
│              Amazon ElastiCache                       │
├──────────────────────┬──────────────────────────────┤
│       Redis OSS      │         Memcached            │
│  (+ Redis compatível)│                              │
├──────────────────────┼──────────────────────────────┤
│ • Estruturas ricas   │ • Cache simples key-value    │
│ • Persistência       │ • Multi-threaded             │
│ • Replicação         │ • Sem persistência           │
│ • Multi-AZ failover  │ • Sem replicação             │
│ • Backup/Restore     │ • Particionamento simples    │
└──────────────────────┴──────────────────────────────┘
```

### 1.4 Quando NÃO usar ElastiCache

- Dados que mudam com muita frequência e precisam de consistência forte → use RDS diretamente
- Necessidade de queries complexas (JOIN, GROUP BY) → banco relacional
- Cache específico para DynamoDB → use DAX
- Cache de conteúdo estático para usuários globais → use CloudFront

---

## 2. Redis vs Memcached — Comparação COMPLETA

### 2.1 Tabela Comparativa Detalhada

| Característica | Redis | Memcached |
|---|---|---|
| **Persistência (RDB/AOF)** | ✅ Sim | ❌ Não |
| **Replicação** | ✅ Até 5 read replicas por shard | ❌ Não |
| **Multi-AZ com Auto-Failover** | ✅ Sim | ❌ Não |
| **Backup e Restore** | ✅ Snapshots automáticos e manuais | ❌ Não |
| **Cluster Mode (sharding)** | ✅ Até 500 shards | ✅ Particionamento automático |
| **Pub/Sub** | ✅ Sim | ❌ Não |
| **Sorted Sets** | ✅ Sim (leaderboards) | ❌ Não |
| **Geospatial** | ✅ GEOADD, GEODIST, GEORADIUS | ❌ Não |
| **Streams** | ✅ Redis Streams (log append-only) | ❌ Não |
| **Lua Scripting** | ✅ Execução atômica de scripts | ❌ Não |
| **Autenticação** | ✅ Redis AUTH + tokens | ❌ SASL apenas |
| **Encryption in-transit (TLS)** | ✅ Sim | ✅ Sim |
| **Encryption at-rest (KMS)** | ✅ Sim | ❌ Não |
| **Threads** | Single-threaded (I/O threads no 6+) | Multi-threaded nativo |
| **Tipos de dados** | Strings, Lists, Sets, Sorted Sets, Hashes, Bitmaps, HyperLogLog, Streams | Strings simples (key-value) |
| **Tamanho máximo do valor** | 512 MB | 1 MB |
| **Global Datastore** | ✅ Cross-region replication | ❌ Não |
| **Compliance** | HIPAA, PCI DSS, FedRAMP | Limitado |
| **Caso de uso ideal** | Session store, leaderboards, pub/sub, geospatial, real-time analytics | Cache simples de alta throughput |

### 2.2 Regra de Ouro para a Prova

```
┌─────────────────────────────────────────────────────────────────┐
│ REGRA PARA O EXAME:                                             │
│                                                                 │
│ Precisa de UM destes? → REDIS:                                  │
│   • Persistência / Backup                                       │
│   • Multi-AZ / Alta Disponibilidade                             │
│   • Estruturas de dados avançadas (Sorted Sets, Lists, etc.)    │
│   • Pub/Sub                                                     │
│   • Replicação                                                  │
│                                                                 │
│ Precisa APENAS de cache simples + multi-thread? → MEMCACHED     │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Caching Strategies em Profundidade

### 3.1 Lazy Loading (Cache-Aside)

#### Diagrama de Fluxo

```
                    ┌──────────┐
                    │   App    │
                    └────┬─────┘
                         │
                    1. GET key
                         │
                         ▼
                    ┌──────────┐
               ┌────│  Cache   │
               │    └──────────┘
               │
       ┌───────┴───────┐
       │               │
   CACHE HIT       CACHE MISS
       │               │
       ▼               ▼
  2a. Retorna     2b. Query DB
     dado              │
                       ▼
                  ┌──────────┐
                  │    DB    │
                  └────┬─────┘
                       │
                  3. Retorna dado
                       │
                       ▼
                  4. SET key no Cache
                       │
                       ▼
                  5. Retorna dado ao App
```

#### Prós e Contras

| Prós | Contras |
|------|---------|
| Só dados requisitados ficam no cache | Cache Miss Penalty: 3 chamadas (cache + DB + write cache) |
| Falha no cache não é fatal (app busca no DB) | Stale Data: dados podem ficar desatualizados |
| Eficiente em memória | Cold start: cache vazio após reinício |

#### Stale Data Problem

- Dado é gravado no cache e nunca atualizado até expirar (TTL) ou ser removido
- Solução: combinar com TTL para forçar refresh periódico
- Solução avançada: combinar com Write-Through para dados críticos

#### Cache Miss Penalty

- **3 round trips:** App→Cache (miss) → App→DB (query) → App→Cache (write)
- Latência perceptível na primeira requisição de cada key
- Mitigação: pre-warming do cache com dados mais acessados

### 3.2 Write-Through

#### Diagrama de Fluxo

```
                    ┌──────────┐
                    │   App    │
                    └────┬─────┘
                         │
                    1. WRITE data
                         │
                    ┌────┴─────┐
                    │          │
                    ▼          ▼
              ┌──────────┐  ┌──────────┐
              │    DB    │  │  Cache   │
              └──────────┘  └──────────┘
                    │          │
                    ▼          ▼
              2. Confirma   3. SET key
                    │
                    ▼
              4. Retorna sucesso ao App
```

#### Prós e Contras

| Prós | Contras |
|------|---------|
| Cache sempre atualizado (sem stale data) | Write Penalty: cada escrita tem latência extra |
| Leituras subsequentes são muito rápidas | Dados escritos podem nunca ser lidos (desperdício) |
| Consistência entre cache e DB | Cache churn: muita escrita pode evictar dados úteis |

#### Write Penalty

- Cada operação de escrita requer **2 escritas:** DB + Cache
- Aumento de latência em operações de escrita
- Mitigação: usar async writes ou aceitar eventual consistency

### 3.3 Write-Behind (Write-Back)

#### Diagrama de Fluxo

```
                    ┌──────────┐
                    │   App    │
                    └────┬─────┘
                         │
                    1. WRITE to Cache
                         │
                         ▼
                    ┌──────────┐
                    │  Cache   │──── Retorno imediato ao App
                    └────┬─────┘
                         │
                    2. Batch/Async
                         │ (após delay ou batch size)
                         ▼
                    ┌──────────┐
                    │    DB    │
                    └──────────┘
```

#### Características

- App escreve **apenas no cache**, e o cache sincroniza com o DB em background
- Escritas são agrupadas em **batches** para reduzir I/O no banco
- Latência de escrita extremamente baixa para a aplicação
- **Risco:** perda de dados se o cache falhar antes de sincronizar com o DB
- Não é nativamente suportado pelo ElastiCache (requer implementação na aplicação)

### 3.4 Adding TTL — Melhor Prática

```
┌──────────────────────────────────────────────────────────────────┐
│ MELHOR PRÁTICA: Combinar Lazy Loading + Write-Through + TTL      │
│                                                                  │
│ • Lazy Loading: garante que o cache não falha a aplicação        │
│ • Write-Through: mantém dados frequentes atualizados             │
│ • TTL: previne stale data e libera memória automaticamente       │
│                                                                  │
│ Valores comuns de TTL:                                           │
│   - Sessões de usuário: 30 min a 24h                             │
│   - Resultados de query: 1 min a 1h                              │
│   - Dados de referência: 24h+                                    │
│   - Leaderboards: 1-5 min                                        │
└──────────────────────────────────────────────────────────────────┘
```

---

## 4. Redis Cluster Mode: Disabled vs Enabled

### 4.1 Cluster Mode Disabled

```
┌─────────────────────────────────────────┐
│         Cluster Mode DISABLED           │
│                                         │
│   ┌─────────┐                           │
│   │ Primary │──── Read/Write            │
│   └────┬────┘                           │
│        │                                │
│   ┌────┴────────────────────┐           │
│   │    │    │    │    │     │           │
│   ▼    ▼    ▼    ▼    ▼    ▼           │
│  R1   R2   R3   R4   R5  (replicas)    │
│                                         │
│  1 shard, até 5 read replicas           │
│  Scaling: VERTICAL (mudar node type)    │
└─────────────────────────────────────────┘
```

#### Características

- **1 único shard** com 1 primary node + até 5 read replicas
- Todos os dados em um único node (limitado pela memória do node)
- Escalabilidade **vertical**: mudar para instance type maior
- Suporta Multi-AZ com auto-failover
- Operações multi-key funcionam sem restrição
- **Máximo:** ~340 TB (instância maior disponível)

### 4.2 Cluster Mode Enabled

```
┌─────────────────────────────────────────────────────────┐
│              Cluster Mode ENABLED                        │
│                                                         │
│  Shard 1          Shard 2          Shard 3              │
│  ┌────────┐       ┌────────┐       ┌────────┐          │
│  │Primary │       │Primary │       │Primary │          │
│  └───┬────┘       └───┬────┘       └───┬────┘          │
│      │                │                │                │
│   ┌──┴──┐          ┌──┴──┐          ┌──┴──┐            │
│   │ R1  │          │ R1  │          │ R1  │            │
│   └─────┘          └─────┘          └─────┘            │
│                                                         │
│  Slots: 0-5460    Slots: 5461-10922  Slots: 10923-16383│
│                                                         │
│  Até 500 shards, cada shard com até 5 replicas          │
│  Scaling: HORIZONTAL (adicionar shards)                 │
└─────────────────────────────────────────────────────────┘
```

#### Características

- **Até 500 shards**, cada um com primary + até 5 replicas
- Dados distribuídos por hash slots (16.384 slots totais)
- Escalabilidade **horizontal**: adicionar mais shards
- Suporta **online resharding** (sem downtime)
- Operações multi-key limitadas ao mesmo hash slot
- **Máximo teórico:** 500 shards × memória do node

### 4.3 Tabela Comparativa

| Aspecto | Cluster Mode Disabled | Cluster Mode Enabled |
|---------|----------------------|---------------------|
| Shards | 1 | Até 500 |
| Replicas por shard | Até 5 | Até 5 |
| Scaling | Vertical | Horizontal |
| Multi-key operations | Sem restrição | Mesmo hash slot apenas |
| Capacidade máxima | Memória de 1 node | 500 × memória do node |
| Online resharding | N/A | ✅ Sim |
| Quando usar | Datasets < 100GB, multi-key ops | Datasets grandes, alta escrita |

---

## 5. Redis Multi-AZ com Auto-Failover

### 5.1 Arquitetura

```
              Region: us-east-1
┌─────────────────────────────────────────────────┐
│                                                 │
│   AZ-a                    AZ-b                  │
│   ┌──────────┐           ┌──────────┐          │
│   │ Primary  │◄─────────►│ Replica  │          │
│   │  (R/W)   │  Repl.    │  (Read)  │          │
│   └──────────┘  async    └──────────┘          │
│                                                 │
│                           AZ-c                  │
│                          ┌──────────┐          │
│                          │ Replica  │          │
│                          │  (Read)  │          │
│                          └──────────┘          │
│                                                 │
└─────────────────────────────────────────────────┘
```

### 5.2 Como Funciona o Auto-Failover

1. ElastiCache monitora continuamente o primary node
2. Se o primary falha, o serviço detecta em **~30 segundos**
3. Promove automaticamente a replica com menor replication lag
4. Atualiza o DNS endpoint para apontar ao novo primary
5. Aplicação reconecta automaticamente via endpoint

### 5.3 Tempos de Failover

| Etapa | Tempo Aproximado |
|-------|-----------------|
| Detecção da falha | ~10-30 segundos |
| Promoção da replica | ~10-30 segundos |
| Atualização DNS | ~5-10 segundos |
| **Total** | **~30-60 segundos** |

### 5.4 Requisitos

- Mínimo de 1 read replica em outra AZ
- Multi-AZ habilitado na configuração do replication group
- Aplicação deve usar o **Primary Endpoint** (não o endpoint do node)

---

## 6. Redis Global Datastore

### 6.1 Conceito

Global Datastore permite replicação **cross-region** totalmente gerenciada para Redis,
habilitando disaster recovery e leituras com baixa latência em múltiplas regiões.

### 6.2 Arquitetura

```
┌─────────────────────┐         ┌─────────────────────┐
│   Region: us-east-1 │         │  Region: eu-west-1  │
│                     │         │                     │
│  ┌──────────────┐   │  <1s    │  ┌──────────────┐   │
│  │   PRIMARY    │───┼────────►│  │  SECONDARY   │   │
│  │   Cluster    │   │  async  │  │   Cluster    │   │
│  └──────────────┘   │  repl.  │  └──────────────┘   │
│                     │         │                     │
│  • Read/Write       │         │  • Read-only        │
│  • Backups          │         │  • Promovível       │
└─────────────────────┘         └─────────────────────┘
```

### 6.3 Características

- **Replication lag < 1 segundo** (tipicamente ~milliseconds)
- Até **2 regiões secundárias** (total de 3 regiões)
- Failover cross-region é **manual** (promover secondary → primary)
- RPO próximo de zero para disaster recovery
- Compatível com Cluster Mode Enabled
- Cada cluster mantém seu próprio endpoint

### 6.4 Casos de Uso

- **Disaster Recovery (DR):** failover para outra região se a primária cair
- **Leituras globais de baixa latência:** usuários leem da região mais próxima
- **Migração de região:** promover secondary e redirecionar tráfego

---

## 7. ElastiCache Security

### 7.1 Camadas de Segurança

```
┌─────────────────────────────────────────────────────────────┐
│                    SEGURANÇA ElastiCache                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. REDE (Network)                                          │
│     • VPC: cluster roda dentro de uma VPC privada           │
│     • Security Groups: controle de acesso por porta/IP      │
│     • Subnet Groups: define em quais subnets os nodes rodam │
│                                                             │
│  2. AUTENTICAÇÃO (Authentication)                           │
│     • Redis AUTH: token/password para conectar              │
│     • IAM: SOMENTE para chamadas de API (create, delete)    │
│     • IAM NÃO autentica conexões ao cache!                  │
│                                                             │
│  3. ENCRYPTION IN-TRANSIT (TLS/SSL)                         │
│     • Criptografa dados entre app e cache                   │
│     • Habilitado no momento da criação do cluster           │
│     • Suportado por Redis e Memcached                       │
│                                                             │
│  4. ENCRYPTION AT-REST (KMS)                                │
│     • Criptografa dados armazenados em disco/memória        │
│     • Usa AWS KMS (Customer Managed Key ou AWS Managed)     │
│     • Somente Redis (Memcached NÃO suporta)                 │
│     • Habilitado no momento da criação                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 7.2 Redis AUTH — Detalhes

- Token de até 128 caracteres alfanuméricos
- Configurado na criação ou modificação do cluster
- Requer **encryption in-transit habilitada** (TLS)
- Clientes devem fornecer o token ao conectar: `AUTH <token>`
- Suporta rotação de token (dois tokens ativos durante transição)

### 7.3 IAM — Escopo Limitado

| IAM controla (API calls) | IAM NÃO controla |
|--------------------------|-------------------|
| CreateCacheCluster | Conexão ao Redis/Memcached |
| DeleteCacheCluster | Autenticação de dados |
| ModifyCacheCluster | Comandos Redis |
| CreateSnapshot | Leitura/escrita de keys |
| DescribeCacheClusters | Pub/Sub |

> **IMPORTANTE PARA A PROVA:** IAM é usado para gerenciar o recurso ElastiCache via API,
> mas NÃO para autenticar conexões de aplicações ao cache. Para autenticação de conexão,
> use Redis AUTH (token) ou RBAC (Role-Based Access Control) com Redis 6+.

### 7.4 Security Groups

- Funcionam como firewall virtual no nível do cluster
- Controle de acesso por porta (padrão Redis: 6379, Memcached: 11211)
- Regra típica: permitir inbound somente de SG das instâncias EC2/Lambda

---

## 8. Patterns de Uso

### 8.1 Session Store (Stateless Application)

```
┌──────┐     ┌──────┐     ┌──────┐
│ EC2  │     │ EC2  │     │ EC2  │    ← Auto Scaling Group
│  #1  │     │  #2  │     │  #3  │
└──┬───┘     └──┬───┘     └──┬───┘
   │             │             │
   └─────────────┼─────────────┘
                 │
                 ▼
          ┌──────────────┐
          │  ElastiCache │    ← Session centralizada
          │    Redis     │       com TTL
          └──────────────┘
```

- **Problema:** instâncias EC2 em Auto Scaling Group perdem sessão ao escalar
- **Solução:** armazenar sessão no Redis com TTL
- Qualquer instância pode ler a sessão do usuário
- Aplicação torna-se **stateless** (requisito para Auto Scaling eficiente)
- TTL garante que sessões expiradas são removidas automaticamente

### 8.2 Leaderboard (Redis Sorted Sets)

```
ZADD leaderboard 1500 "player_A"
ZADD leaderboard 2300 "player_B"
ZADD leaderboard 1800 "player_C"

ZREVRANGE leaderboard 0 9    → Top 10 jogadores
ZRANK leaderboard "player_A" → Posição do jogador
ZINCRBY leaderboard 100 "player_A" → +100 pontos
```

- **Sorted Sets:** coleção ordenada por score com complexidade O(log N)
- Operações de ranking, top-N e atualização de score são nativas
- Ideal para leaderboards em tempo real (games, competições)
- Garantia de ordenação automática ao inserir/atualizar

### 8.3 DB Query Caching (Reduzir Load no RDS)

```
┌───────┐      ┌──────────────┐      ┌──────────┐
│  App  │─────►│ ElastiCache  │─────►│   RDS    │
│       │◄─────│   (Redis)    │◄─────│          │
└───────┘      └──────────────┘      └──────────┘

Fluxo:
1. App faz hash da query SQL → key do cache
2. Verifica se key existe no Redis
3. HIT → retorna resultado cacheado
4. MISS → executa query no RDS → armazena resultado no Redis com TTL
```

- Reduz leituras no RDS em **até 90%** para workloads read-heavy
- Ideal para queries repetitivas e dados com mudança moderada
- TTL deve ser definido baseado na frequência de atualização dos dados
- Invalidação: TTL automático ou invalidação explícita em writes

### 8.4 Real-Time Analytics

- Contadores em tempo real (views, likes, clicks) usando INCR/INCRBY
- HyperLogLog para contagem de elementos únicos (ex: unique visitors)
- Bitmaps para tracking de eventos diários (user logged in on day X)
- Redis Streams para ingestão e processamento de eventos ordered

### 8.5 Pub/Sub Messaging (Redis)

```
┌──────────┐    PUBLISH     ┌──────────┐    SUBSCRIBE    ┌──────────┐
│Publisher │───────────────►│  Redis   │────────────────►│Subscriber│
│  (App)   │   channel:     │  Pub/Sub │   channel:      │  (App)   │
└──────────┘   "orders"     └──────────┘   "orders"      └──────────┘
                                │
                                ├────────────────────────►┌──────────┐
                                │                         │Subscriber│
                                │                         │   #2     │
                                └────────────────────────►└──────────┘
```

- Mensagens em tempo real entre componentes
- **Não persiste mensagens** (se subscriber estiver offline, perde a mensagem)
- Para durabilidade, use Redis Streams ou SQS/SNS
- Útil para notificações em tempo real, chat, invalidação de cache distribuído

---

## 9. ElastiCache vs DAX vs CloudFront vs Global Accelerator

### 9.1 Tabela Comparativa — Quando Usar Cada Cache

| Serviço | Tipo de Cache | Caso de Uso Principal | Localização |
|---------|--------------|----------------------|-------------|
| **ElastiCache Redis** | In-memory genérico | Session store, leaderboards, query caching, pub/sub | Dentro da VPC |
| **ElastiCache Memcached** | In-memory simples | Cache de objetos, HTML fragments | Dentro da VPC |
| **DAX (DynamoDB Accelerator)** | In-memory para DynamoDB | Cache de leituras DynamoDB, microssegundos | Dentro da VPC |
| **CloudFront** | CDN (edge cache) | Conteúdo estático/dinâmico para usuários globais | Edge Locations |
| **Global Accelerator** | Network layer | Roteamento otimizado TCP/UDP, failover IP | Edge + AWS backbone |

### 9.2 Regras para a Prova

```
┌─────────────────────────────────────────────────────────────────────┐
│ DECISÃO DE CACHE NO EXAME:                                          │
│                                                                     │
│ "Cache para DynamoDB"          → DAX                                │
│ "Cache para RDS/queries SQL"   → ElastiCache                        │
│ "Cache de conteúdo estático"   → CloudFront                         │
│ "Session store centralizado"   → ElastiCache Redis                  │
│ "Latência global + IP fixo"    → Global Accelerator                 │
│ "Leaderboard / Sorted data"    → ElastiCache Redis                  │
│ "API caching"                  → API Gateway Cache OU CloudFront    │
│ "Cache com microsecond lat."   → DAX (DynamoDB) ou ElastiCache      │
│                                                                     │
│ DAX vs ElastiCache:                                                 │
│   • DAX = API-compatível com DynamoDB (drop-in, sem mudar código)   │
│   • ElastiCache = requer mudança no código da aplicação             │
└─────────────────────────────────────────────────────────────────────┘
```

### 9.3 DAX vs ElastiCache — Diferenças Chave

| Aspecto | DAX | ElastiCache |
|---------|-----|-------------|
| Banco alvo | Somente DynamoDB | Qualquer (RDS, Aurora, APIs) |
| Integração | Transparente (SDK compatível) | Requer mudança no código |
| Latência | Microssegundos | Sub-milissegundo |
| Tipos de dados | Items e Queries DynamoDB | Key-value genérico + estruturas |
| Multi-AZ | ✅ | ✅ (Redis) |
| Cluster | Até 11 nodes | Até 500 shards (Redis) |

---

## 10. Eviction Policies (Políticas de Despejo)

### 10.1 O que são?

Quando a memória do cache está cheia, a eviction policy define **qual key será removida**
para liberar espaço para novas chaves.

### 10.2 Políticas Disponíveis no Redis

| Política | Descrição | Escopo |
|----------|-----------|--------|
| **noeviction** | Retorna erro quando memória cheia (não remove nada) | Todas as keys |
| **allkeys-lru** | Remove a key menos recentemente usada (LRU) | Todas as keys |
| **allkeys-lfu** | Remove a key menos frequentemente usada (LFU) | Todas as keys |
| **allkeys-random** | Remove key aleatória | Todas as keys |
| **volatile-lru** | Remove a key LRU que tenha TTL definido | Apenas keys com TTL |
| **volatile-lfu** | Remove a key LFU que tenha TTL definido | Apenas keys com TTL |
| **volatile-random** | Remove key aleatória com TTL | Apenas keys com TTL |
| **volatile-ttl** | Remove a key com menor TTL restante | Apenas keys com TTL |

### 10.3 Quando Usar Cada Política

```
┌─────────────────────────────────────────────────────────────────┐
│ RECOMENDAÇÕES:                                                  │
│                                                                 │
│ • allkeys-lru    → Padrão recomendado (cache genérico)          │
│ • allkeys-lfu    → Quando poucos itens são muito acessados      │
│ • volatile-lru   → Mix de dados persistentes + cache            │
│ • volatile-ttl   → Quando TTL reflete prioridade                │
│ • noeviction     → Quando perda de dados é inaceitável          │
│                    (ex: session store sem redundância)           │
└─────────────────────────────────────────────────────────────────┘
```

### 10.4 LRU vs LFU

- **LRU (Least Recently Used):** remove o item que não é acessado há mais tempo
  - Bom para: padrões de acesso que mudam ao longo do tempo
  - Problema: um scan de muitas keys pode evictar keys populares

- **LFU (Least Frequently Used):** remove o item acessado menos vezes
  - Bom para: workloads com "hot keys" estáveis
  - Problema: keys que foram populares no passado mas não são mais ficam no cache

---

## 11. Monitoring — CloudWatch Metrics

### 11.1 Métricas Críticas

| Métrica | Descrição | Ação quando Alta |
|---------|-----------|-----------------|
| **CPUUtilization** | CPU do host (inclui processos do SO) | Scale up (node maior) |
| **EngineCPUUtilization** | CPU usada pelo engine Redis/Memcached | Verificar hot keys, otimizar queries |
| **CurrConnections** | Conexões ativas ao cache | Verificar connection pooling |
| **Evictions** | Número de keys removidas por falta de memória | Aumentar memória ou ajustar TTLs |
| **CacheMisses** | Número de leituras que não encontraram a key | Verificar TTL, pre-warming |
| **CacheHits** | Número de leituras bem-sucedidas | Métrica de saúde (quanto maior, melhor) |
| **ReplicationLag** | Atraso da replica em relação ao primary (segundos) | Verificar carga do primary |
| **FreeableMemory** | Memória disponível no node | Se baixa, escalar ou ajustar eviction |
| **NetworkBytesIn/Out** | Tráfego de rede | Verificar limites do node type |
| **SwapUsage** | Uso de swap (memória em disco) | **Deve ser 0!** Se > 0, scale up urgente |

### 11.2 Alarmes Recomendados

```
┌─────────────────────────────────────────────────────────────────┐
│ ALARMES CloudWatch RECOMENDADOS:                                │
│                                                                 │
│ • EngineCPUUtilization > 90% por 5 min → Alarme CRITICAL        │
│ • Evictions > 0 constante → Alarme WARNING (memória insuficiente)│
│ • SwapUsage > 50MB → Alarme CRITICAL (scale up imediato)        │
│ • ReplicationLag > 1s → Alarme WARNING (verificar primary)      │
│ • CurrConnections próximo ao limite → Alarme WARNING            │
│ • CacheMisses / (CacheMisses + CacheHits) > 80% → Cache ineficaz│
└─────────────────────────────────────────────────────────────────┘
```

### 11.3 EngineCPUUtilization vs CPUUtilization

- **CPUUtilization:** inclui SO, processos auxiliares, e o engine
- **EngineCPUUtilization:** **somente** o processo Redis/Memcached
- Para Redis (single-threaded): se EngineCPUUtilization > 90%, o engine está saturado
- Solução: escalar horizontalmente (Cluster Mode Enabled) ou vertical

---

## 12. Palavras-Chave da Prova SAA-C03

### 12.1 Cenários e Respostas — Mínimo 15 Padrões

| # | Cenário na Prova | Resposta |
|---|-----------------|----------|
| 1 | "Reduzir latência de leituras repetitivas no RDS" | ElastiCache com Lazy Loading + TTL |
| 2 | "Aplicação stateless com sessões compartilhadas entre EC2" | ElastiCache Redis como Session Store |
| 3 | "Leaderboard em tempo real para jogo online" | ElastiCache Redis com Sorted Sets |
| 4 | "Cache para DynamoDB com latência de microssegundos" | DAX (NÃO ElastiCache) |
| 5 | "Cache com alta disponibilidade e failover automático" | ElastiCache Redis com Multi-AZ |
| 6 | "Cache simples, multi-threaded, sem necessidade de persistência" | ElastiCache Memcached |
| 7 | "Disaster recovery para cache cross-region" | Redis Global Datastore |
| 8 | "Cache com encryption at-rest e in-transit" | ElastiCache Redis com KMS + TLS |
| 9 | "Pub/Sub messaging em tempo real" | ElastiCache Redis Pub/Sub |
| 10 | "Escalar cache horizontalmente para datasets grandes" | Redis Cluster Mode Enabled |
| 11 | "Dados no cache ficando desatualizados (stale)" | Implementar TTL + Write-Through |
| 12 | "Cache está ficando sem memória, keys sendo removidas" | Verificar Evictions metric, scale up ou ajustar TTL |
| 13 | "Autenticar conexões ao ElastiCache Redis" | Redis AUTH token (NÃO IAM) |
| 14 | "Gerenciar quem pode criar/deletar clusters ElastiCache" | IAM Policies |
| 15 | "Reduzir custo de leituras no Aurora sem mudar arquitetura" | ElastiCache na frente do Aurora |
| 16 | "Armazenar dados geoespaciais com queries de proximidade" | ElastiCache Redis (GEOADD, GEORADIUS) |

### 12.2 Palavras-Chave que Indicam ElastiCache na Prova

```
┌─────────────────────────────────────────────────────────────────────┐
│ TRIGGERS para ElastiCache:                                          │
│                                                                     │
│ • "in-memory cache"                                                 │
│ • "sub-millisecond latency"                                         │
│ • "reduce database load"                                            │
│ • "session management" / "session store"                            │
│ • "leaderboard" / "ranking"                                         │
│ • "stateless application"                                           │
│ • "cache query results"                                             │
│ • "reduce read replicas cost"                                       │
│ • "real-time" + "low latency"                                       │
│ • "pub/sub" (sem necessidade de durabilidade)                       │
│                                                                     │
│ TRIGGERS para NÃO ser ElastiCache:                                  │
│                                                                     │
│ • "DynamoDB" + "cache" → DAX                                        │
│ • "static content" + "global" → CloudFront                          │
│ • "persistent queue" → SQS                                          │
│ • "durable messaging" → SNS + SQS                                   │
│ • "complex queries" → RDS/Aurora read replicas                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 12.3 Pegadinhas Comuns

| Pegadinha | Verdade |
|-----------|---------|
| "IAM autentica conexões ao Redis" | ❌ FALSO — IAM só gerencia API calls. Use Redis AUTH |
| "Memcached suporta Multi-AZ failover" | ❌ FALSO — Somente Redis |
| "ElastiCache substitui o banco de dados" | ❌ FALSO — É uma camada de cache, não substituto |
| "DAX funciona com qualquer banco" | ❌ FALSO — DAX é SOMENTE para DynamoDB |
| "Global Datastore tem failover automático" | ❌ FALSO — Failover cross-region é MANUAL |
| "Redis Cluster Mode suporta operações multi-key sem restrição" | ❌ FALSO — Limitado ao mesmo hash slot |
| "Encryption at-rest funciona no Memcached" | ❌ FALSO — Somente Redis suporta KMS |

---

## Resumo Visual — Árvore de Decisão

```
                        Preciso de CACHE?
                              │
                    ┌─────────┴──────────┐
                    │                    │
              Para DynamoDB?        Para outro serviço?
                    │                    │
                    ▼                    ▼
                  DAX              É conteúdo estático
                                  servido globalmente?
                                        │
                                  ┌─────┴─────┐
                                  │           │
                                 SIM         NÃO
                                  │           │
                                  ▼           ▼
                              CloudFront   ElastiCache
                                              │
                                     ┌────────┴────────┐
                                     │                 │
                              Precisa de:         Apenas cache
                              • Persistência      simples +
                              • Multi-AZ          multi-thread?
                              • Sorted Sets           │
                              • Pub/Sub               ▼
                                     │           Memcached
                                     ▼
                                   Redis
                                     │
                              ┌──────┴──────┐
                              │             │
                         Dataset         Dataset
                         pequeno         grande
                              │             │
                              ▼             ▼
                        Cluster Mode   Cluster Mode
                         Disabled       Enabled
```

---

*Última atualização: Julho 2026 — Preparação SAA-C03*
