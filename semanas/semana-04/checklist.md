# Semana 04 — Bancos de Dados
> 23/07 a 29/07/2026

## Checklist de Estudo

### RDS
- [ ] Assistir aulas de RDS no curso
- [ ] Engines: MySQL, PostgreSQL, MariaDB, Oracle, SQL Server
- [ ] Multi-AZ: failover automático, sincrônico, standby NÃO serve leitura
- [ ] Read Replicas: assíncrono, melhora leitura, pode ser cross-region
- [ ] Multi-AZ vs Read Replica — DIFERENÇA CRÍTICA
- [ ] Automated Backups vs Manual Snapshots
- [ ] RDS Proxy: pooling de conexões
- [ ] Encryption at rest (KMS) e in transit (SSL/TLS)
- [ ] IAM Database Authentication

### Aurora
- [ ] Assistir aulas de Aurora no curso
- [ ] Storage distribuído: 6 cópias em 3 AZs
- [ ] Aurora Reader Endpoint e Writer Endpoint
- [ ] Aurora Serverless v2
- [ ] Aurora Global Database: réplica cross-region com <1s lag
- [ ] Aurora Multi-Master
- [ ] Backtrack: volta no tempo sem restore
- [ ] Aurora Replicas (até 15) vs RDS Read Replicas (até 5)

### ElastiCache
- [ ] Redis vs Memcached — DIFERENÇA CRÍTICA
- [ ] Caching Strategies: Lazy Loading vs Write-Through
- [ ] Redis: persistência, backup, multi-AZ, sorted sets
- [ ] Memcached: multithreaded, sem persistência
- [ ] Redis Cluster Mode (sharding)

### Outros Bancos
- [ ] Redshift: OLAP, data warehouse, columnar
- [ ] Neptune: banco de grafos
- [ ] DocumentDB: MongoDB compatível
- [ ] Keyspaces: Cassandra compatível
- [ ] Timestream: séries temporais
- [ ] DynamoDB (preview — aprofunda semana 5)

### Prática
- [ ] Criar RDS MySQL com Multi-AZ
- [ ] Criar Read Replica
- [ ] Testar failover Multi-AZ
- [ ] Lab: `lab-05-rds-multi-az`

## Simulado da Semana
- [ ] 20 questões de RDS/Aurora — Tutorials Dojo
- [ ] 20 questões de ElastiCache/DynamoDB — Tutorials Dojo
- [ ] Revisar todos os erros

## Horas Estudadas
| Dia | Horas | Observações |
|-----|-------|-------------|
| Qua 23/07 | | |
| Qui 24/07 | | |
| Sex 25/07 | | |
| Sáb 26/07 | | |
| Dom 27/07 | | |
| Seg 28/07 | | |
| Ter 29/07 | | |
| **Total** | | |
