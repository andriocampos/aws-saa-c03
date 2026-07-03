# RDS — Relational Database Service

## Engines Suportadas

MySQL, PostgreSQL, MariaDB, Oracle, SQL Server, Db2

## Multi-AZ vs Read Replicas — DIFERENÇA CRÍTICA

| | Multi-AZ | Read Replicas |
|-|----------|---------------|
| Objetivo | Alta disponibilidade | Performance de leitura |
| Replicação | Síncrona | Assíncrona |
| Standby serve tráfego | ❌ Não | ✅ Sim (somente leitura) |
| Failover automático | ✅ Sim (~1-2 min) | ❌ Manual (promoção) |
| Cross-region | ❌ Mesma região | ✅ Possível |
| Custo | 2x a instância | Por instância adicional |

## Aurora

- Storage distribuído: 6 cópias em 3 AZs automaticamente
- Aurora é até 5x mais rápido que MySQL RDS
- **Aurora Serverless v2:** auto-scaling instantâneo de capacidade
- **Aurora Global Database:** réplica cross-region com lag <1s, até 16 read replicas por região
- **Backtrack:** voltar no tempo sem restore de snapshot (apenas MySQL)
- Até 15 Aurora Replicas (vs 5 Read Replicas no RDS)

## Backups

| Tipo | Retenção | Restore |
|------|----------|---------|
| Automated Backup | 1-35 dias | Point-in-time |
| Manual Snapshot | Indefinido | Por snapshot |

## RDS Proxy

- Pool de conexões de banco de dados
- Reduz stress no banco em caso de muitas conexões (ex: Lambda)
- Failover mais rápido (até 66% mais rápido)
- IAM Authentication e Secrets Manager integration
