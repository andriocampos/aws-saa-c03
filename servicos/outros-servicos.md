# Outros Serviços AWS — SAA-C03

Guia de estudo para a certificação AWS Solutions Architect Associate (SAA-C03).
Cobre serviços complementares frequentemente cobrados na prova.

---

## 1. AWS CloudFormation

### 1.1 Visão Geral

AWS CloudFormation é o serviço de **Infrastructure as Code (IaC) nativo** da AWS.
Permite provisionar e gerenciar recursos AWS de forma declarativa usando templates.

- **Templates**: arquivos em formato YAML ou JSON que descrevem os recursos desejados
- **Stacks**: conjunto de recursos provisionados a partir de um template
- **Determinístico**: mesma entrada sempre gera a mesma infraestrutura

### 1.2 Estrutura de um Template

```yaml
AWSTemplateFormatVersion: "2010-09-09"
Description: "Exemplo de template"
Parameters:       # Valores de entrada
Mappings:         # Lookup tables estáticas
Conditions:       # Lógica condicional
Resources:        # OBRIGATÓRIO — recursos a criar
Outputs:          # Valores de saída (ex: URL do ALB)
```

### 1.3 Stacks e Stack Sets

| Conceito | Descrição |
|----------|-----------|
| **Stack** | Unidade de deploy — cria/atualiza/deleta recursos como um grupo |
| **Nested Stacks** | Stacks reutilizáveis referenciadas dentro de outra stack |
| **Cross-Stack References** | Exportar outputs de uma stack e importar em outra |
| **StackSets** | Deploy de stacks em **múltiplas contas e regiões** simultaneamente |

**StackSets** são ideais para:
- Aplicar configurações de compliance em todas as contas de uma organização
- Deploy de IAM roles ou Config rules em todas as regiões
- Gerenciamento centralizado via conta administradora

### 1.4 Drift Detection

- Detecta quando recursos foram **modificados manualmente** (fora do CloudFormation)
- Compara o estado atual do recurso com o definido no template
- Status: IN_SYNC, MODIFIED, DELETED, NOT_CHECKED

### 1.5 ChangeSets

- **Preview** das mudanças antes de aplicar uma atualização
- Mostra quais recursos serão adicionados, modificados ou removidos
- Não executa nada — apenas mostra o plano
- Permite revisão humana antes do deploy

### 1.6 Rollback

- Se a criação/atualização falhar, CloudFormation faz **rollback automático**
- Retorna ao estado anterior (última versão estável)
- Pode ser desabilitado para debugging (`--disable-rollback`)
- `OnFailure`: DO_NOTHING, ROLLBACK, DELETE

### 1.7 Service Role

- IAM Role que o CloudFormation **assume** para criar/modificar/deletar recursos
- Permite separação de responsabilidades: usuário pode executar stacks sem ter permissão direta nos recursos
- Princípio do menor privilégio aplicado ao CloudFormation

### 1.8 DeletionPolicy

Controla o que acontece com um recurso quando a stack é deletada:

| Policy | Comportamento |
|--------|---------------|
| **Delete** | Recurso é deletado (padrão para maioria dos recursos) |
| **Retain** | Recurso é mantido mesmo após deleção da stack |
| **Snapshot** | Cria snapshot antes de deletar (RDS, EBS, ElastiCache, Redshift) |

```yaml
Resources:
  MyDB:
    Type: AWS::RDS::DBInstance
    DeletionPolicy: Snapshot
    Properties:
      DBInstanceClass: db.t3.micro
```

### 1.9 Pontos-chave para a Prova

- CloudFormation é **gratuito** (paga apenas pelos recursos provisionados)
- StackSets = multi-account + multi-region
- Drift Detection = detectar mudanças manuais
- ChangeSets = preview antes de aplicar
- DeletionPolicy: Retain para manter, Snapshot para backup antes de deletar

---

## 2. Amazon SES (Simple Email Service)

### 2.1 Visão Geral

Amazon SES é um serviço de **envio e recebimento de emails** escalável e econômico.

- Envio de emails **transacionais** (confirmação de pedido, reset de senha)
- Envio de emails de **marketing** (newsletters, promoções)
- **Recebimento** de emails com processamento via Lambda/S3/SNS

### 2.2 Características

- Alta entregabilidade (deliverability)
- Suporte a DKIM, SPF, DMARC para autenticação
- Reputação gerenciada pela AWS
- Métricas: bounce rate, complaint rate, delivery rate
- **Sandbox mode**: precisa verificar emails antes de produção

### 2.3 Integrações

| Integração | Uso |
|------------|-----|
| **SNS** | Notificações de bounce/complaint/delivery |
| **Lambda** | Processar emails recebidos, lógica customizada |
| **S3** | Armazenar emails recebidos |
| **CloudWatch** | Métricas e alarmes |
| **Kinesis Firehose** | Streaming de eventos de email |

### 2.4 Casos de Uso

- Aplicação envia email de confirmação de cadastro
- Sistema de e-commerce envia recibos
- Plataforma envia notificações para usuários
- Receber emails em domínio próprio e processar via Lambda

---

## 3. Amazon Pinpoint

### 3.1 Visão Geral

Amazon Pinpoint é um serviço de **marketing e comunicação multi-channel**.
Diferente do SES que foca em email, Pinpoint orquestra campanhas completas.

### 3.2 Canais Suportados

- **Email**
- **SMS**
- **Push notifications** (mobile)
- **Voice** (chamadas de voz)
- **In-app messaging**

### 3.3 Funcionalidades

- **Segmentação de usuários**: criar segmentos baseados em atributos e comportamento
- **Campanhas**: mensagens programadas para segmentos específicos
- **Journeys**: fluxos automatizados multi-step baseados em eventos
- **A/B Testing**: testar variações de mensagens
- **Analytics**: métricas de engajamento por canal

### 3.4 Casos de Uso

- Campanha de re-engajamento para usuários inativos
- Onboarding automatizado multi-channel
- Promoções segmentadas por localização ou comportamento
- Notificações transacionais com fallback (email → SMS → push)


---

## 4. SES vs Pinpoint vs SNS — Tabela Comparativa

| Critério | Amazon SES | Amazon Pinpoint | Amazon SNS |
|----------|-----------|----------------|------------|
| **Foco principal** | Envio de email em escala | Marketing multi-channel | Pub/Sub e notificações |
| **Canais** | Email apenas | Email, SMS, Push, Voice, In-app | SMS, Push, Email (básico), HTTP |
| **Segmentação** | Não | Sim (segmentos de usuários) | Não (tópicos/assinaturas) |
| **Campanhas** | Não | Sim (journeys, A/B test) | Não |
| **Transacional** | Sim (forte) | Sim | Sim |
| **Marketing** | Básico (bulk email) | Completo (multi-channel) | Não |
| **Analytics** | Métricas de email | Analytics completo por canal | Métricas básicas |
| **Quando usar** | App precisa enviar emails | Marketing orquestrado multi-canal | Notificações pub/sub, fan-out |

### Resumo para a Prova

- **"Enviar email transacional da aplicação"** → SES
- **"Campanha de marketing multi-channel com segmentação"** → Pinpoint
- **"Notificar múltiplos subscribers de um evento"** → SNS
- **"SMS marketing com segmentação"** → Pinpoint
- **"Fan-out de mensagens para múltiplas filas"** → SNS

---

## 5. SSM Session Manager

### 5.1 Visão Geral

AWS Systems Manager Session Manager permite **acesso remoto a instâncias EC2 sem SSH**.

### 5.2 Características Principais

- **SEM necessidade de porta SSH (22) aberta** no Security Group
- **SEM bastion host** / jump box
- **SEM key pairs SSH** para gerenciar
- Acesso via Console AWS, CLI ou SDK
- **Audit completo** via CloudTrail (quem acessou, quando, comandos executados)
- Logs de sessão enviados para S3 ou CloudWatch Logs

### 5.3 Pré-requisitos

1. SSM Agent instalado na instância (pré-instalado em Amazon Linux 2/2023)
2. IAM Instance Profile com policy `AmazonSSMManagedInstanceCore`
3. Conectividade com o endpoint do SSM (via internet ou VPC Endpoint)

### 5.4 Benefícios de Segurança

| Aspecto | SSH Tradicional | Session Manager |
|---------|----------------|-----------------|
| Porta aberta | Sim (22) | Não |
| Bastion host | Necessário em private subnet | Não necessário |
| Key management | Chaves SSH a gerenciar | IAM policies |
| Auditoria | Limitada | CloudTrail + logs completos |
| Acesso granular | IP-based (SG) | IAM-based (por instância, tag, etc.) |

### 5.5 Pontos-chave para a Prova

- Cenário: "acesso seguro a EC2 em private subnet sem SSH" → Session Manager
- Cenário: "auditoria de comandos executados em instâncias" → Session Manager + CloudTrail
- Cenário: "eliminar bastion host" → Session Manager

---

## 6. SSM — Outros Serviços

### 6.1 Run Command

- Executa comandos/scripts em **múltiplas instâncias** simultaneamente
- Sem SSH, sem bastion
- Controle via IAM, output para S3/CloudWatch
- Exemplos: instalar pacotes, reiniciar serviços, coletar logs

### 6.2 Patch Manager

- **Automatiza patching** de instâncias EC2
- Define **Patch Baselines** (quais patches aplicar)
- Agenda via Maintenance Windows
- Suporta Windows e Linux
- Relatórios de compliance de patches

### 6.3 Maintenance Windows

- Define **janelas de manutenção** programadas
- Executa tarefas automatizadas (patching, scripts, automations)
- Controle de horário para minimizar impacto
- Integra com Run Command e Automation

### 6.4 Automation

- **Runbooks** para automatizar tarefas operacionais
- Exemplos: criar AMI, resize de instâncias, remediation de Config rules
- Pode ser triggered por EventBridge ou Config
- Runbooks pré-definidos pela AWS ou customizados

### 6.5 Parameter Store

- Armazenamento seguro de **configurações e secrets**
- Hierarquia de parâmetros (path-based)
- Integração com KMS para criptografia (SecureString)
- Versionamento automático
- **Nota**: detalhado em `seguranca.md`

### 6.6 Tabela Resumo SSM

| Serviço | Função |
|---------|--------|
| Session Manager | Shell remoto sem SSH |
| Run Command | Executar comandos em massa |
| Patch Manager | Patching automatizado |
| Maintenance Windows | Agendar tarefas |
| Automation | Runbooks operacionais |
| Parameter Store | Configurações e secrets |

---

## 7. AWS Cost Explorer

### 7.1 Visão Geral

AWS Cost Explorer permite **visualizar, entender e gerenciar custos e uso** da AWS.

### 7.2 Funcionalidades

- **Visualização de custos**: gráficos por serviço, conta, região, tag
- **Forecast**: previsão de gastos futuros (até 12 meses)
- **Savings Plans Recommendations**: recomendações de economia baseadas no uso histórico
- **Reserved Instance Recommendations**: sugestões de RIs para economia
- **Right-sizing Recommendations**: instâncias sub/super provisionadas

### 7.3 Granularidade

| Granularidade | Descrição | Uso |
|---------------|-----------|-----|
| **Monthly** | Visão mensal agregada | Tendências de longo prazo |
| **Daily** | Custos por dia | Identificar picos |
| **Hourly** | Custos por hora | Troubleshooting de picos específicos |

### 7.4 Filtros e Agrupamentos

- Por **serviço** (EC2, S3, RDS...)
- Por **conta** (em ambiente multi-account)
- Por **região**
- Por **tag** (cost allocation tags)
- Por **tipo de custo** (on-demand, reserved, spot)

### 7.5 Pontos-chave para a Prova

- "Visualizar custos e prever gastos futuros" → Cost Explorer
- "Recomendações de Savings Plans" → Cost Explorer
- Cost Explorer precisa ser **ativado** (não vem habilitado por padrão)


---

## 8. AWS Cost Anomaly Detection

### 8.1 Visão Geral

Usa **Machine Learning** para detectar automaticamente gastos anômalos na conta AWS.

### 8.2 Características

- Detecta padrões incomuns de gasto sem necessidade de definir thresholds manuais
- ML aprende o padrão normal de gastos e alerta sobre desvios
- Pode monitorar por: serviço, conta, cost allocation tag, cost category
- **Alertas** enviados via SNS ou email
- Mostra **root cause analysis** (qual serviço/recurso causou o pico)

### 8.3 Configuração

1. Criar **Cost Monitor** (define o escopo de monitoramento)
2. Criar **Alert Subscription** (define quem recebe alertas e threshold mínimo)
3. ML começa a aprender o padrão (melhora com o tempo)

### 8.4 Pontos-chave para a Prova

- "Detectar gastos inesperados automaticamente" → Cost Anomaly Detection
- "ML para identificar custos anômalos" → Cost Anomaly Detection
- Diferente de Budgets (que usa thresholds fixos)

---

## 9. AWS Budgets

### 9.1 Visão Geral

AWS Budgets permite criar **orçamentos** e receber alertas quando custos ou uso se aproximam ou excedem o limite definido.

### 9.2 Tipos de Budget

| Tipo | Monitora |
|------|----------|
| **Cost Budget** | Gastos em dólares |
| **Usage Budget** | Quantidade de uso (ex: horas EC2) |
| **Reservation Budget** | Utilização de Reserved Instances |
| **Savings Plans Budget** | Utilização de Savings Plans |

### 9.3 Alertas

- Alertas baseados em **thresholds** (ex: 80%, 100%, 120% do budget)
- Enviados via **email** ou **SNS**
- Pode definir alertas para custo **real** (actual) ou **previsto** (forecasted)

### 9.4 Budget Actions (Ações Automáticas)

- Executar ações automaticamente quando threshold é atingido:
  - Aplicar **IAM policy** restritiva (negar criação de recursos)
  - Aplicar **SCP** (Service Control Policy) na conta
  - Parar instâncias EC2 específicas
- Pode exigir aprovação manual ou ser totalmente automatizado

### 9.5 Pontos-chave para a Prova

- "Alertar quando custo exceder X dólares" → Budgets
- "Ação automática para cortar gastos" → Budgets Actions
- "Impedir criação de recursos quando budget excedido" → Budget Actions com IAM policy

### 9.6 Cost Explorer vs Budgets vs Anomaly Detection

| Serviço | Função Principal |
|---------|-----------------|
| **Cost Explorer** | Visualizar e analisar custos passados e futuros |
| **Budgets** | Definir limites e alertar quando atingidos |
| **Cost Anomaly Detection** | ML detecta gastos fora do padrão automaticamente |

---

## 10. AWS Outposts

### 10.1 Visão Geral

AWS Outposts leva **infraestrutura AWS para o seu data center on-premises**.
A AWS entrega, instala e gerencia **racks completos** de hardware no seu ambiente.

### 10.2 Características

- **Mesmas APIs e ferramentas** da AWS (Console, CLI, SDK, CloudFormation)
- Hardware gerenciado pela AWS (manutenção, patches, atualizações)
- Conectado à região AWS mais próxima
- Suporta: EC2, EBS, S3, RDS, ECS, EKS, EMR

### 10.3 Casos de Uso

| Caso de Uso | Justificativa |
|-------------|---------------|
| **Latência ultra-baixa** | Workloads que precisam de <10ms de latência local |
| **Residência de dados** | Dados que não podem sair do país/região por regulação |
| **Migração gradual** | Manter workloads on-premises enquanto migra para cloud |
| **Processamento local** | Dados gerados localmente processados no local |

### 10.4 Modelos

- **Outposts Rack**: rack completo 42U (para grandes workloads)
- **Outposts Server**: servidor individual (para locais com espaço limitado)

### 10.5 Pontos-chave para a Prova

- "Workload precisa rodar on-premises com APIs AWS" → Outposts
- "Requisito de residência de dados + serviços AWS" → Outposts
- "Latência local + consistência com cloud" → Outposts
- Outposts ≠ Direct Connect (DC é conectividade, Outposts é computação local)

---

## 11. AWS Batch

### 11.1 Visão Geral

AWS Batch é um serviço **fully managed** para executar **jobs de processamento em lote** em escala.

### 11.2 Características

- Provisiona automaticamente a quantidade ideal de computação (EC2 ou Fargate)
- Gerencia filas de jobs, prioridades e dependências
- Escala de zero a milhares de jobs
- Suporta containers Docker
- Sem necessidade de gerenciar clusters ou schedulers

### 11.3 Componentes

| Componente | Descrição |
|------------|-----------|
| **Job** | Unidade de trabalho (script, container) |
| **Job Definition** | Template do job (imagem, vCPU, memória, variáveis) |
| **Job Queue** | Fila de jobs aguardando execução |
| **Compute Environment** | Recursos computacionais (EC2 ou Fargate) |

### 11.4 AWS Batch vs Lambda

| Critério | AWS Batch | AWS Lambda |
|----------|-----------|------------|
| **Duração máxima** | Sem limite | 15 minutos |
| **Runtime** | Qualquer (Docker container) | Runtimes suportados (Python, Node, Java...) |
| **Storage** | EBS volumes (ilimitado) | 512 MB /tmp (até 10 GB) |
| **Computação** | EC2 ou Fargate (personalizada) | Até 10 GB RAM, 6 vCPU |
| **Startup** | Minutos (provisionar EC2) | Milissegundos (cold start ~1s) |
| **Gerenciamento** | Managed (mas mais config) | Serverless (zero config) |
| **Caso de uso** | Jobs longos, batch pesado, HPC | Eventos curtos, microserviços, APIs |

### 11.5 Pontos-chave para a Prova

- "Job de processamento que leva horas" → Batch
- "Processamento batch de milhões de registros" → Batch
- "Docker container com job longo" → Batch
- "Evento rápido, stateless, < 15 min" → Lambda

---

## 12. Amazon AppFlow

### 12.1 Visão Geral

Amazon AppFlow é um serviço de **integração de dados** que transfere dados entre **aplicações SaaS e serviços AWS** de forma segura.

### 12.2 Conectores Suportados (Exemplos)

**Fontes (Sources):**
- Salesforce, SAP, ServiceNow
- Slack, Zendesk, Google Analytics
- Datadog, Amplitude

**Destinos (Destinations):**
- Amazon S3
- Amazon Redshift
- Salesforce (bidirecional)
- Snowflake, Zendesk

### 12.3 Tipos de Flow

| Tipo | Descrição |
|------|-----------|
| **On-demand** | Execução manual |
| **Scheduled** | Agendado (hourly, daily, weekly) |
| **Event-driven** | Triggado por eventos na fonte (ex: novo registro no Salesforce) |

### 12.4 Funcionalidades

- **Transformações**: filtrar, mapear, mascarar, validar campos
- **Criptografia**: dados criptografados em trânsito e em repouso
- **PrivateLink**: dados trafegam pela rede privada AWS (não pela internet)
- **Particionamento**: dados no S3 particionados por data automaticamente

### 12.5 Pontos-chave para a Prova

- "Integrar Salesforce com S3/Redshift" → AppFlow
- "Transferir dados de SaaS para AWS sem código" → AppFlow
- "Integração SaaS ↔ AWS com agendamento" → AppFlow


---

## 13. AWS Amplify

### 13.1 Visão Geral

AWS Amplify é um conjunto de ferramentas para **desenvolver e hospedar aplicações web e mobile full-stack**.

### 13.2 Componentes

| Componente | Função |
|------------|--------|
| **Amplify Hosting** | Hospedagem de apps web com CI/CD (similar ao Netlify/Vercel) |
| **Amplify Studio** | Interface visual para configurar backend |
| **Amplify Libraries** | SDKs para frontend (React, Angular, Vue, Flutter, iOS, Android) |
| **Amplify CLI** | Provisionar backend via linha de comando |

### 13.3 Funcionalidades de Backend

- **Authentication**: Cognito User Pools integrado
- **API**: GraphQL (AppSync) ou REST (API Gateway + Lambda)
- **Storage**: S3 para arquivos, DynamoDB para dados
- **Functions**: Lambda functions
- **Analytics**: Pinpoint integrado

### 13.4 Hosting

- Deploy automático a partir de repositórios Git (GitHub, GitLab, Bitbucket, CodeCommit)
- Branch previews (PR previews)
- Custom domains com HTTPS automático
- CDN global (CloudFront)
- SSR (Server-Side Rendering) suportado

### 13.5 Pontos-chave para a Prova

- "Hospedar aplicação web full-stack com CI/CD" → Amplify
- "Frontend React/Angular com backend serverless" → Amplify
- "Deploy automático a partir do GitHub" → Amplify Hosting

---

## 14. AWS Control Tower

### 14.1 Visão Geral

AWS Control Tower automatiza a **configuração e governança de ambientes multi-account** seguindo boas práticas da AWS.

### 14.2 Conceitos Principais

| Conceito | Descrição |
|----------|-----------|
| **Landing Zone** | Ambiente multi-account configurado com boas práticas |
| **Guardrails** | Regras de governança aplicadas às contas |
| **Account Factory** | Provisionamento automatizado de novas contas |
| **Dashboard** | Visão centralizada de compliance |

### 14.3 Tipos de Guardrails

| Tipo | Mecanismo | Ação |
|------|-----------|------|
| **Preventive** | SCP (Service Control Policy) | **Impede** ações não conformes |
| **Detective** | AWS Config Rules | **Detecta** recursos não conformes |
| **Proactive** | CloudFormation Hooks | **Bloqueia** antes da criação |

**Exemplos de Guardrails:**
- Preventive: impedir desabilitar CloudTrail, impedir acesso público a S3
- Detective: detectar MFA não habilitado no root, detectar EBS sem criptografia

### 14.4 Account Factory

- Template para criar novas contas com configuração padronizada
- Configurações de rede (VPC), IAM, security baselines
- Pode ser usado por usuários autorizados via Service Catalog
- Garante que toda nova conta já nasce em compliance

### 14.5 Landing Zone

Estrutura padrão criada pelo Control Tower:

```
Organization Root
├── Security OU
│   ├── Audit Account (segurança)
│   └── Log Archive Account (logs centralizados)
├── Sandbox OU
│   └── Contas de desenvolvimento
└── Production OU
    └── Contas de produção
```

### 14.6 Pontos-chave para a Prova

- "Configurar ambiente multi-account com governança" → Control Tower
- "Guardrails preventivos" → SCP
- "Guardrails detectivos" → Config Rules
- "Provisionar novas contas padronizadas" → Account Factory
- Control Tower usa: Organizations, SCPs, Config, CloudTrail, SSO

---

## 15. AWS Instance Scheduler

### 15.1 Visão Geral

AWS Instance Scheduler é uma solução da AWS que **inicia e para instâncias EC2 e RDS** automaticamente com base em schedules definidos.

### 15.2 Objetivo

- **Reduzir custos** parando recursos fora do horário de uso
- Exemplo: desligar instâncias de desenvolvimento à noite e fins de semana
- Economia potencial de **65-70%** (10h/dia × 5 dias = ~30% do tempo ligado)

### 15.3 Como Funciona

1. Deploy via CloudFormation (solução pré-configurada)
2. Define **schedules** (horários de operação) em DynamoDB
3. Lambda function executa periodicamente verificando os schedules
4. Instâncias taggeadas com o schedule são iniciadas/paradas automaticamente

### 15.4 Características

- Suporta **múltiplas regiões** e **múltiplas contas**
- Configuração via tags nas instâncias
- Timezone-aware
- Pode definir períodos de exceção (não parar em determinadas datas)
- Logs e métricas via CloudWatch

### 15.5 Exemplo de Schedule

| Parâmetro | Valor |
|-----------|-------|
| Nome | office-hours |
| Timezone | America/Sao_Paulo |
| Início | 08:00 |
| Fim | 18:00 |
| Dias | Mon-Fri |

Tag na instância: `Schedule = office-hours`

### 15.6 Pontos-chave para a Prova

- "Economizar custos parando instâncias fora do horário" → Instance Scheduler
- "Start/stop automatizado de EC2/RDS" → Instance Scheduler
- "Reduzir custos de ambientes de dev/test" → Instance Scheduler

---

## 16. Palavras-chave da Prova SAA-C03

Cenários frequentes na prova e a resposta correta:

| # | Cenário / Palavra-chave | Resposta |
|---|------------------------|----------|
| 1 | "Infrastructure as Code nativa da AWS" | CloudFormation |
| 2 | "Deploy multi-account e multi-region simultaneamente" | CloudFormation StackSets |
| 3 | "Detectar mudanças manuais na infraestrutura" | CloudFormation Drift Detection |
| 4 | "Preview de mudanças antes de aplicar update na stack" | CloudFormation ChangeSets |
| 5 | "Manter recurso após deletar stack" | DeletionPolicy: Retain |
| 6 | "Criar snapshot de RDS antes de deletar stack" | DeletionPolicy: Snapshot |
| 7 | "Enviar email transacional da aplicação" | Amazon SES |
| 8 | "Campanha de marketing multi-channel com segmentação" | Amazon Pinpoint |
| 9 | "Fan-out de notificações para múltiplos subscribers" | Amazon SNS |
| 10 | "Acesso remoto a EC2 sem SSH e sem bastion host" | SSM Session Manager |
| 11 | "Auditoria de comandos executados em EC2" | SSM Session Manager + CloudTrail |
| 12 | "Executar comandos em centenas de instâncias" | SSM Run Command |
| 13 | "Patching automatizado de servidores" | SSM Patch Manager |
| 14 | "Visualizar custos e prever gastos futuros" | AWS Cost Explorer |
| 15 | "ML detecta gastos anômalos automaticamente" | Cost Anomaly Detection |
| 16 | "Alertar quando custo ultrapassar valor definido" | AWS Budgets |
| 17 | "Ação automática quando budget é excedido" | AWS Budgets Actions |
| 18 | "Rodar workloads AWS no data center local (on-premises)" | AWS Outposts |
| 19 | "Requisito de residência de dados + serviços AWS" | AWS Outposts |
| 20 | "Job de processamento batch que leva horas/dias" | AWS Batch |
| 21 | "Batch vs Lambda — job longo, Docker, sem limite de tempo" | AWS Batch |
| 22 | "Integrar Salesforce/SAP com S3 ou Redshift" | Amazon AppFlow |
| 23 | "Transferir dados de SaaS para AWS sem código" | Amazon AppFlow |
| 24 | "Hospedar app web full-stack com CI/CD" | AWS Amplify |
| 25 | "Governança multi-account com guardrails" | AWS Control Tower |
| 26 | "Guardrails preventivos em multi-account" | Control Tower + SCPs |
| 27 | "Provisionar novas contas AWS padronizadas" | Control Tower Account Factory |
| 28 | "Economizar custos parando EC2/RDS fora do horário" | AWS Instance Scheduler |
| 29 | "Recomendações de Savings Plans baseadas no uso" | Cost Explorer |
| 30 | "Processar emails recebidos com Lambda" | Amazon SES + Lambda |

---

## Resumo Final — Mapa Mental

```
Outros Serviços AWS (SAA-C03)
│
├── IaC & Deploy
│   └── CloudFormation (Stacks, StackSets, Drift, ChangeSets, DeletionPolicy)
│
├── Comunicação
│   ├── SES (Email transacional/marketing)
│   ├── Pinpoint (Marketing multi-channel)
│   └── SNS (Pub/Sub, fan-out)
│
├── Gerenciamento (SSM)
│   ├── Session Manager (shell sem SSH)
│   ├── Run Command (comandos em massa)
│   ├── Patch Manager (patching)
│   ├── Maintenance Windows (agendamento)
│   ├── Automation (runbooks)
│   └── Parameter Store (configs/secrets)
│
├── Custos
│   ├── Cost Explorer (visualizar/forecast)
│   ├── Cost Anomaly Detection (ML)
│   ├── Budgets (alertas/ações)
│   └── Instance Scheduler (start/stop)
│
├── Infraestrutura Especial
│   ├── Outposts (AWS on-premises)
│   └── Batch (processamento em lote)
│
├── Integrações
│   └── AppFlow (SaaS ↔ AWS)
│
├── Desenvolvimento
│   └── Amplify (full-stack web/mobile)
│
└── Governança
    └── Control Tower (multi-account, guardrails, Account Factory)
```

---

*Última atualização: Julho 2026*
