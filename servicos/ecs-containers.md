# Containers na AWS — ECS, EKS, ECR, App Runner, Beanstalk (SAA-C03)

> Guia aprofundado para a certificação AWS Solutions Architect Associate (SAA-C03).
> Cobre conceitos de containers, serviços de orquestração, deploy e palavras-chave da prova.

---

## 1. Conceitos Fundamentais de Containers

### 1.1 Docker
- Motor de containerização que empacota aplicação + dependências em uma unidade portável
- Container = processo isolado no host usando namespaces e cgroups do kernel Linux
- Diferente de VM: compartilha o kernel do host, muito mais leve (MB vs GB)
- Dockerfile → define instruções para construir a imagem

### 1.2 Container Image
- Template read-only com camadas (layers) empilhadas
- Cada instrução no Dockerfile cria uma nova layer
- Layers são cacheadas e compartilhadas entre imagens (eficiência de storage)
- Identificada por repositório:tag ou repositório@digest (SHA256)

### 1.3 Container Registry
- Armazena e distribui container images
- Exemplos: Amazon ECR, Docker Hub, GitHub Container Registry
- Pull = baixar imagem | Push = enviar imagem
- Autenticação necessária para registries privados

### 1.4 Orquestração de Containers
- Gerencia o ciclo de vida de dezenas/centenas/milhares de containers
- Responsabilidades: scheduling, scaling, networking, load balancing, health checks
- Na AWS: ECS (proprietário) e EKS (Kubernetes gerenciado)

```
┌─────────────────────────────────────────────────────────┐
│                 ORQUESTRAÇÃO DE CONTAINERS               │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   Desenvolvedor                                         │
│       │                                                 │
│       ▼                                                 │
│   [Dockerfile] ──build──► [Image] ──push──► [Registry] │
│                                                  │      │
│                                                  ▼      │
│                                          [Orquestrador] │
│                                           /    |    \   │
│                                          ▼     ▼     ▼  │
│                                       [Task] [Task] [Task]
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 2. ECS — Elastic Container Service — Conceitos

### 2.1 Cluster
- Agrupamento lógico de recursos de computação (EC2 instances ou Fargate)
- Pode conter múltiplos services e standalone tasks
- Cada conta AWS tem um cluster default
- Clusters podem ter Capacity Providers associados

### 2.2 Task Definition
Funciona como um "blueprint" para rodar containers. É um JSON com:

| Campo | Descrição |
|-------|-----------|
| **Family** | Nome lógico da task definition (ex: `web-app`) |
| **Revision** | Versão incremental (family:revision → `web-app:3`) |
| **Container Definitions** | Array com 1+ containers na mesma task |
| **CPU / Memory** | Recursos alocados (obrigatório no Fargate) |
| **Port Mappings** | containerPort ↔ hostPort |
| **Environment Variables** | key-value diretos ou referências ao SSM/Secrets Manager |
| **Secrets** | Referência a SSM Parameter Store ou Secrets Manager (injetados em runtime) |
| **Log Configuration** | Driver de log (awslogs para CloudWatch, splunk, fluentd) |
| **Task Role ARN** | Role IAM assumida pela aplicação |
| **Execution Role ARN** | Role IAM usada pelo agente ECS |
| **Network Mode** | awsvpc, bridge, host, none |
| **Volumes** | EFS, Docker volumes, bind mounts |
| **Launch Type** | EC2, FARGATE ou EXTERNAL |

### 2.3 Task
- Instanciação em execução de uma Task Definition
- Pode ser standalone (run-task) ou parte de um Service
- Tem lifecycle: PROVISIONING → PENDING → RUNNING → STOPPED
- Cada task Fargate recebe um ENI próprio (IP privado na VPC)

### 2.4 Service
- Mantém um número desejado (desired count) de tasks em execução
- Reposiciona tasks que falharem automaticamente
- Integra com ALB/NLB para distribuição de tráfego
- Suporta deployment strategies e auto scaling

```
┌──────────────────────────────────────────────────────┐
│                    ECS CLUSTER                        │
│                                                      │
│  ┌─────────────── Service A ──────────────────┐     │
│  │  desired_count = 3                          │     │
│  │  ┌──────┐  ┌──────┐  ┌──────┐             │     │
│  │  │Task 1│  │Task 2│  │Task 3│             │     │
│  │  └──────┘  └──────┘  └──────┘             │     │
│  └─────────────────────────────────────────────┘     │
│                                                      │
│  ┌─────────────── Service B ──────────────────┐     │
│  │  desired_count = 2                          │     │
│  │  ┌──────┐  ┌──────┐                        │     │
│  │  │Task 1│  │Task 2│                        │     │
│  │  └──────┘  └──────┘                        │     │
│  └─────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────┘
```

---

## 3. ECS Launch Types: EC2 vs Fargate

### Tabela Comparativa Completa

| # | Critério | EC2 Launch Type | Fargate Launch Type |
|---|----------|-----------------|---------------------|
| 1 | Gerenciamento de infra | Você provisiona e gerencia EC2 | AWS gerencia totalmente |
| 2 | Visibilidade do OS | Acesso SSH ao host, controle total | Sem acesso ao host/OS |
| 3 | Networking modes | awsvpc, bridge, host, none | Apenas awsvpc |
| 4 | Suporte a GPU | ✅ Sim (instâncias P/G) | ❌ Não suportado |
| 5 | Modelo de custo | Paga EC2 (mesmo ociosa) | Paga por vCPU + memória por segundo |
| 6 | Spot/economia | EC2 Spot Instances | Fargate Spot (até 70% desconto) |
| 7 | Densidade de containers | Alta (múltiplos tasks por instância) | 1 task = 1 microVM isolada |
| 8 | Scaling da infra | Manual ou via Capacity Providers/ASG | Automático e transparente |
| 9 | Scaling de tasks | Service Auto Scaling | Service Auto Scaling |
| 10 | Startup time | Rápido (host já existe) | ~30-60s (provisionar microVM) |
| 11 | Segurança/isolamento | Containers compartilham kernel do host | Isolamento de kernel por task (Firecracker) |
| 12 | Storage efêmero | Acesso ao disco do host | 20 GB efêmero (expansível até 200 GB) |
| 13 | EFS mount | ✅ Sim | ✅ Sim |
| 14 | Daemon/sidecar no host | ✅ Sim (ex: Datadog agent) | ❌ Precisa ser sidecar na task |
| 15 | Patching do OS | Responsabilidade sua | AWS cuida |
| 16 | Compliance (ex: CIS) | Você aplica hardening | AWS garante |
| 17 | Windows containers | ✅ Sim | ✅ Sim (suporte limitado) |
| 18 | Quando usar | GPU, compliance custom, alta densidade, daemons | Serverless, microserviços, simplicidade, batch jobs |

---

## 4. ECS Networking

### 4.1 Modo awsvpc (PADRÃO no Fargate, recomendado no EC2)
- Cada task recebe seu próprio ENI (Elastic Network Interface)
- Task tem IP privado próprio na subnet da VPC
- Permite usar Security Groups por task (isolamento granular)
- Obrigatório no Fargate
- No EC2: limita número de tasks por instância (limite de ENIs)

### 4.2 Modo bridge (apenas EC2)
- Usa bridge network do Docker (docker0)
- Containers compartilham o ENI do host via port mapping dinâmico
- Host port 0 → Docker aloca porta aleatória (ALB dynamic port mapping)
- Permite múltiplos containers na mesma porta do container (portas do host diferentes)

### 4.3 Modo host (apenas EC2)
- Container compartilha o network namespace do host diretamente
- Sem port mapping — container usa a porta do host diretamente
- Melhor performance de rede (sem NAT/bridge overhead)
- Limitação: apenas 1 task por host usando a mesma porta

### 4.4 Modo none
- Container sem conectividade de rede externa
- Usado para tasks de processamento que não precisam de rede

```
┌─────────────────────────────────────────────────────────────────┐
│                    COMPARAÇÃO DE NETWORK MODES                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  awsvpc:          bridge:            host:                      │
│  ┌─────────┐     ┌─────────────┐    ┌──────────────┐          │
│  │ Task    │     │  EC2 Host   │    │  EC2 Host    │          │
│  │ ENI:    │     │  ENI: 10.0.1.5   │  ENI: 10.0.1.5│         │
│  │10.0.1.10│     │  ┌────┐┌────┐│   │  ┌────┐      │          │
│  │ SG: sg-A│     │  │:80 ││:80 ││   │  │:80 │      │          │
│  └─────────┘     │  │→32768│→32769│  │  │    │      │          │
│                   │  └────┘└────┘│   │  └────┘      │          │
│  ┌─────────┐     └─────────────┘    └──────────────┘          │
│  │ Task    │                                                    │
│  │ ENI:    │     Portas dinâmicas    Container usa              │
│  │10.0.1.11│     no host             porta do host              │
│  │ SG: sg-B│                         diretamente               │
│  └─────────┘                                                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. ECS IAM Roles

### 5.1 Task Execution Role
- Usada pelo **ECS Agent / Fargate agent**
- Permissões necessárias ANTES de o container iniciar:
  - `ecr:GetAuthorizationToken` — autenticar no ECR
  - `ecr:BatchGetImage` — pull da imagem
  - `logs:CreateLogStream`, `logs:PutLogEvents` — enviar logs ao CloudWatch
  - `ssm:GetParameters` — buscar secrets do SSM Parameter Store
  - `secretsmanager:GetSecretValue` — buscar do Secrets Manager

### 5.2 Task Role
- Usada pela **aplicação rodando dentro do container**
- Definida na Task Definition (campo `taskRoleArn`)
- Cada service/task pode ter role diferente (princípio do menor privilégio)
- Exemplos: acessar S3, DynamoDB, SQS, invocar Lambda

### 5.3 Diagrama de Responsabilidades

```
┌─────────────────────────────────────────────────────────────────┐
│                     ECS IAM ROLES                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────┐         ┌──────────────────────────┐     │
│  │ Task Execution   │         │      Task Role           │     │
│  │ Role             │         │                          │     │
│  ├──────────────────┤         ├──────────────────────────┤     │
│  │ QUEM USA:        │         │ QUEM USA:                │     │
│  │ ECS Agent        │         │ Código da aplicação      │     │
│  │                  │         │ (SDK dentro do container)│     │
│  ├──────────────────┤         ├──────────────────────────┤     │
│  │ QUANDO:          │         │ QUANDO:                  │     │
│  │ Antes do start   │         │ Durante execução         │     │
│  │                  │         │                          │     │
│  ├──────────────────┤         ├──────────────────────────┤     │
│  │ PARA QUE:        │         │ PARA QUE:                │     │
│  │ • Pull ECR image │         │ • Acessar S3             │     │
│  │ • Enviar logs    │         │ • Ler/gravar DynamoDB    │     │
│  │ • Buscar secrets │         │ • Publicar no SNS/SQS   │     │
│  │ • Auth no ECR    │         │ • Invocar Lambda         │     │
│  └──────────────────┘         └──────────────────────────┘     │
│                                                                 │
│  IMPORTANTE NA PROVA:                                           │
│  "Aplicação no ECS precisa acessar S3" → Task Role              │
│  "ECS não consegue puxar imagem do ECR" → Task Execution Role   │
└─────────────────────────────────────────────────────────────────┘
```


---

## 6. ECS Service — Deployment e Integração

### 6.1 Desired Count e Reconciliação
- Service garante que N tasks estejam sempre RUNNING
- Se uma task falha/morre, o scheduler reposiciona automaticamente
- `minimumHealthyPercent` e `maximumPercent` controlam o ritmo de deploy

### 6.2 Deployment Strategies

#### Rolling Update (padrão)
- Substitui tasks gradualmente (remove velhas, inicia novas)
- Configuração: `minimumHealthyPercent=50`, `maximumPercent=200`
- Zero downtime se bem configurado com health checks

#### Blue/Green via CodeDeploy
- Cria novo target group (green) com nova versão
- Shift de tráfego: Canary, Linear ou All-at-once
- Rollback automático baseado em alarmes CloudWatch
- Requer ALB/NLB com 2 target groups e listener rules

### 6.3 Load Balancer Integration

```
┌────────────────────────────────────────────────────────────┐
│           ALB + ECS Dynamic Port Mapping                   │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  Internet → ALB (porta 80/443)                             │
│              │                                             │
│              ▼                                             │
│         Target Group                                       │
│         ┌──────────────────────────────────────┐          │
│         │ 10.0.1.5:32768  (Task A - EC2 #1)   │          │
│         │ 10.0.1.5:32769  (Task B - EC2 #1)   │          │
│         │ 10.0.1.6:32770  (Task C - EC2 #2)   │          │
│         └──────────────────────────────────────┘          │
│                                                            │
│  Com awsvpc (Fargate):                                     │
│         ┌──────────────────────────────────────┐          │
│         │ 10.0.1.10:8080  (Task A - ENI)       │          │
│         │ 10.0.1.11:8080  (Task B - ENI)       │          │
│         │ 10.0.1.12:8080  (Task C - ENI)       │          │
│         └──────────────────────────────────────┘          │
│                                                            │
│  NOTA: bridge mode usa portas dinâmicas no host            │
│  awsvpc mode cada task usa a mesma porta (container port)  │
└────────────────────────────────────────────────────────────┘
```

### 6.4 Service Discovery (AWS Cloud Map)
- Registra tasks automaticamente no Route 53 (DNS) ou via API (HTTP namespace)
- Cada task recebe um registro DNS (A ou SRV record)
- Permite comunicação service-to-service sem load balancer
- Padrão: `taskname.namespace` → resolve para IPs das tasks
- Integração nativa com ECS (basta habilitar no service)

---

## 7. ECS Auto Scaling

### 7.1 Service Auto Scaling (Application Auto Scaling)
Escala o **número de tasks** do service:

| Tipo | Descrição | Exemplo |
|------|-----------|---------|
| **Target Tracking** | Mantém métrica em valor alvo | CPU média = 70% |
| **Step Scaling** | Escala em steps baseado em alarmes | Se CPU > 80% → +2 tasks |
| **Scheduled Scaling** | Escala em horários predefinidos | Aumentar às 8h, reduzir às 20h |

### 7.2 Métricas para Scaling

| Métrica | Fonte | Uso |
|---------|-------|-----|
| `ECSServiceAverageCPUUtilization` | CloudWatch | Target tracking padrão |
| `ECSServiceAverageMemoryUtilization` | CloudWatch | Workloads memory-bound |
| `ALBRequestCountPerTarget` | ALB | Escalar por carga de requests |
| Métricas customizadas | CloudWatch Custom | Qualquer métrica do app |

### 7.3 ECS Capacity Providers (escalar EC2 do cluster)

```
┌─────────────────────────────────────────────────────────────┐
│              CAPACITY PROVIDERS — FLUXO                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Service Auto Scaling                                       │
│       │ "Preciso de mais tasks"                             │
│       ▼                                                     │
│  ECS Scheduler                                              │
│       │ "Não há capacidade EC2 suficiente"                  │
│       ▼                                                     │
│  Capacity Provider                                          │
│       │ "Escalar o ASG para adicionar instâncias"           │
│       ▼                                                     │
│  Auto Scaling Group                                         │
│       │                                                     │
│       ▼                                                     │
│  Nova EC2 Instance registrada no cluster                    │
│       │                                                     │
│       ▼                                                     │
│  Tasks posicionadas na nova instância                       │
│                                                             │
│  PARÂMETROS:                                                │
│  • target capacity % (ex: 100% = cluster sempre cheio)      │
│  • managed scaling = enabled                                │
│  • managed termination protection = enabled                 │
└─────────────────────────────────────────────────────────────┘
```

- **Fargate Capacity Provider**: FARGATE e FARGATE_SPOT (sem ASG necessário)
- **EC2 Capacity Provider**: associado a um ASG com managed scaling
- Strategy: peso (weight) + base por provider (ex: 70% Fargate, 30% Fargate Spot)

---

## 8. ECS + Fargate Spot

### 8.1 Características
- Até **70% de desconto** em relação ao Fargate padrão
- AWS pode reclamar a capacidade a qualquer momento
- Task recebe sinal **SIGTERM** com **30 segundos** de aviso antes de ser terminada
- Task entra em estado `DEPROVISIONING` após o warning

### 8.2 Quando Usar
- Batch processing tolerante a interrupção
- Workers de filas (SQS) que podem ser reiniciados
- Ambientes de dev/test
- Workloads com checkpointing

### 8.3 Configuração via Capacity Provider Strategy
```
capacityProviderStrategy:
  - capacityProvider: FARGATE
    weight: 1
    base: 2          # mínimo de 2 tasks em Fargate regular
  - capacityProvider: FARGATE_SPOT
    weight: 3        # 75% das tasks adicionais em Spot
```

---

## 9. ECS Anywhere

### 9.1 Conceito
- Permite rodar ECS tasks em servidores **on-premises** ou em outras clouds
- Servidores registrados como instâncias `EXTERNAL` no cluster ECS
- Control plane continua na AWS (API ECS gerencia tudo)

### 9.2 Como Funciona
1. Instalar o SSM Agent e ECS Agent no servidor on-premises
2. Registrar o servidor no cluster ECS como External Instance
3. Criar Task Definitions com launch type `EXTERNAL`
4. ECS agenda tasks nos servidores registrados

### 9.3 Limitações
- Sem integração com ALB/NLB (load balancing é responsabilidade sua)
- Sem suporte a Service Connect ou Service Discovery nativos
- Networking mode: bridge ou host (sem awsvpc)
- Ideal para: workloads que precisam rodar perto de dados on-premises, requisitos de latência, compliance de localidade de dados


---

## 10. ECR — Elastic Container Registry

### 10.1 Visão Geral
- Registry privado e gerenciado para container images
- Integração nativa com ECS, EKS, Lambda, App Runner
- Suporta Docker images e OCI-compatible images
- Repositório público também disponível (ECR Public Gallery)

### 10.2 Lifecycle Policies
- Regras automáticas para limpar imagens antigas
- Critérios: idade da imagem, contagem de imagens, prefixo de tag
- Exemplo: "manter apenas as 10 imagens mais recentes com tag `latest`"
- Reduz custos de armazenamento automaticamente

### 10.3 Vulnerability Scanning

| Recurso | Basic Scanning | Enhanced Scanning (Inspector) |
|---------|---------------|-------------------------------|
| Motor | Clair (open source) | Amazon Inspector |
| Frequência | On push ou manual | Contínuo e automático |
| Cobertura | CVEs em OS packages | OS packages + linguagens (Python, Java, Node...) |
| Integração | ECR console | Inspector, Security Hub, EventBridge |
| Custo | Gratuito | Pago (por scan) |
| Recomendação prova | Básico | "scanning contínuo de vulnerabilidades" |

### 10.4 Cross-Account Access
- Usar **Resource-Based Policy** no repositório ECR
- Permite que contas diferentes façam pull de imagens
- Exemplo: conta de produção puxa imagem da conta de CI/CD
- Não precisa copiar imagens — acesso direto via policy

### 10.5 Cross-Region Replication
- Replica imagens automaticamente para outras regiões
- Útil para multi-region deployments
- Configurável: replicar tudo ou apenas imagens com determinados prefixos
- Replicação também funciona cross-account

### 10.6 Image Tag Immutability
- Quando habilitada: impede sobrescrever uma tag existente
- Garante que `myapp:v1.2.3` sempre aponta para o mesmo image digest
- Best practice para ambientes de produção
- Previne deploys acidentais com imagem alterada

---

## 11. EKS — Elastic Kubernetes Service (em profundidade)

### 11.1 Arquitetura
- **Control Plane**: gerenciado pela AWS (API Server, etcd, scheduler, controller manager)
- Distribuído em múltiplas AZs automaticamente
- Custo: **$0.10/hora** por cluster (~$73/mês)
- Você interage via `kubectl` e Kubernetes API

### 11.2 Worker Nodes — Tipos

| Tipo | Gerenciamento | Quando Usar |
|------|---------------|-------------|
| **Managed Node Groups** | AWS gerencia ASG, updates, lifecycle | Padrão recomendado |
| **Self-Managed Nodes** | Você gerencia EC2, AMI, updates | Custom AMI, GPU, compliance |
| **Fargate** | Serverless (sem nodes) | Pods isolados, sem gerenciamento |

### 11.3 EKS Networking
- **VPC CNI Plugin**: cada pod recebe um IP da VPC (ENI secundário)
- Pods são cidadãos de primeira classe na VPC (acessíveis por IP)
- **Pod Security Groups**: SGs aplicados diretamente a pods individuais
- Suporta Network Policies via Calico ou Cilium

### 11.4 EKS Add-ons
- Componentes gerenciados que rodam no cluster:
  - **CoreDNS** — DNS interno do cluster
  - **kube-proxy** — regras de rede nos nodes
  - **VPC CNI** — networking de pods
  - **EBS CSI Driver** — volumes persistentes EBS
  - **EFS CSI Driver** — volumes persistentes EFS
- AWS garante compatibilidade e updates dos add-ons

### 11.5 EKS Anywhere
- Distribuição Kubernetes da AWS para rodar **on-premises**
- Usa mesmo tooling do EKS (kubectl, helm, etc.)
- Infraestrutura: VMware vSphere, bare metal, Nutanix, Snow
- Conecta opcionalmente ao console AWS para visibilidade
- Diferente do ECS Anywhere: aqui é Kubernetes completo

---

## 12. ECS vs EKS — Tabela Comparativa

| Critério | ECS | EKS |
|----------|-----|-----|
| **Orquestrador** | Proprietário AWS | Kubernetes (open source) |
| **Complexidade** | Menor, mais simples | Maior, curva de aprendizado K8s |
| **Portabilidade** | Apenas AWS | Multi-cloud, on-premises |
| **Custo control plane** | Gratuito | $0.10/hora por cluster |
| **Custo worker nodes** | EC2 ou Fargate | EC2, Fargate, ou self-managed |
| **Ecossistema** | Integração nativa AWS | Enorme ecossistema K8s (Helm, Istio, Argo...) |
| **Service Mesh** | App Mesh ou Service Connect | Istio, Linkerd, App Mesh |
| **Networking** | awsvpc, bridge, host | VPC CNI (pod IP na VPC) |
| **Secrets** | SSM + Secrets Manager | K8s Secrets + External Secrets |
| **Auto Scaling** | Service Auto Scaling + Capacity Providers | HPA + Cluster Autoscaler / Karpenter |
| **CI/CD** | CodePipeline, CodeDeploy | ArgoCD, FluxCD, CodePipeline |
| **Observabilidade** | CloudWatch Container Insights | Prometheus + Grafana, Container Insights |
| **Quando usar** | Equipe AWS-first, simplicidade | Equipe K8s, multi-cloud, portabilidade |
| **Migração** | N/A | Facilita sair da AWS se necessário |

---

## 13. App Runner

### 13.1 Visão Geral
- Serviço totalmente gerenciado para deploy de aplicações web e APIs
- Abstrai toda a infraestrutura: sem cluster, task definition, load balancer
- Ideal para desenvolvedores que querem deploy rápido sem expertise em infra

### 13.2 Sources de Deploy

| Source | Descrição |
|--------|-----------|
| **Container Image (ECR)** | Imagem já construída, push para ECR, App Runner faz deploy |
| **Source Code (GitHub)** | Código no GitHub, App Runner builda e deploya automaticamente |

### 13.3 Funcionalidades

| Feature | Detalhes |
|---------|----------|
| **Auto Scaling** | Min/max instances configuráveis, scale-to-zero se inativo |
| **HTTPS automático** | Certificado TLS provisionado e renovado automaticamente |
| **Custom Domain** | Associar domínio próprio com certificado |
| **VPC Access** | VPC Connector para acessar recursos privados (RDS, ElastiCache) |
| **Health Checks** | HTTP health check configurável |
| **Observabilidade** | CloudWatch Logs e Metrics automaticamente |
| **Deploy automático** | Push no ECR ou GitHub → redeploy automático |

### 13.4 App Runner vs ECS Fargate

| Critério | App Runner | ECS Fargate |
|----------|------------|-------------|
| Complexidade | Mínima | Média |
| Controle | Pouco | Muito |
| Networking | VPC Connector (outbound) | awsvpc completo |
| Load Balancer | Incluso e gerenciado | Você configura ALB/NLB |
| Service Mesh | ❌ | ✅ Service Connect |
| Sidecars | ❌ | ✅ |
| Scale to zero | ✅ | ❌ (min 1 task) |
| Quando usar | APIs simples, MVPs, protótipos | Microserviços complexos, multi-container |


---

## 14. Elastic Beanstalk

### 14.1 Conceito
- **PaaS** (Platform as a Service) da AWS
- Abstrai provisionamento de infra: EC2, ASG, ELB, RDS, CloudWatch
- Desenvolvedor faz upload do código → Beanstalk cuida do resto
- Controle total sobre recursos por baixo (não é lock-in)
- Gratuito — paga apenas pelos recursos provisionados

### 14.2 Plataformas Suportadas
- Java, .NET, Node.js, Python, Ruby, PHP, Go
- Docker (single container e multi-container via ECS)
- Custom Platform (Packer)

### 14.3 Deployment Policies

| Policy | Downtime | Velocidade | Custo Extra | Rollback |
|--------|----------|------------|-------------|----------|
| **All at once** | ✅ Sim | Mais rápida | ❌ | Redeploy manual |
| **Rolling** | ❌ Parcial | Média | ❌ | Redeploy manual |
| **Rolling with additional batch** | ❌ Não | Média | ✅ Instâncias temporárias | Redeploy manual |
| **Immutable** | ❌ Não | Lenta | ✅ Novo ASG temporário | Terminar novo ASG |
| **Traffic Splitting** | ❌ Não | Lenta | ✅ Novo ASG temporário | Redirecionar tráfego |

**Detalhes importantes para a prova:**
- **All at once**: todas as instâncias de uma vez, causa downtime breve
- **Rolling**: atualiza em lotes (batch size configurável), capacidade reduzida durante deploy
- **Rolling with additional batch**: lança batch extra ANTES de atualizar → mantém capacidade total
- **Immutable**: cria novo ASG com instâncias novas, valida health, swap → mais seguro
- **Traffic Splitting**: como Immutable mas distribui % do tráfego para nova versão (canary testing)

### 14.4 Environment Types

| Tipo | Uso | Componentes |
|------|-----|-------------|
| **Web Server** | Aplicações HTTP | ELB + ASG + EC2 |
| **Worker** | Background processing | SQS queue + ASG + EC2 (daemon lê da fila) |

### 14.5 .ebextensions
- Pasta `.ebextensions/` na raiz do projeto com arquivos `.config` (YAML/JSON)
- Permite customizar TUDO: packages, files, commands, services, resources
- Pode criar recursos CloudFormation adicionais (RDS, ElastiCache, etc.)
- Executados em ordem alfabética

### 14.6 Beanstalk + Docker
- **Single Container**: roda 1 container Docker por instância
- **Multi-Container (ECS)**: usa ECS por baixo para rodar múltiplos containers
- `Dockerrun.aws.json` define a configuração dos containers
- Multi-container gera cluster ECS, task definitions e services automaticamente

---

## 15. AWS Copilot

### 15.1 Conceito
- **CLI** oficial da AWS para deploy simplificado em ECS/Fargate
- Abstrai toda a complexidade: VPC, subnets, cluster, ALB, service, task definition
- Opinado: segue best practices por padrão

### 15.2 Principais Comandos
```
copilot init          → inicializa app + service
copilot deploy        → build, push ECR, deploy ECS
copilot env init      → cria ambiente (dev, staging, prod)
copilot svc status    → mostra status do service
copilot pipeline init → cria CI/CD pipeline
```

### 15.3 Conceitos do Copilot
- **Application**: agrupamento lógico (ex: `myapp`)
- **Environment**: instância do app (dev, prod) — cria VPC, cluster, etc.
- **Service**: workload de longa duração (Load Balanced Web Service, Backend Service)
- **Job**: workload de curta duração (Scheduled Job)

### 15.4 Quando Usar
- Projetos greenfield em ECS/Fargate
- Equipes sem expertise em infra AWS
- Prototipagem rápida com best practices
- Alternativa ao Terraform/CDK para containerized apps

---

## 16. AWS Proton

### 16.1 Conceito
- Serviço de **platform engineering** da AWS
- Equipe de plataforma cria **templates** (environment e service)
- Desenvolvedores consomem templates para deploy self-service
- Garante padronização, compliance e governança

### 16.2 Componentes

| Componente | Descrição |
|------------|-----------|
| **Environment Template** | Define infra compartilhada (VPC, cluster ECS/EKS, namespaces) |
| **Service Template** | Define como um serviço é deployado (task def, ALB, pipeline) |
| **Environment** | Instância de um Environment Template |
| **Service** | Instância de um Service Template em um Environment |

### 16.3 Fluxo de Trabalho
```
Platform Team                          Developer
     │                                      │
     ├── Cria Environment Template ──────► │
     │   (VPC, ECS Cluster, etc.)          │
     │                                      │
     ├── Cria Service Template ──────────► │
     │   (Fargate service + ALB + CI/CD)   │
     │                                      │
     │                                      ├── Escolhe template
     │                                      ├── Fornece parâmetros
     │                                      ├── Deploy self-service
     │                                      │
     ├── Atualiza templates ──────────────► Auto-update nos services
     │
```

### 16.4 Quando Aparece na Prova
- "Padronizar deploys de containers para múltiplas equipes"
- "Platform team quer controlar infra mas dar autonomia aos devs"
- Geralmente como distrator — raramente é a resposta correta no SAA-C03

---

## 17. Palavras-Chave da Prova SAA-C03 — Cenários e Respostas

| # | Cenário / Palavra-chave | Resposta |
|---|------------------------|----------|
| 1 | "Container, serverless, sem gerenciar servidores" | **ECS + Fargate** |
| 2 | "Aplicação no container precisa acessar S3/DynamoDB" | **ECS Task Role** (não execution role) |
| 3 | "ECS não consegue puxar imagem do ECR" | **Task Execution Role** sem permissão ECR |
| 4 | "Kubernetes, portabilidade, multi-cloud" | **EKS** |
| 5 | "Deploy de containers com mínima configuração, HTTPS automático" | **App Runner** |
| 6 | "Reduzir custo de containers tolerantes a interrupção" | **Fargate Spot** ou EC2 Spot com ECS |
| 7 | "Escalar containers baseado em CPU/memória" | **ECS Service Auto Scaling** (Target Tracking) |
| 8 | "Escalar EC2 do cluster ECS automaticamente" | **ECS Capacity Providers** com Managed Scaling |
| 9 | "Blue/green deployment de containers" | **ECS + CodeDeploy** (2 target groups no ALB) |
| 10 | "Container precisa de GPU" | **ECS EC2 Launch Type** (instâncias P/G) |
| 11 | "Scanning contínuo de vulnerabilidades em imagens" | **ECR Enhanced Scanning** (Amazon Inspector) |
| 12 | "Limpar imagens antigas automaticamente no registry" | **ECR Lifecycle Policies** |
| 13 | "Rodar containers em servidores on-premises" | **ECS Anywhere** |
| 14 | "PaaS, upload de código, sem configurar infra" | **Elastic Beanstalk** |
| 15 | "Deploy sem downtime com instâncias novas validadas" | **Beanstalk Immutable Deployment** |
| 16 | "Comunicação entre microserviços sem load balancer" | **ECS Service Discovery** (Cloud Map) |
| 17 | "Container com ENI dedicado e Security Group próprio" | **awsvpc network mode** |
| 18 | "Múltiplos containers na mesma porta do container em EC2" | **bridge mode + ALB dynamic port mapping** |
| 19 | "Compartilhar imagens ECR entre contas AWS" | **ECR Resource-Based Policy** (cross-account) |
| 20 | "Worker environment que processa mensagens de fila" | **Beanstalk Worker Environment** (SQS) |
| 21 | "Secrets injetados no container em runtime" | **SSM Parameter Store ou Secrets Manager** (via Task Definition) |
| 22 | "Cada pod K8s precisa de Security Group próprio" | **EKS Pod Security Groups** |
| 23 | "Deploy simplificado de containers via CLI" | **AWS Copilot** |
| 24 | "Container images replicadas em múltiplas regiões" | **ECR Cross-Region Replication** |
| 25 | "Canary testing com % de tráfego para nova versão" | **Beanstalk Traffic Splitting** ou ECS + CodeDeploy Canary |

---

## Resumo Rápido — Árvore de Decisão

```
┌─────────────────────────────────────────────────────────────────────┐
│                    QUAL SERVIÇO USAR?                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Precisa de containers?                                             │
│       │                                                             │
│       ├── NÃO → Lambda (funções) ou EC2 (VMs)                      │
│       │                                                             │
│       └── SIM                                                       │
│            │                                                        │
│            ├── Kubernetes obrigatório?                               │
│            │    └── SIM → EKS                                       │
│            │                                                        │
│            ├── Máxima simplicidade?                                  │
│            │    └── SIM → App Runner                                 │
│            │                                                        │
│            ├── PaaS com deploy de código?                            │
│            │    └── SIM → Elastic Beanstalk                         │
│            │                                                        │
│            └── Controle + integração AWS?                            │
│                 │                                                    │
│                 ├── Gerenciar servidores? → ECS + EC2                │
│                 └── Serverless?           → ECS + Fargate            │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

> **Dica final para a prova:** O SAA-C03 foca em QUANDO usar cada serviço e nas
> diferenças entre eles — não em configurações detalhadas. Memorize a árvore de
> decisão acima e os cenários da tabela de palavras-chave.

