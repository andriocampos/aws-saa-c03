# Mensageria e Streaming — SQS, SNS, EventBridge, Kinesis, MSK, Amazon MQ

> Guia aprofundado para a certificação AWS SAA-C03

---

## 1. Visão Geral e Quando Usar Cada Serviço

### 1.1 Tabela Comparativa Geral

| Característica | SQS | SNS | EventBridge | Kinesis Data Streams | Kinesis Firehose |
|---|---|---|---|---|---|
| Modelo | Queue (pull) | Pub/Sub (push) | Event Bus (push) | Streaming (pull/push) | Delivery stream (push) |
| Consumers | 1 por mensagem | N subscribers | N targets por rule | N consumers por shard | Destinos gerenciados |
| Persistência | Até 14 dias | Não persiste | Archive (opcional) | 1–365 dias | Não persiste |
| Ordering | Standard: não / FIFO: sim | FIFO: sim | Não garantido | Por shard (partition key) | Não garantido |
| Replay | ❌ | ❌ | ✅ (Archive & Replay) | ✅ Nativo | ❌ |
| Throughput | Ilimitado (Standard) | Ilimitado | Ilimitado (soft limits) | 1MB/s in por shard | Auto-scaling |
| Latência | ms | ms | ms | ~200ms | 60s–900s (buffer) |
| Transformação | Não | Não | Pipes (enrich) | Consumer custom | Lambda integrado |
| Caso de uso principal | Desacoplamento, filas de trabalho | Fan-out, notificações | Eventos AWS/SaaS, automação | Streaming real-time, analytics | ETL para S3/Redshift/OpenSearch |

### 1.2 Diagrama de Decisão

```
┌─────────────────────────────────────────────────────────────┐
│              PRECISO DESACOPLAR COMPONENTES?                 │
└─────────────────────┬───────────────────────────────────────┘
                      │
          ┌───────────▼───────────┐
          │ Precisa de replay?    │
          └───┬───────────────┬───┘
              │ NÃO           │ SIM
              ▼               ▼
   ┌──────────────┐   ┌──────────────────┐
   │ 1:1 ou N:1?  │   │ Kinesis Streams   │
   └──┬────────┬──┘   │ ou EventBridge    │
      │        │       │ Archive & Replay  │
      ▼        ▼       └──────────────────┘
  ┌──────┐ ┌──────┐
  │ SQS  │ │ SNS  │
  │(1:1) │ │(1:N) │
  └──────┘ └──────┘
```

---

## 2. SQS Standard vs FIFO — Tabela Completa

| Atributo | Standard | FIFO |
|---|---|---|
| Ordering | Best-effort (sem garantia) | Estritamente ordenado dentro do Message Group |
| Delivery | At-least-once (pode duplicar) | Exactly-once processing |
| Throughput (sem batching) | Ilimitado | 300 msg/s (send/receive/delete) |
| Throughput (com batching) | Ilimitado | 3.000 msg/s |
| Throughput (high throughput mode) | Ilimitado | 30.000 msg/s (com partições) |
| Deduplication | Não nativa | 5 minutos de janela de dedup |
| Message Group ID | Não aplicável | Obrigatório (define ordering parcial) |
| Sufixo do nome da fila | Qualquer | Deve terminar em `.fifo` |
| Preço | Mais barato | ~20% mais caro |
| Consumers simultâneos | Ilimitados | 1 por Message Group ID em processamento |
| Caso de uso | Alto throughput, tolerância a duplicatas | Transações financeiras, ordering crítico |

---

## 3. Visibility Timeout

### 3.1 Conceito

Quando um consumer recebe uma mensagem, ela fica **invisível** para outros consumers durante o Visibility Timeout. Se o consumer não deletar a mensagem nesse período, ela volta a ficar visível.

### 3.2 Valores

- **Padrão:** 30 segundos
- **Mínimo:** 0 segundos
- **Máximo:** 12 horas

### 3.3 Problemas Comuns

| Situação | Consequência | Solução |
|---|---|---|
| Timeout CURTO demais | Mensagem reaparece antes do processamento terminar → processada 2x | Aumentar o timeout |
| Timeout LONGO demais | Se consumer falhar, mensagem demora a reaparecer → alta latência de retry | Usar ChangeMessageVisibility |

### 3.4 ChangeMessageVisibility API

- Consumer pode chamar `ChangeMessageVisibility` para **estender** o timeout enquanto processa
- Padrão: consumer pede mais tempo se percebe que precisa de mais processamento
- Evita reprocessamento sem precisar configurar timeout excessivamente alto

```
Consumer recebe msg → Timeout = 30s → Processamento lento detectado
    → Chama ChangeMessageVisibility(newTimeout=60s) → Continua processando
```

---

## 4. Dead Letter Queue (DLQ)

### 4.1 Conceito

Fila separada que recebe mensagens que falharam repetidamente no processamento.

### 4.2 Configuração

- **maxReceiveCount:** número máximo de vezes que a mensagem pode ser recebida antes de ir para DLQ (ex: 3)
- **Redrive Policy:** JSON que define a DLQ target ARN e o maxReceiveCount

```json
{
  "deadLetterTargetArn": "arn:aws:sqs:us-east-1:123456789:my-dlq",
  "maxReceiveCount": 3
}
```

### 4.3 DLQ Redrive to Source

- Permite reprocessar mensagens da DLQ enviando-as de volta para a fila original
- Útil após corrigir o bug que causava as falhas
- Disponível via console e API

### 4.4 Quando Usar

- Mensagens com erros de parsing que nunca serão processadas com sucesso
- Debugging: analisar mensagens problemáticas
- Alertas: CloudWatch Alarm quando DLQ recebe mensagens
- **Importante para prova:** DLQ de uma fila Standard deve ser Standard; DLQ de FIFO deve ser FIFO

### 4.5 Retention da DLQ

- Configurar retention da DLQ para o **máximo (14 dias)** para ter tempo de analisar
- O timestamp de expiração é baseado no **enqueue original**, não quando chegou na DLQ

---

## 5. Delay Queue vs Message Timer

| Aspecto | Delay Queue | Message Timer |
|---|---|---|
| Escopo | Toda a fila | Mensagem individual |
| Configuração | `DelaySeconds` na fila | `DelaySeconds` na mensagem |
| Range | 0–15 minutos | 0–15 minutos |
| Prioridade | — | Sobrescreve o delay da fila |
| FIFO suporte | Sim (mas delay por msg não funciona em FIFO) | Não funciona em FIFO |
| Caso de uso | Atrasar todas as mensagens (ex: batch scheduled) | Atrasar uma mensagem específica |

---

## 6. Long Polling vs Short Polling

| Aspecto | Short Polling | Long Polling |
|---|---|---|
| Comportamento | Retorna imediatamente (pode retornar vazio) | Espera até ter mensagem ou timeout |
| WaitTimeSeconds | 0 (padrão) | 1–20 segundos |
| Custo | MAIOR (mais chamadas API vazias) | MENOR (menos chamadas) |
| Latência | Pode perder mensagens recém-chegadas | Captura mensagens assim que chegam |
| Configuração (fila) | `ReceiveMessageWaitTimeSeconds = 0` | `ReceiveMessageWaitTimeSeconds > 0` |
| Configuração (chamada) | Não enviar WaitTimeSeconds | `WaitTimeSeconds=20` na API call |

### 6.1 Recomendação

- **Sempre usar Long Polling** (WaitTimeSeconds=20) salvo necessidade de resposta imediata
- Reduz custo em até 90% comparado com short polling agressivo
- Configurar na fila (nível de fila) ou por chamada de API (nível de consumer)

---

## 7. Message Retention e Tamanho

### 7.1 Retenção

- **Padrão:** 4 dias (345.600 segundos)
- **Mínimo:** 60 segundos
- **Máximo:** 14 dias (1.209.600 segundos)

### 7.2 Tamanho da Mensagem

- **Máximo:** 256 KB
- **Para mensagens maiores:** usar SQS Extended Client Library
  - Armazena payload no S3
  - Envia referência (ponteiro S3) na mensagem SQS
  - Consumer usa a mesma library para buscar do S3
  - Suporta mensagens de até 2 GB

```
┌──────────┐    payload > 256KB    ┌────┐
│ Producer │ ─────────────────────→│ S3 │
│          │                       └────┘
│          │    referência (< 256KB)   │
│          │ ──────────────────→ ┌─────▼─────┐
└──────────┘                     │  SQS Queue │
                                 └─────┬─────┘
                                       │ referência
                                 ┌─────▼─────┐
                                 │  Consumer  │──→ busca payload no S3
                                 └───────────┘
```

---

## 8. SQS + Auto Scaling Group (ASG) Pattern

### 8.1 Diagrama

```
┌──────────┐     ┌───────────┐     ┌─────────────────────┐
│ Producers│────→│ SQS Queue │────→│  EC2 Instances (ASG) │
└──────────┘     └─────┬─────┘     └─────────────────────┘
                       │                       ▲
                       │ métrica               │ scale out/in
                       ▼                       │
              ┌─────────────────┐    ┌─────────┴────────┐
              │  CloudWatch     │───→│  Scaling Policy   │
              │  Alarm          │    │  (Step/Target)    │
              └─────────────────┘    └──────────────────┘
```

### 8.2 Métrica Chave

- **ApproximateNumberOfMessagesVisible** — mensagens disponíveis para processamento
- Configurar alarme: se > X mensagens → scale out
- Custom metric recomendada: `BacklogPerInstance = ApproximateNumberOfMessagesVisible / NumberOfInstances`

### 8.3 Configuração Típica

1. CloudWatch Alarm monitora `ApproximateNumberOfMessagesVisible`
2. Se mensagens acumulam → alarme dispara → ASG adiciona instâncias
3. Se fila esvazia → alarme retorna → ASG remove instâncias
4. Target Tracking: manter backlog por instância em N mensagens

---

## 9. SQS como Buffer (Desacoplamento)

### 9.1 Absorver Picos de Tráfego

```
┌────────────────┐         ┌───────────┐         ┌──────────────┐
│  Frontend      │         │           │         │  Backend     │
│  (picos de     │────────→│ SQS Queue │────────→│  (processa   │
│   tráfego)     │  rápido │           │  ritmo  │   no ritmo)  │
└────────────────┘         └───────────┘  const. └──────────────┘
     10.000 req/s              buffer           1.000 req/s
```

### 9.2 Write Buffer para Banco de Dados

```
┌─────────┐     ┌───────────┐     ┌──────────┐     ┌────────┐
│  API GW  │───→│ SQS Queue │───→│  Lambda   │───→│  RDS   │
└─────────┘     └───────────┘     └──────────┘     └────────┘
   burst           buffer          controlado      sem sobrecarga
```

- Protege o banco de dados de picos de escrita
- Lambda processa em batch com concurrency controlada
- Sem perda de dados mesmo sob carga extrema

### 9.3 Padrão de Desacoplamento

- Serviço A não precisa conhecer Serviço B
- Se B ficar fora do ar, mensagens aguardam na fila
- Retry automático quando B volta
- Cada serviço escala independentemente


---

## 10. SQS FIFO — Deduplication e Message Group ID

### 10.1 Deduplication (Exactly-Once Processing)

| Método | Como funciona | Quando usar |
|---|---|---|
| Content-Based Dedup | SHA-256 hash do body da mensagem | Quando o body é único por natureza |
| Message Deduplication ID | ID explícito enviado pelo producer | Quando o body pode repetir mas a intenção é diferente |

- **Janela de dedup:** 5 minutos
- Se mesma mensagem (mesmo dedup ID ou hash) for enviada em 5 min, é descartada
- Habilitar content-based: `ContentBasedDeduplication = true` na fila

### 10.2 Message Group ID — Ordering Parcial

- Mensagens com **mesmo Message Group ID** são processadas em ordem FIFO
- Mensagens com **Message Group IDs diferentes** podem ser processadas em paralelo
- Cada Message Group ID tem no máximo 1 consumer ativo

```
Message Group ID = "user-123" → [msg1, msg2, msg3] → processadas em ordem
Message Group ID = "user-456" → [msg4, msg5, msg6] → processadas em ordem (paralelo ao grupo acima)
```

### 10.3 Scaling com FIFO

- Para aumentar throughput: usar múltiplos Message Group IDs
- Cada grupo pode ser processado por um consumer diferente
- High Throughput Mode: até 30.000 msg/s com múltiplas partições internas

---

## 11. Temporary Queues e Request-Response Pattern

### 11.1 Temporary Queue Client

- Cria filas virtuais sobre uma única fila FIFO real
- Reduz overhead de criação/destruição de filas
- Ideal para padrão request-response

### 11.2 Request-Response Pattern

```
┌──────────┐  request (+ ReplyTo queue)  ┌───────────────┐
│  Client  │ ──────────────────────────→ │ Request Queue │
│          │                              └───────┬───────┘
│          │                                      │
│          │                                      ▼
│          │                              ┌───────────────┐
│          │  response                    │    Server     │
│          │ ←────────────────────────── │               │
└──────────┘    (via Temporary Queue)     └───────────────┘
```

- Client envia mensagem com atributo `ReplyToQueueUrl`
- Server processa e responde na fila temporária
- Fila temporária é deletada após resposta ou timeout
- Alternativa serverless: API Gateway + Lambda + SQS

---

## 12. SNS — Conceitos Fundamentais

### 12.1 Componentes

| Componente | Descrição |
|---|---|
| **Topic** | Canal lógico de publicação (Standard ou FIFO) |
| **Publisher** | Quem publica mensagens no topic (app, serviço AWS, etc.) |
| **Subscription** | Ligação entre topic e endpoint de destino |
| **Subscriber** | Endpoint que recebe as mensagens (SQS, Lambda, etc.) |

### 12.2 Limites Importantes

- Até **12.500.000** subscriptions por topic
- Até **100.000** topics por conta
- Mensagem máxima: 256 KB
- Para mensagens maiores: SNS Extended Client Library (similar ao SQS)

---

## 13. Subscribers Suportados pelo SNS

| Subscriber | Protocolo | Caso de Uso |
|---|---|---|
| SQS | sqs | Fan-out, processamento assíncrono |
| Lambda | lambda | Processamento serverless de eventos |
| HTTP/HTTPS | http/https | Webhooks, integração com APIs externas |
| Email | email / email-json | Notificações para pessoas |
| SMS | sms | Alertas via texto |
| Mobile Push | application | Notificações push (iOS, Android, etc.) |
| Kinesis Data Firehose | firehose | Archiving, analytics |

---

## 14. Fan-out Pattern (SNS → Múltiplas SQS)

### 14.1 Diagrama

```
                              ┌───────────────┐     ┌────────────────────┐
                         ┌───→│  SQS Queue A  │────→│ Service A (emails) │
                         │    └───────────────┘     └────────────────────┘
┌──────────┐    ┌────────┴──┐
│ Producer │───→│ SNS Topic │ ┌───────────────┐     ┌────────────────────┐
└──────────┘    └────────┬──┘─┤  SQS Queue B  │────→│ Service B (analytics)│
                         │    └───────────────┘     └────────────────────┘
                         │    ┌───────────────┐     ┌────────────────────┐
                         └───→│  SQS Queue C  │────→│ Service C (audit)  │
                              └───────────────┘     └────────────────────┘
```

### 14.2 Vantagens do Fan-out

- **Desacoplamento total:** producer não conhece os consumers
- **Escalabilidade independente:** cada fila escala separadamente
- **Confiabilidade:** se um consumer falha, os outros continuam
- **Adição de consumers:** basta criar nova subscription, zero mudança no producer
- **Retry independente:** cada SQS tem sua DLQ

### 14.3 Requisitos

- SQS Queue deve ter **Access Policy** permitindo SNS publicar nela
- Cross-account fan-out é possível com policies adequadas

---

## 15. SNS FIFO

### 15.1 Características

| Aspecto | SNS FIFO |
|---|---|
| Ordering | Estritamente ordenado |
| Deduplication | Content-based ou Message Dedup ID |
| Subscribers suportados | **Apenas SQS FIFO** |
| Throughput | 300 publishes/s (3.000 com batching) |
| Nome do topic | Deve terminar em `.fifo` |

### 15.2 Fan-out Ordenado

```
Producer → SNS FIFO Topic → SQS FIFO Queue A (ordering preservado)
                           → SQS FIFO Queue B (ordering preservado)
```

- Garante que TODAS as filas recebem mensagens na mesma ordem
- Essencial para cenários onde ordering é crítico em múltiplos consumers

---

## 16. Message Filtering (SNS)

### 16.1 Conceito

- Cada subscription pode ter uma **Filter Policy**
- Filtra mensagens por **atributos** (não pelo body)
- Subscriber recebe apenas mensagens que matcham o filtro
- **Sem filtro:** recebe TODAS as mensagens do topic

### 16.2 Exemplo de Filter Policy

```json
{
  "eventType": ["order_placed"],
  "store": ["store-a", "store-b"],
  "price": [{"numeric": [">=", 100]}]
}
```

### 16.3 Operadores Suportados

| Operador | Exemplo | Descrição |
|---|---|---|
| Exact match | `["order_placed"]` | Valor exato |
| Anything-but | `[{"anything-but": ["cancelled"]}]` | Tudo exceto |
| Prefix | `[{"prefix": "order-"}]` | Começa com |
| Numeric | `[{"numeric": [">=", 100, "<", 500]}]` | Range numérico |
| Exists | `[{"exists": true}]` | Atributo existe |

### 16.4 Benefícios

- Reduz custo (menos mensagens entregues/processadas)
- Simplifica lógica do consumer (não precisa filtrar no código)
- Melhora performance (menos invocações Lambda, menos msgs SQS)

---

## 17. SNS + S3 Event Notifications (Fan-out)

### 17.1 Problema

- S3 Event Notification suporta apenas **1 destino por evento** (tipo + prefixo + sufixo)
- E se precisar notificar múltiplos serviços?

### 17.2 Solução: Fan-out via SNS

```
┌────┐  PutObject   ┌───────────┐     ┌───────────────┐
│ S3 │─────────────→│ SNS Topic │────→│ SQS (process) │
└────┘              └─────┬─────┘     └───────────────┘
                          │           ┌───────────────┐
                          ├──────────→│ Lambda (thumb)│
                          │           └───────────────┘
                          │           ┌───────────────┐
                          └──────────→│ SQS (audit)   │
                                      └───────────────┘
```

### 17.3 Alternativa: S3 → EventBridge

- Habilitar EventBridge notifications no bucket
- EventBridge oferece mais targets e filtering avançado
- Suporta archive & replay


---

## 18. EventBridge — Event Bus

### 18.1 Tipos de Event Bus

| Tipo | Descrição | Exemplo |
|---|---|---|
| **Default** | Recebe eventos de serviços AWS automaticamente | EC2 state change, S3 events, RDS events |
| **Custom** | Eventos da sua aplicação | `order.placed`, `payment.processed` |
| **Partner** | Eventos de SaaS integrados | Datadog, Zendesk, Auth0, Shopify, PagerDuty |

### 18.2 Características

- Event Bus pode ter **Resource Policy** para cross-account access
- Múltiplas rules podem escutar o mesmo event bus
- Eventos são JSON com campos padrão (source, detail-type, detail, etc.)

### 18.3 Estrutura de um Evento

```json
{
  "version": "0",
  "id": "12345-abcde",
  "source": "aws.ec2",
  "detail-type": "EC2 Instance State-change Notification",
  "account": "123456789012",
  "time": "2024-01-15T12:00:00Z",
  "region": "us-east-1",
  "detail": {
    "instance-id": "i-1234567890abcdef0",
    "state": "terminated"
  }
}
```

---

## 19. EventBridge Rules

### 19.1 Event Pattern (Reactive)

Filtra eventos por campos do JSON:

```json
{
  "source": ["aws.ec2"],
  "detail-type": ["EC2 Instance State-change Notification"],
  "detail": {
    "state": ["terminated", "stopped"]
  }
}
```

### 19.2 Schedule (Proactive)

| Tipo | Sintaxe | Exemplo |
|---|---|---|
| Rate | `rate(value unit)` | `rate(5 minutes)`, `rate(1 hour)` |
| Cron | `cron(min hour day month day-of-week year)` | `cron(0 12 * * ? *)` = meio-dia todo dia |

### 19.3 Diferença Importante

- **Event Pattern:** reage a eventos que acontecem
- **Schedule:** gera eventos em intervalos definidos (como cron job)

---

## 20. EventBridge Targets

### 20.1 Lista de Targets Principais (para a prova)

| Target | Caso de Uso |
|---|---|
| Lambda | Processamento serverless de eventos |
| SQS | Buffering, processamento assíncrono |
| SNS | Fan-out adicional, notificações |
| ECS Task | Iniciar containers sob demanda |
| Step Functions | Orquestração de workflows |
| API Gateway | Invocar APIs HTTP |
| Kinesis Data Streams | Streaming de eventos |
| Kinesis Firehose | Archiving direto para S3/Redshift |
| CodePipeline | Trigger de CI/CD |
| SSM Run Command | Automação em instâncias EC2 |
| Batch | Jobs de processamento batch |
| CloudWatch Logs | Logging de eventos |
| Redshift | Carregar dados |
| Inspector | Security assessment |

### 20.2 Múltiplos Targets

- Uma rule pode ter **até 5 targets**
- Todos os targets são invocados em paralelo
- Para mais de 5: encadear com SNS ou SQS

---

## 21. EventBridge Pipes

### 21.1 Conceito

Pipeline ponto-a-ponto com 4 etapas:

```
┌────────┐    ┌────────┐    ┌────────┐    ┌────────┐
│ SOURCE │───→│ FILTER │───→│ ENRICH │───→│ TARGET │
└────────┘    └────────┘    └────────┘    └────────┘
```

### 21.2 Sources Suportadas

- SQS, Kinesis Data Streams, DynamoDB Streams, Amazon MQ, MSK, Self-managed Kafka

### 21.3 Enrichment

- Lambda, Step Functions, API Gateway, API Destinations
- Permite adicionar dados ao evento antes de entregar ao target

### 21.4 Targets

- Qualquer target do EventBridge (Lambda, SQS, Step Functions, etc.)

### 21.5 Diferença: Pipes vs Rules

| Aspecto | Rules | Pipes |
|---|---|---|
| Modelo | Event Bus → Rules → Targets | Source → Filter → Enrich → Target |
| Fan-out | Sim (múltiplas rules, múltiplos targets) | Não (ponto-a-ponto) |
| Enrichment | Não nativo | Sim (Lambda, API GW, Step Functions) |
| Sources | Event Bus | SQS, Kinesis, DynamoDB, MQ, MSK |

---

## 22. EventBridge Scheduler

### 22.1 Tipos de Schedule

| Tipo | Descrição | Exemplo |
|---|---|---|
| One-time | Executa uma vez em data/hora específica | Enviar email em 2024-03-15 às 10:00 |
| Recurring (rate) | Intervalo fixo | A cada 5 minutos |
| Recurring (cron) | Expressão cron | Todo dia às 8:00 UTC |

### 22.2 Vantagens sobre Schedule Rules

- **Milhões** de schedules (rules tem limite de 300 por event bus)
- Time zones nativas
- Flexible time windows (janela de execução)
- Retry policy configurável
- Dead Letter Queue para invocações falhadas

### 22.3 Targets do Scheduler

- Suporta mais de 270 serviços AWS como target
- Mais abrangente que rules de schedule

---

## 23. Schema Registry e Schema Discovery

### 23.1 Schema Registry

- Repositório de schemas de eventos (formato JSONSchema/OpenAPI)
- Permite gerar code bindings (Java, Python, TypeScript) a partir do schema
- Versionamento automático de schemas

### 23.2 Schema Discovery

- EventBridge pode **descobrir automaticamente** o schema dos eventos
- Analisa eventos que passam pelo event bus e infere o schema
- Habilitar: ativar discovery no event bus

### 23.3 Uso

- Desenvolvedor consulta o registry para entender a estrutura do evento
- Gera código tipado para produzir/consumir eventos
- Documenta automaticamente os contratos de eventos

---

## 24. EventBridge vs CloudWatch Events

| Aspecto | CloudWatch Events | EventBridge |
|---|---|---|
| É o mesmo serviço? | ✅ Sim, mesma infraestrutura | ✅ Sim |
| Event Bus custom | ❌ | ✅ |
| Partner integrations | ❌ | ✅ (Datadog, Zendesk, etc.) |
| Schema Registry | ❌ | ✅ |
| Archive & Replay | ❌ | ✅ |
| Pipes | ❌ | ✅ |
| Scheduler avançado | ❌ | ✅ |
| API name | `events` (mesma) | `events` (mesma) |
| Recomendação AWS | Legado | **Usar EventBridge** |

> **Para a prova:** EventBridge é a evolução do CloudWatch Events. Se a questão mencionar "routing de eventos entre serviços AWS", a resposta provavelmente é EventBridge.

---

## 25. Archive and Replay de Eventos

### 25.1 Archive

- Armazena eventos que passam pelo event bus
- Configurável: todos os eventos ou apenas os que matcham um pattern
- Retenção: indefinida ou por período definido
- Custo: paga pelo armazenamento

### 25.2 Replay

- Re-envia eventos arquivados para o event bus
- Filtrável por período de tempo
- Útil para:
  - **Debug:** reprocessar eventos que causaram erros
  - **Nova feature:** testar com eventos históricos
  - **Recovery:** reprocessar após fix de bug
  - **Dev/Test:** reproduzir cenários de produção

```
┌──────────┐    eventos    ┌───────────┐    archive    ┌─────────┐
│  Sources │───────────────→│ Event Bus │──────────────→│ Archive │
└──────────┘               └─────┬─────┘               └────┬────┘
                                 │                          │
                                 │         replay           │
                                 │◄─────────────────────────┘
                                 │
                                 ▼
                           ┌───────────┐
                           │  Targets  │
                           └───────────┘
```


---

## 26. Kinesis Data Streams

### 26.1 Conceitos

| Conceito | Descrição |
|---|---|
| **Stream** | Conjunto de shards que forma o canal de dados |
| **Shard** | Unidade de capacidade (1 MB/s in, 2 MB/s out) |
| **Partition Key** | Determina em qual shard o record vai (hash) |
| **Record** | Dado enviado (partition key + data blob + sequence number) |
| **Sequence Number** | ID único por record dentro do shard (ordering) |

### 26.2 Capacidade por Shard

| Direção | Throughput | Records |
|---|---|---|
| **Input (write)** | 1 MB/s | 1.000 records/s |
| **Output (read) — Shared** | 2 MB/s | 5 reads/s (entre todos consumers) |
| **Output (read) — Enhanced** | 2 MB/s **por consumer** | Dedicado |

### 26.3 Retenção

- **Padrão:** 24 horas
- **Estendida:** até 7 dias (custo adicional)
- **Long-term:** até 365 dias (custo mais alto)
- Replay possível dentro do período de retenção

### 26.4 Modos de Capacidade

| Modo | Descrição | Quando usar |
|---|---|---|
| **Provisioned** | Você define número de shards | Throughput previsível |
| **On-Demand** | Auto-scaling de shards (até 200 MB/s in) | Throughput imprevisível |

### 26.5 Partition Key — Hot Shard Problem

- Se muitos records usarem a mesma partition key → um shard fica sobrecarregado
- Solução: usar partition keys com alta cardinalidade (ex: user_id, device_id)
- Evitar: usar data fixa (ex: data do dia) como partition key

---

## 27. Kinesis Consumers — Shared vs Enhanced Fan-Out

### 27.1 Tabela Comparativa

| Aspecto | Shared (Classic) | Enhanced Fan-Out |
|---|---|---|
| Modelo | Pull (GetRecords API) | Push (SubscribeToShard via HTTP/2) |
| Throughput por shard | 2 MB/s **compartilhado** entre todos consumers | 2 MB/s **por consumer** |
| Latência | ~200ms | ~70ms |
| Consumers por stream | Até 5 GetRecords calls/s por shard | Até 20 consumers registrados |
| Custo | Incluído no preço do shard | Custo adicional por consumer-shard-hour |
| Caso de uso | Poucos consumers, custo menor | Muitos consumers, baixa latência |

### 27.2 Diagrama

```
SHARED (Pull):
┌────────────┐     2 MB/s total     ┌──────────────┐
│   Shard    │─────────────────────→│ Consumer A   │ (divide os 2 MB/s)
│            │─────────────────────→│ Consumer B   │
└────────────┘                      └──────────────┘

ENHANCED FAN-OUT (Push):
┌────────────┐     2 MB/s dedicado  ┌──────────────┐
│   Shard    │═════════════════════→│ Consumer A   │
│            │═════════════════════→│ Consumer B   │ (cada um recebe 2 MB/s)
└────────────┘     2 MB/s dedicado  └──────────────┘
```

### 27.3 KCL (Kinesis Client Library)

- Gerencia lease de shards entre workers
- Checkpoint management (DynamoDB para tracking)
- Scaling: 1 KCL worker por shard (máximo)
- Se mais shards que workers: um worker processa múltiplos shards
- Se mais workers que shards: workers extras ficam idle

---

## 28. Kinesis Data Firehose

### 28.1 Conceito

- Serviço **fully managed** para carregar dados em destinos
- **Near real-time** (não é real-time puro)
- Não precisa escrever código de consumer
- Sem gerenciamento de shards (serverless)

### 28.2 Buffer

| Parâmetro | Range | Padrão |
|---|---|---|
| Buffer Size | 1 MB – 128 MB | 5 MB |
| Buffer Interval | 60s – 900s | 300s |

- Entrega quando **qualquer um** dos limites for atingido primeiro
- Menor buffer = menor latência, mais entregas, mais custo

### 28.3 Destinos Suportados

| Categoria | Destinos |
|---|---|
| AWS | S3, Redshift (via S3 COPY), OpenSearch Service |
| Third-party | Splunk, Datadog, New Relic, MongoDB, Dynatrace |
| Custom | HTTP Endpoint (qualquer API) |

### 28.4 Transformações

- **Lambda Transform:** transforma records antes da entrega
- Casos: converter formato, enriquecer dados, filtrar, comprimir
- Lambda recebe batch de records, retorna batch transformado

### 28.5 Fluxo Completo

```
┌─────────┐    ┌──────────────┐    ┌────────┐    ┌──────────┐    ┌────────────┐
│ Sources │───→│   Firehose   │───→│ Lambda │───→│  Buffer  │───→│   Destino  │
│         │    │ Delivery     │    │Transform│   │(size/time)│   │(S3/Redshift│
│ - KDS   │    │ Stream       │    └────────┘    └──────────┘    │ /OpenSearch)│
│ - SDK   │    └──────────────┘                                  └────────────┘
│ - Agent │              │
│ - IoT   │              │ falhas
└─────────┘              ▼
                  ┌───────────────┐
                  │ S3 (backup/   │
                  │  failed data) │
                  └───────────────┘
```

---

## 29. Data Streams vs Firehose — Tabela COMPLETA

| Aspecto | Kinesis Data Streams | Kinesis Data Firehose |
|---|---|---|
| Tipo | Streaming real-time | Near real-time delivery |
| Latência | ~200ms (shared) / ~70ms (enhanced) | 60s–900s (buffer) |
| Gerenciamento | Provisioned ou On-Demand shards | Totalmente gerenciado (serverless) |
| Consumers | Custom (Lambda, KCL, SDK, KDA) | Destinos pré-definidos |
| Destinos | Qualquer (você codifica) | S3, Redshift, OpenSearch, Splunk, HTTP |
| Replay | ✅ Sim | ❌ Não |
| Retenção | 1–365 dias | Não retém (entrega e descarta) |
| Transformação | No consumer | Lambda integrado |
| Escala | Manual (shards) ou On-Demand | Automática |
| Ordering | Por shard (partition key) | Não garantido |
| Preço | Por shard-hour + PUT payload | Por volume de dados ingeridos |
| Caso de uso | Analytics real-time, múltiplos consumers, replay | ETL simples, archiving, entrega para datastores |

---

## 30. SQS vs Kinesis — Tabela de Decisão

| Cenário | SQS | Kinesis |
|---|---|---|
| Processamento individual de mensagens | ✅ | ❌ |
| Ordering estrito por entidade (FIFO) | ✅ (FIFO) | ✅ (por shard) |
| Throughput ilimitado sem gerenciamento | ✅ (Standard) | ❌ (precisa de shards) |
| Replay de dados | ❌ | ✅ |
| Múltiplos consumers no mesmo dado | ❌ (msg deletada após consumo) | ✅ (múltiplos leitores) |
| Streaming contínuo (IoT, logs, clicks) | ❌ | ✅ |
| Desacoplamento simples entre serviços | ✅ | ❌ (overengineering) |
| Real-time analytics/dashboards | ❌ | ✅ |
| Buffer para absorver picos | ✅ | ✅ (mas mais complexo) |
| Exactly-once processing | ✅ (FIFO) | ❌ (at-least-once) |
| Consumer pode ficar offline | ✅ (até 14 dias) | ✅ (até 365 dias) |
| ETL para S3/Redshift | ❌ (precisa de código) | ✅ (Firehose) |

### 30.1 Regra Prática para a Prova

- **"desacoplar", "fila", "retry", "DLQ"** → SQS
- **"stream", "real-time", "replay", "analytics", "IoT", "clickstream"** → Kinesis
- **"carregar para S3/Redshift sem código"** → Kinesis Firehose
- **"fan-out", "notificar múltiplos"** → SNS
- **"eventos AWS", "automação", "SaaS"** → EventBridge

---

## 31. Amazon MSK (Managed Streaming for Apache Kafka)

### 31.1 Quando Usar MSK vs Kinesis

| Aspecto | MSK | Kinesis Data Streams |
|---|---|---|
| Protocolo | Apache Kafka nativo | AWS proprietário |
| Migração | Ideal para apps que já usam Kafka | Ideal para greenfield AWS |
| Configuração | Alta flexibilidade (topic config, partitions) | Simplificado (shards) |
| Consumers | Kafka consumers (qualquer linguagem) | KCL, Lambda, SDK |
| Retenção | Ilimitada (disco) | 1–365 dias |
| Multi-AZ | Sim (replicação) | Sim (built-in) |
| Serverless | MSK Serverless (auto-scaling) | On-Demand mode |
| Ecosystem | Kafka Connect, Kafka Streams, ksqlDB | Kinesis Analytics (Flink) |

### 31.2 MSK Serverless

- Provisionamento automático de recursos
- Paga por throughput consumido
- Sem gerenciamento de brokers/partitions
- Ideal para cargas variáveis

### 31.3 MSK Connect

- Gerencia Kafka Connect workers
- Source Connectors: puxar dados de fontes (DB, S3, etc.) para MSK
- Sink Connectors: enviar dados de MSK para destinos (S3, OpenSearch, etc.)
- Auto-scaling de workers

---

## 32. Amazon MQ

### 32.1 Conceito

- Serviço gerenciado para **Apache ActiveMQ** e **RabbitMQ**
- Para migração de aplicações on-prem que usam protocolos de mensageria padrão

### 32.2 Protocolos Suportados

| Protocolo | Descrição |
|---|---|
| **MQTT** | IoT, dispositivos leves |
| **AMQP** | Advanced Message Queuing Protocol |
| **STOMP** | Simple Text Oriented Messaging |
| **OpenWire** | Protocolo nativo do ActiveMQ |
| **WSS** | WebSocket Secure |

### 32.3 Quando Usar Amazon MQ (vs SQS/SNS)

| Cenário | Serviço |
|---|---|
| Aplicação nova, cloud-native | **SQS + SNS** (escala infinita, serverless) |
| Migração de app que usa JMS, AMQP, MQTT | **Amazon MQ** (compatibilidade de protocolo) |
| Precisa de queues + topics no mesmo broker | **Amazon MQ** (suporta ambos) |
| Precisa de throughput ilimitado e zero gestão | **SQS/SNS** |

### 32.4 Arquitetura

- **Single-instance:** desenvolvimento/teste
- **Active/Standby (Multi-AZ):** produção (failover automático)
- **Cluster (RabbitMQ):** alta disponibilidade com múltiplos nós
- Storage: EFS (ActiveMQ Multi-AZ) ou EBS

### 32.5 Limitações vs SQS/SNS

- Não escala infinitamente (limitado por broker)
- Requer gerenciamento de instância (não é serverless)
- Não integra nativamente com serviços AWS como SQS/SNS

---

## 33. Palavras-Chave da Prova SAA-C03

| # | Cenário / Palavra-chave na questão | Resposta |
|---|---|---|
| 1 | "desacoplar serviços", "processar mensagens de forma assíncrona" | **SQS Standard** |
| 2 | "garantir ordem de processamento", "exactly-once" | **SQS FIFO** |
| 3 | "mensagem processada duas vezes", "duplicatas" | Verificar **Visibility Timeout** (curto demais) ou usar **SQS FIFO** |
| 4 | "mensagens que falham repetidamente", "analisar erros" | **Dead Letter Queue (DLQ)** |
| 5 | "notificar múltiplos serviços do mesmo evento" | **SNS Fan-out** (SNS → múltiplas SQS) |
| 6 | "cada subscriber receber apenas mensagens relevantes" | **SNS Message Filtering** |
| 7 | "reagir a eventos de serviços AWS automaticamente" | **EventBridge** |
| 8 | "streaming em tempo real", "analytics de clickstream" | **Kinesis Data Streams** |
| 9 | "carregar dados para S3 sem gerenciar infraestrutura" | **Kinesis Data Firehose** |
| 10 | "replay de eventos", "reprocessar dados históricos" | **Kinesis Data Streams** ou **EventBridge Archive & Replay** |
| 11 | "múltiplos consumers lendo o mesmo stream" | **Kinesis Data Streams** (Enhanced Fan-Out se > 2 consumers) |
| 12 | "absorver picos de escrita no banco de dados" | **SQS como buffer** |
| 13 | "escalar workers baseado no tamanho da fila" | **SQS + ASG + CloudWatch (ApproximateNumberOfMessagesVisible)** |
| 14 | "migrar aplicação que usa ActiveMQ/RabbitMQ" | **Amazon MQ** |
| 15 | "protocolo MQTT, AMQP, STOMP" | **Amazon MQ** |
| 16 | "evento de S3 para múltiplos destinos" | **S3 → SNS → Fan-out** ou **S3 → EventBridge** |
| 17 | "schedule/cron na AWS", "executar Lambda a cada 5 min" | **EventBridge Schedule Rule** ou **EventBridge Scheduler** |
| 18 | "mensagens maiores que 256KB" | **SQS Extended Client Library** (armazena no S3) |
| 19 | "reduzir custos de polling em filas vazias" | **Long Polling** (WaitTimeSeconds = 20) |
| 20 | "integrar com Datadog/Zendesk/Auth0 eventos" | **EventBridge Partner Event Bus** |
| 21 | "processar IoT data em tempo real de milhares de devices" | **Kinesis Data Streams** (partition key = device_id) |
| 22 | "ordenar mensagens por cliente/entidade específica" | **SQS FIFO com Message Group ID** |
| 23 | "transformar dados antes de entregar ao S3" | **Kinesis Firehose + Lambda Transform** |
| 24 | "fan-out ordenado para múltiplas filas" | **SNS FIFO → SQS FIFO** |
| 25 | "orquestrar pipeline: source → filter → enrich → target" | **EventBridge Pipes** |
| 26 | "Kafka gerenciado na AWS" | **Amazon MSK** |
| 27 | "atrasar processamento de mensagens por N minutos" | **SQS Delay Queue** ou **Message Timer** |
| 28 | "near real-time ETL para Redshift" | **Kinesis Firehose** (buffer 60s → S3 → COPY Redshift) |
| 29 | "request-response pattern com filas" | **SQS Temporary Queues** |
| 30 | "reprocessar mensagens da DLQ após correção" | **DLQ Redrive to Source** |

---

## Resumo Visual — Fluxo de Decisão para a Prova

```
┌─────────────────────────────────────────────────────────────────┐
│                    PRECISO DE MENSAGERIA?                        │
└──────────────────────────────┬──────────────────────────────────┘
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
          ▼                    ▼                    ▼
   ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
   │  1:1 Queue  │     │  1:N Pub/Sub│     │  Streaming  │
   └──────┬──────┘     └──────┬──────┘     └──────┬──────┘
          │                    │                    │
    ┌─────▼─────┐       ┌─────▼─────┐       ┌─────▼─────┐
    │Protocolo  │       │ Eventos   │       │ Real-time │
    │padrão?    │       │ AWS/SaaS? │       │ ou near?  │
    └──┬────┬───┘       └──┬────┬───┘       └──┬────┬───┘
       │    │              │    │              │    │
      SIM  NÃO           SIM  NÃO          RT   NRT
       │    │              │    │              │    │
       ▼    ▼              ▼    ▼              ▼    ▼
   ┌─────┐┌────┐    ┌──────┐┌────┐    ┌─────┐┌────────┐
   │ MQ  ││SQS │    │Event ││SNS │    │KDS  ││Firehose│
   └─────┘└────┘    │Bridge│└────┘    └─────┘└────────┘
                     └──────┘
```

---

## Dicas Finais para a Prova

1. **SQS Standard** = default para desacoplamento (simples, barato, ilimitado)
2. **SQS FIFO** = quando ordering e exactly-once são requisitos explícitos
3. **SNS** = quando precisa notificar N subscribers de um evento
4. **SNS + SQS** = Fan-out pattern (quase sempre a resposta para "processar mesmo evento de múltiplas formas")
5. **EventBridge** = quando envolve eventos de serviços AWS ou automação baseada em eventos
6. **Kinesis Data Streams** = streaming real-time com replay
7. **Kinesis Firehose** = entrega para S3/Redshift/OpenSearch sem código
8. **Amazon MQ** = migração de apps que usam protocolos padrão (MQTT, AMQP)
9. **MSK** = quando a equipe já conhece Kafka e precisa do ecossistema Kafka

---

*Última atualização: Julho 2026 — Alinhado com o exame SAA-C03*
