# Semana 06 — Integração + CDN
> 06/08 a 12/08/2026

## Checklist de Estudo

### SQS
- [ ] Standard Queue vs FIFO Queue
- [ ] Visibility Timeout (padrão 30s, máx 12h)
- [ ] Dead Letter Queue (DLQ)
- [ ] Delay Queue
- [ ] Long Polling vs Short Polling
- [ ] SQS com ASG: escalar EC2 baseado na fila

### SNS
- [ ] Topics e Subscriptions
- [ ] Subscribers: SQS, Lambda, HTTP/HTTPS, Email, SMS
- [ ] Fan-out pattern: SNS → múltiplas SQS
- [ ] SNS FIFO
- [ ] Message Filtering

### EventBridge
- [ ] Event Bus: default, custom, partner
- [ ] Rules: event pattern matching ou schedule
- [ ] Targets: Lambda, SQS, SNS, ECS, Step Functions
- [ ] EventBridge Pipes e Scheduler

### Kinesis
- [ ] Kinesis Data Streams: shards, retenção, replay
- [ ] Kinesis Data Firehose: near real-time, destinos S3/Redshift/OpenSearch
- [ ] SQS vs Kinesis — DIFERENÇA CRÍTICA
- [ ] MSK (Managed Kafka)

### CloudFront
- [ ] Edge Locations e Regional Edge Caches
- [ ] Origins: S3, ALB, Custom
- [ ] OAC (Origin Access Control): CloudFront → S3 private
- [ ] Cache Behaviors e cache policies
- [ ] Geo Restriction
- [ ] Signed URLs vs Signed Cookies
- [ ] CloudFront Functions vs Lambda@Edge

### Global Accelerator
- [ ] 2 Anycast IPs estáticos globais
- [ ] CloudFront vs Global Accelerator — DIFERENÇA CRÍTICA

## Simulado da Semana
- [ ] 20 questões de SQS/SNS/EventBridge — Tutorials Dojo
- [ ] 20 questões de CloudFront/GA — Tutorials Dojo
- [ ] Revisar todos os erros

## Horas Estudadas
| Dia | Horas | Observações |
|-----|-------|-------------|
| Qua 06/08 | | |
| Qui 07/08 | | |
| Sex 08/08 | | |
| Sáb 09/08 | | |
| Dom 10/08 | | |
| Seg 11/08 | | |
| Ter 12/08 | | |
| **Total** | | |
