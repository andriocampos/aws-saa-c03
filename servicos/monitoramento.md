# Monitoramento, Logging e Auditoria — Guia Aprofundado SAA-C03

> Guia completo para a certificação AWS Solutions Architect Associate (SAA-C03).
> Cobre CloudWatch, CloudTrail, Config, X-Ray, Health Dashboard e Trusted Advisor.

---

## 1. CloudWatch Metrics

### 1.1 Conceitos Fundamentais

O CloudWatch coleta métricas de praticamente todos os serviços AWS. Cada métrica pertence a um **namespace** (ex: `AWS/EC2`, `AWS/RDS`, `AWS/ELB`) e possui **dimensões** que identificam a origem (ex: `InstanceId`, `AutoScalingGroupName`).

```
┌─────────────────────────────────────────────────────────┐
│                   CloudWatch Metrics                      │
├─────────────────────────────────────────────────────────┤
│  Namespace: AWS/EC2                                      │
│  ├── Metric: CPUUtilization                              │
│  │   ├── Dimension: InstanceId = i-0abc123               │
│  │   └── Dimension: InstanceId = i-0def456               │
│  ├── Metric: NetworkIn                                   │
│  │   └── Dimension: InstanceId = i-0abc123               │
│  └── Metric: DiskReadOps                                 │
│      └── Dimension: AutoScalingGroupName = my-asg        │
├─────────────────────────────────────────────────────────┤
│  Namespace: AWS/RDS                                      │
│  ├── Metric: DatabaseConnections                         │
│  └── Metric: FreeStorageSpace                            │
└─────────────────────────────────────────────────────────┘
```

### 1.2 Standard Monitoring vs Detailed Monitoring

| Característica | Standard Monitoring | Detailed Monitoring |
|----------------|--------------------|--------------------|
| Granularidade | **5 minutos** | **1 minuto** |
| Custo | Gratuito | Pago (custo adicional) |
| Habilitação | Padrão para EC2 | Deve ser habilitado explicitamente |
| Serviços | EC2 (padrão) | EC2, ASG, ELB (quando habilitado) |
| Caso de uso | Monitoramento geral | Alarmes mais responsivos, Auto Scaling rápido |

**IMPORTANTE para a prova:** Alguns serviços já enviam métricas a cada 1 minuto por padrão (ELB, RDS, Lambda). O "detailed monitoring" como opção paga aplica-se principalmente ao EC2.

### 1.3 Custom Metrics (PutMetricData)

Métricas que a AWS **NÃO coleta automaticamente** do EC2:
- **Utilização de memória (RAM)**
- **Espaço em disco utilizado**
- **Swap utilizado**
- **Número de processos**

Para coletar essas métricas, é necessário instalar o **CloudWatch Agent** ou usar a API `PutMetricData`.

```
┌──────────────┐    PutMetricData API    ┌───────────────┐
│  EC2 / On-   │ ─────────────────────── │  CloudWatch   │
│  Premises    │   (custom namespace)    │  Metrics      │
│  + CW Agent  │                         │               │
└──────────────┘                         └───────────────┘
```

**Parâmetros do PutMetricData:**
- `MetricName`: nome da métrica
- `Namespace`: namespace customizado (ex: `Custom/MyApp`)
- `Value`: valor numérico
- `Dimensions`: até 30 dimensões por métrica
- `Timestamp`: momento da medição
- `StorageResolution`: 1 (high-resolution) ou 60 (standard)

### 1.4 Resolution (Resolução)

| Tipo | Intervalo de Coleta | Custo | Caso de Uso |
|------|--------------------:|-------|-------------|
| Standard Resolution | 60 segundos (1 min) | Normal | Maioria dos casos |
| High Resolution | 1, 5, 10, ou 30 segundos | Mais caro | Alarmes ultra-rápidos, trading |

**High-Resolution Metrics:**
- Definida via `StorageResolution = 1` no PutMetricData
- Permite alarmes com período de 10, 30 ou 60 segundos
- Ideal para aplicações que precisam reagir em segundos

### 1.5 Retenção de Dados

| Resolução Original | Período de Retenção | Agregação |
|--------------------:|--------------------:|-----------|
| < 60 segundos (high-res) | **3 horas** | Dados brutos |
| 1 minuto | **15 dias** | Depois agrega para 5 min |
| 5 minutos | **63 dias** | Depois agrega para 1 hora |
| 1 hora | **455 dias** (~15 meses) | Retenção máxima automática |

**DICA DA PROVA:** Se a questão pedir "retenção de longo prazo de métricas", a resposta padrão é 455 dias (1 hora de resolução). Para reter por mais tempo, exporte para S3.

### 1.6 Métricas EC2 — O que é coletado vs O que NÃO é

| Coletado Automaticamente (Hypervisor) | NÃO Coletado (precisa Agent) |
|---------------------------------------|-------------------------------|
| CPUUtilization | **Utilização de memória (RAM)** |
| DiskReadOps / DiskWriteOps | **Espaço em disco** |
| DiskReadBytes / DiskWriteBytes | **Swap utilizado** |
| NetworkIn / NetworkOut | **Número de processos** |
| NetworkPacketsIn / NetworkPacketsOut | **Logs do sistema** |
| StatusCheckFailed | Métricas de aplicação |
| StatusCheckFailed_Instance | |
| StatusCheckFailed_System | |

---

## 2. CloudWatch Alarms

### 2.1 Estados de um Alarme

```
         ┌──────────────────┐
         │  INSUFFICIENT_   │
         │     DATA         │ ← Estado inicial (sem dados suficientes)
         └────────┬─────────┘
                  │
         dados chegam
                  │
         ┌───────▼────────┐         threshold violado         ┌──────────┐
         │       OK       │ ────────────────────────────────── │  ALARM   │
         │                │                                    │          │
         └───────▲────────┘         threshold OK novamente     └──────┬───┘
                  │                                                    │
                  └────────────────────────────────────────────────────┘
```

| Estado | Significado |
|--------|------------|
| **OK** | A métrica está dentro do threshold definido |
| **ALARM** | A métrica violou o threshold |
| **INSUFFICIENT_DATA** | Dados insuficientes para avaliar (início ou métrica parada) |

### 2.2 Ações dos Alarmes

| Tipo de Ação | Destino | Exemplo |
|-------------|---------|---------|
| Notificação | **SNS Topic** | Enviar email, SMS, trigger Lambda |
| Auto Scaling | **ASG Policy** | Scale out/in baseado em CPU |
| EC2 Action | **Instância EC2** | Stop, Terminate, Reboot, Recover |

**EC2 Actions detalhadas:**
- **Stop:** para a instância (EBS-backed only)
- **Terminate:** termina a instância permanentemente
- **Reboot:** reinicia a instância
- **Recover:** move para novo hardware (mantém IP, metadata, EBS)

### 2.3 Evaluation Period e Datapoints to Alarm

- **Period:** janela de tempo para cada avaliação (ex: 5 minutos)
- **Evaluation Periods:** quantos períodos consecutivos avaliar (ex: 3)
- **Datapoints to Alarm:** quantos períodos devem estar em violação (ex: 2 de 3)

```
Exemplo: Period=5min, Evaluation Periods=3, Datapoints to Alarm=2

Período 1: 85% CPU (> 80% threshold) → BREACH ✗
Período 2: 75% CPU (< 80% threshold) → OK ✓
Período 3: 90% CPU (> 80% threshold) → BREACH ✗

Resultado: 2 de 3 em breach → ALARM disparado!
```

### 2.4 Composite Alarms

Combinam múltiplos alarmes usando operadores **AND** e **OR** para reduzir ruído de alertas.

```
┌─────────────────┐     ┌─────────────────┐
│ Alarm: High CPU │     │ Alarm: High Mem │
│   (> 80%)       │     │   (> 90%)       │
└────────┬────────┘     └────────┬────────┘
         │                       │
         └───────────┬───────────┘
                     │ AND
              ┌──────▼──────┐
              │  Composite  │
              │   Alarm     │ → Só dispara SNS se AMBOS estiverem em ALARM
              └─────────────┘
```

**Benefícios:**
- Reduz alarmes falsos (alert fatigue)
- Permite lógica complexa: "(CPU alta AND Memória alta) OR (Disk full)"
- Cada alarme filho pode ter suas próprias ações

### 2.5 Tratamento de Missing Data

| Configuração | Comportamento |
|-------------|--------------|
| `missing` (padrão) | Mantém o estado atual do alarme |
| `notBreaching` | Trata dados ausentes como "dentro do threshold" |
| `breaching` | Trata dados ausentes como "violação" |
| `ignore` | Ignora e espera pelo próximo datapoint |

**DICA DA PROVA:** Para alarmes em instâncias que podem ser desligadas legitimamente, use `missing` ou `notBreaching` para evitar alarmes falsos.

---

## 3. CloudWatch Logs

### 3.1 Arquitetura de Logs

```
┌─────────────────────────────────────────────────────────────┐
│                    CloudWatch Logs                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Log Group: /aws/lambda/my-function                          │
│  ├── Log Stream: 2024/01/15/[$LATEST]abc123                  │
│  │   ├── Log Event: "START RequestId: xxx"                   │
│  │   ├── Log Event: "Processing order 12345"                 │
│  │   └── Log Event: "END RequestId: xxx"                     │
│  ├── Log Stream: 2024/01/15/[$LATEST]def456                  │
│  └── Log Stream: 2024/01/16/[$LATEST]ghi789                  │
│                                                              │
│  Log Group: /var/log/messages                                │
│  ├── Log Stream: i-0abc123 (instância EC2)                   │
│  └── Log Stream: i-0def456 (instância EC2)                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Expiration Policies (Retenção)

| Política | Descrição |
|----------|-----------|
| Never Expire | Logs mantidos indefinidamente (padrão) |
| 1 dia a 10 anos | Períodos configuráveis de retenção |

**IMPORTANTE:** A retenção padrão é **Never Expire**. Sempre configure uma política de expiração para controlar custos!

### 3.3 Metric Filters

Extraem métricas numéricas a partir de padrões encontrados nos logs.

```
┌──────────────┐    Metric Filter     ┌───────────────┐    Alarm    ┌─────────┐
│ CloudWatch   │ ──────────────────── │  CloudWatch   │ ──────────  │   SNS   │
│ Logs         │  pattern: "ERROR"    │  Metric       │             │  Topic  │
│              │  → count errors      │  ErrorCount   │             │         │
└──────────────┘                      └───────────────┘             └─────────┘
```

**Exemplos de padrões:**
- `[ip, user, timestamp, request, status_code=5*, bytes]` — erros 5xx
- `{ $.errorCode = "AccessDenied" }` — JSON filter para acesso negado
- `"ERROR"` — busca literal pela palavra ERROR

### 3.4 Subscription Filters

Enviam logs em **tempo real** para outros destinos:

| Destino | Caso de Uso |
|---------|-------------|
| **AWS Lambda** | Processamento customizado, transformação |
| **Kinesis Data Streams** | Análise em tempo real |
| **Kinesis Data Firehose** | Entrega para S3, OpenSearch, Splunk |

```
                    ┌──── Lambda (processamento)
                    │
Log Group ──── Subscription Filter ──┼──── Kinesis Data Streams (real-time analytics)
                    │
                    └──── Kinesis Firehose (S3, OpenSearch)
```

**Cross-Account Log Sharing:**
- Conta origem configura subscription filter apontando para Kinesis/Lambda na conta destino
- Requer permissões cross-account via resource policy

### 3.5 CloudWatch Logs Insights

Linguagem de query para análise de logs. **NÃO é real-time** — consulta logs já armazenados.

**Exemplos de queries:**

```sql
-- Top 20 log events mais recentes
fields @timestamp, @message
| sort @timestamp desc
| limit 20

-- Contagem de erros por hora
filter @message like /ERROR/
| stats count(*) as errorCount by bin(1h)
| sort errorCount desc

-- Latência média por endpoint
filter @message like /API/
| parse @message "* * * *ms" as method, endpoint, status, latency
| stats avg(latency), max(latency), min(latency) by endpoint

-- Top 10 IPs com mais requests
parse @message '* - - *' as ip, rest
| stats count(*) as requestCount by ip
| sort requestCount desc
| limit 10
```

### 3.6 Export to S3 (CreateExportTask)

- **NÃO é real-time** — é um batch export (pode levar até 12 horas)
- Usa a API `CreateExportTask`
- O bucket S3 deve ter policy permitindo `logs.amazonaws.com`
- Para real-time, use **Subscription Filters** com Kinesis Firehose

### 3.7 Live Tail

- Visualização em **tempo real** dos logs no console
- Permite filtrar por padrões enquanto os logs chegam
- Útil para debugging em tempo real

---

## 4. CloudWatch Agent

### 4.1 Unified CloudWatch Agent vs Legacy

| Característica | Unified Agent (novo) | Legacy Monitoring Scripts |
|---------------|---------------------|--------------------------|
| Coleta métricas | ✅ RAM, Disk, custom | ✅ Limitado |
| Coleta logs | ✅ | ❌ |
| On-premises | ✅ | ❌ |
| Configuração | JSON file ou SSM Parameter Store | Scripts Perl |
| Recomendação | **USAR ESTE** | Deprecado |

### 4.2 Instalação e Configuração

```
┌─────────────────────────────────────────────────────────────┐
│                  EC2 Instance / On-Premises                   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │           Unified CloudWatch Agent                   │    │
│  │                                                      │    │
│  │  Coleta:                                             │    │
│  │  • Métricas de sistema (RAM, Disk, Swap, CPU det.)  │    │
│  │  • Logs de arquivos (/var/log/*, app logs)          │    │
│  │  • StatsD metrics (da aplicação)                    │    │
│  │  • collectd metrics                                  │    │
│  └──────────────────────┬───────────────────────────────┘    │
│                         │                                    │
└─────────────────────────┼────────────────────────────────────┘
                          │ IAM Role (EC2) ou credentials
                          ▼
                 ┌─────────────────┐
                 │   CloudWatch    │
                 │  Metrics + Logs │
                 └─────────────────┘
```

**Requisitos:**
- IAM Role com permissão `CloudWatchAgentServerPolicy`
- Configuração via JSON (wizard disponível) ou SSM Parameter Store
- Funciona em **EC2** e **servidores on-premises** (hybrid)

### 4.3 Métricas Coletadas pelo Agent

- `mem_used_percent` — uso de memória RAM
- `disk_used_percent` — uso de disco
- `swap_used_percent` — uso de swap
- `netstat_tcp_established` — conexões TCP
- `processes_total` — total de processos
- CPU detalhado: per-core, idle, iowait, steal, etc.

---

## 5. CloudWatch Dashboards

### 5.1 Características

- **Globais:** podem exibir métricas de **múltiplas regiões** e **múltiplas contas**
- Não pertencem a uma região específica
- Até 3 dashboards gratuitos (50 métricas cada); depois cobrado por dashboard/mês
- Atualização automática configurável (10s, 1min, 2min, 5min, 15min)

### 5.2 Tipos de Widgets

| Widget | Função |
|--------|--------|
| Line | Gráfico de linhas (tendências no tempo) |
| Stacked area | Áreas empilhadas (composição) |
| Number | Valor numérico único (KPI) |
| Bar | Gráfico de barras |
| Pie | Gráfico de pizza |
| Text | Markdown livre (documentação) |
| Log table | Resultados de Logs Insights |
| Alarm status | Status visual de alarmes |
| Explorer | Métricas dinâmicas por tag |

### 5.3 Cross-Account e Cross-Region

```
┌──────────────────────────────────────────────┐
│         CloudWatch Dashboard (Global)         │
├──────────────────────────────────────────────┤
│                                              │
│  Widget 1: EC2 CPU (us-east-1, Conta A)     │
│  Widget 2: RDS Connections (eu-west-1)       │
│  Widget 3: Lambda Errors (Conta B)           │
│  Widget 4: ALB Requests (ap-southeast-1)     │
│                                              │
└──────────────────────────────────────────────┘
```

**Requisitos para cross-account:**
- Conta de monitoramento configurada como "monitoring account"
- Contas fonte habilitam compartilhamento via CloudWatch cross-account observability

---

## 6. CloudWatch Container Insights

### 6.1 O que Monitora

| Plataforma | Métricas Coletadas |
|-----------|-------------------|
| **ECS** | CPU, memória, rede, disco por task/service/cluster |
| **EKS** | CPU, memória, rede por pod/node/namespace/cluster |
| **Kubernetes (self-managed)** | Mesmas métricas do EKS |
| **Fargate** | CPU e memória por task |

### 6.2 Arquitetura

```
┌─────────────────────────────────────────────┐
│             ECS/EKS Cluster                  │
│                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │  Task/   │  │  Task/   │  │  Task/   │  │
│  │  Pod 1   │  │  Pod 2   │  │  Pod 3   │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  │
│       │              │              │        │
│  ┌────▼──────────────▼──────────────▼────┐  │
│  │     CloudWatch Agent (DaemonSet)       │  │
│  │     ou CW Agent Sidecar (Fargate)      │  │
│  └───────────────────┬───────────────────┘  │
│                      │                       │
└──────────────────────┼───────────────────────┘
                       ▼
              ┌─────────────────┐
              │  CloudWatch     │
              │  Container      │
              │  Insights       │
              └─────────────────┘
```

**DICA DA PROVA:** Container Insights usa o CloudWatch Agent configurado como DaemonSet no EKS/K8s ou como sidecar no Fargate.

---

## 7. CloudWatch Lambda Insights

### 7.1 Características

- Extensão (Lambda Layer) que coleta métricas de performance de funções Lambda
- Métricas coletadas:
  - **Duration** (tempo de execução)
  - **Memory utilization** (uso real vs alocado)
  - **Cold starts** (quantos e duração)
  - **CPU total time**
  - **Network (TX/RX bytes)**
  - **Init duration**

### 7.2 Como Habilitar

1. Adicionar a Lambda Layer do CloudWatch Lambda Insights
2. Adicionar permissão `CloudWatchLambdaInsightsExecutionRolePolicy` à role da Lambda
3. Métricas aparecem no namespace `LambdaInsights`

---

## 8. CloudWatch Contributor Insights

### 8.1 Conceito

Identifica os **top-N contributors** (maiores contribuidores) para um padrão de tráfego.

### 8.2 Exemplos de Uso

| Cenário | Contributor Identificado |
|---------|-------------------------|
| DDoS/tráfego anômalo | Top 10 IPs por volume de requests |
| Erros frequentes | Top URLs com mais erros 5xx |
| Uso de recursos | Top usuários consumindo mais API calls |
| VPC Flow Logs | Top hosts gerando tráfego |

### 8.3 Funcionamento

```
CloudWatch Logs ──→ Contributor Insights Rule ──→ Top-N Report
(VPC Flow Logs,      (define campos e filtros)     (IPs, URLs,
 access logs, etc.)                                 users, etc.)
```

- Funciona sobre **CloudWatch Logs**
- Regras podem ser criadas via console ou predefinidas pela AWS
- Atualização em near real-time

---

## 9. CloudWatch Application Insights

### 9.1 O que é

Monitoração automática de aplicações que detecta problemas e gera dashboards automaticamente.

### 9.2 Aplicações Suportadas

- Aplicações **.NET** e **SQL Server**
- Java
- IIS
- SharePoint
- Bancos de dados (MySQL, PostgreSQL, Oracle)
- SAP HANA

### 9.3 Características

- Detecta problemas automaticamente usando **machine learning**
- Cria dashboards com métricas, logs e alarmes correlacionados
- Integra com **SSM OpsCenter** para criar OpsItems automaticamente
- Reduz tempo de troubleshooting (MTTR)

---

## 10. CloudWatch Synthetics (Canaries)

### 10.1 Conceito

Scripts que rodam **periodicamente** para monitorar endpoints, APIs e workflows de forma **proativa** — antes que os usuários reportem problemas.

### 10.2 Características

| Aspecto | Detalhe |
|---------|---------|
| Linguagem | **Node.js** ou **Python** |
| Frequência | A cada 1 minuto ou conforme schedule (cron) |
| O que testa | URLs, APIs, workflows multi-step |
| Métricas | Latência, disponibilidade, screenshots |
| Alertas | Integra com CloudWatch Alarms |

### 10.3 Blueprints Disponíveis

- **Heartbeat Monitor:** verifica se URL responde (GET)
- **API Canary:** testa REST APIs (GET, POST, PUT, DELETE)
- **Broken Link Checker:** verifica links quebrados em uma página
- **Visual Monitoring:** compara screenshots para detectar mudanças visuais
- **Canary Recorder:** grava interações no browser e reproduz

### 10.4 Arquitetura

```
┌────────────────┐      executa a cada X min      ┌──────────────────┐
│   CloudWatch   │ ──────────────────────────────→ │  Canary Script   │
│   Synthetics   │                                 │  (Lambda)        │
│   (Schedule)   │                                 │                  │
└────────────────┘                                 └────────┬─────────┘
                                                            │
                                                   testa endpoint
                                                            │
                                                            ▼
                                                   ┌──────────────────┐
                                                   │  Sua API/Site    │
                                                   │  (endpoint)      │
                                                   └──────────────────┘
         Resultado ──→ CloudWatch Metrics ──→ Alarm ──→ SNS
         Screenshots ──→ S3
```

**DICA DA PROVA:** "Monitorar disponibilidade proativamente" ou "verificar endpoint antes dos usuários" = **CloudWatch Synthetics Canaries**.

---

## 11. CloudWatch Evidently

### 11.1 Conceito

Serviço para **feature flags** e **A/B testing** integrado ao CloudWatch.

### 11.2 Funcionalidades

| Funcionalidade | Descrição |
|---------------|-----------|
| **Feature Flags** | Habilitar/desabilitar features para % dos usuários |
| **A/B Testing (Experiments)** | Comparar variações e medir impacto em métricas |
| **Launches** | Rollout gradual de features (ex: 10% → 50% → 100%) |
| **Overrides** | Forçar variação para usuários específicos (testing) |

### 11.3 Fluxo

```
┌──────────┐     feature flag check     ┌───────────────────┐
│  Client  │ ────────────────────────── │  CloudWatch       │
│  (App)   │                            │  Evidently        │
│          │ ◄──── variation response    │                   │
└──────────┘                            └───────┬───────────┘
                                                │
                                        armazena resultados
                                                │
                                                ▼
                                        ┌───────────────────┐
                                        │  CloudWatch Logs  │
                                        │  ou S3            │
                                        └───────────────────┘
```

**Diferença de outros serviços:**
- AppConfig (SSM) = feature flags simples sem analytics
- Evidently = feature flags + experimentos + métricas de impacto

---

## 12. AWS CloudTrail

### 12.1 Conceito

Registra **todas as chamadas de API** feitas na conta AWS. Responde: **quem** fez **o quê**, **quando** e **de onde**.

```
┌──────────────────────────────────────────────────────────────┐
│                        CloudTrail                              │
│                                                               │
│  Quem: IAM User "admin" (arn:aws:iam::123:user/admin)        │
│  O quê: TerminateInstances                                    │
│  Quando: 2024-01-15T14:30:00Z                                 │
│  De onde: IP 203.0.113.50                                     │
│  Resultado: Success                                           │
│  Recursos: i-0abc123def456                                    │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

### 12.2 Tipos de Eventos

| Tipo | O que Registra | Custo | Exemplos |
|------|---------------|-------|----------|
| **Management Events** | Operações de gerenciamento em recursos | Gratuito (1ª cópia, 1 trail) | CreateBucket, RunInstances, CreateVPC |
| **Data Events** | Operações nos dados dos recursos | Pago | S3 GetObject/PutObject, Lambda Invoke |
| **Insights Events** | Atividade anômala de API | Pago | Spike em chamadas TerminateInstances |

### 12.3 Management Events — Detalhe

- **Read Events:** DescribeInstances, ListBuckets, GetBucketPolicy
- **Write Events:** CreateInstance, DeleteBucket, PutBucketPolicy
- Pode configurar trail para capturar apenas Read, apenas Write, ou ambos
- **1 cópia gratuita** por região (primeiro trail)

### 12.4 Data Events — Detalhe

- **S3 Object-Level:** GetObject, PutObject, DeleteObject
- **Lambda Function Invocations:** Invoke
- **DynamoDB:** GetItem, PutItem, DeleteItem
- **Alto volume** — por isso é pago e desabilitado por padrão
- Pode filtrar por bucket/função específica para reduzir custos

### 12.5 Insights Events

- Detecta **atividade incomum** usando baseline de atividade normal
- Exemplos:
  - Spike repentino em `TerminateInstances` (possível ataque)
  - Aumento anormal em `AuthorizeSecurityGroupIngress`
  - Pico em chamadas de API de uma região não usual
- Gera evento no EventBridge para automação

### 12.6 Trail — Configurações

| Configuração | Descrição |
|-------------|-----------|
| **Multi-Region Trail** | Captura eventos de TODAS as regiões (recomendado) |
| **Organization Trail** | Trail para toda a AWS Organization |
| **S3 Delivery** | Entrega logs compactados (.json.gz) em S3 |
| **CloudWatch Logs** | Entrega em tempo real para CloudWatch Logs |
| **SNS Notification** | Notifica quando novo arquivo é entregue |
| **Log File Integrity Validation** | Digest files para verificar se logs foram alterados |
| **KMS Encryption** | Criptografa logs com CMK |

### 12.7 Log File Integrity Validation

```
Trail ──→ S3 Bucket
           ├── AWSLogs/123456789012/CloudTrail/us-east-1/2024/01/15/
           │   ├── 123456789012_CloudTrail_us-east-1_20240115T1430Z_abc.json.gz
           │   └── 123456789012_CloudTrail_us-east-1_20240115T1500Z_def.json.gz
           └── AWSLogs/123456789012/CloudTrail-Digest/us-east-1/2024/01/15/
               └── digest-file.json.gz (hash SHA-256 dos logs)
```

- Usa **SHA-256 hashing** e **RSA signing**
- Digest files permitem verificar se logs foram modificados ou deletados
- Comando: `aws cloudtrail validate-logs`
- **IMPORTANTE para compliance:** prova de que logs não foram adulterados

### 12.8 Integração com EventBridge

```
CloudTrail Event ──→ EventBridge Rule ──→ Target (Lambda, SNS, SSM, etc.)

Exemplo: Detectar quando alguém deleta um bucket S3
{
  "source": ["aws.s3"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventName": ["DeleteBucket"]
  }
}
```

**Casos de uso:**
- Alertar quando security group é modificado
- Trigger Lambda quando root user faz login
- Reverter mudanças não autorizadas automaticamente

### 12.9 CloudTrail Lake

- **Data lake** para eventos do CloudTrail
- Permite **SQL queries** diretamente nos eventos (sem exportar para Athena)
- Retenção configurável (até 7 anos)
- Suporta eventos de múltiplas contas e regiões
- Alternativa ao Athena para queries simples em eventos CloudTrail

```sql
-- Exemplo: Quem deletou buckets nos últimos 7 dias?
SELECT eventTime, userIdentity.arn, requestParameters
FROM event_data_store_id
WHERE eventName = 'DeleteBucket'
AND eventTime > '2024-01-08'
ORDER BY eventTime DESC
```

---

## 13. AWS Config

### 13.1 Conceito

Monitora e registra as **configurações** dos recursos AWS ao longo do tempo. Responde: "O recurso está configurado corretamente?" e "Como estava configurado no passado?"

### 13.2 Config Rules

| Tipo | Descrição | Exemplos |
|------|-----------|----------|
| **AWS Managed Rules** | Regras predefinidas pela AWS (150+) | `s3-bucket-versioning-enabled`, `restricted-ssh` |
| **Custom Rules** | Regras via **Lambda function** | Verificar tags obrigatórias, naming conventions |

### 13.3 Trigger de Avaliação

| Trigger | Quando Avalia | Caso de Uso |
|---------|--------------|-------------|
| **Configuration Change** | Quando o recurso muda | "Alertar quando SG permite 0.0.0.0/0" |
| **Periodic** | A cada 1h, 3h, 6h, 12h ou 24h | "Verificar compliance a cada 6 horas" |

### 13.4 Remediation

```
┌───────────────┐    rule violation    ┌──────────────────┐    remediation    ┌───────────────┐
│  AWS Config   │ ──────────────────── │  NON_COMPLIANT   │ ────────────────  │  SSM          │
│  Rule         │                      │  Resource        │                   │  Automation   │
└───────────────┘                      └──────────────────┘                   └───────────────┘
```

| Tipo | Descrição |
|------|-----------|
| **Manual Remediation** | Admin executa a ação manualmente após alerta |
| **Automatic Remediation** | SSM Automation Document executa automaticamente |
| **Auto Remediation com retries** | Tenta remediar automaticamente com N retries |

**Exemplos de remediação automática:**
- SG com porta 22 aberta → SSM fecha a porta automaticamente
- S3 sem encryption → SSM habilita encryption
- IAM user sem MFA → notifica e bloqueia após prazo

### 13.5 Config Aggregator

```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   Conta A    │  │   Conta B    │  │   Conta C    │
│  us-east-1   │  │  eu-west-1   │  │  ap-south-1  │
│  Config      │  │  Config      │  │  Config      │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │
       └─────────────────┼─────────────────┘
                         ▼
              ┌──────────────────────┐
              │   Config Aggregator   │
              │   (conta central)     │
              │                       │
              │  Visão consolidada    │
              │  de compliance        │
              └──────────────────────┘
```

- Agrega dados de **múltiplas contas** e **múltiplas regiões**
- Visão centralizada de compliance para toda a organização
- Não precisa de autorização individual se usar AWS Organizations

### 13.6 Conformance Packs

- Conjunto de **Config Rules + Remediation actions** empacotados
- Templates prontos para frameworks: PCI-DSS, HIPAA, NIST, CIS
- Podem ser implantados em toda a Organization via delegated admin
- YAML template define rules e remediações

### 13.7 Config Timeline e Relacionamentos

- **Timeline:** histórico completo de mudanças de configuração do recurso
- **Relationships:** mostra dependências entre recursos
  - Ex: EC2 → Security Group → VPC → Subnet
- Permite responder: "Qual era a configuração desse SG em 01/jan?"

---

## 14. CloudWatch vs CloudTrail vs Config — Tabela Comparativa Final

| Aspecto | CloudWatch | CloudTrail | AWS Config |
|---------|-----------|------------|------------|
| **Foco** | Performance e operações | Auditoria de API | Compliance de configuração |
| **Pergunta** | "Está funcionando bem?" | "Quem fez isso?" | "Está configurado certo?" |
| **O que monitora** | Métricas, logs, eventos | Chamadas de API | Estado de configuração |
| **Granularidade** | Segundos a minutos | Evento individual | Snapshot de configuração |
| **Tempo real** | Sim (métricas e logs) | ~15 min delay | Near real-time |
| **Retenção padrão** | Métricas: 455d; Logs: configurável | 90 dias (console) | Indefinido |
| **Armazenamento longo** | Logs em CW; export S3 | Trail → S3 (ilimitado) | S3 (snapshots) |
| **Ações automáticas** | Alarms → SNS/ASG/EC2 | EventBridge → Lambda | Remediation → SSM |
| **Custo base** | Métricas básicas grátis | 1 trail Management grátis | Pago por rule evaluation |

### 14.1 Cenário Integrado — Exemplo Prático

```
Cenário: "Alguém deletou a regra do Security Group que permitia acesso ao RDS"

1. CloudTrail: registrou QUEM fez a chamada RevokeSecurityGroupIngress
2. Config: registrou O QUE mudou (antes e depois da configuração do SG)
3. CloudWatch: alerta de queda de conexões no RDS (métrica DatabaseConnections)

Automação:
CloudTrail Event → EventBridge → Lambda (reverte a mudança)
Config Rule → NON_COMPLIANT → SSM Remediation (restaura a regra)
CloudWatch Alarm → SNS → equipe de operações alertada
```

---

## 15. AWS X-Ray

### 15.1 Conceito

Serviço de **distributed tracing** que permite analisar e debugar aplicações distribuídas (microserviços).

### 15.2 Componentes

| Componente | Descrição |
|-----------|-----------|
| **Segment** | Unidade de trabalho de um serviço (ex: request inteira no seu app) |
| **Subsegment** | Chamada downstream (ex: query DynamoDB, call HTTP externo) |
| **Trace** | Conjunto de segments que representam um request end-to-end |
| **Annotations** | Key-value pairs **indexados** (para filtrar traces) |
| **Metadata** | Key-value pairs **não indexados** (dados extras) |
| **Service Map** | Visualização gráfica das dependências entre serviços |
| **Sampling Rules** | Controla % de requests rastreados |

### 15.3 Arquitetura

```
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐
│  Client │───→│  API GW │───→│ Lambda/ │───→│DynamoDB │
│         │    │         │    │  ECS    │    │         │
└─────────┘    └────┬────┘    └────┬────┘    └────┬────┘
                    │              │              │
                    │   segments   │  subsegments │
                    ▼              ▼              ▼
              ┌─────────────────────────────────────────┐
              │           X-Ray Daemon/Agent             │
              │     (UDP port 2000 → X-Ray API)         │
              └────────────────────┬────────────────────┘
                                   │
                                   ▼
                          ┌─────────────────┐
                          │   X-Ray Console │
                          │  Service Map    │
                          │  Trace Details  │
                          └─────────────────┘
```

### 15.4 X-Ray Daemon

- Processo que roda em background e envia traces para o X-Ray API
- Escuta na porta **UDP 2000**
- Deve rodar no EC2, ECS (sidecar), Elastic Beanstalk (pré-instalado)
- **Lambda:** daemon já integrado — não precisa instalar separadamente

### 15.5 Sampling Rules

| Parâmetro | Descrição |
|-----------|-----------|
| **Reservoir** | Requests fixos por segundo sempre rastreados |
| **Rate** | Percentual de requests adicionais rastreados |

Padrão: reservoir=1, rate=5% → 1 request/s sempre + 5% do restante

### 15.6 Integrações

| Serviço | Como Integrar |
|---------|--------------|
| **Lambda** | Habilitar Active Tracing (checkbox) |
| **API Gateway** | Habilitar X-Ray Tracing no stage |
| **ECS/Fargate** | Sidecar container com X-Ray Daemon |
| **Elastic Beanstalk** | Configuração no .ebextensions |
| **EC2** | Instalar X-Ray Daemon + SDK no código |
| **App Mesh** | Envoy proxy envia traces automaticamente |

### 15.7 Annotations vs Metadata

| | Annotations | Metadata |
|-|------------|----------|
| Indexado | ✅ Sim | ❌ Não |
| Filtrável | ✅ Sim (filter expressions) | ❌ Não |
| Tipo | String, Number, Boolean | Qualquer objeto |
| Uso | `user_id=123`, `environment=prod` | Request/response body, debug info |

---

## 16. AWS Health Dashboard

### 16.1 Dois Dashboards Distintos

| Aspecto | Service Health Dashboard | Account Health Dashboard |
|---------|------------------------|------------------------|
| **Escopo** | Global — todos os serviços AWS | **Sua conta** especificamente |
| **Antigo nome** | Service Health Dashboard | Personal Health Dashboard (PHD) |
| **Conteúdo** | Status de todos os serviços por região | Eventos que afetam SEUS recursos |
| **Acesso** | Público (status.aws.amazon.com) | Requer login na conta |
| **Personalização** | Nenhuma | Filtros, notificações, automação |

### 16.2 Account Health Dashboard — Detalhe

- Mostra eventos de **manutenção programada** nos seus recursos
- Alerta sobre **degradação de serviço** que afeta você
- Notifica sobre **mudanças** que requerem ação (deprecated APIs, etc.)
- Histórico de eventos passados

### 16.3 Integração com EventBridge

```
AWS Health Event ──→ EventBridge Rule ──→ Targets
                                          ├── SNS (notificação)
                                          ├── Lambda (automação)
                                          └── SSM Automation (remediar)

Exemplo de Rule:
{
  "source": ["aws.health"],
  "detail-type": ["AWS Health Event"],
  "detail": {
    "service": ["EC2"],
    "eventTypeCategory": ["scheduledChange"]
  }
}
```

**Casos de uso:**
- EC2 com manutenção programada → Lambda migra instância automaticamente
- AZ com degradação → trigger failover para outra AZ
- Alerta imediato ao time de operações sobre qualquer evento

**DICA DA PROVA:** "Receber alertas automáticos sobre manutenção programada em seus recursos" = **AWS Health Dashboard + EventBridge**.

---

## 17. AWS Trusted Advisor

### 17.1 As 5 Categorias (Pilares)

```
┌─────────────────────────────────────────────────────────────────┐
│                     TRUSTED ADVISOR                               │
├─────────────┬────────────┬──────────┬────────────┬──────────────┤
│    COST     │PERFORMANCE │ SECURITY │   FAULT    │   SERVICE    │
│OPTIMIZATION │            │          │ TOLERANCE  │   LIMITS     │
├─────────────┼────────────┼──────────┼────────────┼──────────────┤
│• Idle ELBs  │• High      │• MFA on  │• RDS Multi-│• VPCs (limit │
│• Underutil. │  utiliz.   │  Root    │  AZ?       │  5/region)   │
│  EC2        │  EC2       │• SG open │• S3 bucket │• EIPs        │
│• Unassoc.   │• CloudFront│  ports   │  versioning│• Auto Scaling│
│  EIPs       │  optimize  │• IAM Use │• EBS snaps │  groups      │
│• Old snaps  │• Over-prov.│• S3 perms│• Route 53  │• etc.        │
│             │  EBS       │          │  health ck │              │
└─────────────┴────────────┴──────────┴────────────┴──────────────┘
```

### 17.2 Checks por Nível de Suporte

| Nível de Suporte | Checks Disponíveis |
|-----------------|-------------------|
| **Basic / Developer** | 7 checks core (6 security + Service Limits) |
| **Business** | **TODAS** as checks + API access |
| **Enterprise** | **TODAS** as checks + API access + TAM |

**7 checks gratuitas (Basic/Developer):**
1. MFA no Root Account
2. Security Groups — portas irrestritas
3. S3 Bucket Permissions (público)
4. IAM Use (pelo menos 1 IAM user criado)
5. EBS Public Snapshots
6. RDS Public Snapshots
7. Service Limits (80% do limite)

### 17.3 Integração e Automação

- **API/SDK:** acessível via `aws support` (requer Business+ support)
- **EventBridge:** pode disparar automações quando check muda de status
- **Refresh:** manual ou automático (a cada semana para Business+)
- **Organizational View:** visão consolidada para AWS Organizations

**DICA DA PROVA:** "Identificar recursos idle/subutilizados para reduzir custos" ou "verificar service limits" = **Trusted Advisor**. Mas para TODAS as checks, precisa de **Business ou Enterprise Support**.

---

## 18. Palavras-Chave da Prova SAA-C03 — Cenários e Respostas

| # | Cenário / Palavra-Chave na Questão | Resposta |
|---|-------------------------------------|----------|
| 1 | "Monitorar utilização de memória (RAM) do EC2" | **CloudWatch Agent** (custom metric — não coletado por padrão) |
| 2 | "Quem deletou o recurso?" / "auditoria de API" | **CloudTrail** |
| 3 | "Verificar se Security Groups estão em conformidade" | **AWS Config** (Config Rules) |
| 4 | "Alertar quando CPU > 80% e escalar" | **CloudWatch Alarm** → ASG Policy |
| 5 | "Identificar gargalos entre microserviços" / "distributed tracing" | **X-Ray** |
| 6 | "Monitorar endpoint proativamente antes dos usuários reportarem" | **CloudWatch Synthetics (Canaries)** |
| 7 | "Reduzir alarmes falsos combinando condições" | **CloudWatch Composite Alarms** |
| 8 | "Enviar logs em tempo real para OpenSearch/S3" | **Subscription Filter → Kinesis Firehose** |
| 9 | "Exportar logs para S3 (batch, não real-time)" | **CreateExportTask** |
| 10 | "Identificar top IPs causando erros" / "top contributors" | **CloudWatch Contributor Insights** |
| 11 | "Feature flags e A/B testing" | **CloudWatch Evidently** |
| 12 | "Métricas de containers ECS/EKS" | **CloudWatch Container Insights** |
| 13 | "Cold starts e performance de Lambda" | **CloudWatch Lambda Insights** |
| 14 | "Remediar automaticamente recurso fora de compliance" | **AWS Config + SSM Automation** |
| 15 | "Detectar atividade anômala de API" | **CloudTrail Insights** |
| 16 | "SQL queries em eventos de CloudTrail" | **CloudTrail Lake** (ou Athena com S3) |
| 17 | "Automação baseada em evento de API" (ex: deletou algo) | **CloudTrail + EventBridge + Lambda** |
| 18 | "Manutenção programada nos meus recursos — alertar" | **AWS Health Dashboard + EventBridge** |
| 19 | "Verificar service limits antes de atingir" | **Trusted Advisor** (Service Limits check) |
| 20 | "Recurso idle / subutilizado para cortar custos" | **Trusted Advisor** (Cost Optimization) |
| 21 | "Visão centralizada de compliance multi-account" | **AWS Config Aggregator** |
| 22 | "Coletar logs de servidores on-premises" | **CloudWatch Agent** (hybrid) |
| 23 | "Verificar integridade dos logs de auditoria" | **CloudTrail Log File Integrity Validation** |
| 24 | "Monitorar aplicação .NET/SQL Server automaticamente" | **CloudWatch Application Insights** |
| 25 | "Dashboard com métricas de múltiplas regiões e contas" | **CloudWatch Dashboard** (cross-region/cross-account) |

---

## Resumo Visual — Árvore de Decisão

```
Preciso monitorar...
│
├── PERFORMANCE (métricas, thresholds, escalar)?
│   └── CloudWatch (Metrics + Alarms + Dashboards)
│       ├── RAM/Disk? → CloudWatch Agent
│       ├── Containers? → Container Insights
│       ├── Lambda perf? → Lambda Insights
│       └── Disponibilidade proativa? → Synthetics Canaries
│
├── QUEM FEZ O QUÊ (auditoria, segurança)?
│   └── CloudTrail
│       ├── Automação? → EventBridge
│       ├── Anomalias? → Insights Events
│       └── Queries SQL? → CloudTrail Lake / Athena
│
├── CONFIGURAÇÃO CORRETA (compliance)?
│   └── AWS Config
│       ├── Remediar? → SSM Automation
│       ├── Multi-account? → Aggregator
│       └── Framework (PCI/HIPAA)? → Conformance Packs
│
├── DEPENDÊNCIAS ENTRE SERVIÇOS (latência, erros)?
│   └── X-Ray (distributed tracing)
│
├── SAÚDE DA CONTA / MANUTENÇÃO?
│   └── AWS Health Dashboard + EventBridge
│
└── OTIMIZAÇÃO GERAL (custo, segurança, limites)?
    └── Trusted Advisor (precisa Business+ para tudo)
```

---

## Referências Rápidas para Revisão

### Retenção de Dados — Resumo

| Serviço | Retenção Padrão | Retenção Máxima |
|---------|----------------|-----------------|
| CloudWatch Metrics | Depende da resolução (3h → 455d) | 455 dias (1h resolution) |
| CloudWatch Logs | Never Expire (configurável) | Indefinido |
| CloudTrail (console) | 90 dias | 90 dias (sem trail) |
| CloudTrail (S3 trail) | Indefinido | Indefinido (lifecycle policy) |
| CloudTrail Lake | Configurável | 7 anos (2555 dias) |
| AWS Config | Indefinido | Indefinido |
| X-Ray Traces | 30 dias | 30 dias |

### Custos — O que é Gratuito

| Serviço | Gratuito | Pago |
|---------|----------|------|
| CloudWatch | Basic metrics (5min), 10 alarms, 5GB logs ingest | Detailed, custom metrics, logs extra |
| CloudTrail | 1 trail (Management Events) | Data Events, Insights, trails extras |
| Config | Nada (pago por avaliação de regra) | Tudo |
| X-Ray | 100k traces/mês, 1M traces scanned | Acima dos limites |
| Trusted Advisor | 7 checks (Basic) | Todas checks (Business+) |
| Health Dashboard | Gratuito | - |

---

*Documento preparado para estudo da certificação AWS SAA-C03. Última atualização: Julho 2026.*
