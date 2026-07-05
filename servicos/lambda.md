# AWS Lambda & Serverless — Guia Completo SAA-C03

> Documento expandido para estudo aprofundado da certificação AWS Solutions Architect Associate (SAA-C03).
> Cobre Lambda, API Gateway, Step Functions, Cognito e AppSync.

---

## 1. AWS Lambda — Conceitos Fundamentais

### 1.1 O que é AWS Lambda

AWS Lambda é um serviço de computação **serverless** e **event-driven** que executa código em resposta a eventos sem necessidade de provisionar ou gerenciar servidores.

**Características principais:**
- **Event-driven:** executa em resposta a triggers (S3, DynamoDB, API Gateway, etc.)
- **Stateless:** cada invocação é independente; não mantém estado entre execuções
- **Pay-per-use:** cobrado por número de invocações + duração (em ms) + memória alocada
- **Auto-scaling:** escala automaticamente de 0 a milhares de execuções simultâneas
- **Efêmero:** ambiente de execução é temporário

### 1.2 Modelo de Precificação

```
Custo = (Número de Requests × $0.20/1M) + (GB-segundo × $0.0000166667)
```

- **Free Tier:** 1 milhão de requests + 400.000 GB-segundos/mês
- Duração arredondada para o próximo ms
- Memória alocada determina o custo por ms

### 1.3 Runtimes Suportados

| Runtime         | Versões Suportadas        |
|-----------------|---------------------------|
| Node.js         | 18.x, 20.x, 22.x         |
| Python          | 3.9, 3.10, 3.11, 3.12    |
| Java            | 11, 17, 21               |
| .NET            | 6, 8                     |
| Go              | provided.al2/al2023      |
| Ruby            | 3.2, 3.3                 |
| Custom Runtime  | Amazon Linux 2/2023       |
| Container Image | Até 10 GB                 |

---

## 2. Limites do AWS Lambda (TODOS)

### 2.1 Tabela Completa de Limites

| Parâmetro                        | Limite                          | Ajustável? |
|----------------------------------|---------------------------------|------------|
| **Timeout máximo**               | 15 minutos (900 segundos)       | Não        |
| **Memória RAM**                  | 128 MB a 10.240 MB (10 GB)     | —          |
| **Incremento de memória**        | 1 MB                            | —          |
| **Armazenamento /tmp**           | 512 MB a 10.240 MB (10 GB)     | —          |
| **Pacote deploy (zip)**          | 50 MB (upload direto)           | Não        |
| **Pacote descomprimido**         | 250 MB (incluindo layers)       | Não        |
| **Variáveis de ambiente**        | 4 KB (total)                    | Não        |
| **Concorrência padrão/região**   | 1.000 execuções simultâneas     | Sim        |
| **Payload síncrono**             | 6 MB (request + response)       | Não        |
| **Payload assíncrono**           | 256 KB                          | Não        |
| **Layers por função**            | 5 layers                        | Não        |
| **Versões por função**           | Sem limite prático              | —          |
| **File descriptors**             | 1.024                           | Não        |
| **Threads/processos**            | 1.024                           | Não        |
| **Burst concurrency**            | 500-3000 (varia por região)     | Não        |

### 2.2 Dica para a Prova

> ⚠️ Se a questão menciona processamento > 15 minutos → NÃO é Lambda.
> Use ECS/Fargate, EC2 ou Step Functions para orquestrar múltiplas Lambda.
> Se payload > 6 MB síncrono → use S3 como intermediário.

---

## 3. Execution Model — Cold Start vs Warm Start

### 3.1 Fases de Execução

```
┌─────────────────────────────────────────────────────────────┐
│                    CICLO DE VIDA LAMBDA                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────┐    ┌──────────────┐    ┌──────────────────┐  │
│  │   INIT   │───▶│   INVOKE     │───▶│    SHUTDOWN      │  │
│  │  Phase   │    │   Phase      │    │    Phase         │  │
│  └──────────┘    └──────────────┘    └──────────────────┘  │
│       │                 │                                    │
│       ▼                 ▼                                    │
│  - Download code   - Executa handler   - Cleanup            │
│  - Init runtime    - Processa evento   - Extensions stop    │
│  - Init extensions - Retorna response                       │
│  - Run init code                                            │
│  (FORA do handler)                                          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Cold Start vs Warm Start

| Aspecto            | Cold Start                          | Warm Start                    |
|--------------------|-------------------------------------|-------------------------------|
| **Quando ocorre**  | 1ª invocação ou após inatividade    | Invocações subsequentes       |
| **Latência**       | +100ms a +10s (VPC pior)            | Apenas tempo do handler       |
| **Init phase**     | Executada                           | Pulada (reuso do contexto)    |
| **Código fora handler** | Executado                      | Reutilizado                   |
| **Conexões DB**    | Precisam ser criadas                | Reutilizadas                  |

### 3.3 Execution Context Reuse — Best Practices

```python
# ✅ CORRETO: conexão FORA do handler (reutilizada em warm starts)
import boto3
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('MinhaTabela')

def handler(event, context):
    # handler usa a conexão já estabelecida
    response = table.get_item(Key={'id': event['id']})
    return response['Item']
```

```python
# ❌ ERRADO: conexão DENTRO do handler (recriada a cada invocação)
def handler(event, context):
    import boto3
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('MinhaTabela')
    response = table.get_item(Key={'id': event['id']})
    return response['Item']
```

---

## 4. Triggers e Event Sources

### 4.1 Diagrama de Event Sources

```
                         ┌─────────────────┐
    ┌──── S3 ────────────┤                 │
    ├──── DynamoDB ──────┤                 │
    ├──── Kinesis ───────┤                 │
    ├──── SQS ──────────┤                 │
    ├──── SNS ──────────┤   AWS LAMBDA    │
    ├──── API Gateway ──┤                 │
    ├──── ALB ──────────┤                 │
    ├──── EventBridge ──┤                 │
    ├──── Cognito ──────┤                 │
    ├──── CloudFront ───┤                 │
    ├──── IoT Rules ────┤                 │
    └──── CloudWatch ───┤                 │
                         └─────────────────┘
```

### 4.2 Modelos de Invocação

| Modelo           | Trigger Exemplo           | Comportamento                          |
|------------------|---------------------------|----------------------------------------|
| **Síncrono**     | API GW, ALB, Cognito      | Caller espera resposta                 |
| **Assíncrono**   | S3, SNS, EventBridge      | Lambda retorna 202, retry automático   |
| **Poll-based**   | SQS, Kinesis, DynamoDB    | Lambda faz polling da source           |

### 4.3 Retry Behavior

- **Síncrono:** sem retry automático (caller decide)
- **Assíncrono:** 2 retries automáticos, depois envia para DLQ ou Destination
- **Poll-based (stream):** retry até expirar o registro no stream
- **Poll-based (SQS):** mensagem volta à fila após visibility timeout

---

## 5. Concurrency — Reserved, Provisioned e Unreserved

### 5.1 Modelo de Concorrência

```
┌─────────────────────────────────────────────────────────────┐
│         CONCURRENCY TOTAL DA CONTA: 1000/região             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐  │
│  │  UNRESERVED   │  │   RESERVED    │  │  PROVISIONED  │  │
│  │  (pool geral) │  │ (por função)  │  │ (pré-aquecido)│  │
│  │               │  │               │  │               │  │
│  │  Compartilhado│  │  Garantido    │  │  Sem cold     │  │
│  │  entre funções│  │  para 1 func  │  │  start        │  │
│  └───────────────┘  └───────────────┘  └───────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 Tipos de Concorrência

| Tipo                   | Descrição                                          | Cold Start? | Custo Extra? |
|------------------------|----------------------------------------------------|-------------|--------------|
| **Unreserved**         | Pool compartilhado entre todas as funções          | Sim         | Não          |
| **Reserved**           | Reserva fixa para uma função (limita e garante)    | Sim         | Não          |
| **Provisioned**        | Instâncias pré-inicializadas sempre prontas        | Não         | Sim          |

### 5.3 Throttling

- Quando concorrência excede o limite → HTTP **429 TooManyRequestsException**
- **Síncrono:** retorna 429 imediatamente
- **Assíncrono:** retry automático por até 6 horas, depois vai para DLQ/Destination
- **SQS:** mensagens retornam à fila
- **Kinesis/DynamoDB Streams:** retry no mesmo shard até sucesso ou expiração

### 5.4 Scaling Behavior

- **Burst limit:** 500-3000 instâncias instantâneas (varia por região)
- Após burst: escala +500 instâncias/minuto
- Limite total: 1000 concurrent executions/região (padrão, ajustável via suporte)

---

## 6. Lambda + VPC

### 6.1 Arquitetura com VPC

```
┌──────────────────────────────────────────────────────────┐
│                       VPC                                 │
│                                                          │
│  ┌─────────────────┐         ┌────────────────────┐    │
│  │ Private Subnet  │         │  Private Subnet    │    │
│  │                 │         │                    │    │
│  │  ┌──────────┐  │         │  ┌──────────────┐ │    │
│  │  │ Lambda   │  │         │  │   RDS        │ │    │
│  │  │ ENI      │──┼─────────┼─▶│   Instance   │ │    │
│  │  └──────────┘  │         │  └──────────────┘ │    │
│  │                 │         │                    │    │
│  └─────────────────┘         └────────────────────┘    │
│          │                                               │
│          ▼                                               │
│  ┌─────────────────┐                                    │
│  │  NAT Gateway    │ ◄── Necessário para internet       │
│  │  (Public Subnet)│                                    │
│  └────────┬────────┘                                    │
│           │                                              │
└───────────┼──────────────────────────────────────────────┘
            ▼
      Internet Gateway
            │
            ▼
        Internet
```

### 6.2 Como Funciona

1. Lambda cria **Elastic Network Interfaces (ENIs)** na(s) subnet(s) especificada(s)
2. ENIs são compartilhadas via **Hyperplane** (desde 2019 — melhoria significativa)
3. Lambda usa Security Groups atribuídos às ENIs

### 6.3 Impacto no Cold Start

| Cenário                | Cold Start Adicional        |
|------------------------|-----------------------------|
| Lambda sem VPC         | ~100-500ms                  |
| Lambda com VPC (novo)  | ~1-2s (criação de ENI)      |
| Lambda com VPC (Hyperplane) | ~200-500ms (melhorado)  |

### 6.4 Best Practices para Lambda + VPC

- **Dedicar subnets** com IPs suficientes para ENIs do Lambda
- Usar **NAT Gateway** em public subnet para acesso à internet
- Para serviços AWS → usar **VPC Endpoints** (evita NAT Gateway)
- Lambda SEM VPC acessa internet diretamente (não precisa NAT)
- Lambda COM VPC em private subnet NÃO tem acesso à internet sem NAT

> ⚠️ **Prova:** Se Lambda precisa acessar RDS + internet → VPC + NAT Gateway.
> Se Lambda só precisa acessar serviços AWS → VPC Endpoints é mais barato.

---

## 7. Lambda Layers

### 7.1 Conceito

Lambda Layers permitem compartilhar código, bibliotecas e dependências entre múltiplas funções Lambda.

```
┌─────────────────────────────────────────────┐
│            Função Lambda                     │
├─────────────────────────────────────────────┤
│  Código da Função (seu código)              │
├─────────────────────────────────────────────┤
│  Layer 1: SDK personalizado                 │
├─────────────────────────────────────────────┤
│  Layer 2: Bibliotecas comuns                │
├─────────────────────────────────────────────┤
│  Layer 3: Módulos de logging                │
├─────────────────────────────────────────────┤
│  Runtime                                     │
└─────────────────────────────────────────────┘
```

### 7.2 Limites de Layers

| Parâmetro                          | Limite        |
|------------------------------------|---------------|
| Layers por função                  | 5             |
| Tamanho total (unzipped + função)  | 250 MB        |
| Layers podem ser compartilhados    | Entre contas  |

### 7.3 Casos de Uso

- Bibliotecas de terceiros (numpy, pandas, etc.)
- SDK customizado compartilhado entre funções
- Código de utilidade/helpers
- Custom runtimes

---

## 8. Aliases e Versions

### 8.1 Versions (Versões)

- Cada publicação cria uma versão **imutável** ($LATEST é mutável)
- Versão = código + configuração congelados
- ARN com versão: `arn:aws:lambda:region:account:function:nome:1`

### 8.2 Aliases

- Ponteiro nomeado para uma versão específica
- Exemplo: `PROD` → versão 5, `DEV` → versão 8
- ARN com alias: `arn:aws:lambda:region:account:function:nome:PROD`

### 8.3 Traffic Shifting (Blue/Green & Canary)

```
                    ┌─────────────────┐
                    │   Alias "PROD"   │
                    └────────┬─────────┘
                             │
                    ┌────────┴─────────┐
                    │  Traffic Split   │
                    │                  │
              ┌─────▼─────┐     ┌─────▼─────┐
              │ Version 5  │     │ Version 6  │
              │   (95%)    │     │   (5%)     │
              └────────────┘     └────────────┘
```

| Estratégia      | Descrição                                      |
|-----------------|------------------------------------------------|
| **Canary**      | X% para nova versão, depois 100% se OK         |
| **Linear**      | Incremento gradual (ex: +10% a cada 10 min)    |
| **All-at-once** | 100% imediatamente para nova versão             |

- Integrado com **CodeDeploy** para automação
- Rollback automático via CloudWatch Alarms

---

## 9. Lambda Destinations

### 9.1 Conceito

Lambda Destinations é o mecanismo recomendado para processar resultados de invocações **assíncronas**.

```
┌─────────────┐         ┌─────────────┐
│   Evento    │────────▶│   Lambda    │
│  Assíncrono │         │   Function  │
└─────────────┘         └──────┬──────┘
                               │
                    ┌──────────┴──────────┐
                    │                     │
              ┌─────▼─────┐        ┌─────▼─────┐
              │  SUCCESS   │        │  FAILURE   │
              │ Destination│        │ Destination│
              └─────┬─────┘        └─────┬─────┘
                    │                     │
                    ▼                     ▼
              SQS / SNS /          SQS / SNS /
              Lambda /             Lambda /
              EventBridge          EventBridge
```

### 9.2 Destinations vs DLQ (Dead Letter Queue)

| Aspecto              | Destinations                    | DLQ                         |
|----------------------|---------------------------------|-----------------------------|
| **Eventos**          | Sucesso E falha                 | Apenas falha                |
| **Destinos**         | SQS, SNS, Lambda, EventBridge   | SQS ou SNS apenas          |
| **Informação**       | Evento completo + resultado     | Apenas o evento original    |
| **Recomendação AWS** | ✅ Preferido                    | Legacy                      |
| **Configuração**     | Por função                      | Por função                  |

> ⚠️ **Prova:** Destinations é a abordagem recomendada sobre DLQ para novas implementações.

---

## 10. Lambda@Edge vs CloudFront Functions

### 10.1 Tabela Comparativa Completa

| Aspecto                | Lambda@Edge                      | CloudFront Functions              |
|------------------------|----------------------------------|-----------------------------------|
| **Runtime**            | Node.js, Python                  | JavaScript (ECMAScript 5.1)       |
| **Timeout**            | 5s (viewer) / 30s (origin)       | < 1 ms                           |
| **Memória**            | 128 MB - 10 GB                   | 2 MB                             |
| **Pacote máximo**      | 1 MB (viewer) / 50 MB (origin)   | 10 KB                            |
| **Eventos**            | Viewer + Origin (request/response)| Viewer request/response apenas    |
| **Acesso à rede**      | ✅ Sim                           | ❌ Não                           |
| **Acesso ao body**     | ✅ Sim                           | ❌ Não                           |
| **Geolocation headers**| ✅ Sim                           | ✅ Sim                           |
| **Preço por request**  | ~$0.60/1M                        | ~$0.10/1M (6x mais barato)       |
| **Scale**              | Milhares/s                       | Milhões/s                         |
| **Região de deploy**   | us-east-1 (replicado)            | Todas edge locations              |
| **Latência típica**    | ms a segundos                    | Sub-millisecond                   |

### 10.2 Casos de Uso

**CloudFront Functions (leve, rápido):**
- Manipulação de headers
- URL rewrites/redirects
- Normalização de cache keys
- Validação de tokens simples (JWT)

**Lambda@Edge (pesado, flexível):**
- Autenticação/autorização complexa
- Renderização server-side (SSR)
- A/B testing com lógica complexa
- Manipulação de body
- Chamadas a APIs externas

---

## 11. Lambda + RDS Proxy

### 11.1 O Problema

```
Sem RDS Proxy:
┌────────┐  ┌────────┐  ┌────────┐
│Lambda 1│  │Lambda 2│  │Lambda 3│  ... (1000 instâncias)
└───┬────┘  └───┬────┘  └───┬────┘
    │           │           │
    ▼           ▼           ▼
┌─────────────────────────────────┐
│         RDS Instance            │
│   max_connections = 150 ❌ BOOM │
└─────────────────────────────────┘
```

### 11.2 A Solução: RDS Proxy

```
Com RDS Proxy:
┌────────┐  ┌────────┐  ┌────────┐
│Lambda 1│  │Lambda 2│  │Lambda 3│  ... (1000 instâncias)
└───┬────┘  └───┬────┘  └───┬────┘
    │           │           │
    ▼           ▼           ▼
┌─────────────────────────────────┐
│         RDS Proxy               │
│   Connection Pooling ✅         │
│   Multiplexação de conexões     │
└───────────────┬─────────────────┘
                │ (poucas conexões)
                ▼
┌─────────────────────────────────┐
│         RDS Instance            │
│   Conexões gerenciáveis ✅      │
└─────────────────────────────────┘
```

### 11.3 Benefícios do RDS Proxy

- **Connection pooling:** compartilha e reutiliza conexões
- **IAM Authentication:** autenticação via IAM (sem credenciais no código)
- **Failover mais rápido:** reduz tempo de failover em até 66%
- **Enforce TLS:** conexões encriptadas
- **Suporta:** MySQL, PostgreSQL, MariaDB, SQL Server
- **Nunca é público:** acessível apenas dentro da VPC

> ⚠️ **Prova:** Lambda + banco relacional = RDS Proxy. Sempre.

---

## 12. Lambda Container Images

### 12.1 Conceito

Lambda suporta deploy usando **imagens de container** de até **10 GB**, desde que implementem a **Lambda Runtime API**.

### 12.2 Requisitos

| Requisito                     | Detalhe                                   |
|-------------------------------|-------------------------------------------|
| Tamanho máximo da imagem      | 10 GB                                     |
| Base image                    | Deve implementar Lambda Runtime API       |
| Registry                      | Amazon ECR (obrigatório)                  |
| Base images oficiais          | Node.js, Python, Java, .NET, Go, Ruby    |
| Custom base image             | Precisa do Runtime Interface Client (RIC) |

### 12.3 Quando Usar

- Dependências grandes (ML models, bibliotecas pesadas)
- Migração de containers existentes para Lambda
- Necessidade de pacote > 250 MB (zip limit)
- Workflows de CI/CD já baseados em Docker

> ⚠️ **Atenção:** NÃO é ECS/Fargate. Container images em Lambda ainda seguem o modelo Lambda (15 min timeout, event-driven, etc.)

---

## 13. Performance Tuning

### 13.1 Memória = CPU

```
┌─────────────────────────────────────────────────┐
│  Memória alocada define proporcionalmente:       │
│                                                  │
│  128 MB  → CPU mínima (~1/10 vCPU)             │
│  1769 MB → 1 vCPU completo                      │
│  3538 MB → 2 vCPUs                              │
│  10240 MB → 6 vCPUs                             │
│                                                  │
│  💡 Mais memória = mais CPU = execução mais     │
│     rápida (pode ser mais BARATO!)              │
└─────────────────────────────────────────────────┘
```

### 13.2 Graviton2 (arm64)

| Aspecto        | x86_64            | arm64 (Graviton2)      |
|----------------|-------------------|------------------------|
| **Preço**      | Baseline           | 20% mais barato        |
| **Performance**| Baseline           | Até 34% melhor         |
| **Runtimes**   | Todos              | Todos                  |
| **Uso ideal**  | Compatibilidade    | Custo-performance      |

### 13.3 SnapStart (Java)

- Elimina cold start para funções Java (reduz de ~5s para <200ms)
- Tira um **snapshot** do estado inicializado (após Init phase)
- Restaura snapshot em vez de re-executar Init
- Funciona com Java 11+ (Corretto)
- Sem custo adicional
- Limitação: não pode usar estado que muda (random seeds, conexões únicas)

### 13.4 Boas Práticas de Performance

1. **Minimizar pacote de deploy** — apenas código necessário
2. **Código fora do handler** — inicialização reutilizada
3. **Variáveis de ambiente** — para configuração dinâmica
4. **Provisioned Concurrency** — para workloads previsíveis
5. **Arm64** — melhor custo-benefício na maioria dos casos
6. **Power Tuning** — usar AWS Lambda Power Tuning tool

---

## 14. API Gateway — Tipos de API

### 14.1 Tabela Comparativa Completa

| Feature                  | REST API                    | HTTP API                   | WebSocket API              |
|--------------------------|-----------------------------|----------------------------|----------------------------|
| **Protocolo**            | REST                        | REST/HTTP                  | WebSocket                  |
| **Custo**                | ~$3.50/1M requests          | ~$1.00/1M requests         | $1.00/1M msg + $0.25/1M min|
| **Latência**             | ~29ms overhead              | ~10ms overhead             | Persistent connection      |
| **Cache**                | ✅ Sim (0.5-237GB)          | ❌ Não                     | ❌ Não                     |
| **Usage Plans/API Keys** | ✅ Sim                      | ❌ Não                     | ❌ Não                     |
| **Request validation**   | ✅ Sim                      | ❌ Não                     | ❌ Não                     |
| **WAF**                  | ✅ Sim                      | ❌ Não                     | ✅ Sim                     |
| **Resource Policies**    | ✅ Sim                      | ❌ Não                     | ❌ Não                     |
| **Private endpoints**    | ✅ Sim                      | ❌ Não                     | ❌ Não                     |
| **Lambda Authorizer**    | ✅ Token + Request          | ✅ Request apenas          | ✅ Request                 |
| **Cognito Authorizer**   | ✅ Nativo                   | ✅ Via JWT                 | ❌ Não                     |
| **IAM Auth**             | ✅ Sim                      | ✅ Sim                     | ✅ Sim                     |
| **JWT/OIDC Auth**        | Via Lambda Authorizer       | ✅ Nativo                  | ❌ Não                     |
| **Mutual TLS**           | ✅ Sim                      | ✅ Sim                     | ❌ Não                     |
| **Transformações**       | ✅ VTL templates            | ❌ Não                     | ✅ Sim                     |
| **Uso recomendado**      | Full-featured API           | Low-latency, baixo custo   | Real-time (chat, games)    |

> ⚠️ **Prova:** HTTP API = 70% mais barato + menor latência, mas menos features.
> REST API = quando precisa de cache, WAF, resource policies, ou transformações.

---

## 15. Stages, Deployments e Stage Variables

### 15.1 Conceito

```
┌─────────────────────────────────────────┐
│              API Gateway                 │
├─────────────────────────────────────────┤
│                                          │
│  ┌──────────┐  ┌──────────┐  ┌───────┐ │
│  │  dev     │  │  staging │  │ prod  │ │
│  │  Stage   │  │  Stage   │  │ Stage │ │
│  └────┬─────┘  └────┬─────┘  └───┬───┘ │
│       │              │             │     │
│       ▼              ▼             ▼     │
│   Deploy v3     Deploy v2     Deploy v1  │
│                                          │
└─────────────────────────────────────────┘

URLs:
  https://api-id.execute-api.region.amazonaws.com/dev/
  https://api-id.execute-api.region.amazonaws.com/staging/
  https://api-id.execute-api.region.amazonaws.com/prod/
```

### 15.2 Stage Variables

- Variáveis de configuração por stage (como env vars)
- Usadas para direcionar para diferentes Lambda aliases/backends
- Exemplo: `stageVariables.lambdaAlias` → `prod` ou `dev`
- Referenciadas via `${stageVariables.variableName}`

### 15.3 Canary Deployments

- Permite direcionar % do tráfego para novo deployment
- Exemplo: 95% tráfego no deployment atual, 5% no canary
- Promover canary para produção quando estável

---

## 16. Throttling do API Gateway

### 16.1 Limites

| Nível              | Limite Padrão                    | Ajustável? |
|--------------------|----------------------------------|------------|
| **Account-level**  | 10.000 requests/segundo          | Sim        |
| **Burst**          | 5.000 requests                   | Sim        |
| **Per-method**     | Configurável via Usage Plan      | —          |
| **Per-client**     | Via API Keys + Usage Plans       | —          |

### 16.2 Quando Throttled

- Retorna **HTTP 429 Too Many Requests**
- Client deve implementar retry com exponential backoff

### 16.3 Usage Plans e API Keys

```
┌──────────────────────────────────────────┐
│           Usage Plan                      │
├──────────────────────────────────────────┤
│  - Rate: 100 requests/segundo            │
│  - Burst: 200 requests                   │
│  - Quota: 10.000 requests/mês            │
│                                           │
│  API Keys associadas:                     │
│  - Key "Cliente A" → este plan            │
│  - Key "Cliente B" → este plan            │
└──────────────────────────────────────────┘
```

> ⚠️ **Prova:** API Keys NÃO são mecanismo de autenticação! São para controle de uso/throttling apenas.

---

## 17. API Gateway Caching

### 17.1 Configuração

| Parâmetro            | Valor                          |
|----------------------|--------------------------------|
| Capacidade           | 0.5 GB a 237 GB               |
| TTL padrão           | 300 segundos (5 min)           |
| TTL range            | 0 a 3600 segundos (1h)        |
| Escopo               | Por stage                      |
| Invalidação          | Header `Cache-Control: max-age=0` |
| Custo                | $0.02 - $3.80/hora (por tamanho) |
| Encryption           | Opcional                       |

### 17.2 Cache Invalidation

- Client envia header `Cache-Control: max-age=0`
- Requer permissão IAM `execute-api:InvalidateCache`
- Pode exigir autorização (configurável)
- Flush de todo o cache via console

---

## 18. API Gateway Authorizers

### 18.1 Tipos de Autorização

```
┌─────────────────────────────────────────────────────────────┐
│                    AUTHORIZERS                                │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────┐   ┌──────────────────┐   ┌─────────────┐ │
│  │    IAM      │   │ Lambda Authorizer │   │  Cognito    │ │
│  │             │   │                   │   │  User Pool  │ │
│  │ SigV4 auth  │   │ Token-based       │   │             │ │
│  │ IAM policies│   │ Request-based     │   │ JWT token   │ │
│  │             │   │ Custom logic      │   │ Auto-verify │ │
│  └─────────────┘   └──────────────────┘   └─────────────┘ │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 18.2 Comparação Detalhada

| Aspecto              | IAM                        | Lambda Authorizer          | Cognito User Pool      |
|----------------------|----------------------------|----------------------------|------------------------|
| **Mecanismo**        | AWS Signature V4           | Token ou Request params    | JWT Token              |
| **Uso ideal**        | Cross-account, AWS users   | OAuth/SAML/custom          | User management        |
| **Caching**          | Não                        | Sim (TTL configurável)     | Sim (token validity)   |
| **Custo extra**      | Não                        | Sim (invocação Lambda)     | Não                    |
| **Externo (3rd party)** | Não                     | ✅ Sim                    | ✅ Social login        |
| **Granularidade**    | IAM Policy                 | IAM Policy gerada          | Cognito Groups/Scopes  |

### 18.3 Lambda Authorizer — Token vs Request

| Tipo           | Input                                  | Cache Key                    |
|----------------|----------------------------------------|------------------------------|
| **Token**      | Authorization header (Bearer token)    | Token value                  |
| **Request**    | Headers, query strings, stage vars     | Combinação dos parâmetros    |

---

## 19. CORS e Integration Types

### 19.1 CORS (Cross-Origin Resource Sharing)

- Necessário quando frontend em domínio diferente chama a API
- **REST API:** configuração manual dos headers (ou via console)
- **HTTP API:** configuração simples e automática
- Headers necessários:
  - `Access-Control-Allow-Origin`
  - `Access-Control-Allow-Methods`
  - `Access-Control-Allow-Headers`

### 19.2 Integration Types

| Tipo                  | Descrição                                          | Transformação    |
|-----------------------|----------------------------------------------------|------------------|
| **Lambda Proxy**      | Passa evento completo para Lambda, resposta direta | Nenhuma (passthrough) |
| **Lambda Custom**     | Usa mapping templates (VTL) para transformar       | Request + Response |
| **HTTP Proxy**        | Proxy direto para endpoint HTTP                    | Nenhuma          |
| **HTTP Custom**       | Proxy HTTP com mapping templates                   | Request + Response |
| **Mock**              | Retorna resposta sem backend                       | Response apenas  |
| **AWS Service**       | Integração direta com serviços AWS                 | Request + Response |

> ⚠️ **Prova:** Lambda Proxy é o mais comum (90% dos casos). Lambda Custom só quando precisa transformar request/response.

---

## 20. Endpoint Types

### 20.1 Tipos de Endpoint

| Tipo                 | Descrição                                      | Quando Usar                      |
|----------------------|------------------------------------------------|----------------------------------|
| **Edge-Optimized**   | Roteado via CloudFront edge locations          | Clientes globais (padrão)        |
| **Regional**         | Acesso direto na região                        | Clientes na mesma região         |
| **Private**          | Acessível apenas dentro da VPC (via VPC Endpoint) | APIs internas                 |

### 20.2 Detalhes

- **Edge-Optimized:** API Gateway ainda reside em uma região, mas CloudFront melhora latência
- **Regional:** pode adicionar seu próprio CloudFront para mais controle
- **Private:** requer VPC Endpoint (Interface) + Resource Policy para acesso

```
Edge-Optimized:
  Client ──▶ CloudFront Edge ──▶ API Gateway (us-east-1)

Regional:
  Client ──▶ API Gateway (sa-east-1) diretamente

Private:
  EC2/Lambda (VPC) ──▶ VPC Endpoint ──▶ API Gateway
```

---

## 21. Step Functions

### 21.1 Conceito

AWS Step Functions é um serviço de **orquestração serverless** que permite coordenar múltiplos serviços AWS em workflows visuais usando **Amazon States Language (ASL)** em JSON.

### 21.2 Standard vs Express Workflows

| Aspecto                | Standard                          | Express                           |
|------------------------|-----------------------------------|-----------------------------------|
| **Duração máxima**     | 1 ano                             | 5 minutos                         |
| **Modelo de execução** | Exactly-once                      | At-least-once (async) / At-most-once (sync) |
| **Taxa de início**     | 2.000/segundo                     | 100.000/segundo                   |
| **Preço**              | Por transição de estado           | Por execução + duração + memória  |
| **Histórico**          | 90 dias (console) / CloudWatch    | CloudWatch Logs apenas            |
| **Uso ideal**          | Workflows longos, auditoria       | Alto volume, baixa latência       |
| **Semântica**          | Non-idempotent OK                 | Deve ser idempotent               |

### 21.3 Tipos de States

| State        | Descrição                                          | Exemplo                        |
|--------------|----------------------------------------------------|--------------------------------|
| **Task**     | Executa trabalho (Lambda, ECS, DynamoDB, etc.)     | Invocar Lambda                 |
| **Choice**   | Lógica condicional (if/else)                       | If status == "approved"        |
| **Parallel** | Executa branches em paralelo                       | Processar imagem + notificar   |
| **Wait**     | Pausa por tempo ou até timestamp                   | Esperar 30 segundos            |
| **Map**      | Itera sobre array (loop)                           | Processar cada item de lista   |
| **Pass**     | Passa input para output (transformação)            | Adicionar dados fixos          |
| **Succeed**  | Termina com sucesso                                | Fim do workflow                |
| **Fail**     | Termina com falha                                  | Erro de validação              |

### 21.4 Diagrama de Workflow Exemplo

```
┌─────────┐     ┌──────────┐     ┌──────────────┐
│  Start  │────▶│  Task:   │────▶│   Choice:    │
│         │     │ Validate │     │  Is Valid?   │
└─────────┘     └──────────┘     └──────┬───────┘
                                        │
                            ┌───────────┴───────────┐
                            │                       │
                     ┌──────▼──────┐         ┌──────▼──────┐
                     │   Yes:      │         │   No:       │
                     │  Parallel   │         │  Fail       │
                     └──────┬──────┘         └─────────────┘
                            │
                 ┌──────────┴──────────┐
                 │                     │
          ┌──────▼──────┐       ┌──────▼──────┐
          │ Task:       │       │ Task:       │
          │ Process     │       │ Notify      │
          └──────┬──────┘       └──────┬──────┘
                 │                     │
                 └──────────┬──────────┘
                            │
                     ┌──────▼──────┐
                     │  Succeed    │
                     └─────────────┘
```

### 21.5 Integrações Diretas (SDK Integration)

- **Lambda:** invocar funções
- **ECS/Fargate:** rodar tasks
- **DynamoDB:** CRUD operations
- **SQS:** enviar mensagens
- **SNS:** publicar notificações
- **Batch:** submit jobs
- **Glue:** rodar ETL jobs
- **SageMaker:** treinar modelos

### 21.6 Error Handling

- **Retry:** retry automático com backoff configurável
- **Catch:** captura erros e redireciona para outro state
- Combinação de ambos para resiliência

---

## 22. Cognito — User Pools vs Identity Pools

### 22.1 Diagrama Conceitual

```
┌─────────────────────────────────────────────────────────────────┐
│                        AMAZON COGNITO                             │
├───────────────────────────┬─────────────────────────────────────┤
│                           │                                      │
│    USER POOLS             │     IDENTITY POOLS                   │
│    (Autenticação)         │     (Autorização/Acesso)             │
│                           │                                      │
│  "Quem é você?"          │   "O que você pode fazer?"           │
│                           │                                      │
│  ┌─────────────────┐     │     ┌─────────────────────┐         │
│  │ Sign-up/Sign-in │     │     │ AWS Credentials     │         │
│  │ JWT Tokens      │     │     │ (Temporary)         │         │
│  │ MFA             │─────┼────▶│ IAM Roles           │         │
│  │ Social Login    │     │     │ Fine-grained access │         │
│  │ SAML/OIDC       │     │     │ S3, DynamoDB, etc.  │         │
│  └─────────────────┘     │     └─────────────────────┘         │
│                           │                                      │
└───────────────────────────┴─────────────────────────────────────┘
```

### 22.2 Tabela Comparativa COMPLETA

| Aspecto                    | User Pools                            | Identity Pools (Federated Identities) |
|----------------------------|---------------------------------------|---------------------------------------|
| **Função principal**       | Autenticação (AuthN)                  | Autorização (AuthZ)                   |
| **Output**                 | JWT tokens (ID + Access + Refresh)    | Credenciais AWS temporárias           |
| **Diretório de usuários**  | ✅ Gerenciado pelo Cognito            | ❌ Não gerencia usuários              |
| **Sign-up / Sign-in**     | ✅ Sim                                | ❌ Não                                |
| **Social login**           | ✅ Google, Facebook, Apple, Amazon    | ✅ Via User Pool ou diretamente       |
| **SAML 2.0 / OIDC**       | ✅ Enterprise federation              | ✅ Via qualquer IdP                   |
| **MFA**                    | ✅ SMS, TOTP                          | ❌ Não                                |
| **Custom UI**              | ✅ Hosted UI ou custom                | N/A                                   |
| **Lambda Triggers**        | ✅ Pre/Post auth, migration, etc.     | ❌ Não                                |
| **Acesso a AWS Services**  | ❌ Não diretamente                    | ✅ Via IAM Role temporário            |
| **Guest access**           | ❌ Não                                | ✅ Unauthenticated role               |
| **Groups**                 | ✅ Com IAM role mapping               | ✅ Role mapping por claims            |
| **Token customization**    | ✅ Pre-token generation Lambda        | N/A                                   |

### 22.3 Fluxo Completo (User Pool + Identity Pool)

```
┌──────┐    1. Login     ┌─────────────┐
│      │────────────────▶│  Cognito    │
│      │                 │  User Pool  │
│      │◀────────────────│             │
│ App  │   2. JWT Token  └─────────────┘
│      │
│      │    3. JWT Token  ┌─────────────┐
│      │────────────────▶│  Cognito    │
│      │                 │Identity Pool │
│      │◀────────────────│             │
│      │ 4. AWS Creds    └─────────────┘
│      │   (temp IAM)
│      │    5. Access     ┌─────────────┐
│      │────────────────▶│  S3/DynamoDB│
│      │                 │  (IAM auth) │
└──────┘                 └─────────────┘
```

### 22.4 Casos de Uso na Prova

| Cenário                                          | Serviço                       |
|--------------------------------------------------|-------------------------------|
| App precisa de sign-up/sign-in                   | User Pool                     |
| App mobile precisa acessar S3 diretamente        | Identity Pool                 |
| Enterprise SSO com SAML                          | User Pool (federation)        |
| Acesso guest (não autenticado) a recursos AWS    | Identity Pool (unauth role)   |
| API Gateway com autenticação de usuários         | User Pool como Authorizer     |
| Usuários sociais precisam acessar DynamoDB       | User Pool + Identity Pool     |

---

## 23. AWS AppSync

### 23.1 Conceito

AWS AppSync é um serviço **managed GraphQL** que facilita a construção de APIs com:
- **Real-time subscriptions** (via WebSockets)
- **Offline sync** (para mobile apps)
- **Resolvers** que conectam a múltiplos data sources

### 23.2 Arquitetura

```
┌──────────────┐         ┌─────────────────┐
│  Client App  │◀──WS───▶│   AWS AppSync   │
│  (Mobile/Web)│──HTTP──▶│   GraphQL API   │
└──────────────┘         └────────┬────────┘
                                  │
                    ┌─────────────┼─────────────┐
                    │             │             │
              ┌─────▼─────┐ ┌────▼────┐ ┌─────▼─────┐
              │ DynamoDB  │ │ Lambda  │ │   RDS     │
              │           │ │         │ │ (Aurora)  │
              └───────────┘ └─────────┘ └───────────┘
              
              Outros: OpenSearch, HTTP endpoints, EventBridge
```

### 23.3 Características Principais

| Feature                  | Detalhe                                         |
|--------------------------|-------------------------------------------------|
| **Protocolo**            | GraphQL (queries, mutations, subscriptions)      |
| **Real-time**            | ✅ Via WebSocket subscriptions                   |
| **Offline**              | ✅ Sync automático quando reconecta              |
| **Auth**                 | API Key, IAM, Cognito, OIDC                     |
| **Caching**              | ✅ Server-side caching                           |
| **Data Sources**         | DynamoDB, Lambda, RDS, OpenSearch, HTTP, EventBridge |
| **Resolvers**            | VTL (Velocity) ou JavaScript                     |
| **Batching**             | ✅ Pipeline resolvers                            |
| **Merge APIs**           | ✅ Combinar múltiplos schemas                    |

### 23.4 AppSync vs API Gateway

| Aspecto            | AppSync                  | API Gateway              |
|--------------------|--------------------------|--------------------------|
| **Protocolo**      | GraphQL                  | REST / HTTP / WebSocket  |
| **Real-time**      | ✅ Subscriptions nativas | WebSocket API (separado) |
| **Offline sync**   | ✅ Nativo                | ❌ Não                   |
| **Flexibilidade**  | Schema-driven            | Resource-driven          |
| **Uso ideal**      | Mobile, real-time, graph | REST APIs, microservices |

> ⚠️ **Prova:** Se menciona GraphQL → AppSync. Se menciona real-time + sync offline → AppSync.

---

## 24. Palavras-Chave da Prova SAA-C03 — Cenários e Respostas

### 24.1 Mapeamento Cenário → Resposta

| # | Cenário/Palavra-chave na Questão | Resposta |
|---|----------------------------------|----------|
| 1 | "Serverless", "sem gerenciar servidores", "event-driven" | **Lambda** |
| 2 | "Processamento > 15 minutos" | **NÃO é Lambda** → ECS/Fargate ou Step Functions |
| 3 | "Cold start inaceitável", "latência consistente" | **Provisioned Concurrency** |
| 4 | "Lambda + banco relacional", "connection exhaustion" | **RDS Proxy** |
| 5 | "Lambda precisa acessar recursos na VPC + internet" | **Lambda em VPC + NAT Gateway** |
| 6 | "Lambda precisa acessar S3/DynamoDB em VPC" | **VPC Endpoints (Gateway ou Interface)** |
| 7 | "Compartilhar bibliotecas entre funções Lambda" | **Lambda Layers** |
| 8 | "Deploy gradual de Lambda", "canary", "traffic shifting" | **Aliases + CodeDeploy** |
| 9 | "Resultado de invocação assíncrona", "on success/failure" | **Lambda Destinations** |
| 10 | "Manipulação de header no CloudFront", "URL rewrite simples" | **CloudFront Functions** |
| 11 | "Lógica complexa no edge", "SSR", "acesso a rede no edge" | **Lambda@Edge** |
| 12 | "API com cache", "reduzir latência de API" | **API Gateway REST API + Caching** |
| 13 | "API barata", "sem features avançadas", "proxy simples" | **API Gateway HTTP API** |
| 14 | "Real-time bidirectional", "chat", "gaming" | **API Gateway WebSocket** ou **AppSync** |
| 15 | "Autenticação de usuários", "sign-up/sign-in", "MFA" | **Cognito User Pool** |
| 16 | "Acesso mobile a S3/DynamoDB", "credenciais temporárias" | **Cognito Identity Pool** |
| 17 | "Social login (Google, Facebook)" | **Cognito User Pool (federation)** |
| 18 | "Orquestrar múltiplos Lambda", "workflow visual" | **Step Functions** |
| 19 | "Workflow longo (dias/semanas)", "human approval" | **Step Functions Standard** |
| 20 | "Alto volume de execuções", "workflow curto" | **Step Functions Express** |
| 21 | "GraphQL", "real-time subscriptions" | **AppSync** |
| 22 | "Offline sync", "mobile app sync" | **AppSync** |
| 23 | "Lambda com dependência grande (ML)", "container > 250MB" | **Lambda Container Images (até 10 GB)** |
| 24 | "Throttling de API por cliente" | **API Gateway Usage Plans + API Keys** |
| 25 | "Autorizar API com token customizado/OAuth" | **Lambda Authorizer** |
| 26 | "Cross-account API access" | **IAM Authorizer + Resource Policy** |
| 27 | "Lambda Java cold start lento" | **SnapStart** |
| 28 | "Reduzir custo Lambda sem perder performance" | **Graviton2 (arm64)** — 20% mais barato |
| 29 | "Processar items em paralelo no workflow" | **Step Functions Map ou Parallel state** |
| 30 | "API Gateway privada (acesso só VPC)" | **Private Endpoint + VPC Endpoint** |

### 24.2 Armadilhas Comuns

| Armadilha | Correto |
|-----------|---------|
| "API Keys para autenticação" | ❌ API Keys são para throttling, NÃO auth |
| "Lambda@Edge para manipulação simples de header" | ❌ Use CloudFront Functions (mais barato) |
| "Lambda timeout > 15 min" | ❌ Impossível. Use ECS/Fargate |
| "Lambda em VPC acessa internet diretamente" | ❌ Precisa de NAT Gateway |
| "Container image em Lambda = igual ECS" | ❌ Ainda tem limites Lambda (15 min, etc.) |
| "DLQ é a melhor opção para async" | ❌ Destinations é recomendado (mais features) |
| "Provisioned Concurrency = Reserved Concurrency" | ❌ Reserved só reserva, não elimina cold start |
| "HTTP API suporta cache" | ❌ Apenas REST API tem cache |

---

## Resumo Visual — Árvore de Decisão Serverless

```
                    Precisa de computação?
                            │
                    ┌───────┴───────┐
                    │               │
               < 15 min?        > 15 min?
                    │               │
                    ▼               ▼
               AWS Lambda      ECS/Fargate
                    │          ou Step Functions
                    │
         ┌──────────┼──────────────┐
         │          │              │
    Precisa de   Precisa de    Precisa de
    API REST?    orquestração? real-time?
         │          │              │
         ▼          ▼              ▼
    API Gateway  Step Functions  AppSync
    (REST/HTTP)                  ou WebSocket API
```

---

*Documento atualizado em Julho/2026 para o exame AWS SAA-C03.*
*Total de tópicos cobertos: Lambda (13), API Gateway (7), Serverless (3), Prova (1).*
