# Segurança AWS — Criptografia, Proteção e Detecção (SAA-C03)

> **Nota:** IAM, SCPs e Identity Center estão cobertos em `iam.md`.
> Este arquivo foca em **criptografia, proteção de dados e serviços de detecção**.

---

## 1. KMS (Key Management Service) — Em Profundidade

### 1.1 Tipos de Chave

| Tipo | Gerenciado por | Criado por | Visível no Console | Rotação | Custo |
|------|---------------|------------|-------------------|---------|-------|
| **AWS Owned Keys** | AWS | AWS | ❌ Não | Variável (AWS decide) | Gratuito |
| **AWS Managed Keys** | AWS | AWS (por serviço) | ✅ Sim (alias `aws/service`) | Automática a cada 1 ano | Gratuito (uso pago) |
| **Customer Managed Keys (CMK)** | Cliente | Cliente | ✅ Sim | Configurável (automática anual ou manual) | $1/mês + uso |

**Detalhes importantes:**
- **AWS Owned Keys**: usadas internamente pela AWS (ex: SSE-S3). Não aparecem na sua conta.
- **AWS Managed Keys**: criadas automaticamente quando um serviço usa KMS (ex: `aws/ebs`, `aws/rds`). Você NÃO pode gerenciar policies.
- **Customer Managed Keys**: controle total — key policies, grants, rotation, enable/disable, deletion.

### 1.2 Symmetric vs Asymmetric

| Característica | Symmetric (AES-256-GCM) | Asymmetric (RSA, ECC) |
|---------------|--------------------------|------------------------|
| Algoritmo | AES-256 | RSA 2048/3072/4096, ECC NIST P-256/384/521 |
| Chave | Uma única chave (encrypt + decrypt) | Par público/privado |
| Acesso à chave raw | ❌ Nunca sai do KMS | Parte pública pode ser baixada |
| Uso principal | Encrypt/decrypt dados, envelope encryption | Sign/verify, encrypt fora da AWS |
| Serviços AWS | Todos usam symmetric por padrão | Quando quem criptografa não pode chamar KMS |
| Performance | Mais rápido | Mais lento |

**Quando usar Asymmetric:**
- Aplicações externas que não podem chamar a API do KMS
- Verificação de assinatura digital (code signing)
- Encrypt em clientes que não têm credenciais AWS

### 1.3 Key Policies + IAM Policies (Ambas Necessárias)

```
┌─────────────────────────────────────────────────────────┐
│                  ACESSO A UMA CMK                        │
│                                                         │
│   Key Policy (resource-based)                           │
│        +                                                │
│   IAM Policy (identity-based)                           │
│        =                                                │
│   ACESSO CONCEDIDO                                      │
│                                                         │
│   ⚠️  Sem Key Policy = NINGUÉM acessa (nem root)        │
└─────────────────────────────────────────────────────────┘
```

**Default Key Policy:**
- Permite que a conta root tenha acesso total à chave
- Isso "habilita" IAM policies para controlar acesso
- Sem ela, a chave fica órfã (somente AWS support pode recuperar)

**Custom Key Policy:**
- Define exatamente quem pode administrar vs usar a chave
- Permite cross-account access
- Pode ser combinada com IAM policies

**Exemplo de Key Policy cross-account:**
```json
{
  "Sid": "AllowExternalAccount",
  "Effect": "Allow",
  "Principal": {"AWS": "arn:aws:iam::111122223333:root"},
  "Action": [
    "kms:Encrypt",
    "kms:Decrypt",
    "kms:GenerateDataKey"
  ],
  "Resource": "*"
}
```

### 1.4 KMS Grants

- Permissões **temporárias e delegáveis** para operações com chaves KMS
- Usados por serviços AWS (ex: EBS pede grant para re-encrypt ao criar snapshot)
- Criados via `CreateGrant` API
- Podem ser revogados sem alterar key policy ou IAM policy
- Úteis para acesso just-in-time

### 1.5 Key Rotation

| Cenário | Rotação | Como funciona |
|---------|---------|---------------|
| **Customer Managed (gerada no KMS)** | Automática anual (opt-in) | Novo material criptográfico, mesmo Key ID. Material antigo mantido para decrypt |
| **Customer Managed (imported material)** | ❌ Não suporta automática | Manual: criar nova chave, re-encrypt, alias swap |
| **AWS Managed** | Automática a cada 1 ano | Transparente, gerenciado pela AWS |

**Rotação manual (imported keys):**
1. Criar nova CMK com novo material importado
2. Atualizar alias para apontar para nova chave
3. Manter chave antiga para descriptografar dados antigos
4. Aplicações usam alias → transição transparente

### 1.6 Envelope Encryption — Diagrama Completo

```
┌─────────────────────────────────────────────────────────────────┐
│                    ENVELOPE ENCRYPTION                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ENCRYPT FLOW (GenerateDataKey):                                │
│  ════════════════════════════════                                │
│                                                                 │
│  App ──────► KMS API: GenerateDataKey(CMK-ID)                   │
│                │                                                │
│                ▼                                                 │
│  KMS retorna:                                                   │
│    ├── Plaintext Data Key (DEK)  ← usar para encrypt            │
│    └── Encrypted Data Key        ← armazenar junto aos dados    │
│                                                                 │
│  App usa DEK plaintext ──► Encrypt dados localmente (AES-256)   │
│  App DESCARTA DEK plaintext da memória                          │
│  App armazena: [Encrypted DEK] + [Dados Criptografados]         │
│                                                                 │
│                                                                 │
│  DECRYPT FLOW:                                                  │
│  ═════════════                                                  │
│                                                                 │
│  App ──────► KMS API: Decrypt(Encrypted DEK)                    │
│                │                                                │
│                ▼                                                 │
│  KMS retorna: Plaintext DEK                                     │
│                                                                 │
│  App usa DEK plaintext ──► Decrypt dados localmente             │
│  App DESCARTA DEK plaintext da memória                          │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│  POR QUE ENVELOPE ENCRYPTION?                                   │
│  • KMS tem limite de 4KB para encrypt direto                    │
│  • Dados grandes são criptografados localmente (rápido)         │
│  • Apenas a DEK (pequena) vai e volta do KMS (rede)             │
│  • Reduz latência e custo de chamadas KMS                       │
└─────────────────────────────────────────────────────────────────┘
```

### 1.7 KMS Multi-Region Keys

```
┌───────────────┐         ┌───────────────┐
│  us-east-1    │         │  eu-west-1    │
│               │         │               │
│  Primary Key  │◄───────►│  Replica Key  │
│  mrk-abc123   │  Sync   │  mrk-abc123   │
│               │         │               │
└───────────────┘         └───────────────┘
        │                         │
   Mesmo Key ID            Mesmo Key ID
   Mesmo material          Mesmo material
```

- **Mesmo Key ID** e **mesmo material criptográfico** em todas as regiões
- Encrypt em uma região, decrypt em outra SEM cross-region API call
- **NÃO são globais** — cada réplica é gerenciada independentemente
- Use cases: disaster recovery, global DynamoDB tables, Aurora Global Database
- Key policies são independentes por região

### 1.8 KMS Request Quotas e Throttling

| Operação | Quota padrão (por segundo) |
|----------|---------------------------|
| Cryptographic operations (Encrypt, Decrypt, GenerateDataKey) | 5.500 - 30.000 (varia por região e tipo de chave) |
| Symmetric | 5.500 - 30.000 req/s |
| RSA | 500 req/s |
| ECC | 300 req/s |

**Quando há throttling:**
- `ThrottlingException` retornado
- Implementar exponential backoff
- Considerar **DEK caching** (AWS Encryption SDK) para reduzir chamadas
- Solicitar aumento de quota via Service Quotas

**AWS Encryption SDK — DEK Caching:**
- Cache plaintext DEK localmente por tempo/número de uso
- Reduz drasticamente chamadas ao KMS
- Trade-off: menos rotação de DEK vs performance

---

## 2. KMS — Integração com Serviços AWS

### 2.1 S3 Encryption (Server-Side)

| Tipo | Chave | Gerenciamento | Header | Quando usar |
|------|-------|---------------|--------|-------------|
| **SSE-S3** | AWS owned key (AES-256) | AWS total | `x-amz-server-side-encryption: AES256` | Default, sem necessidade de controle |
| **SSE-KMS** | AWS managed ou Customer managed | Cliente controla via KMS | `x-amz-server-side-encryption: aws:kms` | Auditoria (CloudTrail), controle granular |
| **SSE-C** | Chave fornecida pelo cliente | Cliente total | Headers com chave em cada request | Compliance requer chave própria |
| **DSSE-KMS** | KMS key | Dual-layer encryption | `x-amz-server-side-encryption: aws:kms:dsse` | Compliance que exige dupla camada |

**SSE-KMS — Pontos importantes para o exame:**
- Cada GET/PUT gera chamada ao KMS → sujeito a quota/throttling
- Bucket com muitos objetos + SSE-KMS = considerar DEK caching ou SSE-S3
- Permite `s3:PutObject` com condição `"s3:x-amz-server-side-encryption": "aws:kms"`
- CloudTrail registra cada uso da chave (auditoria completa)
- Cross-account: conta destino precisa de permissão na Key Policy

**SSE-C — Pontos importantes:**
- HTTPS obrigatório (chave vai no header)
- AWS NÃO armazena a chave — se perder, perde os dados
- Não funciona com S3 Console (somente API/CLI/SDK)

### 2.2 EBS Encryption

```
┌──────────────────────────────────────────────────────────┐
│              EBS ENCRYPTION FLOW                          │
│                                                          │
│  Volume criado com encryption ──► KMS GenerateDataKey    │
│                                        │                 │
│                                        ▼                 │
│  DEK criptografa dados no volume (AES-256)               │
│  Encrypted DEK armazenado nos metadados do volume        │
│                                                          │
│  EC2 instance attach ──► KMS Decrypt(Encrypted DEK)      │
│                               │                          │
│                               ▼                          │
│  DEK em plaintext no hypervisor (memória volátil)        │
│  Dados criptografados em trânsito entre EC2 e EBS        │
└──────────────────────────────────────────────────────────┘
```

**Pontos para o exame:**
- Encryption at rest E in transit (entre instância e volume)
- Snapshots de volumes criptografados são automaticamente criptografados
- Copiar snapshot não criptografado → pode criptografar na cópia
- **Não é possível remover encryption** de um volume (copiar para novo sem encryption)
- Pode habilitar "EBS encryption by default" na conta (por região)
- Volumes root podem ser criptografados no lançamento

### 2.3 RDS Encryption

- Encryption at rest com KMS (AES-256) no storage, backups, read replicas e snapshots
- **Deve ser habilitado na criação** — não pode criptografar DB existente diretamente
- Para criptografar DB existente: snapshot → copy snapshot encrypted → restore
- Read replicas herdam encryption da instância primária
- **TDE (Transparent Data Encryption)**: suportado para Oracle e SQL Server (gerenciado pelo engine)

### 2.4 Secrets Encryption (Integração Geral)

| Serviço | Encryption | Chave |
|---------|-----------|-------|
| Secrets Manager | AES-256 via KMS | AWS managed ou CMK |
| SSM Parameter Store (SecureString) | AES-256 via KMS | AWS managed ou CMK |
| DynamoDB | AES-256 via KMS | AWS owned, AWS managed, ou CMK |
| Lambda (env vars) | AES-256 via KMS | AWS managed ou CMK |
| SQS | AES-256 via KMS | AWS managed ou CMK |
| SNS | AES-256 via KMS | AWS managed ou CMK |

---

## 3. CloudHSM

### 3.1 Visão Geral

```
┌─────────────────────────────────────────────────────────┐
│                    CloudHSM                              │
│                                                         │
│  ┌─────────────┐    ┌─────────────┐                    │
│  │  HSM Node   │    │  HSM Node   │  ← Cluster HA     │
│  │  (AZ-a)     │    │  (AZ-b)     │                    │
│  └──────┬──────┘    └──────┬──────┘                    │
│         │                  │                            │
│         └────────┬─────────┘                            │
│                  │                                      │
│         ┌───────▼────────┐                              │
│         │  CloudHSM      │                              │
│         │  Client (EC2)  │                              │
│         └────────────────┘                              │
│                                                         │
│  • Hardware dedicado (single-tenant)                    │
│  • FIPS 140-2 Level 3                                   │
│  • VOCÊ gerencia as chaves (AWS não tem acesso)         │
│  • AWS gerencia apenas o hardware                       │
│  • Se perder credenciais = perder chaves (irreversível) │
└─────────────────────────────────────────────────────────┘
```

### 3.2 Use Cases

| Use Case | Por que CloudHSM? |
|----------|-------------------|
| **SSL/TLS Offloading** | Armazena chave privada no HSM, Nginx/Apache faz offload |
| **Certificate Authority (CA)** | Chaves de CA protegidas em hardware FIPS |
| **Oracle TDE** | Oracle Database Transparent Data Encryption requer HSM |
| **Microsoft SignTool** | Code signing com chaves em hardware |
| **Custom Key Store para KMS** | Usa CloudHSM como backend do KMS (compliance) |
| **Compliance regulatória** | FIPS 140-2 Level 3 obrigatório |

### 3.3 CloudHSM vs KMS — Tabela Comparativa

| Critério | KMS | CloudHSM |
|----------|-----|----------|
| **Tenancy** | Multi-tenant | Single-tenant (hardware dedicado) |
| **Compliance** | FIPS 140-2 Level 2 (alguns Level 3) | FIPS 140-2 Level 3 |
| **Gerenciamento de chaves** | AWS + Cliente | Somente Cliente |
| **Acesso AWS às chaves** | Sim (AWS managed) | ❌ Nunca |
| **Alta disponibilidade** | AWS gerencia (multi-AZ) | Cliente configura cluster multi-AZ |
| **Integração com serviços AWS** | Nativa (todos os serviços) | Via Custom Key Store ou aplicação |
| **Performance** | Milhares req/s (shared) | Alta (dedicado, custom crypto) |
| **Algoritmos** | Symmetric, Asymmetric (limitado) | Symmetric, Asymmetric, hashing, HMAC |
| **Custo** | Pay-per-use ($1/chave/mês) | ~$1.50/hora por HSM (~$1.100/mês) |
| **Free tier** | AWS managed keys gratuitas | ❌ |
| **Backup** | AWS automático | AWS automático (encrypted, só restaura no cluster) |
| **Auditoria** | CloudTrail | CloudTrail + CloudWatch Logs (HSM logs) |
| **Controle de acesso** | Key Policies + IAM | HSM Users (CU, CO, AU) |

---

## 4. AWS Secrets Manager

### 4.1 Visão Geral

- Armazena e gerencia **segredos** (credentials, API keys, tokens)
- Encryption com KMS (obrigatório)
- **Rotação automática** nativa com Lambda
- Versionamento automático (AWSCURRENT, AWSPREVIOUS, AWSPENDING)
- Limite: 65.536 bytes por segredo

### 4.2 Rotação Automática

```
┌─────────────────────────────────────────────────────────┐
│              ROTAÇÃO AUTOMÁTICA                          │
│                                                         │
│  Secrets Manager ──► Lambda Function (rotation)         │
│       │                    │                            │
│       │                    ▼                            │
│       │            1. createSecret (AWSPENDING)         │
│       │            2. setSecret (atualiza DB)           │
│       │            3. testSecret (verifica conexão)     │
│       │            4. finishSecret (AWSPENDING→CURRENT) │
│       │                                                 │
│       ▼                                                 │
│  Integração NATIVA (Lambda gerenciada pela AWS):        │
│  • Amazon RDS (MySQL, PostgreSQL, Oracle, SQL Server)   │
│  • Amazon Aurora                                        │
│  • Amazon Redshift                                      │
│  • Amazon DocumentDB                                    │
│                                                         │
│  Integração CUSTOM (Lambda criada pelo cliente):        │
│  • Qualquer outro serviço/banco                         │
└─────────────────────────────────────────────────────────┘
```

**Rotação — Pontos para o exame:**
- Intervalo configurável (mínimo 4 horas, máximo 365 dias)
- Lambda precisa de acesso à rede do banco (VPC, Security Group)
- Lambda precisa de permissão no KMS para re-encrypt
- Multi-user rotation strategy: alterna entre 2 users para zero-downtime

### 4.3 Cross-Account Sharing

- Resource-based policy no segredo permite acesso de outra conta
- Conta consumidora precisa de IAM policy + resource policy no segredo
- Usa ARN completo do segredo (não alias)

### 4.4 Replicação Multi-Region

- Replica segredos para múltiplas regiões automaticamente
- Réplicas são read-only (primary é read-write)
- Se a região primária falhar → promover réplica a primária
- Use case: disaster recovery, aplicações multi-region
- Rotação acontece na região primária e propaga para réplicas

### 4.5 Pricing

| Item | Custo |
|------|-------|
| Por segredo/mês | $0.40 |
| Por 10.000 chamadas API | $0.05 |
| Rotação Lambda | Custo padrão Lambda |

---

## 5. SSM Parameter Store

### 5.1 Visão Geral

- Armazena **configurações e segredos** em hierarquia
- Integrado ao AWS Systems Manager
- Tipos: String, StringList, SecureString
- **Gratuito** no tier Standard

### 5.2 Standard vs Advanced

| Critério | Standard | Advanced |
|----------|----------|----------|
| **Número de parâmetros** | 10.000 por conta/região | 100.000 por conta/região |
| **Tamanho máximo do valor** | 4 KB | 8 KB |
| **Parameter Policies** | ❌ | ✅ (expiration, notification) |
| **Custo armazenamento** | Gratuito | $0.05 por parâmetro/mês |
| **Custo API** | Gratuito (standard throughput) | Gratuito (standard) / $0.05/10k (higher) |
| **Throughput** | 40 TPS padrão (até 1.000 com higher) | 40 TPS padrão (até 1.000 com higher) |
| **Pode converter** | Standard → Advanced | Advanced → Standard (se <4KB e <10k) |

### 5.3 Tipos de Parâmetro

| Tipo | Descrição | Exemplo |
|------|-----------|---------|
| **String** | Texto simples | `ami-0abcdef1234567890` |
| **StringList** | Lista separada por vírgulas | `us-east-1,us-west-2,eu-west-1` |
| **SecureString** | Criptografado com KMS | Senhas, connection strings |

### 5.4 Hierarquia de Parâmetros

```
/myapp/
├── /myapp/dev/
│   ├── /myapp/dev/db-host        (String)
│   ├── /myapp/dev/db-password    (SecureString)
│   └── /myapp/dev/db-port        (String)
├── /myapp/prod/
│   ├── /myapp/prod/db-host       (String)
│   ├── /myapp/prod/db-password   (SecureString)
│   └── /myapp/prod/db-port       (String)
└── /myapp/shared/
    └── /myapp/shared/api-url     (String)
```

**Vantagens da hierarquia:**
- IAM policies por path: `arn:aws:ssm:*:*:parameter/myapp/prod/*`
- `GetParametersByPath` para buscar todos de um nível
- Organização lógica por ambiente/aplicação/componente

### 5.5 Integração com KMS

- SecureString usa KMS para encrypt/decrypt
- Pode usar AWS managed key (`aws/ssm`) ou Customer managed key
- Para cross-account: usar CMK com key policy permitindo a outra conta
- Decrypt transparente no `GetParameter` (se caller tem permissão KMS)

### 5.6 Parameter Policies (Advanced Tier)

| Policy | Descrição |
|--------|-----------|
| **Expiration** | Define TTL — parâmetro expira e pode ser deletado |
| **ExpirationNotification** | Notifica via EventBridge X dias antes de expirar |
| **NoChangeNotification** | Notifica se parâmetro não foi alterado em X dias |

**Use case:** forçar rotação de credenciais alertando equipes antes de expirar.

---

## 6. Secrets Manager vs Parameter Store — Tabela Completa

| Critério | Secrets Manager | SSM Parameter Store |
|----------|----------------|---------------------|
| **Propósito principal** | Segredos (credentials, API keys) | Configurações + segredos |
| **Custo armazenamento** | $0.40/segredo/mês | Gratuito (Standard) |
| **Custo API** | $0.05/10k chamadas | Gratuito (standard throughput) |
| **Rotação automática** | ✅ Nativa (Lambda managed) | ❌ (requer custom Lambda + EventBridge) |
| **Integração RDS/Aurora** | ✅ Nativa (rotation templates) | ❌ Manual |
| **Tamanho máximo** | 65 KB | 4 KB (Standard) / 8 KB (Advanced) |
| **Versionamento** | ✅ Automático (staging labels) | ✅ (por version number) |
| **Replicação multi-region** | ✅ Nativa | ❌ (requer custom solution) |
| **Cross-account** | ✅ Resource-based policy | Limitado (via RAM ou assume role) |
| **Encryption** | Obrigatória (KMS) | Opcional (somente SecureString) |
| **Hierarquia/Path** | ❌ (flat namespace) | ✅ Hierarquia com GetParametersByPath |
| **Parameter Policies (TTL)** | ❌ (usa rotation schedule) | ✅ (Advanced tier) |
| **Integração CloudFormation** | ✅ Dynamic reference | ✅ Dynamic reference |
| **Histórico de alterações** | ✅ (staging labels) | ✅ (version history) |
| **Free Tier** | ❌ | ✅ (Standard tier inteiro) |

**Regra para o exame:**
- **"Rotação automática de credenciais de banco"** → Secrets Manager
- **"Armazenar configuração sem custo"** → Parameter Store Standard
- **"Cross-region secret replication"** → Secrets Manager
- **"Hierarchical configuration"** → Parameter Store

---

## 7. ACM (AWS Certificate Manager)

### 7.1 Visão Geral

- Provisiona certificados **SSL/TLS públicos gratuitamente**
- Renovação automática (certificados públicos gerenciados pela AWS)
- **Não exportável** — chave privada gerenciada pela AWS
- Suporta wildcard certificates (`*.example.com`)
- Regional (exceto CloudFront — deve ser us-east-1)

### 7.2 Validação

| Método | Como funciona | Tempo | Renovação Automática |
|--------|---------------|-------|---------------------|
| **DNS Validation** | Criar CNAME record no DNS | Minutos (se DNS acessível) | ✅ Sim (enquanto CNAME existir) |
| **Email Validation** | AWS envia email para admin do domínio | Horas (aguarda aprovação) | ❌ Requer re-aprovação manual |

**Recomendação:** Sempre usar DNS Validation (automático e confiável).

### 7.3 Integração com Serviços

| Serviço | Suportado | Notas |
|---------|-----------|-------|
| **ALB (Application Load Balancer)** | ✅ | Terminação TLS no ALB |
| **NLB (Network Load Balancer)** | ✅ | TLS listener |
| **CloudFront** | ✅ | Certificado DEVE estar em us-east-1 |
| **API Gateway** | ✅ | Custom domain names |
| **Elastic Beanstalk** | ✅ | Via ALB/NLB |
| **EC2 diretamente** | ❌ | Não suporta (usar self-managed cert) |
| **S3 static website** | ❌ | Usar CloudFront na frente |

### 7.4 ACM Private CA

- Cria **CA privada** dentro da AWS
- Emite certificados privados para recursos internos
- Criptografia mTLS (mutual TLS) entre microserviços
- **Custo:** $400/mês por CA + $0.75 por certificado emitido
- Certificados exportáveis (diferente do ACM público)
- Use case: IoT devices, service mesh, internal APIs

### 7.5 Pontos para o Exame

- Certificado para CloudFront → **DEVE** estar em us-east-1
- Certificado para ALB → deve estar na **mesma região** do ALB
- ACM não funciona com EC2 → instalar cert manualmente ou usar ALB na frente
- Renovação automática só funciona com DNS validation
- Importar certificado externo → sem renovação automática (ACM alerta 45 dias antes)

---

## 8. AWS WAF (Web Application Firewall)

### 8.1 Arquitetura

```
┌──────────────────────────────────────────────────────────────┐
│                        AWS WAF                                │
│                                                              │
│  ┌─────────────┐                                             │
│  │  Web ACL    │ ← Conjunto de Rules (ordenadas por prioridade)│
│  │             │                                             │
│  │  Rule 1 ───────► Rate-based (DDoS L7)                    │
│  │  Rule 2 ───────► IP Set (block list)                      │
│  │  Rule 3 ───────► Geo Match (block countries)              │
│  │  Rule 4 ───────► SQL Injection                            │
│  │  Rule 5 ───────► XSS                                     │
│  │  Rule 6 ───────► Size constraint                          │
│  │  Rule 7 ───────► Regex pattern                            │
│  │  Rule 8 ───────► Managed Rule Group (AWS/Marketplace)     │
│  │             │                                             │
│  │  Default ──────► ALLOW ou BLOCK                           │
│  └─────────────┘                                             │
│                                                              │
│  Associado a: ALB │ API Gateway │ CloudFront │ AppSync │     │
│                Cognito User Pool │ App Runner                 │
└──────────────────────────────────────────────────────────────┘
```

### 8.2 Tipos de Rules

| Tipo | Descrição | Exemplo |
|------|-----------|---------|
| **Rate-based** | Bloqueia IPs que excedem X requests em 5 min | Anti-DDoS camada 7 |
| **IP Set** | Allow/Block por lista de IPs/CIDRs | Block known bad IPs |
| **Geo Match** | Bloqueia por país | Compliance: bloquear tráfego de certos países |
| **Size Constraint** | Bloqueia por tamanho de componente | Body > 8KB |
| **SQL Injection** | Detecta padrões SQLi | Input validation |
| **XSS** | Detecta cross-site scripting | Input validation |
| **Regex Pattern** | Match por expressão regular | Custom patterns |
| **Label Match** | Match por labels adicionados por regras anteriores | Composição de regras |

### 8.3 Managed Rule Groups

| Provedor | Exemplos |
|----------|----------|
| **AWS Managed Rules** | Core Rule Set, Known Bad Inputs, SQL Database, Linux/Windows OS, IP Reputation |
| **AWS Marketplace** | F5, Fortinet, Imperva, GeoGuard |

**AWS Managed Rules — Principais grupos:**
- `AWSManagedRulesCommonRuleSet` — regras OWASP Top 10
- `AWSManagedRulesSQLiRuleSet` — SQL Injection
- `AWSManagedRulesKnownBadInputsRuleSet` — payloads conhecidos
- `AWSManagedRulesAmazonIpReputationList` — IPs maliciosos
- `AWSManagedRulesBotControlRuleSet` — bot detection (custo adicional)

### 8.4 WAF + CloudFront (Proteção Global)

```
Internet ──► CloudFront (WAF Web ACL) ──► ALB (origem)
                  │
                  ▼
         Filtra ANTES de chegar à origem
         • Bloqueia por geolocalização
         • Rate limiting global
         • Protege contra bots
         • SQL injection / XSS filter
```

**Vantagem:** WAF no CloudFront filtra na edge (menor latência, protege globalmente).

### 8.5 Pricing WAF

| Item | Custo |
|------|-------|
| Web ACL | $5/mês |
| Rule | $1/mês por rule |
| Requests | $0.60 por milhão |
| Bot Control | $10/mês + $1/milhão requests |

---

## 9. AWS Shield

### 9.1 Standard vs Advanced — Tabela Completa

| Critério | Shield Standard | Shield Advanced |
|----------|----------------|-----------------|
| **Custo** | Gratuito (automático) | $3.000/mês + taxas de uso |
| **Proteção** | Camadas 3/4 (SYN flood, UDP reflection) | Camadas 3/4/7 (inclui application layer) |
| **Ativação** | Automática para todos os clientes AWS | Opt-in (subscription anual) |
| **DDoS Response Team (DRT)** | ❌ | ✅ 24/7 acesso ao time de resposta AWS |
| **Cost Protection** | ❌ | ✅ Reembolso de scaling causado por DDoS |
| **Visibilidade de ataques** | Básica | ✅ Dashboard detalhado, métricas em tempo real |
| **Mitigação automática** | Layer 3/4 apenas | ✅ Inclui Layer 7 com WAF automático |
| **WAF incluído** | ❌ | ✅ WAF sem custo adicional para recursos protegidos |
| **Health-based detection** | ❌ | ✅ Usa Route 53 health checks para detecção |
| **Recursos protegidos** | EC2, ELB, CloudFront, Route 53, Global Accelerator | EC2, ELB, CloudFront, Route 53, Global Accelerator, Elastic IP |
| **SLA** | Não | ✅ Financial SLA |
| **Integração Firewall Manager** | ❌ | ✅ Deploy centralizado em Organizations |

### 9.2 Quando usar Shield Advanced (para o exame)

- Aplicação de alta visibilidade sujeita a ataques DDoS frequentes
- Necessidade de proteção financeira contra scaling causado por ataque
- Requer acesso ao DDoS Response Team da AWS
- Compliance exige mitigação avançada documentada
- Organização com múltiplas contas precisa de proteção centralizada

---

## 10. AWS Firewall Manager

### 10.1 Visão Geral

```
┌──────────────────────────────────────────────────────────┐
│              AWS FIREWALL MANAGER                         │
│                                                          │
│  ┌─────────────────────────────────────┐                 │
│  │  Management Account (Organizations) │                 │
│  │                                     │                 │
│  │  Security Policies:                 │                 │
│  │  • WAF Rules                        │                 │
│  │  • Shield Advanced                  │                 │
│  │  • Security Groups                  │                 │
│  │  • Network Firewall                 │                 │
│  │  • Route 53 Resolver DNS Firewall   │                 │
│  └──────────────┬──────────────────────┘                 │
│                 │                                         │
│     ┌───────────┼───────────┐                            │
│     ▼           ▼           ▼                            │
│  Account A   Account B   Account C                       │
│  (auto-apply) (auto-apply) (auto-apply)                  │
│                                                          │
│  ✅ Auto-remediation: aplica regras em novos recursos    │
│  ✅ Compliance dashboard                                 │
│  ✅ Scope: por OU, por tag, por tipo de recurso          │
└──────────────────────────────────────────────────────────┘
```

### 10.2 Pré-requisitos

- AWS Organizations habilitado
- Conta de administrador do Firewall Manager designada
- AWS Config habilitado em todas as contas/regiões

### 10.3 Políticas Suportadas

| Política | O que gerencia |
|----------|---------------|
| **WAF Policy** | Web ACLs aplicadas a ALB, API GW, CloudFront |
| **Shield Advanced Policy** | Ativa Shield Advanced em recursos selecionados |
| **Security Group Policy** | Audit e enforce regras de Security Groups |
| **Network Firewall Policy** | Deploy de AWS Network Firewall em VPCs |
| **DNS Firewall Policy** | Regras de DNS filtering |

### 10.4 Auto-Remediation

- Novos recursos criados automaticamente recebem as policies
- Recursos não-compliant podem ser corrigidos automaticamente
- Exemplo: nova ALB criada → WAF Web ACL aplicada automaticamente
- Security Groups: pode remover regras excessivamente permissivas

### 10.5 Para o Exame

- **"Gerenciar WAF rules em todas as contas da organização"** → Firewall Manager
- **"Garantir que todos ALBs tenham WAF"** → Firewall Manager + WAF Policy
- **"Security Groups consistentes em todas as contas"** → Firewall Manager + SG Policy
- Requer: Organizations + AWS Config + conta admin designada

---

## 11. Amazon GuardDuty

### 11.1 Visão Geral

- **Detecção inteligente de ameaças** usando ML, anomaly detection e threat intelligence
- **Sem agente** — analisa logs automaticamente
- Habilitação com **1 clique** (30 dias free trial)
- Findings classificados por severidade: Low, Medium, High

### 11.2 Fontes de Dados

```
┌──────────────────────────────────────────────────────────────┐
│                    GUARDDUTY SOURCES                          │
│                                                              │
│  ┌─────────────────┐  ┌─────────────────┐                   │
│  │ VPC Flow Logs   │  │ DNS Logs        │                   │
│  │ (não precisa    │  │ (queries DNS    │                   │
│  │  habilitar)     │  │  da VPC)        │                   │
│  └────────┬────────┘  └────────┬────────┘                   │
│           │                    │                             │
│  ┌────────┴────────┐  ┌───────┴─────────┐                   │
│  │ CloudTrail      │  │ CloudTrail S3   │                   │
│  │ Management      │  │ Data Events     │                   │
│  │ Events          │  │                 │                   │
│  └────────┬────────┘  └───────┬─────────┘                   │
│           │                    │                             │
│  ┌────────┴────────┐  ┌───────┴─────────┐                   │
│  │ EKS Audit Logs  │  │ RDS Login       │                   │
│  │                 │  │ Activity        │                   │
│  └────────┬────────┘  └───────┬─────────┘                   │
│           │                    │                             │
│  ┌────────┴────────┐  ┌───────┴─────────┐                   │
│  │ Lambda Network  │  │ EBS Malware     │                   │
│  │ Activity        │  │ Protection      │                   │
│  └─────────────────┘  └─────────────────┘                   │
│                                                              │
│  ⚠️ GuardDuty acessa esses logs INDEPENDENTEMENTE            │
│     de estarem habilitados ou não na sua conta               │
└──────────────────────────────────────────────────────────────┘
```

### 11.3 Tipos de Findings

| Categoria | Exemplos |
|-----------|----------|
| **EC2** | CryptoCurrency mining, DDoS, malware C&C communication |
| **IAM** | Credenciais comprometidas, API calls de IPs maliciosos |
| **S3** | Acesso anômalo, desabilitar logging, bucket policies suspeitas |
| **Kubernetes** | Containers privilegiados, acesso anômalo a API server |
| **Malware** | Trojan, ransomware detectado em EBS volumes |

### 11.4 Integração

```
GuardDuty Finding ──► EventBridge ──► Lambda (auto-remediation)
                                  ──► SNS (notificação)
                                  ──► Security Hub (centralização)
```

**Automação comum:**
- Finding "EC2 comprometida" → Lambda isola instância (SG sem regras)
- Finding "credencial comprometida" → Lambda desativa access key
- Finding "S3 público" → Lambda corrige bucket policy

### 11.5 GuardDuty Multi-Account

- Conta admin (delegated administrator via Organizations)
- Habilita automaticamente em todas as contas membros
- Findings centralizados na conta admin
- Pode usar invitation model (sem Organizations)

---

## 12. Amazon Inspector

### 12.1 Visão Geral

- **Vulnerability assessment automático e contínuo**
- Scans automáticos quando: deploy de ECR image, instalar novo pacote em EC2, nova Lambda
- Sem agente dedicado (usa SSM Agent em EC2)
- Findings priorizados por risk score (1-100)

### 12.2 Targets de Scanning

| Target | O que escaneia | Requisito |
|--------|---------------|-----------|
| **EC2 Instances** | CVEs no SO e pacotes, network reachability | SSM Agent instalado e running |
| **ECR Container Images** | CVEs em OS packages e language packages | Push de image ao ECR |
| **Lambda Functions** | CVEs em packages de código e layers | Deploy de nova function/layer |

### 12.3 Tipos de Scan

| Tipo | Descrição |
|------|-----------|
| **Package Vulnerability** | Verifica CVEs em pacotes instalados (NVD database) |
| **Network Reachability** | Identifica paths de rede que expõem portas/serviços |
| **Code Vulnerability** | Lambda code scanning (injection flaws, hardcoded secrets) |

### 12.4 Network Reachability

```
Inspector analisa:
• Security Groups
• Network ACLs
• Route Tables
• Internet Gateways
• VPC Peering

Identifica:
• Portas abertas acessíveis da internet
• Paths de rede não intencionais
• Exposição de serviços (SSH, RDP, databases)
```

### 12.5 Integração

- **Security Hub**: findings enviados automaticamente
- **EventBridge**: automação baseada em findings
- **S3**: exportar findings detalhados
- **Multi-account**: delegated administrator em Organizations

### 12.6 Inspector vs GuardDuty

| Critério | Inspector | GuardDuty |
|----------|-----------|-----------|
| **Foco** | Vulnerabilidades (CVEs) | Ameaças ativas (threats) |
| **Quando** | Proativo (antes do ataque) | Reativo (detecta ataques) |
| **O que analisa** | Pacotes, código, rede | Logs, tráfego, comportamento |
| **Resultado** | Lista de CVEs com severity | Findings de ameaças |

---

## 13. Amazon Macie

### 13.1 Visão Geral

- Usa **ML e pattern matching** para descobrir dados sensíveis no S3
- Identifica: PII, PHI, dados financeiros, credentials
- Classifica e monitora buckets S3 automaticamente
- Dashboard de postura de segurança dos dados

### 13.2 O que Detecta

| Categoria | Exemplos |
|-----------|----------|
| **PII (Personally Identifiable Information)** | CPF, SSN, passaporte, endereço, telefone, email |
| **Financial** | Números de cartão de crédito, contas bancárias |
| **Credentials** | AWS access keys, private keys, tokens |
| **PHI (Health Information)** | Registros médicos, insurance IDs |
| **Custom** | Data identifiers criados pelo cliente (regex + keywords) |

### 13.3 Arquitetura

```
┌─────────────────────────────────────────────────────────┐
│                    MACIE FLOW                            │
│                                                         │
│  S3 Buckets ──► Macie Discovery Job                     │
│                      │                                  │
│                      ▼                                  │
│              ML + Pattern Matching                       │
│                      │                                  │
│                      ▼                                  │
│              Sensitive Data Findings                     │
│                      │                                  │
│           ┌──────────┼──────────┐                       │
│           ▼          ▼          ▼                        │
│     EventBridge  Security Hub  S3 (results)             │
│           │                                             │
│           ▼                                             │
│     Lambda/SNS (alertas e automação)                    │
└─────────────────────────────────────────────────────────┘
```

### 13.4 Tipos de Findings

| Tipo | Descrição |
|------|-----------|
| **Sensitive Data Finding** | Dados sensíveis encontrados em objeto S3 |
| **Policy Finding** | Bucket com configuração insegura (público, sem encryption) |

### 13.5 Para o Exame

- **"Descobrir PII em buckets S3"** → Macie
- **"Classificar dados sensíveis automaticamente"** → Macie
- **"Alertar quando dados de cartão estão em S3"** → Macie + EventBridge + SNS
- Macie é **regional** — habilitar em cada região necessária
- Pode criar custom data identifiers com regex

---

## 14. AWS Security Hub

### 14.1 Visão Geral

```
┌──────────────────────────────────────────────────────────────┐
│                    AWS SECURITY HUB                           │
│                                                              │
│  ┌─────────┐ ┌──────────┐ ┌───────┐ ┌──────────────────┐   │
│  │GuardDuty│ │Inspector │ │ Macie │ │ IAM Access       │   │
│  │         │ │          │ │       │ │ Analyzer         │   │
│  └────┬────┘ └────┬─────┘ └───┬───┘ └────────┬─────────┘   │
│       │           │           │               │             │
│       └───────────┼───────────┼───────────────┘             │
│                   │           │                              │
│                   ▼           ▼                              │
│         ┌─────────────────────────────────┐                  │
│         │     SECURITY HUB (Central)      │                  │
│         │                                 │                  │
│         │  • Agrega findings              │                  │
│         │  • Normaliza (ASFF format)      │                  │
│         │  • Security Standards checks    │                  │
│         │  • Compliance dashboard         │                  │
│         │  • Cross-account aggregation    │                  │
│         └──────────────┬──────────────────┘                  │
│                        │                                     │
│              ┌─────────┼─────────┐                           │
│              ▼         ▼         ▼                           │
│         EventBridge  Custom    3rd Party                     │
│         (automação)  Actions   (Splunk, Jira)                │
│                                                              │
│  Security Standards:                                         │
│  • AWS Foundational Security Best Practices                  │
│  • CIS AWS Foundations Benchmark                             │
│  • PCI DSS v3.2.1                                            │
│  • NIST 800-53                                               │
└──────────────────────────────────────────────────────────────┘
```

### 14.2 Fontes de Findings

| Fonte | O que envia |
|-------|-------------|
| GuardDuty | Threats e anomalias |
| Inspector | Vulnerabilidades (CVEs) |
| Macie | Dados sensíveis expostos |
| Firewall Manager | Non-compliance de WAF/Shield/SG |
| IAM Access Analyzer | Recursos compartilhados externamente |
| Config Rules | Não-conformidades de configuração |
| 3rd Party | Produtos do Marketplace (Qualys, Aqua, etc.) |

### 14.3 Security Standards (Automated Checks)

| Standard | Descrição | Checks |
|----------|-----------|--------|
| **AWS Foundational Best Practices** | Melhores práticas AWS | ~180 checks |
| **CIS Benchmark** | Center for Internet Security | ~50 checks |
| **PCI DSS** | Payment Card Industry | ~30 checks |
| **NIST 800-53** | Framework do governo dos EUA | ~200 checks |

### 14.4 Para o Exame

- **"Painel centralizado de segurança"** → Security Hub
- **"Verificar compliance PCI-DSS"** → Security Hub + PCI standard
- **"Agregar findings de múltiplas contas"** → Security Hub cross-account
- Requer **AWS Config habilitado** (para automated checks)
- Formato padrão: **ASFF (AWS Security Finding Format)**
- Automação: Security Hub → EventBridge → Lambda/SNS

---

## 15. Amazon Detective

### 15.1 Visão Geral

- **Investigação e análise** de segurança (pós-detecção)
- Usa **graph analytics** para correlacionar eventos
- Integra diretamente com GuardDuty findings
- Analisa: VPC Flow Logs, CloudTrail, EKS Audit Logs, GuardDuty findings
- Retenção: até 1 ano de dados

### 15.2 Fluxo de Trabalho

```
GuardDuty detecta ameaça ──► Security Hub agrega
                                    │
                                    ▼
                            Detective investiga
                                    │
                                    ▼
                         Visualizações em grafo:
                         • Quem fez o quê
                         • De onde veio
                         • Quais recursos afetados
                         • Timeline de eventos
                         • Relações entre entidades
```

### 15.3 Diferença: GuardDuty vs Detective

| | GuardDuty | Detective |
|-|-----------|-----------|
| **Função** | Detectar ameaças | Investigar ameaças |
| **Quando** | Primeiro (alerta) | Depois (análise) |
| **Output** | Findings (alertas) | Visualizações e correlações |
| **Analogia** | Alarme de incêndio | Investigador/perito |

### 15.4 Para o Exame

- **"Investigar a causa raiz de um finding do GuardDuty"** → Detective
- **"Visualizar relações entre recursos comprometidos"** → Detective
- Detective NÃO detecta — ele INVESTIGA após detecção

---

## 16. AWS Artifact

### 16.1 Visão Geral

- **Portal self-service** para relatórios de compliance da AWS
- Acesso sob demanda a documentos de auditoria e compliance
- **Sem custo** — disponível no Console AWS
- Dois componentes: Artifact Reports e Artifact Agreements

### 16.2 Relatórios Disponíveis

| Relatório | Descrição |
|-----------|-----------|
| **SOC 1, 2, 3** | System and Organization Controls (auditoria financeira e operacional) |
| **PCI DSS** | Payment Card Industry Data Security Standard |
| **ISO 27001/27017/27018** | Segurança da informação, cloud, privacidade |
| **FedRAMP** | Framework do governo dos EUA |
| **HIPAA** | Health Insurance Portability and Accountability |
| **NIST** | National Institute of Standards and Technology |
| **CSA STAR** | Cloud Security Alliance |

### 16.3 Artifact Agreements

- Aceitar acordos regulatórios (BAA, NDA) pela conta ou organização
- **BAA (Business Associate Addendum)**: necessário para HIPAA
- Pode aceitar para todas as contas via Organizations

### 16.4 Para o Exame

- **"Obter relatório SOC 2 da AWS"** → Artifact
- **"Comprovar compliance da AWS para auditores"** → Artifact
- **"Assinar BAA para HIPAA"** → Artifact Agreements
- Artifact é sobre compliance da **AWS**, não da sua aplicação

---

## 17. AWS Resource Access Manager (RAM)

### 17.1 Visão Geral

- Compartilha recursos AWS **entre contas** sem duplicar
- Funciona com AWS Organizations (sharing automático) ou convites
- Recursos compartilhados aparecem na conta destinatária como se fossem próprios

### 17.2 Recursos Compartilháveis

| Recurso | Use Case |
|---------|----------|
| **VPC Subnets** | Múltiplas contas lançam recursos na mesma subnet |
| **Transit Gateway** | Conectividade centralizada compartilhada |
| **Route 53 Resolver Rules** | DNS forwarding rules compartilhadas |
| **License Manager** | Licenças de software (BYOL) compartilhadas |
| **Aurora DB Clusters** | Compartilhar cluster Aurora entre contas |
| **CodeBuild Projects** | Compartilhar projetos de build |
| **EC2 Dedicated Hosts** | Compartilhar hosts dedicados |
| **AWS Outposts** | Compartilhar outposts |
| **ACM Private CA** | Compartilhar CA privada |
| **Glue Catalog** | Compartilhar databases e tables |

### 17.3 VPC Subnet Sharing (Caso Mais Comum no Exame)

```
┌──────────────────────────────────────────────────────────┐
│         VPC SUBNET SHARING via RAM                        │
│                                                          │
│  Account A (Owner):                                      │
│  ┌────────────────────────────────┐                      │
│  │  VPC 10.0.0.0/16              │                      │
│  │  ┌──────────────────────────┐ │                      │
│  │  │  Subnet 10.0.1.0/24     │ │  ← Shared via RAM    │
│  │  │                          │ │                      │
│  │  │  EC2 (Account A) ●      │ │                      │
│  │  │  EC2 (Account B) ●      │ │  ← Account B usa     │
│  │  │  RDS (Account C) ●      │ │  ← Account C usa     │
│  │  │                          │ │                      │
│  │  └──────────────────────────┘ │                      │
│  └────────────────────────────────┘                      │
│                                                          │
│  • Cada conta gerencia SEUS recursos na subnet           │
│  • Owner gerencia VPC, subnets, route tables, NACLs      │
│  • Participantes NÃO podem modificar a subnet/VPC        │
│  • Security Groups são por conta (isolamento)            │
└──────────────────────────────────────────────────────────┘
```

### 17.4 Para o Exame

- **"Compartilhar subnet entre contas na mesma Organization"** → RAM
- **"Transit Gateway centralizado para múltiplas contas"** → RAM
- **"Reduzir número de VPCs mantendo isolamento de contas"** → RAM + Subnet Sharing
- RAM com Organizations: sharing automático (sem aceitar convite)
- RAM sem Organizations: convite precisa ser aceito

---

## 18. AWS Directory Service

### 18.1 Opções Disponíveis

| Serviço | O que é | Quando usar |
|---------|---------|-------------|
| **AWS Managed Microsoft AD** | AD real (full Microsoft AD) gerenciado pela AWS | Precisa de AD completo na AWS, trust com on-premises AD |
| **AD Connector** | Proxy/redirect para AD on-premises existente | Já tem AD on-premises, não quer replicar |
| **Simple AD** | AD compatível básico (Samba 4) | AD simples, barato, sem necessidade de trust |

### 18.2 AWS Managed Microsoft AD

```
┌─────────────────────────────────────────────────────────┐
│              AWS MANAGED MICROSOFT AD                     │
│                                                          │
│  ┌──────────────┐         ┌──────────────┐              │
│  │ Domain       │  Trust  │ On-premises  │              │
│  │ Controllers  │◄───────►│ AD           │              │
│  │ (Multi-AZ)   │         │              │              │
│  └──────┬───────┘         └──────────────┘              │
│         │                                                │
│    Suporta:                                              │
│    • MFA (RADIUS)                                        │
│    • Trust relationships (forest, external)              │
│    • Group Policies                                      │
│    • LDAP / Kerberos                                     │
│    • Schema extensions                                   │
│    • SSO para aplicações AWS                             │
│    • Integração com RDS (SQL Server, Oracle)             │
│    • Integração com WorkSpaces, QuickSight               │
└─────────────────────────────────────────────────────────┘
```

### 18.3 AD Connector

- **Proxy** que redireciona requests ao AD on-premises
- Não armazena dados de diretório na AWS
- Requer conectividade (VPN ou Direct Connect)
- Suporta: MFA, join de EC2 ao domínio, SSO
- **Não suporta:** trust relationships, SQL Server integration

### 18.4 Simple AD

- AD básico compatível (Samba 4)
- Até 5.000 usuários (small) ou 50.000 (large)
- **Sem trust** com AD on-premises
- Sem MFA
- Custo mais baixo
- Use case: Linux workloads que precisam de LDAP básico

### 18.5 Tabela de Decisão

| Cenário | Solução |
|---------|---------|
| Precisa de AD real na AWS + trust com on-prem | **AWS Managed AD** |
| Já tem AD on-prem, quer autenticar na AWS sem replicar | **AD Connector** |
| AD simples sem integração on-prem, custo baixo | **Simple AD** |
| RDS SQL Server com Windows Authentication | **AWS Managed AD** |
| WorkSpaces com autenticação AD on-prem | **AD Connector** ou **AWS Managed AD com trust** |
| Mais de 5.000 usuários e precisa de AD features | **AWS Managed AD** |

---

## 19. Palavras-Chave da Prova SAA-C03 — Segurança

| # | Cenário / Palavra-chave | Resposta |
|---|------------------------|----------|
| 1 | "Criptografar dados maiores que 4KB" | **Envelope Encryption** (GenerateDataKey) |
| 2 | "Rotação automática de credenciais de banco" | **Secrets Manager** |
| 3 | "Armazenar configuração sem custo" | **SSM Parameter Store** (Standard tier) |
| 4 | "FIPS 140-2 Level 3" | **CloudHSM** |
| 5 | "Hardware dedicado para chaves criptográficas" | **CloudHSM** |
| 6 | "Certificado SSL gratuito para ALB" | **ACM** (Certificate Manager) |
| 7 | "Certificado para CloudFront" | **ACM em us-east-1** |
| 8 | "Proteger contra SQL injection" | **WAF** (SQL injection rule) |
| 9 | "Rate limiting na camada 7" | **WAF** (rate-based rule) |
| 10 | "Proteção contra DDoS sem custo" | **Shield Standard** (automático) |
| 11 | "DDoS Response Team e cost protection" | **Shield Advanced** |
| 12 | "Detectar cryptocurrency mining em EC2" | **GuardDuty** |
| 13 | "Descobrir PII em S3" | **Macie** |
| 14 | "Vulnerability scanning de containers ECR" | **Inspector** |
| 15 | "Painel centralizado de compliance" | **Security Hub** |
| 16 | "Investigar causa raiz de finding de segurança" | **Detective** |
| 17 | "Relatório SOC 2 da AWS" | **Artifact** |
| 18 | "Compartilhar subnet entre contas" | **RAM** (Resource Access Manager) |
| 19 | "Gerenciar WAF em todas as contas da org" | **Firewall Manager** |
| 20 | "Encrypt em outra região sem cross-region API call" | **KMS Multi-Region Keys** |
| 21 | "Chave que nunca sai da AWS (symmetric)" | **KMS** (symmetric key material nunca exportado) |
| 22 | "Encrypt com chave do cliente (S3)" | **SSE-C** |
| 23 | "Auditoria de cada acesso a chave de criptografia" | **SSE-KMS** (CloudTrail) |
| 24 | "AD na AWS com trust para on-premises" | **AWS Managed Microsoft AD** |
| 25 | "Proxy para AD on-premises existente" | **AD Connector** |
| 26 | "Bloquear acesso de países específicos" | **WAF** (Geo Match rule) ou **CloudFront Geo Restriction** |
| 27 | "Secrets replication para DR multi-region" | **Secrets Manager** (multi-region replication) |
| 28 | "Detectar bucket S3 público" | **GuardDuty** (S3 findings) ou **Macie** (policy findings) |
| 29 | "Oracle TDE com chaves em hardware" | **CloudHSM** |
| 30 | "Custom key store no KMS com hardware dedicado" | **CloudHSM** (KMS Custom Key Store) |
| 31 | "Parameter expiration policy" | **SSM Parameter Store Advanced** (parameter policies) |
| 32 | "Certificado privado para mTLS entre microserviços" | **ACM Private CA** |
| 33 | "Network reachability assessment" | **Inspector** |
| 34 | "Automatic remediation de Security Group violações" | **Firewall Manager** |
| 35 | "KMS throttling, muitas chamadas" | **DEK caching** (AWS Encryption SDK) ou **SSE-S3** |

---

## Resumo Visual — Serviços de Segurança AWS

```
┌──────────────────────────────────────────────────────────────────────┐
│                    SEGURANÇA AWS — MAPA MENTAL                        │
│                                                                      │
│  CRIPTOGRAFIA              PROTEÇÃO               DETECÇÃO           │
│  ════════════              ════════               ════════            │
│  • KMS                     • WAF                  • GuardDuty        │
│  • CloudHSM               • Shield               • Inspector        │
│  • ACM                     • Firewall Manager     • Macie            │
│                                                   • Security Hub     │
│  GERENCIAMENTO             COMPLIANCE             • Detective        │
│  DE SEGREDOS               ══════════                                │
│  ══════════════            • Artifact             COMPARTILHAMENTO   │
│  • Secrets Manager         • Security Hub         ════════════════   │
│  • Parameter Store           (standards)          • RAM              │
│                                                                      │
│  IDENTIDADE (ver iam.md)                                             │
│  ═══════════════════════                                             │
│  • IAM, Identity Center, Organizations, SCPs                         │
│                                                                      │
│  DIRETÓRIO                                                           │
│  ═════════                                                           │
│  • AWS Managed AD                                                    │
│  • AD Connector                                                      │
│  • Simple AD                                                         │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Dicas Finais para o Exame

1. **KMS Key Policy é obrigatória** — sem ela, mesmo root não acessa a chave
2. **Envelope Encryption** é o padrão para dados > 4KB (todos os serviços usam)
3. **SSE-KMS gera chamada ao KMS por objeto** — cuidado com throttling em buckets com alto throughput
4. **CloudHSM = FIPS 140-2 Level 3** — sempre que o exame mencionar esse nível
5. **Secrets Manager = rotação automática** — se mencionar rotação de credentials de DB
6. **Parameter Store Standard = gratuito** — quando custo é prioridade e não precisa de rotação
7. **ACM para CloudFront = us-east-1** — sempre!
8. **WAF protege camada 7** — SQL injection, XSS, rate limiting
9. **Shield Standard é gratuito e automático** — já protege todos os clientes
10. **Firewall Manager = Organizations** — gerenciamento centralizado de WAF/Shield/SG
11. **GuardDuty detecta, Detective investiga** — não confundir
12. **Inspector = CVEs, GuardDuty = threats** — vulnerability vs threat
13. **Macie = dados sensíveis no S3** — PII, cartões, credentials
14. **Security Hub = painel central** — agrega tudo, verifica compliance
15. **RAM = compartilhar recursos** — subnet sharing é o caso mais comum
