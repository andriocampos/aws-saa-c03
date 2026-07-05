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

