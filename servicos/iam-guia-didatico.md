# IAM — Guia Didático com Analogias

> Este guia explica os conceitos mais confusos do IAM usando analogias do mundo real e exemplos simples.

---

## 1. Lógica de Avaliação de Policies

### Analogia: O Segurança do Prédio

Imagine que você quer entrar numa sala de um prédio corporativo. O processo de decisão é:

```
Você chega na porta da sala...

1. LISTA NEGRA (Deny explícito)
   O segurança olha a lista negra primeiro.
   → Seu nome está na lista negra? SIM → "Volta pra casa." (FIM)
   → NÃO → próximo passo

2. AUTORIZAÇÃO DA EMPRESA (SCP)
   "Esse departamento tem permissão de acessar este andar?"
   → NÃO → "Seu departamento inteiro está bloqueado." (FIM)
   → SIM → próximo passo

3. LIMITE DO SEU CRACHÁ (Permission Boundary)
   "Seu crachá tem nível de acesso suficiente?"
   → NÃO → "Seu crachá não permite." (FIM)
   → SIM → próximo passo

4. PERMISSÃO INDIVIDUAL (Identity-based ou Resource-based)
   "Você tem autorização específica pra essa sala?"
   → SIM → ✅ "Pode entrar!"
   → NÃO → "Ninguém te autorizou." (FIM)
```

### Regras em português simples

| Regra | Analogia |
|-------|----------|
| Deny SEMPRE vence | Se alguém disse "NÃO", não importa quantos disseram "SIM" |
| Tudo é negado por padrão | Portas trancadas por padrão — você precisa de uma chave |
| Precisa de Allow explícito | Alguém tem que te dar a chave ativamente |

### Exemplo prático: por que Deny vence

```
Situação: João é desenvolvedor

Policy 1 (no grupo "Devs"):     "Allow s3:*"        → pode tudo no S3
Policy 2 (no grupo "Segurança"): "Deny s3:DeleteBucket" → não pode deletar buckets

Resultado: João pode ler, escrever no S3... mas NÃO pode deletar buckets.
O Deny da Policy 2 vence o Allow da Policy 1. Sempre.
```

### Exemplo prático: deny implícito

```
Situação: Maria acabou de ser criada como IAM User

Nenhuma policy foi anexada a ela.

Maria tenta: aws s3 ls
Resultado: ❌ Access Denied

Por quê? Deny IMPLÍCITO. Ninguém disse "Allow" pra ela.
Não precisa de Deny explícito — a ausência de Allow já é um NÃO.
```

---

## 2. Identity-based vs Resource-based Policies

### Analogia: Convite para Festa

**Identity-based policy** = você recebe um convite no seu bolso que diz onde pode ir.
- "João pode entrar nas festas do Clube A e Clube B"
- O convite está COM VOCÊ (na sua identidade)

**Resource-based policy** = a porta da festa tem uma lista de convidados.
- "Pessoas permitidas nesta festa: João, Maria, Pedro"
- A lista está NA PORTA (no recurso)

### Por que isso importa? Cross-account!

```
┌─ CONTA A (sua empresa) ──────────────────────────────────────┐
│                                                               │
│  João quer acessar um bucket S3 na Conta B                   │
│                                                               │
│  OPÇÃO 1: Identity-based (AssumeRole)                        │
│  ─────────────────────────────────────                       │
│  João assume uma Role na Conta B.                            │
│  É como se ele "vestisse um uniforme" da Conta B.            │
│  ⚠️  Enquanto usa o uniforme, PERDE o acesso da Conta A!    │
│                                                               │
│  OPÇÃO 2: Resource-based (Bucket Policy)                     │
│  ─────────────────────────────────────────                   │
│  O bucket na Conta B tem na lista: "João da Conta A pode."   │
│  João acessa o bucket DIRETO, sem trocar de roupa.           │
│  ✅ Mantém acesso à Conta A E acessa o bucket na Conta B!   │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

### Quando usar cada um na prova?

| Cenário | Resposta |
|---------|----------|
| "Precisa acessar recurso cross-account E manter permissões da conta original" | **Resource-based** |
| "Precisa assumir permissões completamente diferentes na outra conta" | **AssumeRole (Identity-based)** |
| "Lambda na Conta A precisa ser invocada por SNS na Conta B" | **Resource-based** (Lambda resource policy) |
| "EC2 na Conta A precisa acessar DynamoDB na Conta B" | **AssumeRole** (DynamoDB não tem resource policy) |

### Quais serviços suportam Resource-based?

Pense assim: os serviços "grandes e compartilháveis" têm resource policy:
- **S3** (bucket policy) — o mais comum na prova
- **SQS** (queue policy)
- **SNS** (topic policy)
- **Lambda** (function policy)
- **KMS** (key policy)
- **ECR, Secrets Manager, API Gateway**

> 💡 **Dica:** Se o serviço NÃO tem resource-based policy (como DynamoDB, EC2, CloudWatch), a única forma de cross-account é via **AssumeRole**.


---

## 3. Trust Policy vs Permission Policy

### Analogia: Carro de Aluguel

Pense numa Role como um **carro de aluguel**:

- **Trust Policy** = "QUEM pode alugar este carro?"
  - Só maiores de 21 anos com CNH válida (→ só EC2, ou só a Conta 123456)
  - Está escrita no **contrato da locadora** (no recurso = na Role)

- **Permission Policy** = "O QUE o carro pode fazer?"
  - Pode andar na cidade, mas não pode sair do estado (→ pode s3:GetObject, mas não s3:DeleteObject)
  - Está no **manual de regras do carro** (anexada à Role)

### Exemplo visual

```
                    IAM ROLE "BackendRole"
        ┌─────────────────────────────────────────────┐
        │                                             │
        │  🔑 TRUST POLICY (quem pode assumir?)       │
        │  ┌─────────────────────────────────────┐    │
        │  │ "Principal": {                      │    │
        │  │   "Service": "ec2.amazonaws.com"    │    │
        │  │ }                                   │    │
        │  │                                     │    │
        │  │ Tradução: "Só instâncias EC2        │    │
        │  │ podem usar esta Role"               │    │
        │  └─────────────────────────────────────┘    │
        │                                             │
        │  📋 PERMISSION POLICY (o que pode fazer?)   │
        │  ┌─────────────────────────────────────┐    │
        │  │ "Action": "s3:GetObject"            │    │
        │  │ "Resource": "arn:...:app-bucket/*"  │    │
        │  │                                     │    │
        │  │ Tradução: "Quem usar esta Role      │    │
        │  │ pode ler objetos do app-bucket"     │    │
        │  └─────────────────────────────────────┘    │
        │                                             │
        └─────────────────────────────────────────────┘
```

### Em linguagem humana

| Pergunta | Quem responde | Exemplo |
|----------|---------------|---------|
| "Quem pode usar esta role?" | Trust Policy | "Só Lambda" ou "Só a Conta 999" |
| "O que quem usar esta role pode fazer?" | Permission Policy | "Pode ler S3 e escrever DynamoDB" |

### Principals comuns em Trust Policies

```json
// Serviço AWS (EC2, Lambda, ECS...)
"Principal": { "Service": "lambda.amazonaws.com" }

// Outra conta AWS (cross-account)
"Principal": { "AWS": "arn:aws:iam::111111111111:root" }

// Usuário específico de outra conta
"Principal": { "AWS": "arn:aws:iam::111111111111:user/joao" }

// Identity Provider (SAML, Cognito)
"Principal": { "Federated": "cognito-identity.amazonaws.com" }
```

---

## 4. STS e Cross-Account — Passo a Passo

### Analogia: Cartão de Visitante

Imagine que você trabalha no **Prédio A** (Conta A) e precisa acessar uma sala no **Prédio B** (Conta B):

1. O **Prédio B** cria um crachá de visitante (Role) com a regra: "Funcionários do Prédio A podem pegar este crachá" → **Trust Policy**
2. Seu **chefe no Prédio A** autoriza você a pedir o crachá de visitante → **sts:AssumeRole permission**
3. Você vai na recepção do Prédio B e pede o crachá → **chamada sts:AssumeRole**
4. A recepção verifica: "Você é do Prédio A? Sim? Toma, aqui seu crachá temporário" → **STS retorna credenciais temporárias**
5. Você usa o crachá de visitante para acessar a sala → **acessa recursos da Conta B**

### Fluxo técnico simplificado

```
Passo 1: Admin da Conta B cria Role com Trust Policy
────────────────────────────────────────────────────
"Conta A (111...) pode assumir esta Role"


Passo 2: Admin da Conta A dá permissão ao User
────────────────────────────────────────────────
"João pode chamar sts:AssumeRole na Role da Conta B"


Passo 3: João executa
────────────────────────────────────────────────
aws sts assume-role \
  --role-arn arn:aws:iam::222222222222:role/CrossRole \
  --role-session-name joao-session


Passo 4: STS retorna
────────────────────────────────────────────────
{
  "AccessKeyId": "ASIA...",       ← temporário!
  "SecretAccessKey": "xyz...",    ← temporário!
  "SessionToken": "FwoGZX...",   ← temporário!
  "Expiration": "2026-07-04T23:00:00Z"  ← expira!
}


Passo 5: João usa as credenciais temporárias
────────────────────────────────────────────────
AWS_ACCESS_KEY_ID=ASIA... aws s3 ls s3://bucket-conta-b/
→ ✅ Funciona!
```

### O que pode dar errado?

| Problema | Causa | Solução |
|----------|-------|---------|
| "AccessDenied" ao chamar AssumeRole | Trust Policy da Role não lista a Conta A | Adicionar Conta A no Principal da Trust Policy |
| "AccessDenied" ao chamar AssumeRole | User na Conta A não tem permissão sts:AssumeRole | Dar Allow sts:AssumeRole ao User |
| "AccessDenied" ao acessar S3 na Conta B | Permission Policy da Role não permite s3 | Adicionar Allow s3:* na Permission Policy da Role |
| Credenciais expiraram | Sessão expirou (padrão 1h) | Chamar AssumeRole novamente |

### Quando usar cada API do STS na prova

| Situação | API |
|----------|-----|
| EC2 na Conta A precisa acessar S3 na Conta B | `AssumeRole` |
| App mobile login com Google/Facebook | `AssumeRoleWithWebIdentity` (ou melhor: Cognito) |
| Funcionários da empresa usando Active Directory | `AssumeRoleWithSAML` |
| Quero proteger uma ação com MFA | `GetSessionToken` |
| "Quem sou eu?" (debug) | `GetCallerIdentity` |

### Dica de prova

> Se a pergunta menciona "credenciais temporárias" ou "acesso temporário" → a resposta envolve **STS** e **Roles**.
> Se menciona "credenciais permanentes" ou "access keys" → provavelmente é o erro que a questão quer que você identifique (anti-pattern).


---

## 5. Permission Boundaries

### Analogia: Coleira com Cerca Invisível

Pense no IAM User como um **cachorro** e nas permissões como o **espaço onde ele pode correr**:

- **Identity-based policy** = "O cachorro pode ir ao parque, à praça e ao pet shop" (permissões dadas)
- **Permission Boundary** = "O cachorro tem uma coleira eletrônica que não deixa ele sair do bairro" (limite máximo)

**Resultado:** O cachorro pode ir ao parque e à praça (estão no bairro), mas NÃO pode ir ao shopping (fora do bairro), mesmo que a policy diga "pode ir a qualquer loja".

```
┌─────────── PERMISSION BOUNDARY (o bairro) ────────────────┐
│                                                            │
│   Permite: S3, CloudWatch, EC2:Describe*                  │
│                                                            │
│   ┌──── IDENTITY POLICY (onde o cachorro pode ir) ────┐   │
│   │                                                    │   │
│   │   Permite: S3:*, EC2:*, RDS:*, Lambda:*            │   │
│   │                                                    │   │
│   └────────────────────────────────────────────────────┘   │
│                                                            │
│   RESULTADO EFETIVO (interseção):                          │
│   ✅ S3:*           (está em ambos)                       │
│   ✅ EC2:Describe*  (está em ambos - boundary é restrito)  │
│   ✅ CloudWatch     (está no boundary mas não na policy)  │
│      → Na verdade ❌! Precisa estar em AMBOS.             │
│   ❌ RDS:*          (não está no boundary)                │
│   ❌ Lambda:*       (não está no boundary)                │
│   ❌ EC2:Start/Stop (boundary só permite Describe)        │
│                                                            │
│   EFETIVO REAL: S3:* + EC2:Describe*                      │
│   (apenas o que está nos DOIS círculos)                    │
└────────────────────────────────────────────────────────────┘
```

### A regra de ouro

> **Acesso efetivo = Identity Policy ∩ Permission Boundary**
> (só o que está nos DOIS ao mesmo tempo)

### Caso de uso clássico (aparece na prova!)

**Cenário:** Você é admin e quer permitir que o time de DevOps crie novos IAM Users, mas sem deixar eles criarem "super-users" com mais poder que eles mesmos.

**Solução:**
1. Cria um Permission Boundary chamado `DevBoundary` que limita: só S3, CloudWatch e EC2
2. Dá ao DevOps permissão de criar Users, MAS com condição: "só pode criar se anexar DevBoundary"

```
DevOps cria User "estagiario"
    → obrigado a anexar DevBoundary
    → estagiario NUNCA terá acesso a RDS, Lambda, IAM...
    → mesmo que o DevOps tente dar "Allow *" ao estagiário,
       o Boundary limita ao máximo
```

### Pontos-chave

- Boundary **NÃO dá permissão** — apenas **LIMITA** o máximo
- Aplica-se a **Users e Roles** (não a Groups)
- É uma policy normal (mesma sintaxe JSON), apenas anexada de forma diferente
- Útil para **delegação segura**: deixar pessoas criarem entidades IAM sem risco

---

## 6. SCPs — Service Control Policies

### Analogia: Regras do Condomínio

Pense na AWS Organization como um **condomínio**:

- **Contas AWS** = apartamentos
- **OUs** = blocos do condomínio
- **SCPs** = regras do condomínio
- **Management Account** = o síndico (não segue as regras, só aplica)

```
Regra do condomínio: "Nenhum apartamento pode ter churrasqueira a carvão"

→ Apartamento 101 (Conta A): tem permissão do dono de usar o terraço
  MAS a regra do condomínio proíbe churrasqueira → ❌ não pode

→ Apartamento do síndico (Management Account): pode ter churrasqueira
  porque o síndico NÃO é afetado pelas regras → ✅ pode
```

### SCPs NÃO dão permissão!

Isso confunde muita gente. Pense assim:

```
SCP "Allow s3:*" na OU "Produção"
    → NÃO significa que todos na OU podem usar S3
    → Significa: "S3 é PERMITIDO como possibilidade"
    → O User ainda precisa de uma Identity Policy com Allow s3:*

É como dizer: "O condomínio permite ter animais"
    → Isso não te dá um cachorro
    → Apenas permite que você POSSA ter um (se quiser e comprar)
```

### Estratégias

| Estratégia | Como funciona | Analogia |
|------------|---------------|----------|
| **Deny List** (mais comum) | Allow tudo por padrão, Deny específico | "Pode tudo, EXCETO churrasqueira e fogos de artifício" |
| **Allow List** (mais restritivo) | Remove o Allow * e só permite serviços específicos | "Só pode usar piscina e academia. Nada mais." |

### Exemplo: impedir que alguém desabilite CloudTrail

```json
{
  "Effect": "Deny",
  "Action": [
    "cloudtrail:StopLogging",
    "cloudtrail:DeleteTrail"
  ],
  "Resource": "*"
}
```

Tradução: "Nenhuma conta-membro pode desligar ou deletar o CloudTrail, independente de quanta permissão tenha."

### Permission Boundary vs SCP — Tabela de diferenças

| Aspecto | Permission Boundary | SCP |
|---------|:------------------:|:---:|
| **Quem define** | Admin da conta | Admin da Organization |
| **Onde aplica** | User ou Role específico | Conta inteira ou OU |
| **Afeta root?** | ❌ Não | ✅ Sim (root da conta-membro) |
| **Afeta Management Account?** | N/A | ❌ Nunca |
| **Escopo** | Dentro de 1 conta | Múltiplas contas |
| **Analogia** | Coleira no cachorro | Regras do condomínio |
| **Use case** | Delegar criação de Users/Roles | Guardrails organizacionais |

### Resumo visual: quem limita quem

```
Mais amplo ──────────────────────────────────────── Mais restrito

AWS Organization (tudo que existe)
    └── SCPs (limita contas/OUs)
          └── Permission Boundary (limita users/roles)
                └── Identity Policy (permissões efetivas)

Cada camada só pode RESTRINGIR, nunca AMPLIAR a camada acima.
```


---

## 7. Conditions em Policies

### Analogia: Regras com "SE"

Uma policy normal diz: "João pode entrar na sala."
Uma policy com Condition diz: "João pode entrar na sala **SE** estiver de crachá **E** for horário comercial."

São **restrições extras** que você adiciona a um Allow ou Deny.

### Os mais importantes (com linguagem humana)

| Condition | Tradução em português |
|-----------|----------------------|
| `"aws:SourceIp": "10.0.0.0/8"` | "Só se vier deste IP" |
| `"aws:MultiFactorAuthPresent": "true"` | "Só se tiver MFA ativo" |
| `"aws:RequestedRegion": "us-east-1"` | "Só na região us-east-1" |
| `"s3:x-amz-server-side-encryption": "AES256"` | "Só se o upload for criptografado" |
| `"aws:PrincipalOrgID": "o-xxxxx"` | "Só se for da minha Organization" |
| `"ec2:ResourceTag/Env": "dev"` | "Só em recursos com tag Env=dev" |

### Como ler uma Condition no JSON

```json
"Condition": {
  "StringEquals": {            ← operador (como comparar)
    "aws:RequestedRegion": [   ← chave (o que verificar)
      "us-east-1",            ← valores (com o que comparar)
      "eu-west-1"
    ]
  }
}
```

**Tradução:** "Esta regra só vale SE a região solicitada for us-east-1 OU eu-west-1"

### Regra de AND e OR

```
DENTRO da mesma chave (múltiplos valores) → OR
"aws:RequestedRegion": ["us-east-1", "eu-west-1"]
→ "SE for us-east-1 OU eu-west-1"

ENTRE chaves diferentes (no mesmo bloco) → AND
"aws:SourceIp": "10.0.0.0/8",
"aws:MultiFactorAuthPresent": "true"
→ "SE vier do IP 10.x.x.x E tiver MFA"

ENTRE operadores diferentes → AND
"StringEquals": { ... },
"IpAddress": { ... }
→ ambos devem ser verdadeiros
```

### Exemplo prático 1: "Só pode deletar com MFA"

```json
{
  "Effect": "Deny",
  "Action": "s3:DeleteObject",
  "Resource": "arn:aws:s3:::dados-criticos/*",
  "Condition": {
    "BoolIfExists": {
      "aws:MultiFactorAuthPresent": "false"
    }
  }
}
```

**Tradução simples:** "NEGAR deletar objetos do bucket dados-criticos SE o usuário NÃO tiver MFA ativo."

→ Resultado: pra deletar, o cara TEM que ter MFA. Sem MFA = Deny.

### Exemplo prático 2: "Devs só podem mexer em recursos com tag deles"

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

**Tradução:** "Permite EC2 actions SOMENTE se a tag Team do recurso for igual à tag Team do usuário."

→ Time "backend" só mexe em EC2s com tag Team=backend
→ Time "frontend" só mexe em EC2s com tag Team=frontend
→ Isso é **ABAC** (Attribute-Based Access Control)!

### Exemplo prático 3: "Bloquear tudo fora do escritório"

```json
{
  "Effect": "Deny",
  "Action": "*",
  "Resource": "*",
  "Condition": {
    "NotIpAddress": {
      "aws:SourceIp": "203.0.113.0/24"
    }
  }
}
```

**Tradução:** "NEGAR tudo SE o IP NÃO for o IP do escritório (203.0.113.x)"

→ Funcionário em casa? Bloqueado.
→ Funcionário no escritório (IP 203.0.113.50)? Liberado.

---

## 8. Resumo: Mapa Mental de Todo o IAM

```
                        IAM
                         │
         ┌───────────────┼───────────────┐
         │               │               │
    IDENTIDADES      PERMISSÕES       CONTROLES
         │               │               │
    ┌────┴────┐    ┌─────┴──────┐   ┌────┴─────┐
    │         │    │            │   │          │
  Users    Roles  Identity   Resource  SCPs   Permission
  Groups     │    -based     -based    (Org)   Boundary
             │    (no user)  (no recurso)      (no user/role)
             │
        Trust Policy
        (quem assume)
             +
        Permission Policy
        (o que pode fazer)
             +
           STS
        (credenciais
         temporárias)
```

### Cheat Sheet: qual conceito resolve qual problema?

| Problema | Conceito | Analogia rápida |
|----------|----------|-----------------|
| "Quem pode assumir esta role?" | Trust Policy | Contrato da locadora de carros |
| "O que esta role pode fazer?" | Permission Policy | Limites do carro alugado |
| "Como acessar outra conta?" | STS AssumeRole | Pegar crachá de visitante |
| "Limitar o máximo que um user pode ter" | Permission Boundary | Coleira com cerca invisível |
| "Limitar o que contas inteiras podem fazer" | SCP | Regras do condomínio |
| "Permitir acesso cross-account sem trocar de role" | Resource-based policy | Lista de convidados na porta |
| "Só permitir se tiver MFA / IP certo / região" | Conditions | Regras com "SE" |
| "Controle de acesso por tags" | ABAC + Conditions | Pulseira por cor no evento |
| "Deny sempre vence tudo" | Lógica de avaliação | Lista negra do segurança |

### Teste rápido: você entendeu?

Tente responder mentalmente antes de olhar a resposta:

1. **User tem policy "Allow s3:\*" mas está num Boundary que só permite "ec2:\*". Pode acessar S3?**
   → ❌ Não. Interseção vazia para S3.

2. **Conta-membro tem SCP "Deny iam:DeleteUser". O root dessa conta pode deletar users?**
   → ❌ Não. SCP afeta até o root da conta-membro.

3. **Lambda na Conta A quer acessar SQS na Conta B. Qual a forma mais simples?**
   → Resource-based policy na queue SQS permitindo a Lambda da Conta A.

4. **Policy tem "Allow s3:\*" e outra policy tem "Deny s3:DeleteBucket". O user pode deletar bucket?**
   → ❌ Não. Deny explícito SEMPRE vence.

5. **EC2 precisa acessar S3. Melhor usar access keys ou role?**
   → Role (via Instance Profile). Access keys é anti-pattern.

---

> 📖 **Próximo passo:** Agora que entendeu os conceitos, releia o `servicos/iam.md` técnico. Vai fazer muito mais sentido. Depois, me pede um simulado de IAM pra testar!

