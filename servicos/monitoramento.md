# Monitoramento — CloudWatch, CloudTrail, Config

## CloudWatch vs CloudTrail vs Config — DIFERENÇA CRÍTICA

| | CloudWatch | CloudTrail | AWS Config |
|-|------------|------------|------------|
| O que monitora | **Performance** (métricas, logs, alarmes) | **Atividade** (quem fez o quê via API) | **Conformidade** (configuração dos recursos) |
| Pergunta respondida | "Está funcionando?" | "Quem fez isso?" | "Está configurado corretamente?" |
| Granularidade | Tempo real | Eventos de API | Histórico de configuração |
| Retenção padrão | Logs: configurável | 90 dias (trilha → S3 indefinido) | Indefinido |

---

## CloudWatch

### Metrics
- Dados de performance por namespace (ex: `AWS/EC2`, `AWS/RDS`)
- **Standard Metrics:** incluídas (CPU, Disk I/O, Network) — granularidade 5 min
- **Detailed Monitoring:** granularidade 1 min (custo adicional)
- **Custom Metrics:** sua aplicação publica via `PutMetricData` (memória, por ex.)
- Retenção: 1 min → 3h | 5 min → 63 dias | 1h → 455 dias

### Alarms
- Monitora uma métrica e executa ações quando o threshold é atingido
- Estados: **OK**, **ALARM**, **INSUFFICIENT_DATA**
- Ações: notificar SNS, escalar ASG, parar/terminar instância EC2
- **Composite Alarm:** combina múltiplos alarmes com AND/OR

### Logs
- **Log Group:** container de log streams (ex: `/aws/lambda/minha-funcao`)
- **Log Stream:** sequência de eventos de uma fonte (ex: instância específica)
- **Log Insights:** queries SQL-like para análise de logs
- **Metric Filter:** extrai métricas de padrões em logs (ex: contar erros 500)
- **Subscription Filter:** envia logs em tempo real para Lambda, Kinesis, Firehose

### Insights Especializados
- **Container Insights:** métricas e logs de ECS, EKS, Kubernetes
- **Lambda Insights:** performance de funções Lambda (duração, memória, cold starts)
- **Contributor Insights:** identifica top contributors de tráfego (ex: top IPs)

---

## CloudTrail

- Registra todas as chamadas de API feitas na conta AWS
- **Quem** (usuário/role), **o quê** (API call), **quando** (timestamp), **de onde** (IP)
- Habilitado por padrão — histórico de 90 dias no console
- **Trail:** configuração para persistir eventos em S3 (retenção ilimitada) e CloudWatch Logs

### Tipos de Eventos
| Tipo | O que registra | Custo |
|------|---------------|-------|
| Management Events | Operações em recursos (criar EC2, criar S3 bucket, etc.) | Gratuito (1 trilha) |
| Data Events | Operações em dados (GetObject S3, Invoke Lambda) | Pago |
| Insights Events | Atividade incomum de API (anomalia) | Pago |

### Casos de Uso
- Auditoria de segurança: "quem deletou esse bucket?"
- Compliance: registro imutável de atividades
- Investigação de incidentes
- Integração com EventBridge para automação baseada em eventos de API

---

## AWS Config

- Monitora e registra **configurações** dos recursos AWS ao longo do tempo
- **Config Rules:** verifica se recursos estão em conformidade (ex: "todos os S3 devem ter versioning")
- **Remediation:** ação automática quando regra viola (via SSM Automation)
- **Conformance Packs:** conjunto de regras para frameworks (PCI-DSS, HIPAA, etc.)

### Config vs CloudTrail
- Config: "o recurso X estava configurado assim em 01/07" (estado)
- CloudTrail: "o usuário Y fez a chamada Z às 15h30" (evento)

---

## X-Ray

- Distributed tracing para aplicações
- Mapeia chamadas entre microserviços, Lambda, DynamoDB, SQS, etc.
- Identifica gargalos e erros na cadeia de chamadas
- **Sampling:** configura % de requests rastreados (não rastreia tudo por padrão)
- SDK disponível para Node.js, Python, Java, .NET, etc.

---

## AWS Health Dashboard

- **Service Health Dashboard:** status global de todos os serviços AWS
- **Personal Health Dashboard:** eventos que **afetam sua conta especificamente**
- Integra com EventBridge para automação quando um evento de saúde ocorre
