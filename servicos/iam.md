# IAM — Identity and Access Management

> Serviço **global** (não regional) que controla autenticação e autorização em toda a conta AWS.

---

## 1. Entidades IAM

| Entidade | Descrição | Credenciais |
|----------|-----------|-------------|
| **Root Account** | Dono da conta, acesso irrestrito | Email + senha + MFA |
| **Users** | Identidade permanente para pessoa ou serviço | Senha console + Access Keys |
| **Groups** | Coleção de Users (não pode conter outros Groups) | — (herdam policies) |
| **Roles** | Identidade temporária assumida por entidades | Credenciais temporárias via STS |
| **Policies** | Documentos JSON que definem permissões | — |

### Limites importantes para a prova

- Máximo de **5.000 usuários** por conta
- Um usuário pode pertencer a no máximo **10 grupos**
- Uma conta pode ter até **1.000 roles** (soft limit)
- Policies gerenciadas têm limite de **6.144 caracteres** por policy

---

## 2. Tipos de Policy

| Tipo | Onde é anexada | Reutilizável? | Caso de uso |
|------|---------------|---------------|-------------|
| **AWS Managed** | Users, Groups, Roles | Sim | Permissões comuns (ReadOnlyAccess) |
| **Customer Managed** | Users, Groups, Roles | Sim | Permissões customizadas da organização |
| **Inline** | Diretamente na entidade | Não | Permissão 1:1 estrita |
| **Resource-based** | No recurso (S3, SQS, Lambda) | — | Cross-account sem AssumeRole |

### Estrutura JSON de uma Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowS3ReadOnly",
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::meu-bucket",
        "arn:aws:s3:::meu-bucket/*"
      ],
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "us-east-1"
        }
      }
    }
  ]
}
```

### Elementos do Statement

| Campo | Obrigatório? | Descrição |
|-------|:---:|-----------|
| `Effect` | ✅ | `Allow` ou `Deny` |
| `Action` | ✅ | API(s) permitida(s) ou negada(s) |
| `Resource` | ✅ | ARN(s) do recurso alvo |
| `Principal` | Apenas em Resource-based | Quem recebe a permissão |
| `Condition` | ❌ | Restrições adicionais |
| `Sid` | ❌ | Identificador legível (Statement ID) |

> ⚠️ **Principal** NÃO existe em Identity-based policies — ele é implícito (a entidade onde a policy está anexada).

---

## 3. Lógica de Avaliação de Policies

### Fluxo de decisão (ordem de prioridade)

```
┌─────────────────────────────────────────────────┐
│ 1. Deny explícito em QUALQUER policy?           │
│    → SIM: ❌ NEGADO (fim)                       │
│    → NÃO: próximo passo                        │
├─────────────────────────────────────────────────┤
│ 2. SCP da Organization permite?                 │
│    → NÃO: ❌ NEGADO (fim)                       │
│    → SIM: próximo passo                        │
├─────────────────────────────────────────────────┤
│ 3. Permission Boundary permite?                 │
│    → NÃO: ❌ NEGADO (fim)                       │
│    → SIM: próximo passo                        │
├─────────────────────────────────────────────────┤
│ 4. Session Policy permite? (se aplicável)       │
│    → NÃO: ❌ NEGADO (fim)                       │
│    → SIM: próximo passo                        │
├─────────────────────────────────────────────────┤
│ 5. Identity-based OU Resource-based permite?    │
│    → SIM: ✅ PERMITIDO                          │
│    → NÃO: ❌ NEGADO (deny implícito)            │
└─────────────────────────────────────────────────┘
```

### Regras fundamentais

1. **Deny explícito SEMPRE vence** — não importa quantos Allows existam
2. **Deny implícito** — tudo que não é explicitamente permitido é negado
3. **Cross-account** — ambas as contas devem permitir (Identity-based NA conta de origem + Resource-based NO recurso de destino)
4. **Mesmo conta** — basta UM Allow (Identity-based OU Resource-based)

### Exemplo prático: conflito de policies

```json
// Policy 1 (Identity-based no User)
{
  "Effect": "Allow",
  "Action": "s3:*",
  "Resource": "*"
}

// Policy 2 (Permission Boundary no User)  
{
  "Effect": "Allow",
  "Action": ["s3:GetObject", "s3:PutObject"],
  "Resource": "arn:aws:s3:::app-bucket/*"
}
```

**Resultado:** O usuário só pode fazer `GetObject` e `PutObject` no bucket `app-bucket`.  
A interseção entre Identity-based e Permission Boundary define o acesso efetivo.


---

## 4. Trust Policy vs Permission Policy

| Aspecto | Trust Policy | Permission Policy |
|---------|-------------|-------------------|
| **Pergunta** | QUEM pode assumir esta Role? | O QUE esta Role pode fazer? |
| **Onde fica** | Na Role (campo AssumeRolePolicyDocument) | Anexada à Role |
| **Principal** | Obrigatório | Não existe |
| **Tipo** | Sempre Resource-based | Identity-based |

### Exemplo: Trust Policy (quem pode assumir)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

### Exemplo: Permission Policy (o que pode fazer)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::app-data/*"
    }
  ]
}
```

### Diagrama: como uma Role funciona

```
┌─────────────┐       AssumeRole        ┌──────────────────┐
│  EC2 / User │ ─────────────────────►   │      ROLE        │
│  / Lambda   │                          │                  │
└─────────────┘                          │  Trust Policy:   │
                                         │  "Quem pode?"    │
      Recebe credenciais ◄─────────────  │                  │
      temporárias (STS)                  │  Permission:     │
                                         │  "O que pode?"   │
                                         └──────────────────┘
```

---

## 5. STS — Security Token Service

> Serviço **global** que emite **credenciais temporárias** (Access Key + Secret Key + Session Token).

### APIs principais do STS

| API | Caso de uso | Duração padrão |
|-----|-------------|:--------------:|
| `AssumeRole` | Cross-account, trocar de role | 1h (15min–12h) |
| `AssumeRoleWithWebIdentity` | Login com IdP web (Google, Facebook) | 1h (15min–12h) |
| `AssumeRoleWithSAML` | Login com SAML 2.0 (AD FS) | 1h (15min–12h) |
| `GetSessionToken` | MFA para usuário IAM | 12h (15min–36h) |
| `GetFederationToken` | Credenciais para usuários federados | 12h (15min–36h) |
| `GetCallerIdentity` | Verifica quem eu sou (debugging) | — |
| `DecodeAuthorizationMessage` | Decodifica erros de autorização | — |

### Fluxo Cross-Account com AssumeRole

```
   Conta A (111111111111)              Conta B (222222222222)
┌─────────────────────────┐        ┌─────────────────────────┐
│                         │        │                         │
│  IAM User: developer    │        │  Role: CrossAccountRole │
│                         │        │                         │
│  Policy:                │        │  Trust Policy:          │
│  "Allow"                │        │  Principal:             │
│  "sts:AssumeRole"       │───────►│  "arn:aws:iam::         │
│  Resource:              │        │   111111111111:root"    │
│  "arn:aws:iam::         │        │                         │
│   222222222222:role/     │        │  Permission Policy:     │
│   CrossAccountRole"     │        │  "s3:*" em bucket-b    │
│                         │◄───────│                         │
│  Recebe: temp creds     │        │                         │
└─────────────────────────┘        └─────────────────────────┘
```

**Passos:**
1. Admin da Conta B cria Role com Trust Policy permitindo Conta A
2. Admin da Conta A dá permissão ao User para chamar `sts:AssumeRole`
3. User na Conta A chama `sts:AssumeRole` com ARN da Role na Conta B
4. STS retorna credenciais temporárias
5. User usa credenciais temporárias para acessar recursos da Conta B

### Quando usar STS na prova

- **Cross-account access** → `AssumeRole`
- **Mobile app com login social** → `AssumeRoleWithWebIdentity` (melhor: usar Cognito)
- **Enterprise SSO com AD** → `AssumeRoleWithSAML`
- **Proteger operações com MFA** → `GetSessionToken`
- **"Quem sou eu?"** → `GetCallerIdentity`

---

## 6. Instance Profile

> É o **container** que permite associar uma IAM Role a uma instância EC2.

### Como funciona

```
┌──────────────────┐     contém     ┌──────────────┐     gera      ┌─────────────────┐
│ Instance Profile │ ──────────────► │   IAM Role   │ ─────────────► │ Credenciais     │
│ (container)      │                 │              │               │ temporárias     │
└──────────────────┘                 └──────────────┘               │ via metadata    │
        │                                                           │ 169.254.169.254 │
        │ associado                                                 └─────────────────┘
        ▼                                                                    │
┌──────────────────┐                                                         │
│   EC2 Instance   │ ◄──────────────────────────────────────────────────────┘
│                  │   SDK/CLI busca credenciais automaticamente
└──────────────────┘
```

### Pontos importantes

- **Console AWS** cria o Instance Profile automaticamente ao associar uma Role ao EC2
- **CLI/CloudFormation** exige criação explícita do Instance Profile
- Credenciais são rotacionadas automaticamente (~6h antes de expirar)
- Aplicações no EC2 usam o SDK que busca credenciais do metadata service
- **Nunca usar Access Keys no EC2** — sempre usar Instance Profile + Role

### Metadata endpoint

```bash
# Buscar credenciais da role (IMDSv2)
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/iam/security-credentials/MyRole
```

> ⚠️ **IMDSv2** usa tokens (PUT + header) — mais seguro que IMDSv1. Recomendado desabilitar IMDSv1.


---

## 7. Conditions (Condições em Policies)

> Permitem restringir QUANDO uma policy se aplica, baseado em contexto da requisição.

### Operadores de condição mais comuns

| Operador | Tipo | Exemplo |
|----------|------|---------|
| `StringEquals` | String exata | `"aws:RequestedRegion": "us-east-1"` |
| `StringLike` | String com wildcard | `"s3:prefix": "home/${aws:username}/*"` |
| `IpAddress` | Range de IP | `"aws:SourceIp": "203.0.113.0/24"` |
| `NotIpAddress` | IP fora do range | Bloquear acessos de fora da empresa |
| `DateLessThan` | Antes de data | Acesso temporário |
| `Bool` | Booleano | `"aws:MultiFactorAuthPresent": "true"` |
| `ArnLike` | ARN com wildcard | Restringir por recurso específico |
| `Null` | Verifica se chave existe | `"aws:TokenIssueTime": "true"` (não tem token) |

### Condition Keys mais importantes na prova

| Key | Uso |
|-----|-----|
| `aws:SourceIp` | IP de origem da requisição |
| `aws:SourceVpc` | VPC de origem (VPC Endpoints) |
| `aws:SourceVpce` | VPC Endpoint específico |
| `aws:RequestedRegion` | Região da API chamada |
| `aws:PrincipalOrgID` | ID da Organization |
| `aws:MultiFactorAuthPresent` | MFA ativo na sessão |
| `aws:PrincipalTag/` | Tags no principal |
| `s3:x-amz-server-side-encryption` | Exigir criptografia no upload |
| `ec2:ResourceTag/` | Tags no recurso EC2 |

### Exemplo: forçar MFA para deletar objetos S3

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyDeleteWithoutMFA",
      "Effect": "Deny",
      "Action": "s3:DeleteObject",
      "Resource": "arn:aws:s3:::critical-bucket/*",
      "Condition": {
        "BoolIfExists": {
          "aws:MultiFactorAuthPresent": "false"
        }
      }
    }
  ]
}
```

### Exemplo: restringir acesso por IP e região

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "NotIpAddress": {
          "aws:SourceIp": ["203.0.113.0/24", "2001:db8::/32"]
        },
        "StringNotEquals": {
          "aws:RequestedRegion": ["us-east-1", "eu-west-1"]
        }
      }
    }
  ]
}
```

> ⚠️ Múltiplas condições no mesmo bloco usam **AND**. Múltiplos valores na mesma chave usam **OR**.

---

## 8. Identity-based vs Resource-based Policies

| Aspecto | Identity-based | Resource-based |
|---------|---------------|----------------|
| **Onde fica** | No User/Group/Role | No recurso (S3, SQS, SNS, Lambda, KMS) |
| **Principal** | Implícito (a entidade) | Explícito no JSON |
| **Cross-account** | Requer AssumeRole | Permite sem AssumeRole |
| **Permissão efetiva** | União com outros policies da entidade | Adiciona permissão diretamente |

### Cross-account: diferença fundamental

```
┌─────────── IDENTITY-BASED (AssumeRole) ──────────────┐
│                                                       │
│  User na Conta A → AssumeRole → Role na Conta B      │
│  ⚠️  User PERDE suas permissões originais            │
│  ✅  Ganha APENAS as permissões da Role assumida     │
│                                                       │
├─────────── RESOURCE-BASED ────────────────────────────┤
│                                                       │
│  User na Conta A → acessa diretamente recurso B      │
│  ✅  User MANTÉM suas permissões originais           │
│  ✅  SOMA com a permissão do resource policy         │
│                                                       │
└───────────────────────────────────────────────────────┘
```

> 📝 **Na prova:** Se um User precisa acessar recurso cross-account E manter acesso a recursos da própria conta simultaneamente → **Resource-based policy** é a resposta.

### Serviços que suportam Resource-based policies

S3, SQS, SNS, Lambda, KMS, ECR, API Gateway, Secrets Manager, EventBridge, Glacier, Backup

---

## 9. Permission Boundaries

> Define o **máximo** de permissões que uma entidade pode ter. Funciona como um **teto**.

### Como funciona

```
┌───────────────────────────────────────────────────────────────┐
│                    PERMISSION BOUNDARY                         │
│                   (máximo permitido)                           │
│    ┌─────────────────────────────────────────────────────┐    │
│    │                                                     │    │
│    │    ┌─────────────────────────────┐                  │    │
│    │    │    IDENTITY-BASED POLICY    │                  │    │
│    │    │    (permissões concedidas)  │                  │    │
│    │    └─────────────────────────────┘                  │    │
│    │                                                     │    │
│    │    ████████ = ACESSO EFETIVO (interseção)           │    │
│    │                                                     │    │
│    └─────────────────────────────────────────────────────┘    │
│                                                               │
└───────────────────────────────────────────────────────────────┘

Acesso Efetivo = Identity-based ∩ Permission Boundary
```

### Caso de uso clássico na prova

**Cenário:** Permitir que um time de DevOps crie IAM Users/Roles sem escalar privilégios.

```json
// Permission Boundary para novos Users criados pelo DevOps
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*",
        "cloudwatch:*",
        "ec2:Describe*"
      ],
      "Resource": "*"
    }
  ]
}
```

```json
// Policy do DevOps: pode criar Users MAS deve anexar boundary
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "iam:CreateUser",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "iam:PermissionsBoundary": "arn:aws:iam::123456789012:policy/DevBoundary"
        }
      }
    }
  ]
}
```

### Regras

- Aplica-se a **Users e Roles** (não a Groups)
- Não concede permissão — apenas **limita**
- Avaliada ANTES da Identity-based policy
- Útil para **delegação segura** de criação de entidades IAM

---

## 10. SCPs — Service Control Policies (AWS Organizations)

> Define o **máximo** de permissões para contas dentro de uma Organization. Funciona como **guardrail**.

### Características

- Aplica-se a **OUs e Contas-membro** (nunca à Management Account)
- **NÃO concede permissão** — apenas restringe
- Afeta **todos os principals** da conta (inclusive root da conta-membro)
- Não afeta service-linked roles
- Usa mesma sintaxe JSON de IAM policies

### Hierarquia de aplicação

```
         Management Account (não afetada por SCPs)
                    │
            ┌───────┴───────┐
            ▼               ▼
     OU: Produção       OU: Dev
     SCP: Deny          SCP: Allow *
     delete em RDS      (exceto: Deny
            │            OrganizationLeave)
     ┌──────┴──────┐         │
     ▼             ▼         ▼
  Conta A       Conta B    Conta C
  (herda SCP    (herda SCP  (herda SCP
   da OU)        da OU)     da OU Dev)
```

### Estratégias de SCP

| Estratégia | Descrição | Quando usar |
|------------|-----------|-------------|
| **Allow List** | Deny tudo, Allow explícito | Controle estrito, ambientes regulados |
| **Deny List** | Allow tudo (default), Deny específico | Mais flexível, bloquear ações perigosas |

### Exemplo: Deny List — impedir desabilitar CloudTrail

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ProtectCloudTrail",
      "Effect": "Deny",
      "Action": [
        "cloudtrail:StopLogging",
        "cloudtrail:DeleteTrail"
      ],
      "Resource": "*"
    }
  ]
}
```

### Exemplo: restringir regiões permitidas

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyOutsideAllowedRegions",
      "Effect": "Deny",
      "NotAction": [
        "iam:*",
        "organizations:*",
        "support:*",
        "sts:*"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": ["us-east-1", "eu-west-1"]
        }
      }
    }
  ]
}
```

> ⚠️ `NotAction` exclui serviços globais (IAM, STS, Organizations) que precisam funcionar independente da região.


---

## 11. IAM Identity Center (antigo AWS SSO)

> Ponto centralizado para gerenciar acesso a **múltiplas contas AWS** e **aplicações de negócio**.

### Características

- Integra com AWS Organizations (acesso multi-account)
- Suporta Identity Providers: Built-in, Active Directory, Okta, Azure AD
- Login único (SSO) para Console AWS e aplicações SAML 2.0
- **Permission Sets** definem o que o usuário pode fazer em cada conta
- Atribui Permission Sets a Users/Groups por conta/OU

### Arquitetura

```
┌─────────────────────────────────────────────────────────────────┐
│                    IAM Identity Center                           │
│                                                                 │
│  Identity Source:         Permission Sets:                      │
│  ┌─────────────────┐     ┌─────────────────────────────────┐   │
│  │ AD / Okta /     │     │ AdministratorAccess → Conta Prod │   │
│  │ Built-in        │     │ ReadOnlyAccess → Conta Dev       │   │
│  │                 │     │ CustomDevOps → Conta Staging     │   │
│  └─────────────────┘     └─────────────────────────────────┘   │
│                                                                 │
│  Assignments:                                                   │
│  User "João" + PermSet "Admin" → Conta Produção                │
│  Group "Devs" + PermSet "ReadOnly" → Conta Dev                 │
└─────────────────────────────────────────────────────────────────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
         Conta Prod   Conta Dev    Conta Staging
```

### Permission Sets vs IAM Policies

| Aspecto | Permission Set | IAM Policy |
|---------|---------------|------------|
| Escopo | Multi-account (via Identity Center) | Conta individual |
| Criação | No Identity Center | No IAM de cada conta |
| Resultado | Cria Role automaticamente na conta destino | Policy anexada manualmente |
| Duração | Sessão temporária (1h–12h) | Permanente (User) ou temporária (Role) |

### Quando usar na prova

- "Gerenciar acesso centralizado para múltiplas contas" → **IAM Identity Center**
- "SSO para console AWS" → **IAM Identity Center**
- "Funcionários da empresa acessarem várias contas" → **IAM Identity Center**
- "Integrar Active Directory com AWS" → **IAM Identity Center** (ou AD Connector)

---

## 12. Ferramentas de Auditoria e Análise

| Ferramenta | O que faz | Quando usar |
|------------|-----------|-------------|
| **IAM Access Analyzer** | Identifica recursos compartilhados com entidades externas | Encontrar buckets S3, roles, KMS keys expostas |
| **IAM Credentials Report** | CSV com status de todos os Users (senha, keys, MFA) | Auditoria de compliance, encontrar keys antigas |
| **Access Advisor** | Mostra últimos acessos de cada serviço por entidade | Identificar permissões não usadas (least privilege) |
| **CloudTrail** | Log de todas as chamadas API | Investigar quem fez o quê e quando |
| **IAM Policy Simulator** | Testa policies sem aplicar | Debugging de permissões |
| **Organizations - Policy Changes** | Histórico de mudanças em SCPs | Auditoria de guardrails |

### IAM Access Analyzer — detalhes

- Analisa **Zone of Trust** (sua conta ou Organization)
- Gera **findings** para recursos acessíveis de fora da zona
- Tipos de recurso analisados: S3, IAM Roles, KMS, Lambda, SQS, Secrets Manager
- Pode **gerar policies** baseadas em atividade real (CloudTrail)
- Pode **validar policies** antes de aplicar

### IAM Credentials Report

```
Gera CSV com colunas:
- user
- arn
- password_enabled / password_last_used
- access_key_1_active / access_key_1_last_rotated
- access_key_2_active / access_key_2_last_rotated  
- mfa_active
- password_last_changed
```

> 📝 **Na prova:** "Auditar quais usuários não rotacionaram keys" → **Credentials Report**

---

## 13. Boas Práticas (Best Practices)

### Segurança do Root Account

- ✅ Ativar MFA no root (hardware MFA preferível)
- ✅ Não criar Access Keys para root
- ✅ Usar root APENAS para tarefas que exigem root
- ✅ Criar um IAM User admin para uso diário

### Princípio do Menor Privilégio

- ✅ Começar com zero permissões e adicionar conforme necessário
- ✅ Usar **Access Advisor** para identificar permissões não usadas
- ✅ Usar **IAM Access Analyzer** para gerar policies mínimas
- ✅ Revisar e remover permissões regularmente

### Credenciais e Access Keys

- ✅ Usar Roles para serviços AWS (EC2, Lambda, ECS) — nunca Access Keys
- ✅ Rotacionar Access Keys a cada 90 dias
- ✅ Usar credenciais temporárias (STS) sempre que possível
- ✅ Nunca compartilhar credenciais ou embutir em código

### Organizacional

- ✅ Usar Groups para atribuir permissões (não inline em Users)
- ✅ Usar AWS Organizations + SCPs para guardrails
- ✅ Usar IAM Identity Center para multi-account
- ✅ Usar Permission Boundaries para delegar criação de Users/Roles
- ✅ Ativar CloudTrail em todas as regiões
- ✅ Usar tags para controle de acesso (ABAC)

---

## 14. ABAC — Attribute-Based Access Control

> Controle de acesso baseado em **tags** (atributos) ao invés de ARNs explícitos.

### Exemplo: permitir acesso apenas a recursos com mesma tag de projeto

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:*",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "ec2:ResourceTag/Project": "${aws:PrincipalTag/Project}"
        }
      }
    }
  ]
}
```

**Vantagem:** Não precisa atualizar policies quando novos recursos são criados — basta ter a tag correta.

---

## 15. Palavras-chave da Prova SAA-C03

| Cenário na prova | Resposta |
|-----------------|----------|
| "Acesso cross-account a S3 mantendo permissões originais" | Resource-based policy (bucket policy) |
| "Acesso cross-account precisando assumir role" | IAM Role + Trust Policy + sts:AssumeRole |
| "EC2 precisa acessar S3" | IAM Role + Instance Profile |
| "Limitar o que roles criadas por devs podem fazer" | Permission Boundary |
| "Impedir contas de usar certas regiões" | SCP com Deny + Condition RequestedRegion |
| "Login centralizado para múltiplas contas" | IAM Identity Center |
| "Federar usuários corporativos (AD)" | IAM Identity Center ou SAML 2.0 Federation |
| "Auditar permissões não usadas" | Access Advisor |
| "Encontrar recursos expostos externamente" | IAM Access Analyzer |
| "Verificar status de MFA e keys de todos os users" | IAM Credentials Report |
| "Proteger operação com MFA" | Condition `aws:MultiFactorAuthPresent` |
| "Credenciais temporárias para app mobile" | Cognito + STS AssumeRoleWithWebIdentity |
| "Exigir criptografia em uploads S3" | Condition `s3:x-amz-server-side-encryption` |
| "Aplicação no EC2 precisa credenciais" | Instance Profile (nunca Access Keys) |
| "Permitir acesso apenas da VPC" | Condition `aws:SourceVpc` ou VPC Endpoint policy |
| "Delegar criação de Users sem escalar privilégios" | Permission Boundary obrigatória via Condition |
| "Bloquear ações perigosas em toda a organização" | SCP Deny List |
| "Acesso baseado em tags" | ABAC com PrincipalTag/ResourceTag |

---

## 16. Resumo Visual — Hierarquia de Controle

```
┌─────────────────────────────────────────────────────────────────┐
│                     AWS Organization                             │
│                                                                 │
│  ┌────── SCPs ──────┐     (guardrails para contas)              │
│  │                  │                                           │
│  │  ┌── Permission Boundary ──┐   (teto para entidades)        │
│  │  │                         │                                 │
│  │  │  ┌── Identity Policy ──┐│                                 │
│  │  │  │                     ││                                 │
│  │  │  │  ACESSO EFETIVO =   ││                                 │
│  │  │  │  SCP ∩ Boundary ∩   ││                                 │
│  │  │  │  Identity Policy    ││                                 │
│  │  │  │                     ││                                 │
│  │  │  └─────────────────────┘│                                 │
│  │  └─────────────────────────┘                                 │
│  └──────────────────┘                                           │
└─────────────────────────────────────────────────────────────────┘
```

> 🎯 **Acesso efetivo** = SCP ∩ Permission Boundary ∩ Session Policy ∩ (Identity-based ∪ Resource-based) — sem Deny explícito.

