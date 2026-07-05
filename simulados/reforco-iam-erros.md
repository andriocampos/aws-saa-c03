# IAM — Material de Reforço (Baseado nos Erros do Quiz)

> Este material aprofunda os 3 tópicos onde você errou. Leia com calma e releia antes do próximo simulado.

---

## 1. Federação e IAM Identity Center — Quem faz o quê?

### O problema: existem MUITAS formas de federar. Qual usar quando?

Pense assim — existem 3 "mundos" de usuários que querem acessar a AWS:

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  MUNDO 1: Funcionários da empresa (AD, Okta, Azure AD)          │
│  → IAM Identity Center (SSO)                                   │
│                                                                 │
│  MUNDO 2: Usuários de app (Google, Facebook, login próprio)     │
│  → Cognito (que usa AssumeRoleWithWebIdentity por baixo)       │
│                                                                 │
│  MUNDO 3: Sistemas legados com SAML 2.0 já configurado         │
│  → AssumeRoleWithSAML (direto, sem Cognito)                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Tabela de decisão definitiva

| Cenário na prova | Resposta CORRETA | Por que NÃO as outras |
|-----------------|------------------|----------------------|
| "Funcionários com AD querem SSO no Console" | **IAM Identity Center** | Directory Service só gerencia o AD, não faz SSO |
| "SSO para múltiplas contas AWS" | **IAM Identity Center** | Cognito é para apps, não para Console multi-account |
| "App mobile com login Google/Facebook" | **Cognito Identity Pools** (usa WebIdentity) | Identity Center é para funcionários, não clientes |
| "Sistema corporativo com SAML 2.0 já existente" | **AssumeRoleWithSAML** ou **Identity Center** | WebIdentity é para IdPs web (Google, etc.) |
| "Milhões de usuários do app precisam de credenciais AWS temporárias" | **Cognito Identity Pools** | Identity Center não escala para milhões de clientes |

### IAM Identity Center — Como funciona (passo a passo)

```
┌──────────────────────────────────────────────────────────────────┐
│                    IAM IDENTITY CENTER                            │
│                                                                  │
│  1. Conecta a um Identity Source:                                │
│     • Built-in directory (users no próprio Identity Center)      │
│     • Active Directory (AWS Managed AD ou AD Connector)          │
│     • External IdP (Okta, Azure AD, etc. via SAML/SCIM)         │
│                                                                  │
│  2. Cria Permission Sets:                                        │
│     • São "pacotes de permissões" (como templates de IAM Policy) │
│     • Ex: "AdministratorAccess", "ReadOnly", "DevOpsAccess"     │
│                                                                  │
│  3. Atribui: User/Group + Permission Set → Conta AWS            │
│     • "Time Backend + DevOpsAccess → Conta Produção"            │
│     • "Time QA + ReadOnly → Conta Staging"                      │
│                                                                  │
│  4. Resultado: Para cada atribuição, Identity Center CRIA        │
│     automaticamente uma IAM ROLE na conta destino                │
│     O usuário ASSUME essa role temporariamente ao fazer login    │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### Por que Permission Set = Role (sua questão 29)

```
Você cria:  Permission Set "DevAccess" para User "João" na Conta 123

Identity Center faz por baixo:
  → Cria Role "AWSReservedSSO_DevAccess_abc123" na Conta 123
  → Trust Policy permite Identity Center assumir essa Role
  → Permission Policy = o que você definiu no Permission Set

Quando João faz login:
  → Identity Center chama sts:AssumeRole nessa Role
  → João recebe credenciais TEMPORÁRIAS
  → Sessão expira (1h-12h configurável)
```

**Memorize:** Permission Set → cria Role → User assume Role temporariamente.

### AssumeRoleWithWebIdentity vs Cognito (sua questão 7)

```
DIRETO (não recomendado pela AWS):
  App → Google Sign-In → token → AssumeRoleWithWebIdentity → creds AWS

VIA COGNITO (recomendado):
  App → Google Sign-In → Cognito Identity Pool → credenciais AWS
  
  (Cognito chama AssumeRoleWithWebIdentity por baixo,
   mas adiciona: unauthenticated access, sync, analytics)
```

**Na prova:** Se a resposta tem "Cognito" E "AssumeRoleWithWebIdentity", escolha Cognito.
Se só tem "AssumeRoleWithWebIdentity" sem Cognito como opção, aí sim é a correta.

### AWS Directory Service — NÃO é SSO!

| Serviço | O que faz | NÃO faz |
|---------|-----------|---------|
| **AWS Managed AD** | Roda AD completo na AWS | ❌ Não faz SSO sozinho |
| **AD Connector** | Proxy para AD on-premises | ❌ Não faz SSO sozinho |
| **Simple AD** | AD básico para apps simples | ❌ Não faz SSO sozinho |
| **IAM Identity Center** | SSO + gerenciamento de acesso | ✅ FAZ SSO! |

**Regra:** Directory Service gerencia o DIRETÓRIO. Identity Center gerencia o ACESSO/SSO.
Para SSO no Console → sempre **Identity Center** (que INTEGRA com Directory Service).


---

## 2. Ferramentas de Auditoria — A Trinca que Confunde

### O problema: Access Advisor vs Access Analyzer vs Credentials Report

Esses três nomes são parecidos e a prova ADORA trocar um pelo outro. Decore assim:

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  📊 CREDENTIALS REPORT                                          │
│  Pergunta: "Qual o STATUS das credenciais de todos os Users?"   │
│  Formato: CSV (planilha) com TODOS os users                     │
│  Dados: senha ativa?, key ativa?, MFA ativo?, última rotação?   │
│  Use case: "Auditoria geral", "quem não tem MFA?",            │
│            "quem não rotacionou keys em 90 dias?"               │
│                                                                 │
│  Analogia: RELATÓRIO DO RH — lista todo mundo e seu status      │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  👁️ ACCESS ADVISOR                                              │
│  Pergunta: "Quais serviços esse User/Role REALMENTE usou?"      │
│  Formato: Lista de serviços + data do último acesso             │
│  Dados: "S3 usado há 2 dias", "RDS nunca usado"                │
│  Use case: "Aplicar least privilege", "remover permissões       │
│            que não estão sendo usadas"                           │
│                                                                 │
│  Analogia: HISTÓRICO DE NAVEGAÇÃO — mostra onde você foi        │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  🔍 ACCESS ANALYZER                                             │
│  Pergunta: "Algum recurso meu está EXPOSTO para fora?"          │
│  Formato: Findings (alertas) por recurso exposto                │
│  Dados: "Bucket X acessível pela Conta 999",                    │
│         "Role Y pode ser assumida por qualquer um"              │
│  Use case: "Encontrar recursos expostos externamente",          │
│            "gerar policies mínimas baseadas em uso real"         │
│                                                                 │
│  Analogia: ALARME DE SEGURANÇA — avisa se deixou porta aberta   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Tabela comparativa rápida

| | Credentials Report | Access Advisor | Access Analyzer |
|-|:--:|:--:|:--:|
| **Escopo** | TODOS os Users da conta | UM User/Role/Group | Recursos da conta/org |
| **O que mostra** | Status de credenciais | Último acesso por serviço | Recursos expostos externamente |
| **Formato** | CSV para download | Tab no console por entidade | Findings (alertas) |
| **Pergunta** | "Credenciais estão seguras?" | "Permissão está sendo usada?" | "Algo está exposto?" |

### Cheat sheet para a prova

| Pergunta na prova | Ferramenta |
|-------------------|------------|
| "Quais users não têm MFA?" | **Credentials Report** |
| "Quais users não rotacionaram keys?" | **Credentials Report** |
| "Quais permissões não estão sendo usadas?" | **Access Advisor** |
| "Aplicar princípio do menor privilégio" | **Access Advisor** |
| "Bucket S3 está acessível de fora da conta?" | **Access Analyzer** |
| "Gerar policy baseada em atividade real" | **Access Analyzer** |
| "Role pode ser assumida por conta externa?" | **Access Analyzer** |

### Access Analyzer — Mais detalhes (sua questão 22)

O Access Analyzer tem uma "Zona de Confiança":
- Se zona = sua **conta** → alerta quando recurso é acessível por QUALQUER outra conta
- Se zona = sua **Organization** → alerta quando recurso é acessível por contas FORA da org

**Finding NÃO significa erro de sintaxe!** Significa: "este recurso está acessível por alguém de fora."

Recursos analisados: S3, IAM Roles, KMS, Lambda, SQS, Secrets Manager, SNS, EBS Snapshots, RDS Snapshots, ECR


---

## 3. STS — Detalhes que Caem na Prova

### Durações das credenciais (sua questão 19)

| API | Duração PADRÃO | Mínimo | Máximo |
|-----|:--------------:|:------:|:------:|
| `AssumeRole` | **1 hora** | 15 min | 12 horas* |
| `AssumeRoleWithWebIdentity` | **1 hora** | 15 min | 12 horas* |
| `AssumeRoleWithSAML` | **1 hora** | 15 min | 12 horas* |
| `GetSessionToken` | **12 horas** | 15 min | 36 horas |
| `GetFederationToken` | **12 horas** | 15 min | 36 horas |

*MaxSessionDuration configurável na Role (padrão 1h, máx 12h)

**Memorize:** AssumeRole* = **1 hora**. GetSession/GetFederation = **12 horas**.

### Dica mnemônica

```
AssumeRole = "visita rápida" → 1 hora (padrão)
GetSessionToken = "dia inteiro de trabalho" → 12 horas (padrão)
```

---

## 4. Conditions Avançadas — aws:PrincipalOrgID

### O que é (sua questão 27)

`aws:PrincipalOrgID` é a Condition Key que verifica se quem está fazendo a requisição pertence à sua Organization.

### Por que é útil?

**Problema:** Você tem 50 contas na Organization e quer que um bucket S3 seja acessível por TODAS elas.

**Sem PrincipalOrgID (trabalhoso):**
```json
"Principal": {
  "AWS": [
    "arn:aws:iam::111111111111:root",
    "arn:aws:iam::222222222222:root",
    "arn:aws:iam::333333333333:root"
    // ... mais 47 contas
  ]
}
```
→ Toda vez que criar conta nova, tem que atualizar a policy!

**Com PrincipalOrgID (elegante):**
```json
{
  "Effect": "Allow",
  "Principal": "*",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::shared-bucket/*",
  "Condition": {
    "StringEquals": {
      "aws:PrincipalOrgID": "o-abc123def4"
    }
  }
}
```
→ QUALQUER conta da Organization pode acessar. Adicionou conta nova? Já tem acesso!

### Principal: "*" NÃO é perigoso com PrincipalOrgID

```
Principal: "*"  SEM Condition  → ❌ MUNDO INTEIRO pode acessar (PERIGO!)
Principal: "*"  COM PrincipalOrgID → ✅ Só sua Organization pode (SEGURO!)
```

**Na prova:** Se vir `Principal: "*"` com `Condition aws:PrincipalOrgID`, é um pattern VÁLIDO e seguro.

---

## 5. Resumo dos Erros — Flashcards para Decorar

Leia em voz alta 3 vezes cada um:

```
❌ ERREI: "App mobile com Google → AssumeRoleWithSAML"
✅ CERTO: "App mobile com Google → Cognito (que usa WebIdentity por baixo)"
   REGRA: SAML = corporativo (AD). Web Identity = social (Google, Facebook).

❌ ERREI: "AD + SSO Console → Simple AD"
✅ CERTO: "AD + SSO Console → IAM Identity Center"
   REGRA: Directory Service = gerencia AD. Identity Center = FAZ o SSO.

❌ ERREI: "AssumeRole dura 15 minutos"
✅ CERTO: "AssumeRole dura 1 HORA (padrão)"
   REGRA: 15 min é o MÍNIMO. 1 hora é o PADRÃO.

❌ ERREI: "Access Analyzer encontra erros de sintaxe"
✅ CERTO: "Access Analyzer encontra recursos EXPOSTOS externamente"
   REGRA: Analyzer = portas abertas. Advisor = permissões não usadas.

❌ ERREI: "Credentials Report mostra recursos acessados"
✅ CERTO: "Credentials Report mostra STATUS de credenciais (CSV de todos users)"
   REGRA: Report = status. Advisor = último acesso. Analyzer = exposição.

❌ ERREI: "Principal: * sem Condition serve para toda a Organization"
✅ CERTO: "Principal: * + Condition aws:PrincipalOrgID = acesso para a Org"
   REGRA: PrincipalOrgID é o filtro que torna Principal:* seguro.

❌ ERREI: "Permission Set cria policy na Management Account"
✅ CERTO: "Permission Set cria IAM ROLE na conta destino"
   REGRA: Identity Center = cria Roles automaticamente por conta.
```

---

## 6. Plano de Ação

1. **Releia esta página** amanhã de manhã (espaçamento ajuda a fixar)
2. **Foque nos flashcards** da seção 5 (os ❌/✅)
3. **Refaça o quiz em 3 dias** — meta: 90%+ (27/30)


---

## 7. SCPs — Service Control Policies (Aprofundamento)

### O que é um SCP?

Um SCP é uma **cerca ao redor de uma conta inteira**. Ele define o MÁXIMO que qualquer pessoa dentro daquela conta pode fazer — inclusive o root.

### Analogia: Regras do Condomínio (expandida)

```
Prédio (Organization)
├── Bloco A (OU: Produção)
│   ├── Apto 101 (Conta Prod-1) ← regras do Bloco A se aplicam
│   └── Apto 102 (Conta Prod-2) ← regras do Bloco A se aplicam
├── Bloco B (OU: Desenvolvimento)
│   └── Apto 201 (Conta Dev-1)  ← regras do Bloco B se aplicam
└── Portaria (Management Account) ← NÃO segue regras, apenas APLICA

Regra do Bloco A: "Proibido fogos de artifício" (Deny cloudtrail:Delete*)
→ Morador do 101 com PhD em pirotecnia (AdministratorAccess)?
   Não importa. A REGRA DO BLOCO proíbe. Ponto final.

Porteiro (Management Account)?
→ Pode fazer fogos. Regras do condomínio não se aplicam a ele.
```

### Herança de SCPs

```
                    ┌─────────────────┐
                    │   Root OU       │
                    │   SCP: Allow *  │ ← FullAWSAccess (padrão)
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼                             ▼
   ┌──────────────────┐         ┌──────────────────┐
   │  OU: Produção    │         │  OU: Dev         │
   │  SCP: Deny       │         │  SCP: Deny       │
   │  ec2:Terminate*  │         │  organizations:  │
   │  em prod         │         │  LeaveOrg        │
   └────────┬─────────┘         └────────┬─────────┘
            │                             │
            ▼                             ▼
   ┌──────────────────┐         ┌──────────────────┐
   │  Conta Prod-1    │         │  Conta Dev-1     │
   │                  │         │                  │
   │  EFETIVO:        │         │  EFETIVO:        │
   │  Tudo EXCETO     │         │  Tudo EXCETO     │
   │  ec2:Terminate   │         │  LeaveOrg        │
   └──────────────────┘         └──────────────────┘

A conta herda SCPs de TODAS as OUs acima dela (intersecção).
```

### Pontos que CAEM na prova

| Afirmação | Verdadeiro? |
|-----------|:-----------:|
| SCP afeta a Management Account | ❌ NUNCA |
| SCP afeta o root de contas-membro | ✅ SIM |
| SCP concede permissões | ❌ Apenas restringe |
| SCP afeta service-linked roles | ❌ NÃO afeta |
| SCP precisa de Allow para funcionar | ✅ Se remover o FullAWSAccess padrão, nada funciona |
| SCP é avaliado ANTES da identity policy | ✅ Se SCP nega, identity Allow não salva |

### Estratégia Deny List (mais comum — 90% dos casos)

**Como funciona:** Mantém o `FullAWSAccess` (Allow *) e adiciona Denys específicos.

```json
// SCP 1 — já existe por padrão
{
  "Effect": "Allow",
  "Action": "*",
  "Resource": "*"
}

// SCP 2 — você adiciona
{
  "Effect": "Deny",
  "Action": [
    "cloudtrail:StopLogging",
    "cloudtrail:DeleteTrail",
    "config:StopConfigurationRecorder"
  ],
  "Resource": "*"
}
```

**Resultado:** Pode tudo, EXCETO desligar CloudTrail e Config.

### Estratégia Allow List (raro — ambientes ultra-restritivos)

**Como funciona:** REMOVE o `FullAWSAccess` e só permite serviços específicos.

```json
// Remove o FullAWSAccess padrão e coloca:
{
  "Effect": "Allow",
  "Action": [
    "ec2:*",
    "s3:*",
    "rds:*",
    "cloudwatch:*"
  ],
  "Resource": "*"
}
```

**Resultado:** Só pode usar EC2, S3, RDS e CloudWatch. TODO o resto está bloqueado.

### SCP para restringir regiões (exemplo clássico da prova)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "NotAction": [
        "iam:*",
        "organizations:*",
        "support:*",
        "sts:*",
        "budgets:*"
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

**Tradução linha por linha:**
- `Deny` → bloqueia
- `NotAction: iam, organizations, sts...` → EXCETO esses serviços globais (precisam funcionar em qualquer região)
- `Condition: StringNotEquals: us-east-1, eu-west-1` → quando a região NÃO for us-east-1 ou eu-west-1

**Resultado:** Ninguém na conta pode criar recursos fora de us-east-1 e eu-west-1, mas IAM/STS/Organizations continuam funcionando (são globais).

> ⚠️ `NotAction` é a chave aqui. Se usasse `Action: "*"` com Deny, bloquearia até IAM e STS, quebrando tudo.

---

## 8. ABAC — Attribute-Based Access Control (Aprofundamento)

### O que é?

ABAC é uma forma de controlar acesso usando **tags** em vez de listar ARNs explícitos.

### Analogia: Pulseiras em Festival

```
RBAC (tradicional — por cargo):
  "Segurança pode acessar backstage, camarins e palco"
  "Público pode acessar área geral"
  → Cada novo espaço precisa atualizar a regra de cada grupo

ABAC (por atributo — por pulseira):
  "Pulseira VERMELHA acessa qualquer área com tag cor=vermelho"
  "Pulseira AZUL acessa qualquer área com tag cor=azul"
  → Criou área nova com tag cor=vermelho? Quem tem pulseira vermelha já entra!
```

### RBAC vs ABAC

| Aspecto | RBAC (Role-Based) | ABAC (Attribute-Based) |
|---------|:--:|:--:|
| **Como define acesso** | Por ARN do recurso | Por tag do recurso + tag do principal |
| **Criar recurso novo** | Atualizar policy manualmente | Já funciona se tag estiver correta |
| **Escalabilidade** | Mais policies conforme cresce | Mesma policy serve para tudo |
| **Granularidade** | Por recurso individual | Por atributo/grupo lógico |
| **Complexidade** | Simples de entender | Precisa disciplina de tagging |

### Como funciona na prática

**Cenário:** 3 times (backend, frontend, data) com EC2 instances cada. Cada time só deve acessar SUAS instâncias.

**Sem ABAC (3 policies diferentes):**
```json
// Policy do time backend
{"Action": "ec2:*", "Resource": "arn:aws:ec2:*:*:instance/i-backend1"}
// Policy do time frontend
{"Action": "ec2:*", "Resource": "arn:aws:ec2:*:*:instance/i-frontend1"}
// Policy do time data
{"Action": "ec2:*", "Resource": "arn:aws:ec2:*:*:instance/i-data1"}
```
→ Cada nova instância = atualizar policy. 100 instâncias = 100 ARNs. Pesadelo.

**Com ABAC (1 policy para TODOS):**
```json
{
  "Effect": "Allow",
  "Action": "ec2:*",
  "Resource": "*",
  "Condition": {
    "StringEquals": {
      "ec2:ResourceTag/Team": "${aws:PrincipalTag/Team}"
    }
  }
}
```
→ **UMA policy.** Serve para backend, frontend, data, e qualquer time futuro!

**Como funciona:**
```
User "João" tem tag Team=backend
Instance "i-abc" tem tag Team=backend
→ João acessa i-abc? ✅ SIM (tags combinam)

Instance "i-xyz" tem tag Team=frontend
→ João acessa i-xyz? ❌ NÃO (tags não combinam)
```

### Tags usadas no ABAC

| Condition Key | Onde a tag está | Exemplo |
|---------------|:---:|---------|
| `aws:PrincipalTag/Team` | No User ou Role | Tag do "quem está pedindo" |
| `ec2:ResourceTag/Team` | Na instância EC2 | Tag do "recurso sendo acessado" |
| `s3:ResourceTag/Project` | No bucket/objeto S3 | Tag do recurso S3 |
| `aws:RequestTag/Team` | Na requisição (ao criar recurso) | Tag sendo aplicada agora |
| `aws:TagKeys` | Na requisição | Quais chaves de tag estão sendo passadas |

### Exemplo completo: ABAC com proteção de tags

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowActionsOnOwnResources",
      "Effect": "Allow",
      "Action": ["ec2:StartInstances", "ec2:StopInstances", "ec2:RebootInstances"],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "ec2:ResourceTag/Team": "${aws:PrincipalTag/Team}"
        }
      }
    },
    {
      "Sid": "DenyTagModification",
      "Effect": "Deny",
      "Action": ["ec2:CreateTags", "ec2:DeleteTags"],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:ResourceTag/Team": "${aws:PrincipalTag/Team}"
        }
      }
    }
  ]
}
```

**O que faz:**
1. Permite start/stop/reboot APENAS em instances com mesma tag Team
2. IMPEDE que o próprio user mude a tag Team (senão ele poderia "se promover")

### Quando usar ABAC na prova

| Cenário | ABAC é a resposta? |
|---------|:--:|
| "Múltiplos times precisam acessar apenas seus próprios recursos" | ✅ |
| "Escalar permissões sem atualizar policies a cada novo recurso" | ✅ |
| "Controle de acesso baseado em projeto/departamento/ambiente" | ✅ |
| "Um user específico precisa acessar um bucket específico" | ❌ (RBAC é mais simples) |
| "Todos os devs precisam de read-only em tudo" | ❌ (RBAC — um group com policy) |

### Pré-requisitos para ABAC funcionar

1. **Tags nos principals** — Users/Roles devem ter tags (ex: `Team=backend`)
2. **Tags nos recursos** — EC2, S3, RDS etc. devem ter tags correspondentes
3. **Policy com Condition** — Comparar `PrincipalTag` com `ResourceTag`
4. **Proteção de tags** — Impedir que users mudem suas próprias tags (senão escapam do controle)

### Vantagem principal (memorize para a prova)

> ABAC **escala sem atualizar policies**. Criou recurso novo com tag correta? Acesso já funciona automaticamente. Criou time novo com tag? Mesma policy serve.

