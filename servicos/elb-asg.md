# ELB (Elastic Load Balancing) & ASG (Auto Scaling Group) — Guia Completo SAA-C03

---

## 1. Visão Geral do ELB

### 1.1 Por que usar um Load Balancer?

- **Distribuir tráfego** entre múltiplas instâncias/targets downstream
- **Expor um único ponto de acesso (DNS)** para a aplicação
- **Absorver falhas** de instâncias downstream com health checks
- **Fornecer terminação SSL/TLS** (HTTPS) para seus websites
- **Enforçar stickiness** com cookies
- **Alta disponibilidade** entre zonas de disponibilidade (AZs)
- **Separar tráfego público do privado** (internal vs internet-facing)
- **Integração nativa** com AWS Certificate Manager, CloudWatch, WAF, Route 53

### 1.2 Tipos de Load Balancer na AWS

| Tipo | Camada OSI | Lançamento | Protocolo |
|------|-----------|------------|-----------|
| CLB (Classic) | 4 e 7 | 2009 | HTTP, HTTPS, TCP, SSL |
| ALB (Application) | 7 | 2016 | HTTP, HTTPS, WebSocket |
| NLB (Network) | 4 | 2017 | TCP, TLS, UDP |
| GLB (Gateway) | 3 | 2020 | IP (GENEVE 6081) |

> ⚠️ **Na prova**: CLB é considerado legacy. AWS recomenda ALB ou NLB.

### 1.3 Conceitos Fundamentais

```
┌─────────────────────────────────────────────────────────┐
│                      INTERNET                           │
└──────────────────────────┬──────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│              ELB (DNS name: xxx.region.elb.amazonaws.com)│
│   ┌──────────┐    ┌──────────┐    ┌──────────┐         │
│   │  AZ-1a   │    │  AZ-1b   │    │  AZ-1c   │         │
│   │  (node)  │    │  (node)  │    │  (node)  │         │
│   └────┬─────┘    └────┬─────┘    └────┬─────┘         │
└────────┼───────────────┼───────────────┼────────────────┘
         │               │               │
         ▼               ▼               ▼
    ┌─────────┐    ┌─────────┐    ┌─────────┐
    │ Target  │    │ Target  │    │ Target  │
    │ Group A │    │ Group A │    │ Group A │
    └─────────┘    └─────────┘    └─────────┘
```

### 1.4 Health Checks

- O ELB verifica periodicamente se os targets estão saudáveis
- Se um target falha no health check → marcado como **unhealthy** → tráfego não é enviado
- Configuração: protocolo + porta + path (ex: HTTP:80/health)
- Targets saudáveis voltam a receber tráfego automaticamente

### 1.5 Cross-Zone Load Balancing

```
SEM Cross-Zone:                    COM Cross-Zone:
┌────────────┐ ┌────────────┐     ┌────────────┐ ┌────────────┐
│   AZ-1a    │ │   AZ-1b    │     │   AZ-1a    │ │   AZ-1b    │
│ LB Node    │ │ LB Node    │     │ LB Node    │ │ LB Node    │
│  50% total │ │  50% total │     │            │ │            │
│  ┌──┐┌──┐  │ │  ┌──┐      │     │  ┌──┐┌──┐  │ │  ┌──┐      │
│  │25││25│  │ │  │50│      │     │  │33││33│  │ │  │33│      │
│  └──┘└──┘  │ │  └──┘      │     │  └──┘└──┘  │ │  └──┘      │
└────────────┘ └────────────┘     └────────────┘ └────────────┘
 Distribuição desigual!            Distribuição uniforme!
```

---

## 2. ALB (Application Load Balancer) — Camada 7

### 2.1 Características Principais

- Opera na **Camada 7** (HTTP/HTTPS)
- Suporta **HTTP/2** e **WebSocket**
- Roteamento avançado baseado em regras (rules)
- Suporta **múltiplos listeners** com múltiplas regras
- Ideal para **microserviços** e **containers** (ECS)
- DNS name fixo (NÃO possui IP estático — use NLB se precisar)

### 2.2 Roteamento Avançado (Routing Rules)

O ALB pode rotear baseado em:

| Critério | Exemplo | Uso Típico |
|----------|---------|------------|
| **Path** (URL path) | `/api/*` → TG-API, `/images/*` → TG-Images | Microserviços |
| **Host** (hostname) | `app.example.com` → TG-App, `api.example.com` → TG-API | Multi-tenant |
| **HTTP Headers** | `X-Custom-Header: mobile` → TG-Mobile | A/B testing |
| **Query String** | `?platform=mobile` → TG-Mobile | Feature flags |
| **Source IP** | `10.0.0.0/8` → TG-Internal | Rede corporativa |
| **HTTP Method** | `POST` → TG-Write, `GET` → TG-Read | CQRS |

```
                         ┌─────────────────┐
                         │       ALB       │
                         └────────┬────────┘
                                  │
              ┌───────────────────┼───────────────────┐
              │                   │                   │
     /api/*   │        /app/*    │      /admin/*     │
              ▼                   ▼                   ▼
    ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
    │  TG: API     │   │  TG: App     │   │  TG: Admin   │
    │  (ECS tasks) │   │  (EC2)       │   │  (Lambda)    │
    └──────────────┘   └──────────────┘   └──────────────┘
```

### 2.3 Target Groups do ALB

| Tipo de Target | Descrição | Caso de Uso |
|---------------|-----------|-------------|
| **EC2 Instances** | Instâncias por Instance ID | Aplicações tradicionais |
| **ECS Tasks** | Containers registrados dinamicamente | Microserviços em containers |
| **Lambda Functions** | Invocação via HTTP | Serverless HTTP APIs |
| **IP Addresses** | IPs privados (inclusive on-premises) | Hybrid cloud, peering |

> ⚠️ **Não é possível misturar tipos** de target no mesmo Target Group.

### 2.4 Sticky Sessions (Session Affinity)

Permite que requisições de um mesmo cliente sejam enviadas sempre ao mesmo target.

| Tipo de Cookie | Nome | Duração | Controle |
|---------------|------|---------|----------|
| **Duration-based** (LB generated) | `AWSALB` | 1s a 7 dias | Controlado pelo ALB |
| **Application-based** (Custom) | Nome customizado (NÃO usar AWSALB*) | Definido pela app | Controlado pela aplicação |

- **Quando usar**: aplicações que armazenam estado de sessão local (não usar com stateless)
- **Desvantagem**: pode causar desbalanceamento de carga
- Habilitado no **Target Group** level

### 2.5 Cross-Zone Load Balancing no ALB

- **Habilitado por padrão** no ALB
- **Sem custo adicional** para tráfego entre AZs no ALB
- Pode ser desabilitado no nível do Target Group

### 2.6 WebSocket e HTTP/2

- **WebSocket**: suportado nativamente (upgrade de HTTP para conexão persistente)
- **HTTP/2**: suportado no frontend (client → ALB); backend usa HTTP/1.1
- Connection multiplexing reduz latência

### 2.7 Redirect Actions e Fixed Response

**Redirect Actions:**
- HTTP → HTTPS (padrão de segurança)
- Domínio antigo → novo domínio
- Código de status: 301 (permanente) ou 302 (temporário)

**Fixed Response:**
- Retorna resposta estática sem target (ex: página de manutenção)
- Configurável: status code, content-type, body
- Exemplo: retornar 503 com mensagem "Em manutenção"

### 2.8 Weighted Target Groups

- Distribuir tráfego entre Target Groups com **pesos diferentes**
- Útil para **blue-green deployments** e **canary releases**
- Exemplo: 90% → v1, 10% → v2

### 2.9 Slow Start Mode

- Novos targets recebem tráfego **gradualmente** (ramp-up)
- Duração configurável: 30s a 900s
- Permite que a instância "aqueça" (warm up caches, JVM, etc.)
- Após o período, recebe carga total normalmente

### 2.10 Cabeçalhos Especiais do ALB

| Header | Conteúdo |
|--------|----------|
| `X-Forwarded-For` | IP real do cliente |
| `X-Forwarded-Port` | Porta original da requisição |
| `X-Forwarded-Proto` | Protocolo original (HTTP ou HTTPS) |

> O ALB termina a conexão do cliente e abre nova conexão com o target. O target vê o IP do ALB como source IP.


---

## 3. NLB (Network Load Balancer) — Camada 4

### 3.1 Características Principais

- Opera na **Camada 4** (TCP, UDP, TLS)
- **Ultra alta performance**: milhões de requisições por segundo
- **Latência ultra baixa**: ~100ms (vs ~400ms do ALB)
- **IP estático por AZ** — pode associar **Elastic IP** por AZ
- Ideal quando você precisa de **IP fixo** para whitelist em firewalls
- **Preserve source IP**: o target vê o IP real do cliente (não o do LB)
- Não inspeciona conteúdo HTTP (não entende headers, paths, etc.)

### 3.2 IP Estático e Elastic IP

```
┌─────────────────────────────────────────────────────────┐
│                         NLB                              │
│                                                         │
│  AZ-1a: 10.0.1.100 (ou EIP: 54.23.xx.xx)              │
│  AZ-1b: 10.0.2.100 (ou EIP: 54.24.xx.xx)              │
│  AZ-1c: 10.0.3.100 (ou EIP: 54.25.xx.xx)              │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

- Cada AZ habilitada recebe **1 IP estático** (ou Elastic IP atribuído)
- Permite que clientes usem IPs fixos para firewall rules
- **Na prova**: "preciso de IP fixo/estático para meu load balancer" → NLB

### 3.3 TLS Termination

- NLB pode terminar TLS (decrypt) e enviar TCP para o backend
- Suporta **SNI** (Server Name Indication) para múltiplos certificados
- Opção de **TCP pass-through**: tráfego TLS passa direto para o target (target faz decrypt)

### 3.4 Preserve Source IP

- **Por padrão, o NLB preserva o IP do cliente** como source IP
- Targets veem o IP real do cliente (diferente do ALB)
- Para targets registrados por IP, pode ser necessário habilitar Proxy Protocol v2

### 3.5 Cross-Zone Load Balancing no NLB

- **Desabilitado por padrão** no NLB
- Se habilitado, **cobra taxa adicional** por transferência entre AZs
- Motivo: NLB é usado em cenários de alta performance onde custo de transferência importa

### 3.6 Target Groups do NLB

| Tipo de Target | Descrição | Caso de Uso |
|---------------|-----------|-------------|
| **EC2 Instances** | Por Instance ID | Aplicações TCP tradicionais |
| **IP Addresses** | IPs privados | Hybrid cloud, on-premises |
| **ALB** | Application Load Balancer | NLB na frente do ALB (IP fixo + routing L7) |

> 🔑 **Na prova**: "Preciso de IP estático + roteamento por path" → **NLB na frente do ALB**

### 3.7 Proxy Protocol (v2)

- Adicionado no header TCP para passar informações do cliente
- Contém: source IP, destination IP, source port, destination port
- Necessário quando target precisa do IP do cliente e está registrado por IP

### 3.8 Casos de Uso do NLB

- Aplicações que precisam de **IP fixo/estático**
- Aplicações com **milhões de requisições** simultâneas
- **Gaming**, **IoT**, **streaming** em tempo real
- **TCP/UDP** puro (não HTTP)
- Integração com **AWS PrivateLink** (requer NLB)
- Baixa latência extrema

---

## 4. GLB (Gateway Load Balancer) — Camada 3

### 4.1 Características Principais

- Opera na **Camada 3** (Network Layer — pacotes IP)
- Usa protocolo **GENEVE** na porta **6081**
- Combina **Transparent Network Gateway** + **Load Balancer**
- Usado para rotear tráfego através de **appliances virtuais** (firewalls, IDS/IPS, deep packet inspection)
- Targets: instâncias EC2 ou IPs rodando appliances de segurança

### 4.2 Protocolo GENEVE (porta 6081)

- Generic Network Virtualization Encapsulation
- Encapsula pacotes originais para manter transparência
- Appliance processa e devolve ao GLB que encaminha ao destino
- Preserva headers originais do pacote

### 4.3 Diagrama de Fluxo com Appliances de Segurança

```
┌──────────┐         ┌──────────────────────────────────────────┐
│  USERS   │         │              AWS VPC                      │
│(Internet)│         │                                          │
└────┬─────┘         │  ┌─────────────┐                        │
     │               │  │  Internet   │                        │
     │               │  │   Gateway   │                        │
     │               │  └──────┬──────┘                        │
     │               │         │                               │
     │               │         ▼                               │
     │               │  ┌─────────────┐    Route Table:        │
     └───────────────┼─▶│     GLB     │    0.0.0.0/0 → GLB    │
                     │  │  (Gateway)  │    endpoint            │
                     │  └──────┬──────┘                        │
                     │         │                               │
                     │         │ GENEVE (porta 6081)           │
                     │         ▼                               │
                     │  ┌─────────────────────────────┐        │
                     │  │   Target Group (Appliances) │        │
                     │  │  ┌───────┐  ┌───────┐      │        │
                     │  │  │Firewall│  │  IDS  │      │        │
                     │  │  │  VM   │  │  VM   │      │        │
                     │  │  └───┬───┘  └───┬───┘      │        │
                     │  └──────┼──────────┼───────────┘        │
                     │         │          │                    │
                     │         ▼          ▼                    │
                     │  ┌─────────────┐                        │
                     │  │     GLB     │ (retorno)              │
                     │  └──────┬──────┘                        │
                     │         │                               │
                     │         ▼                               │
                     │  ┌─────────────┐                        │
                     │  │ Application │                        │
                     │  │   Servers   │                        │
                     │  └─────────────┘                        │
                     └──────────────────────────────────────────┘
```

### 4.4 Target Groups do GLB

| Tipo de Target | Descrição |
|---------------|-----------|
| **EC2 Instances** | Appliances virtuais (firewalls, IDS/IPS) |
| **IP Addresses** | IPs privados de appliances |

### 4.5 Casos de Uso do GLB

- **Firewalls de terceiros** (Palo Alto, Fortinet, Check Point)
- **Intrusion Detection/Prevention** (IDS/IPS)
- **Deep Packet Inspection**
- **Compliance** — todo tráfego deve passar por inspeção
- **Payload manipulation** (modificar pacotes)

---

## 5. SSL/TLS no ELB

### 5.1 Certificados SSL/TLS

- Gerenciados pelo **AWS Certificate Manager (ACM)**
- Também é possível fazer upload de certificados próprios para o IAM
- O ELB usa **X.509 certificates** (SSL/TLS server certificate)
- Suporte a certificados públicos e privados

### 5.2 SNI (Server Name Indication)

- Resolve o problema de **múltiplos certificados SSL** em um único load balancer
- O cliente indica o hostname no handshake TLS inicial
- O servidor seleciona o certificado correto

| Load Balancer | Suporte a SNI |
|--------------|---------------|
| CLB | ❌ Não (1 certificado por CLB) |
| ALB | ✅ Sim (múltiplos certificados) |
| NLB | ✅ Sim (múltiplos certificados) |

```
Cliente → TLS Hello (hostname: api.example.com)
                         │
                         ▼
              ┌─────────────────────┐
              │        ALB          │
              │                     │
              │ Cert 1: api.example.com ──────► selecionado!
              │ Cert 2: www.example.com
              │ Cert 3: admin.example.com
              └─────────────────────┘
```

### 5.3 Connection Draining / Deregistration Delay

- Quando uma instância é marcada como **draining** (saindo do TG):
  - Conexões existentes têm tempo para completar
  - Novas conexões NÃO são enviadas
- **Tempo padrão**: 300 segundos (5 minutos)
- **Range**: 0 a 3600 segundos
- **Defina 0** se requisições são curtas e pode matar imediatamente
- **Na prova**: "instâncias estão sendo terminadas antes de completar requisições" → aumentar deregistration delay


---

## 6. Health Checks — Configuração Detalhada

### 6.1 Parâmetros de Health Check

| Parâmetro | Descrição | Valor Padrão |
|-----------|-----------|--------------|
| **Protocol** | HTTP, HTTPS, TCP | HTTP |
| **Port** | Porta de verificação | traffic-port |
| **Path** | URL path (apenas HTTP/HTTPS) | / |
| **Interval** | Intervalo entre checks | 30s |
| **Timeout** | Tempo máximo de resposta | 5s |
| **Healthy Threshold** | Checks consecutivos para healthy | 5 |
| **Unhealthy Threshold** | Checks consecutivos para unhealthy | 2 |
| **Success Codes** | Códigos HTTP considerados saudáveis | 200 |

### 6.2 Comportamento

```
                    Health Check Flow
                    
Target registrado ──► Inicial: UNUSED
         │
         ▼
    Primeiro check passa?
    ├── SIM ──► Status: HEALTHY ──► Recebe tráfego
    └── NÃO ──► Status: UNHEALTHY ──► Não recebe tráfego
                      │
                      ▼
              Continua verificando...
              Passa (healthy threshold) vezes?
              └── SIM ──► Status: HEALTHY
```

### 6.3 Health Check Grace Period (ASG)

- Período após launch onde health checks do ELB são **ignorados**
- Padrão: **300 segundos** (para ASG)
- Evita que instâncias em boot sejam marcadas unhealthy prematuramente
- **Na prova**: "instâncias novas são terminadas imediatamente após launch" → aumentar grace period

---

## 7. Access Logs e Request Tracing

### 7.1 Access Logs

- Logs detalhados de **todas as requisições** processadas pelo ELB
- Armazenados no **Amazon S3** (bucket configurável)
- Contém: timestamp, client IP, latencies, request path, server response, etc.
- **Desabilitado por padrão** (habilitar se precisar auditar/debugar)
- Formato: campos separados por espaço

**Campos importantes dos Access Logs:**
- `request_processing_time` — tempo do ELB para enviar ao target
- `target_processing_time` — tempo do target para responder
- `response_processing_time` — tempo do ELB para enviar resposta ao cliente
- `elb_status_code` — código HTTP retornado pelo ELB
- `target_status_code` — código HTTP retornado pelo target

### 7.2 Request Tracing (ALB)

- Header `X-Amzn-Trace-Id` adicionado automaticamente pelo ALB
- Permite rastrear uma requisição através de múltiplos serviços
- Formato: `Root=1-{timestamp}-{id}`
- Integração com **AWS X-Ray** para distributed tracing

### 7.3 CloudWatch Metrics do ELB

| Métrica | Descrição | Alerta Sugerido |
|---------|-----------|-----------------|
| `RequestCount` | Total de requisições | — |
| `HealthyHostCount` | Targets saudáveis | < mínimo esperado |
| `UnHealthyHostCount` | Targets não saudáveis | > 0 |
| `HTTPCode_ELB_5XX` | Erros 5xx do ELB | > threshold |
| `HTTPCode_Target_5XX` | Erros 5xx do target | > threshold |
| `TargetResponseTime` | Latência do target | > SLA |
| `SurgeQueueLength` (CLB) | Fila de requisições | > 0 |
| `SpilloverCount` (CLB) | Requisições rejeitadas | > 0 |
| `ActiveConnectionCount` | Conexões ativas | — |
| `ConsumedLCUs` | LCUs consumidas (ALB) | Custo |

---

## 8. Tabela Comparativa: ALB vs NLB vs GLB

| Critério | ALB | NLB | GLB |
|----------|-----|-----|-----|
| **Camada OSI** | 7 (HTTP/HTTPS) | 4 (TCP/UDP/TLS) | 3 (IP/GENEVE) |
| **Protocolos** | HTTP, HTTPS, WebSocket | TCP, UDP, TLS | IP (GENEVE 6081) |
| **IP Estático** | ❌ (apenas DNS) | ✅ (Elastic IP por AZ) | ❌ |
| **Preserve Source IP** | ❌ (usa X-Forwarded-For) | ✅ (nativo) | ✅ (transparente) |
| **SSL Termination** | ✅ | ✅ | ❌ |
| **SNI** | ✅ | ✅ | N/A |
| **Roteamento L7** | ✅ (path, host, headers, etc.) | ❌ | ❌ |
| **WebSocket** | ✅ | ✅ (TCP nativo) | N/A |
| **Cross-Zone LB (padrão)** | ✅ Habilitado | ❌ Desabilitado | ❌ Desabilitado |
| **Custo Cross-Zone** | Grátis | Cobra | Cobra |
| **Performance** | Milhares req/s | Milhões req/s | Milhões pacotes/s |
| **Latência** | ~400ms | ~100ms | Variável |
| **Health Check** | HTTP/HTTPS | TCP/HTTP/HTTPS | HTTP/HTTPS/TCP |
| **Sticky Sessions** | ✅ (cookies) | ❌ | ❌ |
| **Targets** | EC2, ECS, Lambda, IP | EC2, IP, ALB | EC2, IP |
| **WAF** | ✅ | ❌ | ❌ |
| **Security Groups** | ✅ | ✅ (desde 2023) | ❌ |
| **PrivateLink** | ❌ | ✅ (necessário) | ✅ |
| **Redirect/Fixed Response** | ✅ | ❌ | ❌ |
| **Weighted Target Groups** | ✅ | ❌ | ❌ |


---

## 9. ASG (Auto Scaling Group) — Conceitos Fundamentais

### 9.1 O que é o ASG?

- Escala automaticamente o número de EC2 instances
- Garante um **mínimo**, **desejado** e **máximo** de instâncias
- Registra automaticamente novas instâncias no **Target Group** do ELB
- Substitui instâncias unhealthy automaticamente
- **Custo**: gratuito (paga apenas pelas instâncias EC2 criadas)

### 9.2 Capacidades

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Minimum ◄──────── Desired ──────────► Maximum              │
│  Capacity          Capacity             Capacity            │
│                                                             │
│  Ex: 2             Ex: 4                Ex: 10              │
│                                                             │
│  [██][██]          [██][██][██][██]     [██][██]...[██]     │
│  Nunca abaixo      Estado atual         Nunca acima         │
│  deste valor       (scaling ajusta)     deste valor         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 9.3 Launch Template vs Launch Configuration

| Critério | Launch Template | Launch Configuration |
|----------|----------------|---------------------|
| **Status** | ✅ Recomendado | ⚠️ Legacy (deprecated) |
| **Versionamento** | ✅ Sim (v1, v2, v3...) | ❌ Não (imutável) |
| **Mixed Instances** | ✅ Spot + On-Demand | ❌ Apenas um tipo |
| **Instance Types Múltiplos** | ✅ Sim | ❌ Apenas um |
| **Placement Groups** | ✅ | ❌ |
| **Capacity Reservations** | ✅ | ❌ |
| **Dedicated Hosts** | ✅ | ❌ |
| **T2 Unlimited** | ✅ | ❌ |
| **Herança de parâmetros** | ✅ (parcial override) | ❌ |
| **Conteúdo** | AMI ID, Instance Type, Key Pair, SGs, User Data, IAM Role, EBS, etc. | Mesmo conteúdo básico |

> ⚠️ **Na prova**: sempre prefira Launch Template. Launch Configuration não pode ser editada.

### 9.4 Atributos Importantes do ASG

- **VPC e Subnets**: define em quais AZs as instâncias serão lançadas
- **Load Balancer**: Target Group(s) associados
- **Health Check Type**: EC2 ou ELB
- **Health Check Grace Period**: tempo para ignorar checks após launch
- **Termination Policy**: regra para decidir qual instância terminar no scale-in
- **Tags**: propagadas para instâncias criadas

---

## 10. Scaling Policies

### 10.1 Tipos de Scaling Policy

#### A) Target Tracking Scaling

- **Mais simples e recomendada**
- Define uma métrica-alvo e o ASG ajusta automaticamente
- Exemplo: "Manter CPU média em 40%"
- O ASG cria e gerencia os alarmes CloudWatch automaticamente

```
Exemplo: TargetTrackingScaling
  Metric: ASGAverageCPUUtilization
  Target: 40.0
  
  CPU > 40% → Scale Out (adiciona instâncias)
  CPU < 40% → Scale In (remove instâncias)
```

**Métricas pré-definidas:**
- `ASGAverageCPUUtilization` — CPU média do ASG
- `ASGAverageNetworkIn` — bytes de rede recebidos
- `ASGAverageNetworkOut` — bytes de rede enviados
- `ALBRequestCountPerTarget` — requisições por target no ALB

#### B) Step Scaling

- Define **múltiplos steps** baseados em alarmes CloudWatch
- Mais granular que Target Tracking
- Você cria os alarmes manualmente

```
Exemplo: StepScaling
  Alarme: CPUUtilization
  
  Step 1: CPU 60-70% → adicionar 1 instância
  Step 2: CPU 70-80% → adicionar 2 instâncias
  Step 3: CPU 80-90% → adicionar 3 instâncias
  Step 4: CPU > 90%  → adicionar 4 instâncias
```

#### C) Scheduled Scaling

- Escala em **horários predefinidos**
- Baseado em padrões conhecidos de carga
- Usa expressões cron ou datas específicas

```
Exemplo: ScheduledScaling
  "Toda sexta-feira 17h, min=10 (evento semanal)"
  "Todo dia útil 8h, desired=5"
  "Todo dia útil 20h, desired=2"
  "Black Friday 2024-11-29, min=50, max=100"
```

#### D) Predictive Scaling

- Usa **Machine Learning** para prever carga futura
- Analisa padrões históricos e escala proativamente
- **Provisiona instâncias ANTES** do pico de carga
- Combina bem com Target Tracking para ajuste fino

```
┌────────────────────────────────────────┐
│     Predictive Scaling                 │
│                                        │
│  Carga Real:     ╱╲    ╱╲             │
│                 ╱  ╲  ╱  ╲            │
│                ╱    ╲╱    ╲           │
│                                        │
│  Previsão:      ╱╲    ╱╲    (prevê    │
│  (antecipa)    ╱  ╲  ╱  ╲   picos)   │
│               ╱    ╲╱    ╲            │
│                                        │
│  Scale acontece ANTES do pico!         │
└────────────────────────────────────────┘
```

### 10.2 Quando usar cada política?

| Política | Quando Usar | Exemplo |
|----------|-------------|---------|
| **Target Tracking** | Carga variável, métrica clara | "Manter CPU em 50%" |
| **Step Scaling** | Precisa de ações proporcionais | "Mais instâncias conforme CPU sobe" |
| **Scheduled** | Padrões conhecidos | "Evento toda sexta às 18h" |
| **Predictive** | Padrões cíclicos recorrentes | "Pico todo dia às 9h" |

> 💡 **Melhor prática**: combinar Predictive + Target Tracking

---

## 11. Scaling Cooldown e Warm-up

### 11.1 Cooldown Period

- Após uma atividade de scaling, o ASG entra em **cooldown**
- Durante o cooldown, **não lança nem termina** instâncias adicionais
- **Padrão**: 300 segundos (5 minutos)
- **Objetivo**: dar tempo para métricas estabilizarem após scaling
- Aplicável a Simple Scaling (não a Step/Target Tracking)

```
Scale Out          Cooldown (300s)         Próxima ação
    │                   │                       │
    ▼                   ▼                       ▼
[+2 instâncias] ──► [Aguardando...] ──► [Avalia novamente]
                    Nenhuma ação de
                    scaling permitida
```

### 11.2 Warm-up Period (Instance Warmup)

- Tempo que uma nova instância leva para "aquecer" e contribuir com métricas
- Durante warm-up, a instância **NÃO é contada** nas métricas do ASG
- Evita scale-out excessivo enquanto instâncias ainda estão inicializando
- Configurável por scaling policy (Target Tracking e Step Scaling)
- **Padrão**: não definido (conta métricas imediatamente)

### 11.3 Diferença: Cooldown vs Warm-up

| Aspecto | Cooldown | Warm-up |
|---------|----------|---------|
| **Escopo** | ASG inteiro | Instância individual |
| **Efeito** | Bloqueia novas ações de scaling | Exclui instância das métricas |
| **Quando** | Após qualquer scaling activity | Após launch de nova instância |
| **Padrão** | 300s | Não definido |

---

## 12. Health Checks do ASG

### 12.1 Tipos de Health Check

| Tipo | Verifica | Quando marca unhealthy |
|------|----------|----------------------|
| **EC2** (padrão) | Status check da instância | Instance status = impaired, stopped, terminated |
| **ELB** | Health check do Target Group | Target reportado unhealthy pelo ELB |
| **Custom** | VPC Lattice ou custom | Sinal externo via API |

### 12.2 Comportamento

- Instância marcada **unhealthy** → ASG **termina** e lança nova instância
- Health checks são **aditivos** (EC2 + ELB = ambos devem passar)
- **Grace Period**: tempo após launch onde health checks são ignorados

### 12.3 Grace Period do ASG

- **Padrão**: 300 segundos
- Recomendação: configurar tempo suficiente para a aplicação iniciar
- Se muito curto → instâncias terminadas antes de estar prontas (loop de termination)
- Se muito longo → instâncias unhealthy ficam ativas por mais tempo

> ⚠️ **Na prova**: "ASG está terminando instâncias repetidamente logo após launch" → aumentar Health Check Grace Period


---

## 13. Lifecycle Hooks

### 13.1 O que são?

- Permitem executar **ações customizadas** durante o ciclo de vida da instância
- A instância entra em estado de **espera (wait)** antes de prosseguir
- Tempo máximo de espera: **48 horas** (padrão: 1 hora)
- Ações: executar scripts, instalar software, enviar logs, fazer backup

### 13.2 Estados com Lifecycle Hooks

```
┌─────────────────────────────────────────────────────────────────────┐
│                    LIFECYCLE DE UMA INSTÂNCIA NO ASG                  │
│                                                                     │
│  SCALE OUT (Launch):                                                │
│                                                                     │
│  Pending ──► Pending:Wait ──► Pending:Proceed ──► InService         │
│              (hook ativo)      (ação concluída)                      │
│                   │                                                  │
│                   ├── EventBridge / SNS / SQS                       │
│                   ├── Executar script de configuração                │
│                   └── Registrar em serviço de discovery              │
│                                                                     │
│  SCALE IN (Terminate):                                              │
│                                                                     │
│  InService ──► Terminating ──► Terminating:Wait ──► Terminating:Proceed ──► Terminated
│                                 (hook ativo)         (ação concluída)        │
│                                      │                                      │
│                                      ├── Fazer backup de logs               │
│                                      ├── Deregistrar de service discovery   │
│                                      └── Notificar equipe                   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 13.3 Integração com Outros Serviços

| Serviço | Uso com Lifecycle Hooks |
|---------|----------------------|
| **EventBridge** | Disparar Lambda ou Step Functions |
| **SNS** | Notificar equipe |
| **SQS** | Enfileirar ação para worker |
| **SSM Run Command** | Executar script na instância |
| **Lambda** | Lógica customizada |

### 13.4 Resultado do Hook

- `CONTINUE` → prossegue com o ciclo normal
- `ABANDON` → no launch: termina a instância; no terminate: prossegue com terminação
- Timeout → executa a ação padrão configurada (CONTINUE ou ABANDON)

---

## 14. Instance Refresh

### 14.1 O que é?

- Atualiza instâncias do ASG de forma **rolling** (gradual)
- Substitui instâncias antigas por novas (nova AMI, novo Launch Template version)
- Sem downtime se configurado corretamente

### 14.2 Parâmetros

| Parâmetro | Descrição | Padrão |
|-----------|-----------|--------|
| **Min Healthy Percentage** | % mínimo de instâncias saudáveis durante refresh | 90% |
| **Instance Warmup** | Tempo para nova instância ser considerada pronta | Valor do health check |
| **Max Healthy Percentage** | % máximo (permite over-provisioning temporário) | 100% |
| **Skip Matching** | Pula instâncias que já tem a config desejada | Sim |

### 14.3 Funcionamento

```
Instance Refresh (Min Healthy = 90%, ASG com 10 instâncias):

Fase 1: Termina 1 instância (9/10 = 90% ✓)
         Lança 1 nova instância
         Aguarda warmup
         
Fase 2: Termina próxima instância (9/10 = 90% ✓)
         Lança 1 nova instância
         Aguarda warmup

... repete até todas serem substituídas ...

Fase 10: Última instância substituída
          Refresh COMPLETO ✓
```

### 14.4 Rollback

- Se health check falha durante refresh → pode fazer rollback automático
- Desde 2023: **Auto Rollback** disponível
- Volta para o Launch Template version anterior

---

## 15. Termination Policies

### 15.1 Política Padrão (Default)

A política padrão segue esta ordem:

1. Seleciona a AZ com **mais instâncias** (balancear entre AZs)
2. Na AZ selecionada, aplica a política configurada:
   - Termina instância com **Launch Configuration mais antiga** (se existir)
   - Termina instância com **Launch Template mais antigo**
   - Se empate → termina a instância **mais próxima da próxima billing hour**
   - Se ainda empate → escolhe **aleatoriamente**

### 15.2 Políticas Disponíveis

| Política | Comportamento |
|----------|--------------|
| **Default** | Balanceia AZs → oldest config → closest to billing hour |
| **OldestInstance** | Termina instância mais velha do grupo |
| **NewestInstance** | Termina instância mais nova (útil para teste) |
| **OldestLaunchConfiguration** | Termina instância com LC mais antiga |
| **OldestLaunchTemplate** | Termina instância com LT version mais antigo |
| **AllocationStrategy** | Alinha com allocation strategy (Spot) |
| **ClosestToNextInstanceHour** | Mais próxima da próxima hora de billing |

### 15.3 Múltiplas Políticas

- É possível configurar uma **lista ordenada** de políticas
- O ASG aplica na ordem até desempatar
- Exemplo: `[OldestLaunchTemplate, ClosestToNextInstanceHour]`

---

## 16. Mixed Instances Policy (Spot + On-Demand)

### 16.1 O que é?

- Permite usar **múltiplos tipos de instância** e **Spot + On-Demand** no mesmo ASG
- Maximiza economia com Spot mantendo baseline com On-Demand
- Requer **Launch Template** (não funciona com Launch Configuration)

### 16.2 Configuração

```
Mixed Instances Policy:
├── Launch Template (base)
├── Overrides (tipos alternativos)
│   ├── m5.large
│   ├── m5a.large
│   ├── m4.large
│   └── c5.large
├── Instances Distribution:
│   ├── On-Demand Base Capacity: 2 (mínimo On-Demand)
│   ├── On-Demand Percentage Above Base: 25%
│   ├── Spot Allocation Strategy: capacity-optimized
│   └── Spot Max Price: (opcional, padrão = On-Demand price)
```

### 16.3 Allocation Strategies para Spot

| Strategy | Descrição | Quando Usar |
|----------|-----------|-------------|
| **capacity-optimized** | Escolhe pool com mais capacidade disponível | Maioria dos casos (recomendado) |
| **lowest-price** | Escolhe pool mais barato | Workloads flexíveis em tipo |
| **price-capacity-optimized** | Balanço entre preço e capacidade | Melhor custo-benefício |

### 16.4 Exemplo Prático

```
ASG: 10 instâncias desejadas
  On-Demand Base: 2
  On-Demand % Above Base: 25%
  
  Cálculo:
  - Base On-Demand: 2 instâncias
  - Acima da base: 8 instâncias
    - 25% On-Demand: 2 instâncias
    - 75% Spot: 6 instâncias
  
  Total: 4 On-Demand + 6 Spot = 10 instâncias
```

---

## 17. Scale-in Protection

### 17.1 O que é?

- Protege instâncias específicas de serem terminadas durante **scale-in**
- A instância continua sendo gerenciada pelo ASG
- Health checks continuam funcionando normalmente
- **NÃO protege** contra: terminação manual, Spot interruption, health check failure

### 17.2 Níveis de Proteção

| Nível | Escopo | Efeito |
|-------|--------|--------|
| **ASG level** | Todo o grupo | Novas instâncias ganham proteção automaticamente |
| **Instance level** | Instância específica | Apenas aquela instância é protegida |

### 17.3 Casos de Uso

- Instâncias executando **processos longos** (batch jobs)
- Instâncias com **estado local** importante
- **Leader election** — proteger a instância líder
- Processamento de **transações em andamento**

---

## 18. ASG + SQS Pattern

### 18.1 Arquitetura

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│  Producers ──► SQS Queue ──► Consumers (ASG)                     │
│                    │                                             │
│                    │  CloudWatch Metric:                         │
│                    │  ApproximateNumberOfMessagesVisible          │
│                    │                                             │
│                    ▼                                             │
│            CloudWatch Alarm                                       │
│                    │                                             │
│                    ▼                                             │
│            ASG Scaling Policy                                     │
│            (Target Tracking ou Step)                              │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### 18.2 Métrica Customizada Recomendada

Para escalar corretamente, use uma **métrica customizada**:

```
Backlog Per Instance = ApproximateNumberOfMessagesVisible / Número de instâncias no ASG
```

**Target Tracking** com essa métrica:
- Target: "Manter backlog per instance em 10 mensagens"
- Se backlog sobe → mais instâncias
- Se backlog desce → menos instâncias

### 18.3 Configuração com Step Scaling

```
Alarme 1: Messages > 1000 → Adicionar 2 instâncias
Alarme 2: Messages > 5000 → Adicionar 5 instâncias
Alarme 3: Messages > 10000 → Adicionar 10 instâncias
Alarme 4: Messages < 100 → Remover 2 instâncias
```

### 18.4 Boas Práticas

- Usar **Target Tracking** com métrica customizada (backlog/instância)
- Configurar **Visibility Timeout** do SQS > tempo de processamento
- Usar **Scale-in Protection** para instâncias processando mensagens
- Implementar **graceful shutdown**: instância para de consumir antes de terminar
- Usar **Lifecycle Hooks** para dar tempo ao worker de finalizar

---

## 19. Palavras-Chave da Prova SAA-C03

### Cenários Frequentes e Respostas

| # | Cenário/Palavra-Chave | Resposta |
|---|----------------------|----------|
| 1 | "Preciso de IP estático no load balancer" | **NLB** (suporta Elastic IP por AZ) |
| 2 | "Roteamento por URL path ou hostname" | **ALB** (roteamento L7 avançado) |
| 3 | "Milhões de requisições por segundo, baixa latência" | **NLB** (camada 4, ultra performance) |
| 4 | "Inspecionar tráfego com firewall de terceiros" | **GLB** (GENEVE, appliances de segurança) |
| 5 | "Múltiplos certificados SSL no mesmo LB" | **SNI** no ALB ou NLB |
| 6 | "Instâncias terminadas antes de completar requisições" | Aumentar **Deregistration Delay** |
| 7 | "Instâncias novas terminadas imediatamente pelo ASG" | Aumentar **Health Check Grace Period** |
| 8 | "Escalar baseado em fila SQS" | **ASG + Custom Metric** (ApproximateNumberOfMessages / InService) |
| 9 | "Executar script antes da instância entrar em serviço" | **Lifecycle Hook** (Pending:Wait) |
| 10 | "Fazer backup antes da instância ser terminada" | **Lifecycle Hook** (Terminating:Wait) |
| 11 | "Atualizar AMI de todas as instâncias sem downtime" | **Instance Refresh** (rolling update) |
| 12 | "Usar Spot + On-Demand no mesmo ASG" | **Mixed Instances Policy** |
| 13 | "IP estático + roteamento por path" | **NLB na frente do ALB** |
| 14 | "Proteger instância de scale-in (processo longo)" | **Scale-in Protection** |
| 15 | "Escalar proativamente antes do pico de tráfego" | **Predictive Scaling** |
| 16 | "Distribuir uniformemente entre AZs" | **Cross-Zone Load Balancing** habilitado |
| 17 | "Aplicação stateful, manter sessão no mesmo server" | **Sticky Sessions** (ALB cookies) |
| 18 | "Preciso que o target veja o IP real do cliente" | **NLB** (preserve source IP) ou X-Forwarded-For no ALB |
| 19 | "Serverless HTTP via load balancer" | **ALB** com target group Lambda |
| 20 | "AWS PrivateLink para expor serviço" | **NLB** (obrigatório para PrivateLink) |
| 21 | "Redirecionar HTTP para HTTPS" | **ALB Redirect Action** |
| 22 | "Canary deployment / blue-green com peso" | **ALB Weighted Target Groups** |
| 23 | "Instância precisa aquecer antes de receber carga total" | **Slow Start Mode** (ALB) ou Instance Warmup (ASG) |
| 24 | "Manter CPU média em X%" | **Target Tracking Scaling** |
| 25 | "Escalar em horário fixo (evento conhecido)" | **Scheduled Scaling** |

---

## 20. Resumo de Custos

| Componente | Modelo de Cobrança |
|------------|-------------------|
| **ALB** | Por hora + LCU (Load Balancer Capacity Units) |
| **NLB** | Por hora + NLCU (Network LB Capacity Units) |
| **GLB** | Por hora + GLCU (Gateway LB Capacity Units) |
| **Cross-Zone (ALB)** | Grátis |
| **Cross-Zone (NLB/GLB)** | Cobra por GB transferido entre AZs |
| **ASG** | Grátis (paga apenas pelas instâncias EC2) |

---

## 21. Dicas Finais para a Prova

1. **ALB = HTTP/HTTPS inteligente** (path routing, host routing, Lambda targets)
2. **NLB = TCP/UDP rápido com IP fixo** (PrivateLink, gaming, IoT)
3. **GLB = inspeção de tráfego** (firewalls, IDS/IPS, GENEVE)
4. **Launch Template > Launch Configuration** (sempre na prova)
5. **Predictive Scaling** = ML que antecipa picos
6. **Target Tracking** = mais simples e recomendada para a maioria dos casos
7. **Connection Draining** = dar tempo para requisições em andamento
8. **Health Check Grace Period** = evitar loop de termination em instâncias novas
9. **Lifecycle Hooks** = ações pré-launch e pré-terminate
10. **Instance Refresh** = atualizar ASG sem downtime (rolling)

---

*Documento preparado para certificação AWS Solutions Architect Associate (SAA-C03)*
*Última atualização: Julho 2026*
