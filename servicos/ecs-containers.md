# Containers na AWS — ECS, EKS, ECR

## Quando usar cada opção

| | ECS + EC2 | ECS + Fargate | EKS | App Runner |
|-|-----------|---------------|-----|------------|
| Gerencia infra | ✅ Você | ❌ AWS | ✅ Você (nodes) | ❌ AWS |
| Complexidade | Média | Baixa | Alta | Muito baixa |
| Custo | Menor | Médio | Maior | Maior |
| Kubernetes | ❌ | ❌ | ✅ | ❌ |
| Quando usar | Controle sobre instâncias, spot instances | Serverless containers, sem overhead | K8s existente, portabilidade | Deploy simples e rápido |

---

## ECS — Elastic Container Service

### Conceitos
- **Cluster:** agrupamento lógico de recursos (EC2 ou Fargate)
- **Task Definition:** blueprint do container (imagem, CPU, memória, portas, variáveis, roles)
- **Task:** instância em execução de uma Task Definition
- **Service:** mantém N tasks rodando, integra com ALB, faz rolling updates

### ECS com EC2 vs ECS com Fargate — DIFERENÇA CRÍTICA

| | EC2 Launch Type | Fargate Launch Type |
|-|----------------|---------------------|
| Gerencia instâncias | ✅ Você provisiona e gerencia | ❌ AWS gerencia |
| Visibilidade do servidor | ✅ Acesso ao OS | ❌ Sem acesso ao host |
| Custo | Paga pela instância EC2 (mesmo ociosa) | Paga apenas pelo que a task usa |
| Spot Instances | ✅ Suportado | ✅ Fargate Spot disponível |
| Densidade de containers | Alta (múltiplos containers por instância) | 1 task = 1 ambiente isolado |
| Quando usar | Workloads pesados, controle fino, GPUs | Serverless, microserviços, simplicidade |

### IAM Roles no ECS
- **Task Role:** permissões que o código da aplicação dentro do container precisa (ex: acessar S3)
- **Task Execution Role:** permissões que o ECS agent precisa (ex: puxar imagem do ECR, gravar logs)

### ECS Service Auto Scaling
- Escala o número de tasks baseado em métricas CloudWatch
- Target Tracking (CPU, memória, ALB requests por target)
- Step Scaling e Scheduled Scaling disponíveis

---

## EKS — Elastic Kubernetes Service

- Kubernetes gerenciado pela AWS
- AWS gerencia o control plane (API server, etcd)
- Você gerencia os worker nodes (EC2) ou usa Fargate
- Quando usar: time já usa Kubernetes, portabilidade entre clouds, ecossistema K8s

### ECS vs EKS
| | ECS | EKS |
|-|-----|-----|
| Orquestrador | Próprio da AWS | Kubernetes (open source) |
| Curva de aprendizado | Menor | Maior |
| Portabilidade | Apenas AWS | Multi-cloud |
| Custo do control plane | Gratuito | $0.10/h por cluster |

---

## ECR — Elastic Container Registry

- Repositório privado de imagens Docker gerenciado pela AWS
- Integração nativa com ECS, EKS, Lambda (container image)
- **Scan de vulnerabilidades:** automático no push ou manual
- **Lifecycle Policies:** remove imagens antigas automaticamente (reduz custo)
- **Cross-account access:** via resource-based policy

---

## App Runner

- Deploy de containers ou código-fonte com configuração mínima
- Auto scaling automático incluindo scale-to-zero
- HTTPS automático, load balancing incluso
- Casos de uso: APIs simples, web apps, microserviços que não precisam de customização

---

## Diferenças Críticas

- **ECS Fargate vs Lambda:** Fargate para containers de longa duração; Lambda para funções curtas (máx 15 min)
- **ECS vs EKS:** ECS é mais simples e nativo AWS; EKS é para quem já conhece/usa Kubernetes
- **Task Role vs Task Execution Role:** Task Role = permissões da aplicação; Execution Role = permissões do agente ECS
