# CloudFront + Global Accelerator — Guia Completo SAA-C03

---

## 1. Conceitos Fundamentais

### 1.1 O que é o Amazon CloudFront

O Amazon CloudFront é a **CDN (Content Delivery Network)** global da AWS. Ele distribui
conteúdo estático e dinâmico para usuários finais com baixa latência, utilizando uma
rede de pontos de presença (PoPs) espalhados pelo mundo.

### 1.2 Infraestrutura Global

| Componente              | Quantidade | Função                                              |
|-------------------------|-----------|-----------------------------------------------------|
| Edge Locations          | 400+      | Servem conteúdo cacheado ao usuário final           |
| Regional Edge Caches    | ~13       | Camada intermediária com cache maior e mais durável  |
| Origins                 | N/A       | Fonte original do conteúdo (S3, ALB, EC2, HTTP)     |

- **Edge Locations** ficam em grandes cidades e metrópoles globais
- **Regional Edge Caches** ficam entre as Edge Locations e a Origin
- Regional Edge Caches possuem cache MAIOR que Edge Locations
- Se o conteúdo não está na Edge, vai ao Regional Edge Cache antes da Origin

### 1.3 Diagrama de Fluxo — Como Funciona o Caching

```
┌──────────┐         ┌──────────────────┐        ┌─────────────────────┐        ┌──────────┐
│  Usuário │──req──▶ │  Edge Location   │──miss─▶│ Regional Edge Cache │──miss─▶│  Origin  │
│  (client)│◀──res── │  (400+ PoPs)     │◀──hit──│   (~13 globais)     │◀──res──│(S3/ALB/..)│
└──────────┘         └──────────────────┘        └─────────────────────┘        └──────────┘
                            │                              │
                         cache HIT?                     cache HIT?
                         SIM → retorna                  SIM → retorna + popula Edge
                         NÃO → próximo nível           NÃO → busca na Origin
```

### 1.4 Fluxo Detalhado de uma Requisição

1. Usuário faz request DNS → CloudFront retorna IP da Edge Location mais próxima
2. Edge Location verifica se tem o objeto em cache
3. **Cache HIT** → retorna imediatamente (latência mínima)
4. **Cache MISS** → Edge consulta o Regional Edge Cache
5. Se Regional tem → retorna para Edge (que armazena em cache) → retorna ao usuário
6. Se Regional não tem → busca na Origin configurada
7. Origin retorna → Regional armazena → Edge armazena → usuário recebe
8. Requisições subsequentes servidas do cache (até TTL expirar)

### 1.5 Benefícios Principais

- Redução de latência global (conteúdo próximo ao usuário)
- Proteção contra DDoS (integração com AWS Shield Standard gratuito)
- Redução de carga na origin (menos requests chegam ao backend)
- Suporte a HTTPS com certificado ACM gratuito
- Compressão automática (gzip, Brotli)

---

## 2. Origins Suportadas

### 2.1 Tipos de Origin

| Origin                | Protocolo       | Uso Principal                              | OAC Suportado |
|-----------------------|----------------|--------------------------------------------|---------------|
| S3 Bucket             | S3 Protocol    | Assets estáticos, arquivos, SPA            | ✅ Sim         |
| S3 Static Website     | HTTP/HTTPS     | Website estático hospedado no S3           | ❌ (público)   |
| ALB                   | HTTP/HTTPS     | APIs, aplicações dinâmicas                 | ❌ N/A         |
| EC2                   | HTTP/HTTPS     | Servidor web direto                        | ❌ N/A         |
| Custom HTTP Origin    | HTTP/HTTPS     | Qualquer servidor web na internet          | ❌ N/A         |
| MediaStore            | HTTPS          | Streaming de vídeo ao vivo                 | ✅ Sim         |
| MediaPackage          | HTTPS          | Empacotamento de vídeo VOD/Live            | ❌ N/A         |

### 2.2 S3 como Origin

- **S3 REST API endpoint** (recomendado): `bucket-name.s3.region.amazonaws.com`
  - Suporta OAC para acesso privado
  - Suporta SSE-S3 e SSE-KMS
- **S3 Website endpoint**: `bucket-name.s3-website-region.amazonaws.com`
  - Tratado como Custom HTTP Origin
  - Bucket DEVE ser público (sem OAC)
  - Suporta redirecionamentos e index document

### 2.3 ALB como Origin

- ALB **DEVE ser público** (internet-facing)
- Security Group do ALB deve permitir IPs das Edge Locations do CloudFront
- AWS publica a lista de IPs em: `https://ip-ranges.amazonaws.com/ip-ranges.json`
- CloudFront pode adicionar custom headers para validar que request veio dele

### 2.4 EC2 como Origin

- EC2 **DEVE ter IP público** (ou estar atrás de um ALB público)
- Security Group deve permitir IPs de todas as Edge Locations
- Alternativa recomendada: EC2 atrás de ALB para simplificar SG

---

## 3. OAC vs OAI — Controle de Acesso à Origin S3

### 3.1 Visão Geral

O objetivo é permitir que **apenas o CloudFront** acesse o bucket S3 privado,
impedindo acesso direto pela URL do S3.

### 3.2 Tabela Comparativa Completa

| Critério                        | OAC (Origin Access Control)        | OAI (Origin Access Identity)       |
|---------------------------------|------------------------------------|------------------------------------|
| Status                          | ✅ Atual e recomendado              | ⚠️ Legado (deprecated)             |
| Suporte a SSE-S3                | ✅ Sim                              | ✅ Sim                              |
| Suporte a SSE-KMS               | ✅ Sim                              | ❌ Não                              |
| Regiões S3 suportadas           | ✅ Todas (incluindo opt-in)         | ❌ Algumas regiões não suportadas   |
| Suporte a S3 bucket             | ✅ Sim                              | ✅ Sim                              |
| Suporte a MediaStore            | ✅ Sim                              | ❌ Não                              |
| Suporte a Lambda Function URL   | ✅ Sim                              | ❌ Não                              |
| Assinatura de requests          | SigV4                              | Identidade especial                |
| Granularidade                   | Por distribution ou por behavior   | Por distribution                   |
| Dynamic requests (PUT/DELETE)   | ✅ Sim                              | ❌ Limitado                         |
| Bucket Policy necessária        | ✅ Obrigatória                      | ✅ Obrigatória                      |
| Facilidade de auditoria         | ✅ CloudTrail nativo                | ❌ Limitado                         |

### 3.3 Bucket Policy para OAC (Exemplo)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontServicePrincipalReadOnly",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::meu-bucket/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::111122223333:distribution/EDFDVBD6EXAMPLE"
        }
      }
    }
  ]
}
```

### 3.4 OAC com SSE-KMS

Para funcionar com SSE-KMS, a KMS Key Policy deve permitir:
- `kms:Decrypt` para o service principal `cloudfront.amazonaws.com`
- Condition com o ARN da distribution

---

## 4. Cache Behaviors

### 4.1 Conceito

Cache Behaviors são **regras** que definem como o CloudFront processa requests
baseando-se no path pattern da URL. Cada distribution tem:

- **1 Default Cache Behavior** (`*`) — obrigatório, pega tudo que não match em outros
- **0 ou mais Cache Behaviors adicionais** — com path patterns específicos

### 4.2 Configurações por Behavior

| Configuração               | Opções                                                    |
|---------------------------|-----------------------------------------------------------|
| Path Pattern              | `/api/*`, `/images/*.jpg`, `/static/*`                    |
| Origin ou Origin Group    | Qual origin atende esse path                              |
| Viewer Protocol Policy    | HTTP and HTTPS / Redirect HTTP to HTTPS / HTTPS Only      |
| Allowed HTTP Methods      | GET,HEAD / GET,HEAD,OPTIONS / ALL (inclui POST,PUT,DELETE) |
| Cache Policy              | Qual policy de cache usar                                 |
| Origin Request Policy     | Quais headers/cookies enviar à origin                     |
| Response Headers Policy   | Headers de segurança (CORS, HSTS, etc.)                   |
| Function Associations     | CloudFront Functions ou Lambda@Edge                       |
| Compress Objects          | Sim/Não (gzip + Brotli)                                  |
| Restrict Viewer Access    | Sim (Signed URL/Cookie) / Não                             |

### 4.3 Precedência de Path Patterns

- Behaviors são avaliados **de cima para baixo** (ordem de precedência)
- O **primeiro match** ganha
- Default (`*`) é sempre o último
- Patterns são case-sensitive
- Suportam wildcards: `*` (qualquer coisa) e `?` (um caractere)

**Exemplo de precedência:**
```
1. /api/v2/*          → Origin: ALB-v2
2. /api/*             → Origin: ALB-v1
3. /static/*.css      → Origin: S3-assets (cache 30 dias)
4. /static/*          → Origin: S3-assets (cache 7 dias)
5. * (default)        → Origin: S3-website
```

---

## 5. Cache Policy e Origin Request Policy

### 5.1 Separação de Concerns

A AWS separou em duas policies distintas:

| Policy                | Propósito                                           |
|-----------------------|----------------------------------------------------|
| **Cache Policy**      | Define o que compõe a **cache key**                 |
| **Origin Request Policy** | Define o que é **encaminhado à origin**        |

Isso permite cachear eficientemente enquanto envia informações necessárias à origin.

### 5.2 Cache Policy — Detalhes

A Cache Key é composta por:
- URL (sempre incluída)
- Headers (opcional — lista explícita)
- Query Strings (nenhuma / lista / todas / todas exceto lista)
- Cookies (nenhum / lista / todos / todos exceto lista)

**Quanto MAIS itens na cache key → MENOR cache hit ratio**

| Managed Cache Policy        | Comportamento                                   |
|----------------------------|------------------------------------------------|
| CachingOptimized           | Ignora headers/cookies/query strings            |
| CachingOptimizedForUncompressed | Igual acima, sem compressão               |
| CachingDisabled            | TTL = 0, sem cache                             |
| Elemental-MediaPackage     | Otimizada para streaming                        |

### 5.3 Origin Request Policy — Detalhes

Define quais informações são **encaminhadas à origin** (sem afetar cache key):
- Headers adicionais
- Cookies adicionais
- Query Strings adicionais

| Managed Origin Request Policy | Comportamento                               |
|------------------------------|---------------------------------------------|
| AllViewer                    | Envia todos headers/cookies/QS do viewer    |
| AllViewerExceptHostHeader    | Todos exceto Host (útil para ALB)           |
| CORS-S3Origin                | Envia headers CORS para S3                  |
| UserAgentRefererHeaders      | Envia User-Agent e Referer                  |

### 5.4 Exemplo Prático — API com Autenticação

```
Cache Policy:        Query strings = "page,limit" (para paginar)
                     Headers = nenhum
                     Cookies = nenhum

Origin Request Policy: Headers = "Authorization, X-Custom-Header"
                       Cookies = todos
                       Query strings = todas
```

Resultado: Cache key usa apenas page/limit, mas a origin recebe tudo para autenticação.

---

## 6. TTL e Invalidation

### 6.1 Hierarquia de TTL

O CloudFront determina quanto tempo manter um objeto em cache seguindo esta lógica:

```
┌─────────────────────────────────────────────────────────────────────┐
│  Origin envia Cache-Control / Expires header?                       │
│                                                                     │
│  SIM → TTL = valor do header (respeitando min/max TTL da policy)    │
│  NÃO → TTL = Default TTL da Cache Policy                           │
└─────────────────────────────────────────────────────────────────────┘
```

### 6.2 Configurações de TTL na Cache Policy

| Parâmetro    | Default (CachingOptimized) | Descrição                                    |
|-------------|---------------------------|----------------------------------------------|
| Minimum TTL | 1 segundo                 | Piso: nunca cacheia por menos que isso        |
| Maximum TTL | 31.536.000s (365 dias)    | Teto: nunca cacheia por mais que isso         |
| Default TTL | 86.400s (24 horas)        | Usado quando origin não envia cache headers   |

### 6.3 Headers de Cache da Origin

| Header                          | Exemplo                        | Efeito                          |
|--------------------------------|-------------------------------|--------------------------------|
| `Cache-Control: max-age=3600`  | Cache por 1 hora              | TTL = 3600s (se dentro do range)|
| `Cache-Control: s-maxage=7200` | Cache compartilhado 2h        | Prioridade sobre max-age para CDN|
| `Cache-Control: no-cache`      | Sempre revalidar              | CloudFront revalida com origin  |
| `Cache-Control: no-store`      | Não cachear                   | TTL efetivo = Minimum TTL       |
| `Expires: Thu, 01 Dec 2025...` | Data absoluta de expiração    | Usado se Cache-Control ausente  |

### 6.4 Cache Invalidation

Invalidation força a remoção de objetos do cache antes do TTL expirar.

| Aspecto           | Detalhes                                               |
|-------------------|--------------------------------------------------------|
| Custo             | Primeiros 1.000 paths/mês: GRÁTIS. Depois: $0.005/path|
| Tempo             | Leva alguns minutos para propagar globalmente          |
| Wildcards         | `/*` invalida tudo, `/images/*` invalida diretório     |
| Contagem          | `/images/*` = 1 path (wildcard conta como 1)           |
| Alternativa       | Versionamento de arquivo (`app-v2.js`) é mais eficiente|

### 6.5 Boas Práticas de Cache

- Use **versionamento de objetos** (fingerprinting) em vez de invalidation
  - Ex: `style-abc123.css` em vez de `style.css`
- Configure TTL longo para assets estáticos (JS, CSS, imagens)
- Configure TTL curto ou 0 para conteúdo dinâmico (APIs)
- Use `Cache-Control: no-cache` para conteúdo que precisa revalidação

---

## 7. Geo Restriction (Restrição Geográfica)

### 7.1 Tipos de Restrição

| Tipo          | Comportamento                                           |
|---------------|--------------------------------------------------------|
| **Allowlist** | Apenas países da lista PODEM acessar                    |
| **Blocklist** | Países da lista são BLOQUEADOS (demais podem acessar)   |
| **Nenhum**    | Sem restrição geográfica                                |

### 7.2 Como Funciona

- Usa banco de dados GeoIP **built-in** (baseado no IP do viewer)
- CloudFront retorna **HTTP 403 Forbidden** para países bloqueados
- Resolução por **país** (não por estado/cidade)
- Usa códigos de país ISO 3166-1 alpha-2 (BR, US, DE, etc.)

### 7.3 Geo Restriction vs 3rd Party GeoIP

| Aspecto              | Built-in CloudFront        | 3rd Party (MaxMind, etc.)     |
|---------------------|---------------------------|-------------------------------|
| Granularidade       | País apenas               | País, estado, cidade, CEP     |
| Implementação       | Console/API (simples)     | Lambda@Edge + banco GeoIP     |
| Custo adicional     | Nenhum                    | Custo do Lambda + licença DB  |
| Precisão            | Boa (nível país)          | Pode ser mais granular        |
| Customização        | Limitada                  | Total (lógica custom)         |

### 7.4 Caso de Uso na Prova

> "Empresa precisa restringir acesso a conteúdo apenas para usuários no Brasil e Portugal"
> → Geo Restriction com **Allowlist** contendo BR e PT

---

## 8. Signed URLs vs Signed Cookies

### 8.1 Propósito

Restringir acesso a conteúdo **privado** distribuído pelo CloudFront.
Apenas usuários com URL/Cookie assinados válidos podem acessar.

### 8.2 Tabela Comparativa Completa

| Critério                    | Signed URL                          | Signed Cookie                       |
|-----------------------------|-------------------------------------|-------------------------------------|
| Escopo                      | **1 arquivo** por URL               | **Múltiplos arquivos** (path)       |
| Formato                     | URL com parâmetros de assinatura    | Cookies Set-Cookie no browser       |
| Compatibilidade             | Qualquer client HTTP                | Apenas clients com suporte a cookies|
| Uso típico                  | Download individual, streaming HLS  | Área premium, site inteiro privado  |
| Mudança de URL              | Sim (URL diferente da original)     | Não (URL original mantida)          |
| RTMP (legado)               | Obrigatório (era o único método)    | Não suportado                       |
| Expiração                   | Timestamp na URL                    | Timestamp no cookie                 |
| IP restriction              | Opcional (CIDR na policy)           | Opcional (CIDR na policy)           |
| Custom policy               | Sim                                 | Sim (obrigatório para cookies)      |

### 8.3 Trusted Key Groups vs Trusted Signers (Legado)

| Aspecto                 | Trusted Key Groups (Recomendado)    | Trusted Signers (Legado)            |
|-------------------------|-------------------------------------|-------------------------------------|
| Gerenciamento de chaves | Via API do CloudFront               | Root account da AWS                 |
| Tipo de chave           | RSA key pair (você gera)            | CloudFront Key Pairs (root only)    |
| Rotação de chaves       | Fácil (múltiplas chaves por grupo)  | Difícil (requer root login)         |
| IAM permissions         | Sim (controle fino)                 | Não (root apenas)                   |
| Múltiplos signers       | Sim (múltiplos key groups)          | Limitado                            |
| Status                  | ✅ Recomendado                       | ⚠️ Legado                           |

### 8.4 Fluxo de Assinatura

```
┌──────────┐       ┌──────────────┐       ┌────────────────┐       ┌──────────┐
│  Usuário │──1──▶ │  Aplicação   │──2──▶  │ Gera Signed    │──3──▶ │CloudFront│
│          │◀──4── │  Backend     │        │ URL/Cookie     │       │  Edge    │
└──────────┘       └──────────────┘       └────────────────┘       └──────────┘

1. Usuário autentica na aplicação
2. App verifica permissão e gera signed URL/cookie com private key
3. Usuário acessa CloudFront com a signed URL/cookie
4. CloudFront valida assinatura com public key → serve conteúdo
```

### 8.5 CloudFront Signed URL vs S3 Pre-Signed URL

| Aspecto              | CloudFront Signed URL              | S3 Pre-Signed URL                  |
|---------------------|------------------------------------|------------------------------------|
| Rede                | CDN (Edge Location)                | Direto ao S3                       |
| Performance         | Melhor (cache + proximidade)       | Depende da região do bucket        |
| Expiração           | Configurável (minutos a anos)      | Máximo 7 dias (com IAM role)       |
| Funcionalidades     | Geo restriction, IP restriction    | Apenas acesso ao objeto            |
| Custo               | CloudFront data transfer           | S3 data transfer                   |

---

## 9. CloudFront Functions vs Lambda@Edge

### 9.1 Tabela Comparativa COMPLETA

| Critério                  | CloudFront Functions               | Lambda@Edge                         |
|---------------------------|------------------------------------|------------------------------------|
| **Runtime**               | JavaScript (ECMAScript 5.1)        | Node.js, Python                    |
| **Timeout**               | < 1 ms                             | 5s (viewer) / 30s (origin)         |
| **Memória máxima**        | 2 MB                               | 128 MB (viewer) / 10 GB (origin)   |
| **Tamanho do pacote**     | 10 KB                              | 1 MB (viewer) / 50 MB (origin)     |
| **Eventos suportados**    | Viewer Request, Viewer Response     | Viewer Request/Response + Origin Request/Response |
| **Acesso à rede**         | ❌ Não                              | ✅ Sim (HTTP calls, DynamoDB, etc.) |
| **Acesso ao body**        | ❌ Não                              | ✅ Sim (leitura e modificação)      |
| **File system access**    | ❌ Não                              | ✅ Sim (/tmp)                       |
| **Escala**                | Milhões de req/s                   | Milhares de req/s                  |
| **Custo**                 | ~$0.10 por 1M invocações           | ~$0.60 por 1M + duração            |
| **Deploy**                | Edge Locations (segundos)          | Réplicas regionais (minutos)       |
| **Região de criação**     | Qualquer                           | us-east-1 apenas                   |
| **Logs**                  | CloudWatch (limitado)              | CloudWatch (em cada região)        |
| **KVS (Key Value Store)** | ✅ Sim (CloudFront KeyValueStore)   | ❌ Não (usa DynamoDB/S3)           |

### 9.2 Eventos no Ciclo de Vida da Request

```
         Viewer Request    Origin Request    Origin Response    Viewer Response
              │                  │                  │                  │
  Usuário ──▶ │ ──▶ Cache ──▶   │ ──▶ Origin ──▶   │ ──▶ Cache ──▶   │ ──▶ Usuário
              │                  │                  │                  │
  CF Func: ───┤                  │                  │                  ├─── CF Func
  Lambda@E: ──┤──────────────────┤──────────────────┤──────────────────┤─── Lambda@E
```

### 9.3 Casos de Uso — CloudFront Functions

- Manipulação de headers (adicionar, remover, modificar)
- URL rewrites e redirects simples
- Normalização de cache key (lowercase, sort query strings)
- Validação de token JWT simples (sem rede)
- A/B testing baseado em header/cookie
- Adicionar security headers (HSTS, X-Frame-Options)

### 9.4 Casos de Uso — Lambda@Edge

- Autenticação/autorização complexa (consulta a banco/API)
- Geração de conteúdo dinâmico na edge
- Resize de imagens on-the-fly (Origin Response)
- Bot detection avançado
- A/B testing com lógica complexa (consulta a feature flags)
- Manipulação do body da request/response
- Redirect baseado em geolocalização granular (cidade/estado)
- SEO: Server-Side Rendering na edge

---

## 10. Field-Level Encryption

### 10.1 Conceito

Field-Level Encryption adiciona uma camada **extra** de proteção para dados sensíveis
específicos dentro de requisições POST. Os dados são criptografados na Edge Location
e só podem ser descriptografados pela aplicação backend que possui a private key.

### 10.2 Como Funciona

```
┌────────┐  HTTPS   ┌───────────────┐  HTTPS (campo encrypted)  ┌──────────────┐
│ Client │────────▶ │ Edge Location │──────────────────────────▶ │ Origin (ALB) │
│        │          │ Encrypts field│                             │              │
└────────┘          └───────────────┘                             └──────┬───────┘
                                                                         │
                                                                         ▼
                                                                  ┌──────────────┐
                                                                  │  App Server  │
                                                                  │ (tem private │
                                                                  │  key p/ dec) │
                                                                  └──────────────┘
```

### 10.3 Características

| Aspecto                | Detalhes                                               |
|------------------------|--------------------------------------------------------|
| Algoritmo              | RSA com OAEP padding                                   |
| Campos protegidos      | Até 10 campos por request                              |
| Tipo de request        | POST apenas (form data)                                |
| Camada extra           | Funciona SOBRE HTTPS (dupla proteção)                  |
| Quem descriptografa    | Apenas a aplicação com a private key                   |
| Intermediários         | ALB, web servers internos NÃO conseguem ler            |

### 10.4 Caso de Uso na Prova

> "Aplicação processa dados de cartão de crédito. Mesmo administradores do web server
> intermediário não devem ver o número do cartão."
> → Field-Level Encryption protege o campo do cartão da edge até o app final.

---

## 11. CloudFront + S3 — Cenários de Integração

### 11.1 S3 REST API Endpoint vs S3 Website Endpoint

| Aspecto                    | S3 REST API Endpoint                  | S3 Static Website Endpoint            |
|----------------------------|---------------------------------------|---------------------------------------|
| URL formato                | `bucket.s3.region.amazonaws.com`      | `bucket.s3-website-region.amazonaws.com`|
| OAC suportado              | ✅ Sim (bucket privado)                | ❌ Não (bucket deve ser público)       |
| HTTPS Origin → CloudFront  | ✅ Sim                                 | ❌ HTTP apenas (origin)                |
| Index document             | ❌ Não                                 | ✅ Sim (index.html automático)         |
| Error document             | ❌ Não (retorna XML error)             | ✅ Sim (custom error page)             |
| Redirects                  | ❌ Não                                 | ✅ Sim (redirect rules)                |
| Caso de uso                | Assets privados via CloudFront        | Website estático completo             |

### 11.2 Configuração para Bucket Privado com OAC

1. Criar distribution com origin = S3 REST API endpoint
2. Criar OAC e associar à distribution
3. Configurar Bucket Policy permitindo `cloudfront.amazonaws.com`
4. Remover qualquer acesso público do bucket
5. Testar: acesso direto ao S3 → 403, acesso via CloudFront → 200

### 11.3 SPA (Single Page Application) no CloudFront + S3

- Usar S3 REST API endpoint com OAC (privado)
- Configurar Custom Error Response: 403/404 → retorna `/index.html` com HTTP 200
- Isso permite que o framework SPA (React, Vue, Angular) faça client-side routing

---

## 12. CloudFront + ALB/EC2

### 12.1 Arquitetura com ALB

```
┌────────┐       ┌──────────────┐       ┌─────────────┐       ┌──────────────┐
│ Users  │──────▶│  CloudFront  │──────▶│  ALB        │──────▶│ EC2 (private)│
│(global)│       │  (Edge)      │       │  (público)  │       │ Target Group │
└────────┘       └──────────────┘       └─────────────┘       └──────────────┘
```

### 12.2 Requisitos de Security Group

| Componente | Security Group deve permitir                              |
|------------|----------------------------------------------------------|
| ALB        | Inbound: IPs das Edge Locations do CloudFront (port 80/443)|
| EC2        | Inbound: Security Group do ALB (port da aplicação)        |

### 12.3 Validação de Origin (Custom Header)

Para garantir que requests vêm apenas do CloudFront (e não direto ao ALB):

1. CloudFront adiciona header customizado: `X-Custom-Header: secret-value`
2. ALB listener rule verifica presença do header
3. Requests sem o header são rejeitadas (return 403)

### 12.4 EC2 Direto como Origin (Sem ALB)

| Requisito                         | Motivo                                        |
|-----------------------------------|-----------------------------------------------|
| EC2 precisa de IP público         | CloudFront precisa alcançar via internet       |
| SG permite IPs de todas as edges  | Lista grande e muda frequentemente             |
| Sem health check integrado        | CloudFront não tem health check nativo para EC2|

**Recomendação:** Usar ALB na frente do EC2 para simplificar e ter health checks.

---

## 13. CloudFront Logs

### 13.1 Standard Logs (Access Logs)

| Aspecto           | Detalhes                                               |
|-------------------|--------------------------------------------------------|
| Destino           | S3 bucket                                              |
| Formato           | Arquivo de log com campos tabulados                    |
| Frequência        | A cada poucos minutos (não real-time)                  |
| Custo             | Sem custo adicional (apenas armazenamento S3)          |
| Conteúdo          | IP, URI, status code, bytes, referrer, user-agent, etc.|
| Latência          | Até 24h de atraso possível                             |
| Ativação          | Por distribution                                       |

### 13.2 Real-Time Logs

| Aspecto           | Detalhes                                               |
|-------------------|--------------------------------------------------------|
| Destino           | Kinesis Data Streams                                   |
| Latência          | Segundos (near real-time)                              |
| Custo             | Custo do Kinesis + campos selecionados                 |
| Sampling          | Configurável (1% a 100% das requests)                  |
| Conteúdo          | Campos selecionáveis (mais opções que standard)        |
| Processamento     | Kinesis → Lambda/Firehose → S3/OpenSearch/etc.         |
| Ativação          | Por Cache Behavior (granular)                          |

### 13.3 Diagrama de Real-Time Logs

```
CloudFront ──▶ Kinesis Data Streams ──▶ Kinesis Data Firehose ──▶ S3 / OpenSearch
                                    └──▶ Lambda (processamento) ──▶ DynamoDB
```

---

## 14. Price Classes

### 14.1 Conceito

Price Classes permitem reduzir custos limitando as Edge Locations usadas pela distribution.

### 14.2 Comparativo

| Price Class | Regiões incluídas                                          | Custo    | Cobertura |
|-------------|-----------------------------------------------------------|----------|-----------|
| **All**     | Todas as Edge Locations globais                            | Mais alto| Máxima    |
| **200**     | Maioria das regiões (exclui as mais caras)                 | Médio    | Boa       |
| **100**     | Apenas América do Norte + Europa                           | Mais baixo| Limitada  |

### 14.3 Detalhes das Regiões

| Região                         | All | 200 | 100 |
|--------------------------------|-----|-----|-----|
| América do Norte               | ✅  | ✅  | ✅  |
| Europa                         | ✅  | ✅  | ✅  |
| Ásia (Japão, Hong Kong, etc.)  | ✅  | ✅  | ❌  |
| Austrália e Nova Zelândia      | ✅  | ✅  | ❌  |
| América do Sul                 | ✅  | ✅  | ❌  |
| Oriente Médio                  | ✅  | ✅  | ❌  |
| África                         | ✅  | ❌  | ❌  |
| Índia                          | ✅  | ✅  | ❌  |

### 14.4 Trade-off na Prova

> "Empresa quer reduzir custos do CloudFront e seus usuários estão apenas nos EUA e Europa"
> → **Price Class 100** (menor custo, cobre apenas essas regiões)

---

## 15. Origin Groups e Origin Failover

### 15.1 Conceito

Origin Groups fornecem **alta disponibilidade** configurando failover automático
entre uma origin primária e uma secundária.

### 15.2 Como Funciona

```
                    ┌─────────────────────┐
                    │   Origin Group      │
                    │                     │
                    │  ┌───────────────┐  │
CloudFront ────────▶│  │ Primary Origin│  │ ──▶ Se falhar (5xx, timeout)
                    │  └───────┬───────┘  │
                    │          │ failover  │
                    │  ┌───────▼───────┐  │
                    │  │Secondary Origin│  │ ──▶ CloudFront tenta aqui
                    │  └───────────────┘  │
                    └─────────────────────┘
```

### 15.3 Configuração

| Aspecto                    | Detalhes                                          |
|----------------------------|---------------------------------------------------|
| Origins por grupo          | Exatamente 2 (primary + secondary)                |
| Failover trigger           | HTTP status codes configuráveis (500, 502, 503, 504, 403, 404) |
| Failover automático        | Sim, sem intervenção manual                       |
| Origin types               | Podem ser diferentes (S3 + S3, S3 + ALB, etc.)   |
| Caso de uso principal      | S3 cross-region replication + failover            |

### 15.4 Cenário Clássico na Prova

> "Garantir que o site continue disponível mesmo se o bucket S3 primário ficar indisponível"
> → Origin Group com primary = S3 us-east-1, secondary = S3 eu-west-1 (com CRR)

---

## 16. Continuous Deployment (Staging Distribution)

### 16.1 Conceito

Permite testar mudanças na configuração do CloudFront com uma porcentagem do tráfego
real antes de aplicar em produção (Blue/Green deployment para CDN).

### 16.2 Como Funciona

| Aspecto              | Detalhes                                               |
|----------------------|--------------------------------------------------------|
| Staging distribution | Cópia da distribution primária para teste              |
| Traffic split        | Configurável por porcentagem (ex: 5% → staging)       |
| Header-based        | Ou rotear por header específico para testes internos   |
| Promoção            | Staging → Production quando satisfeito                 |
| Rollback            | Desviar 100% de volta para production                  |

### 16.3 Fluxo

```
                              ┌─────────────────────────┐
                         95%  │ Production Distribution  │
Usuários ──── CloudFront ────▶│ (configuração atual)     │
                         5%   │                          │
                              └─────────────────────────┘
                              ┌─────────────────────────┐
                              │ Staging Distribution     │
                         ────▶│ (nova configuração)      │
                              └─────────────────────────┘
```

---

## 17. AWS Global Accelerator — Conceitos

### 17.1 O que é

O AWS Global Accelerator é um serviço de rede que melhora a disponibilidade e performance
de aplicações usando a **rede global privada da AWS** em vez da internet pública.

### 17.2 Características Fundamentais

| Característica             | Detalhes                                               |
|---------------------------|--------------------------------------------------------|
| IPs                       | 2 Anycast IPs estáticos (fixos, não mudam)             |
| Rede                      | Tráfego roteado pela rede privada AWS                  |
| Health Checks             | Verifica saúde dos endpoints por região                |
| Failover                  | Automático em < 30 segundos                            |
| Protocolos                | TCP e UDP                                              |
| Camada                    | Camada 4 (transporte)                                  |
| DDoS Protection           | AWS Shield Standard integrado                          |

### 17.3 Como Funciona

```
┌────────────┐     Anycast IP      ┌──────────────┐    AWS Private    ┌──────────────┐
│  Usuário   │ ──────────────────▶ │ Edge Location│ ────Network─────▶ │  Endpoint    │
│ (qualquer  │                     │  mais próxima│                    │ (ALB/NLB/EC2)│
│  lugar)    │                     │              │                    │ em qualquer  │
└────────────┘                     └──────────────┘                    │ região       │
                                                                       └──────────────┘
```

### 17.4 Anycast vs Unicast

| Tipo      | Comportamento                                              |
|-----------|------------------------------------------------------------|
| Unicast   | 1 IP = 1 servidor específico                               |
| Anycast   | 1 IP = múltiplos servidores; rede roteia para o mais próximo|

Global Accelerator usa **Anycast**: os 2 IPs são anunciados em todas as Edge Locations.
O roteamento BGP direciona o tráfego automaticamente para a edge mais próxima.

---

## 18. Global Accelerator — Endpoints

### 18.1 Tipos de Endpoints Suportados

| Endpoint Type    | Detalhes                                                  |
|-----------------|-----------------------------------------------------------|
| ALB             | Application Load Balancer (internet-facing ou internal)    |
| NLB             | Network Load Balancer                                      |
| EC2 Instance    | Instância com IP público ou Elastic IP                     |
| Elastic IP      | IP estático associado a recurso                            |

### 18.2 Endpoint Groups

- Cada **Endpoint Group** corresponde a uma **região AWS**
- Pode ter múltiplos endpoints dentro de um group
- Health checks são feitos por endpoint group

### 18.3 Arquitetura Multi-Region

```
                                    ┌─── Endpoint Group: us-east-1 ───┐
                                    │  ALB-1 (weight: 50)              │
Global Accelerator ────────────────▶│  ALB-2 (weight: 50)              │
(2 Anycast IPs)                     └────────────────────────────────┘
                                    ┌─── Endpoint Group: eu-west-1 ───┐
                    ───────────────▶│  NLB-1 (weight: 100)             │
                                    └────────────────────────────────┘
```

---

## 19. Global Accelerator — Routing

### 19.1 Traffic Dial (por Região)

| Configuração  | Descrição                                              |
|--------------|--------------------------------------------------------|
| Traffic Dial | Porcentagem de tráfego direcionado a um endpoint group |
| Range        | 0% a 100%                                              |
| Uso          | Blue/Green deployment entre regiões                    |
| Exemplo      | us-east-1: 80%, eu-west-1: 20%                         |

### 19.2 Endpoint Weights (por Endpoint)

| Configuração     | Descrição                                           |
|-----------------|-----------------------------------------------------|
| Endpoint Weight | Peso relativo entre endpoints no MESMO group         |
| Range           | 0 a 255                                             |
| Uso             | Distribuir tráfego entre endpoints na mesma região  |
| Weight = 0      | Endpoint não recebe tráfego (mas mantém health check)|

### 19.3 Fluxo de Roteamento Completo

```
Request → Anycast IP → Edge Location mais próxima
       → AWS Network → Escolhe Endpoint Group (por saúde + traffic dial)
       → Dentro do Group → Escolhe Endpoint (por health + weight)
       → Entrega ao endpoint saudável
```

---

## 20. Global Accelerator — Client Affinity

### 20.1 Conceito

Client Affinity garante que requests do **mesmo client IP** são sempre direcionados
ao **mesmo endpoint** (similar a sticky sessions).

### 20.2 Configurações

| Opção          | Comportamento                                         |
|----------------|-------------------------------------------------------|
| NONE (default) | Sem afinidade — requests distribuídas por peso        |
| SOURCE_IP      | Mesmo IP sempre vai ao mesmo endpoint                 |

### 20.3 Quando Usar

- Aplicações stateful que mantêm sessão no servidor
- Jogos multiplayer que precisam de conexão persistente
- Protocolos que requerem conexão estável (WebSocket sobre TCP)

---

## 21. CloudFront vs Global Accelerator — Tabela Completa

### 21.1 Comparação Detalhada (15+ Critérios)

| Critério                     | CloudFront                          | Global Accelerator                  |
|------------------------------|-------------------------------------|-------------------------------------|
| **Tipo de serviço**          | CDN (Content Delivery Network)      | Network accelerator                 |
| **Camada OSI**               | Camada 7 (HTTP/HTTPS)               | Camada 4 (TCP/UDP)                  |
| **Protocolos**               | HTTP, HTTPS, WebSocket              | TCP, UDP (qualquer protocolo)       |
| **Cache de conteúdo**        | ✅ Sim (principal benefício)         | ❌ Não cacheia nada                  |
| **IP estático**              | ❌ Não (DNS dinâmico via CNAME)      | ✅ 2 Anycast IPs fixos              |
| **Como melhora latência**    | Cache próximo ao usuário            | Rede privada AWS (menos hops)       |
| **Conteúdo estático**        | ✅ Ideal                             | ❌ Não otimiza (sem cache)           |
| **Conteúdo dinâmico**        | ✅ Sim (Dynamic Content Acceleration)| ✅ Sim                               |
| **Protocolos não-HTTP**      | ❌ Não                               | ✅ Sim (jogos, IoT, VoIP)           |
| **Edge processing**          | ✅ Functions + Lambda@Edge           | ❌ Não                               |
| **DDoS protection**          | Shield Standard + opção Advanced    | Shield Standard + opção Advanced    |
| **Health checks**            | Origin health checks                | Endpoint health checks por região   |
| **Failover**                 | Origin Groups (manual config)       | Automático < 30s entre regiões      |
| **SSL/TLS termination**      | Na Edge Location                    | No endpoint (pass-through)          |
| **Geo Restriction**          | ✅ Built-in                          | ❌ Não disponível                    |
| **Signed URLs/Cookies**      | ✅ Sim                               | ❌ Não                               |
| **Compressão**               | ✅ gzip + Brotli                     | ❌ Não                               |
| **Preço base**               | Pay per request + data transfer     | Fixed fee/hora + data transfer      |
| **IP whitelist por client**  | Difícil (IPs dinâmicos)             | ✅ Fácil (2 IPs fixos)              |
| **Integração com WAF**       | ✅ AWS WAF                           | ❌ Não                               |
| **Use case principal**       | Websites, APIs, streaming           | Gaming, IoT, VoIP, fintech          |

### 21.2 Regras Práticas para a Prova

| Se a questão mencionar...                    | Resposta provável        |
|----------------------------------------------|--------------------------|
| Cache, CDN, conteúdo estático                | CloudFront               |
| IP fixo/estático, whitelist de IP            | Global Accelerator       |
| HTTP/HTTPS, website, API REST                | CloudFront               |
| TCP/UDP genérico, gaming, IoT                | Global Accelerator       |
| Failover automático entre regiões < 30s      | Global Accelerator       |
| Proteção de conteúdo (signed URL/cookie)     | CloudFront               |
| Reduzir latência para conteúdo estático      | CloudFront               |
| Rede privada AWS, eliminar internet hops     | Global Accelerator       |
| WAF, bot protection, geo-restriction         | CloudFront               |
| Anycast, BGP                                 | Global Accelerator       |

---

## 22. Palavras-Chave da Prova SAA-C03 — Cenários e Respostas

### 22.1 Mapeamento Cenário → Resposta

| #  | Cenário na Prova                                                              | Resposta                                      |
|----|-------------------------------------------------------------------------------|-----------------------------------------------|
| 1  | "Distribuir conteúdo estático globalmente com baixa latência"                 | CloudFront com S3 origin + OAC                |
| 2  | "Bucket S3 privado acessível apenas via CloudFront"                           | OAC (Origin Access Control) + Bucket Policy   |
| 3  | "Criptografia SSE-KMS no S3 com CloudFront na frente"                         | OAC (não OAI — OAI não suporta KMS)          |
| 4  | "Restringir acesso a conteúdo por país"                                       | CloudFront Geo Restriction                    |
| 5  | "Acesso a conteúdo premium com assinatura/login"                              | Signed Cookies (múltiplos arquivos)           |
| 6  | "Gerar URL temporária para download de 1 arquivo"                             | Signed URL com expiração                      |
| 7  | "Manipulação de headers simples com menor latência e custo"                   | CloudFront Functions                          |
| 8  | "Lógica complexa com acesso a banco de dados na edge"                         | Lambda@Edge                                   |
| 9  | "Resize de imagem dinâmico baseado em device"                                 | Lambda@Edge (Origin Response)                 |
| 10 | "Reduzir custos do CloudFront, usuários apenas nos EUA e Europa"              | Price Class 100                               |
| 11 | "Alta disponibilidade para conteúdo S3 com failover automático"               | Origin Group (primary + secondary S3 com CRR) |
| 12 | "Aplicação precisa de IP estático para whitelist em firewall"                  | Global Accelerator (2 Anycast IPs)            |
| 13 | "Gaming TCP/UDP com failover rápido entre regiões"                            | Global Accelerator                            |
| 14 | "Proteger campo de cartão de crédito end-to-end até o app"                    | Field-Level Encryption                        |
| 15 | "Testar nova configuração de CDN com 5% do tráfego"                           | Continuous Deployment (staging distribution)  |
| 16 | "Logs de acesso CloudFront em tempo real para análise"                         | Real-Time Logs → Kinesis Data Streams         |
| 17 | "Forçar HTTPS em toda comunicação client → CloudFront"                         | Viewer Protocol Policy: Redirect HTTP to HTTPS|
| 18 | "Invalidar cache de todos os arquivos CSS após deploy"                         | Invalidation com path `/*.css` ou versionamento|
| 19 | "ALB atrás do CloudFront — como garantir que requests vêm da CDN"             | Custom header no CloudFront + ALB rule        |
| 20 | "API com paginação — cachear por query string page/limit"                     | Cache Policy incluindo query strings específicas|
| 21 | "Aplicação VoIP com baixa latência e protocolo UDP"                           | Global Accelerator (suporta UDP)              |
| 22 | "Failover automático entre regiões em menos de 1 minuto"                      | Global Accelerator (failover < 30s)           |
| 23 | "SPA React no S3 privado com client-side routing funcionando"                 | CloudFront + S3 OAC + Custom Error 403→index.html|
| 24 | "Reduzir carga na origin sem mudar TTL dos headers"                           | Aumentar Default TTL na Cache Policy          |
| 25 | "Signed URL vs S3 Pre-Signed URL para download"                               | CloudFront Signed URL = CDN + cache; S3 Pre-Signed = direto ao S3|

### 22.2 Dicas Rápidas para a Prova

1. **OAC > OAI** — Sempre que a questão mencionar acesso privado a S3 via CloudFront, a resposta moderna é OAC
2. **CloudFront Functions para coisas simples** — Header manipulation, redirects, normalização
3. **Lambda@Edge para coisas complexas** — Rede, body, autenticação avançada
4. **Global Accelerator ≠ CDN** — Não cacheia nada, apenas roteia pela rede privada AWS
5. **IP fixo = Global Accelerator** — CloudFront usa DNS/CNAME dinâmico
6. **Signed URL = 1 arquivo / Signed Cookie = múltiplos** — Decorar essa diferença
7. **Price Class 100 = mais barato** — Apenas NA + EU
8. **Origin Group = HA** — Failover automático entre 2 origins
9. **Field-Level Encryption** — Protege campos específicos, não o payload inteiro
10. **Cache-Control no-store + Minimum TTL** — O Minimum TTL da policy é o piso absoluto

---

## Resumo Visual — Arquitetura Completa CloudFront

```
                    ┌─────────────────────────────────────────────────────────────┐
                    │                    CLOUDFRONT DISTRIBUTION                   │
                    │                                                             │
                    │  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐       │
                    │  │  Behavior 1 │   │  Behavior 2 │   │  Default *  │       │
                    │  │  /api/*     │   │  /static/*  │   │             │       │
                    │  └──────┬──────┘   └──────┬──────┘   └──────┬──────┘       │
                    │         │                  │                  │             │
                    │         ▼                  ▼                  ▼             │
                    │  ┌────────────┐    ┌────────────┐     ┌────────────┐       │
                    │  │Origin Group│    │  S3 Origin │     │  S3 Origin │       │
                    │  │ (ALB+ALB)  │    │  + OAC     │     │  website   │       │
                    │  └────────────┘    └────────────┘     └────────────┘       │
                    │                                                             │
                    │  Funcionalidades:                                           │
                    │  • Cache Policy + Origin Request Policy                     │
                    │  • CloudFront Functions / Lambda@Edge                       │
                    │  • Signed URLs / Signed Cookies                             │
                    │  • Geo Restriction                                          │
                    │  • Field-Level Encryption                                   │
                    │  • Real-Time Logs → Kinesis                                 │
                    │  • Standard Logs → S3                                       │
                    └─────────────────────────────────────────────────────────────┘
```

---

*Última atualização: Julho 2026 — Baseado no conteúdo do exame AWS SAA-C03*
