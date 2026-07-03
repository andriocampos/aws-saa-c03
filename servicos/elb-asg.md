# ELB — Elastic Load Balancing + ASG — Auto Scaling Group

## Tipos de Load Balancer

| | ALB | NLB | GLB |
|-|-----|-----|-----|
| Camada OSI | 7 (HTTP/HTTPS) | 4 (TCP/UDP/TLS) | 3 (IP) |
| Protocolos | HTTP, HTTPS, WebSocket | TCP, UDP, TLS | IP (GENEVE 6081) |
| IP estático | ❌ (DNS) | ✅ por AZ | ❌ |
| Preserve source IP | ❌ | ✅ | ✅ |
| Latência | Moderada | Ultrabaixa | — |
| Casos de uso | Apps web, microserviços, roteamento avançado | Alta performance, jogos, IoT, NLBs com IP fixo | Firewalls, IDS/IPS, appliances de rede |

### ALB — Application Load Balancer
- Roteamento por **path** (`/api/*` → target group A), **host** (`api.site.com`), **headers**, **query string**
- **Sticky Sessions** (AWSALB cookie) — mantém usuário na mesma instância
- **WebSocket** e HTTP/2 suportados
- Target types: EC2 instances, ECS tasks, Lambda, IPs
- **Cross-Zone Load Balancing:** habilitado por padrão, sem custo extra

### NLB — Network Load Balancer
- Milhões de req/s com latência de microssegundos
- **IP estático por AZ** (útil para whitelist de firewall)
- **Preserve client IP** — a instância vê o IP real do cliente
- TLS Termination suportado
- Cross-Zone Load Balancing: desabilitado por padrão, **cobra por uso**

### GLB — Gateway Load Balancer
- Usado para inserir appliances de rede (firewall, IDS/IPS) de forma transparente
- Protocolo GENEVE na porta 6081
- Combina gateway + load balancer em um único serviço

## Funcionalidades Comuns

### Connection Draining / Deregistration Delay
- Tempo que o LB aguarda conexões ativas terminarem antes de desregistrar uma instância
- Padrão: 300s | Range: 0-3600s
- `0` = desabilita (desregistra imediatamente)

### Health Checks
- O LB remove instâncias não saudáveis do pool automaticamente
- Configura-se: path, intervalo, threshold de healthy/unhealthy, timeout

### SSL/TLS — Server Name Indication (SNI)
- ALB e NLB suportam múltiplos certificados SSL em um listener via SNI
- CLB (legacy) suporta apenas um certificado por listener

---

## Auto Scaling Group (ASG)

### Launch Template vs Launch Configuration

| | Launch Template | Launch Configuration |
|-|----------------|---------------------|
| Status | ✅ Recomendado | ⚠️ Legado |
| Versões | ✅ Suporta versões | ❌ Imutável |
| Spot + On-Demand | ✅ Mix na mesma ASG | ❌ Apenas um tipo |
| Placement Groups | ✅ | ❌ |

### Scaling Policies

| Tipo | Como funciona | Quando usar |
|------|--------------|-------------|
| **Target Tracking** | Mantém métrica em valor alvo (ex: CPU 50%) | Maioria dos casos — mais simples |
| **Step Scaling** | Define steps baseados em alarmes CloudWatch | Controle granular por faixa |
| **Scheduled** | Escala em horários previsíveis | Black Friday, horário comercial |
| **Predictive** | ML analisa histórico e escala proativamente | Padrões cíclicos e regulares |

### Health Checks
| Tipo | O que verifica |
|------|---------------|
| EC2 | Instância está running (hardware/hypervisor) |
| ELB | Health check do Load Balancer (resposta HTTP 200) |

> Use **ELB health check** quando a instância pode estar rodando mas a aplicação falhou.

### Lifecycle Hooks
Permitem executar ações customizadas durante transições do ASG:
- `pending:wait` — antes de instância entrar em serviço (ex: instalar software)
- `terminating:wait` — antes de instância ser terminada (ex: salvar logs)

### Cooldown Period
- Tempo que o ASG aguarda após scaling antes de avaliar novo scaling
- Padrão: 300s
- Evita que o ASG suba e derrube instâncias rapidamente (thrashing)

### Instance Refresh
- Atualiza gradualmente as instâncias quando o launch template muda
- Define percentual mínimo de instâncias saudáveis durante a atualização

## Diferenças Críticas

- **ALB vs NLB:** ALB roteia por conteúdo HTTP; NLB por TCP/UDP com menor latência e IP estático
- **ALB vs GLB:** GLB é para appliances de segurança de rede, não para apps
- **EC2 health check vs ELB health check:** ELB detecta falhas de aplicação; EC2 só detecta falhas de infraestrutura
- **Target Tracking vs Step Scaling:** Target Tracking é mais simples e cobre 80% dos casos
