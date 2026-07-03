# ElastiCache

## Redis vs Memcached — DIFERENÇA CRÍTICA

| | Redis | Memcached |
|-|-------|-----------|
| Persistência | ✅ Sim (RDB e AOF) | ❌ Não |
| Backup e restore | ✅ Sim | ❌ Não |
| Replicação | ✅ Multi-AZ com failover | ❌ Não |
| Clustering (sharding) | ✅ Cluster Mode | ✅ Multithreaded nativo |
| Multi-AZ | ✅ Sim | ❌ Não |
| Sorted Sets | ✅ Sim | ❌ Não |
| Pub/Sub | ✅ Sim | ❌ Não |
| Threads | Single-threaded | Multi-threaded |
| Casos de uso | Session store, leaderboards, pub/sub, ML | Cache simples de alta performance |

> **Regra:** Se precisar de persistência, replicação, multi-AZ ou estruturas de dados avançadas → **Redis**. Se quiser apenas cache simples e multithreaded → **Memcached**.

## Caching Strategies

### Lazy Loading (Cache-Aside)
```
App → Cache HIT → retorna dado
App → Cache MISS → busca no DB → grava no cache → retorna dado
```
- **Vantagens:** só carrega dados que são efetivamente requisitados
- **Desvantagens:** primeira leitura sempre vai ao banco (cache miss penalty); dados podem ficar stale

### Write-Through
```
App → escreve no DB → escreve no cache (sempre)
```
- **Vantagens:** cache sempre atualizado, sem dados stale
- **Desvantagens:** escreve dados que podem nunca ser lidos; overhead em cada write

### Session Store
- Armazenar sessões de usuário de forma centralizada
- Permite que múltiplas instâncias EC2 compartilhem sessões (stateless app)
- Redis com TTL é a solução padrão

## Redis Cluster Mode

| | Cluster Mode Disabled | Cluster Mode Enabled |
|-|----------------------|---------------------|
| Shards | 1 primary + até 5 replicas | Até 500 shards |
| Escalabilidade | Vertical (mudar tipo de instância) | Horizontal (adicionar shards) |
| Multi-AZ | ✅ | ✅ |
| Quando usar | Datasets menores, operações multi-key | Datasets grandes, alta escrita |

## Casos de Uso no SAA-C03

| Cenário | Solução |
|---------|---------|
| Reduzir leitura no RDS | ElastiCache com Lazy Loading |
| Compartilhar sessões entre instâncias EC2 | ElastiCache Redis com TTL |
| Leaderboard em tempo real | ElastiCache Redis (Sorted Sets) |
| Cache de resultados de queries | ElastiCache (qualquer) |
| DynamoDB com latência de microssegundos | DAX (não ElastiCache) |

## Diferenças Críticas

- **ElastiCache Redis vs DAX:** ElastiCache é genérico; DAX é específico para DynamoDB e API-compatível
- **Lazy Loading vs Write-Through:** Lazy = dados stale possíveis; Write-Through = cache sempre atualizado mas com overhead
- **Redis vs RDS:** ElastiCache não substitui banco de dados; é uma camada de cache na frente do banco
