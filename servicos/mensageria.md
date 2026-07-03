# Mensageria — SQS, SNS, EventBridge, Kinesis

## Quando usar cada um — Tabela Geral

| | SQS | SNS | EventBridge | Kinesis |
|-|-----|-----|-------------|---------|
| Modelo | Queue (pull) | Pub/Sub (push) | Event Bus (push) | Streaming (pull) |
| Consumers | 1 consumer por mensagem | N subscribers | N targets | N consumers |
| Persistência | Até 14 dias | Não persiste | Não persiste | 1-365 dias |
| Ordering | Standard: não | Não | Não | Por shard |
| Replay | ❌ | ❌ | ❌ | ✅ |
| Casos de uso | Desacoplamento, filas de trabalho | Fan-out, notificações | Eventos de serviços AWS | Streaming, analytics em tempo real |

---

## SQS — Simple Queue Service

### Standard vs FIFO
| | Standard | FIFO |
|-|----------|------|
| Ordering | Best-effort (não garantido) | Garantido (FIFO) |
| Entrega | At-least-once (pode duplicar) | Exactly-once |
| Throughput | Ilimitado | 300 TPS (3.000 com batching) |
| Sufixo obrigatório | — | `.fifo` |

### Parâmetros Importantes
- **Visibility Timeout:** tempo que a mensagem fica invisível após ser consumida (padrão 30s, máx 12h). Deve ser maior que o tempo de processamento.
- **Dead Letter Queue (DLQ):** recebe mensagens que falharam N vezes (maxReceiveCount). Essencial para depuração.
- **Delay Queue:** atrasa a entrega de novas mensagens (0-15 min). Útil para processamento com delay intencional.
- **Long Polling:** aguarda até 20s por mensagens. Reduz chamadas vazias e custo.
- **Message Retention:** 4 dias padrão, configurável até 14 dias.
- **Tamanho máximo:** 256KB. Para mensagens maiores, usar S3 + Extended Client Library.

### SQS com ASG
- CloudWatch Alarm monitorando `ApproximateNumberOfMessagesVisible`
- Alarm dispara scaling policy do ASG
- Pattern clássico para processamento assíncrono escalável

---

## SNS — Simple Notification Service

- **Topic:** canal de publicação
- **Subscribers:** SQS, Lambda, HTTP/HTTPS, Email, SMS, Mobile Push
- **Fan-out Pattern:** SNS → múltiplas SQS — padrão para processamento paralelo
- **Message Filtering:** filter policies por atributos da mensagem (cada subscriber recebe só o que quer)
- **SNS FIFO:** ordering garantido, deduplication, apenas SQS FIFO como subscriber

### Fan-out Pattern
```
Produtor → SNS Topic → SQS Queue 1 (processamento A)
                    → SQS Queue 2 (processamento B)
                    → Lambda      (notificação)
```
Usado para: processar eventos em paralelo de forma desacoplada

---

## EventBridge

- Formerly CloudWatch Events
- **Default Event Bus:** eventos de serviços AWS (EC2, S3, RDS, etc.)
- **Custom Event Bus:** eventos da sua aplicação
- **Partner Event Bus:** eventos de SaaS (Datadog, Zendesk, etc.)

### Rules
- **Event Pattern:** filtra eventos por estrutura JSON (ex: EC2 instance state = terminated)
- **Schedule:** cron ou rate expression (ex: `rate(5 minutes)`)

### Targets
Lambda, SQS, SNS, ECS Task, Step Functions, API Gateway, Kinesis, CodePipeline, e outros

### EventBridge vs CloudWatch Events
- São o mesmo serviço — EventBridge é o nome novo com features adicionais

---

## Kinesis

### Data Streams vs Data Firehose — DIFERENÇA CRÍTICA

| | Kinesis Data Streams | Kinesis Data Firehose |
|-|---------------------|----------------------|
| Tipo | Streaming em tempo real | Near real-time (buffer) |
| Latência | ~200ms | 60s ou 1MB (o que vier primeiro) |
| Consumers | Custom (Lambda, KDA, apps) | Destinos gerenciados |
| Destinos | Flexível (você escreve o consumer) | S3, Redshift, OpenSearch, Splunk |
| Replay | ✅ Sim (1-365 dias) | ❌ Não |
| Escala | Manual (shards) | Automática |
| Transformação | No consumer | Lambda integrado |

### Shards (Data Streams)
- **1 shard** = 1MB/s entrada, 2MB/s saída
- Escalar: shard split (mais shards) ou merge (menos shards)
- **Partition Key** determina para qual shard a mensagem vai

### SQS vs Kinesis — Quando usar cada
| Cenário | Use |
|---------|-----|
| Processamento de mensagens individuais, desacoplamento | SQS |
| Streaming de logs, clickstream, IoT | Kinesis Data Streams |
| ETL para S3/Redshift sem código de consumer | Kinesis Firehose |
| Múltiplos consumers independentes no mesmo stream | Kinesis Data Streams |
| Ordenação garantida + exactly-once delivery | SQS FIFO |

---

## MSK — Managed Streaming for Apache Kafka
- Kafka gerenciado pela AWS
- Substitui Kinesis quando já existe expertise em Kafka
- Maior flexibilidade de configuração, mas mais complexo
