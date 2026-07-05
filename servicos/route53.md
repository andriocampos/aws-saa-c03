# Route 53 — Guia Completo para AWS SAA-C03

> Serviço de DNS gerenciado, altamente disponível e escalável da AWS.
> Nome "Route 53" refere-se à porta 53 (DNS) e à histórica Route 66 americana.
> SLA: 100% de disponibilidade.

---

## 1. Conceitos Fundamentais de DNS

### 1.1 O que é DNS

O Domain Name System traduz nomes legíveis (www.exemplo.com) em endereços IP (192.0.2.1).
É um sistema hierárquico e distribuído globalmente.

### 1.2 Componentes Principais

| Componente | Descrição |
|-----------|-----------|
| **Domain Registrar** | Entidade credenciada (ICANN) onde você registra domínios (Route 53, GoDaddy, Namecheap) |
| **Hosted Zone** | Container de records DNS para um domínio — equivale a um "arquivo de zona" |
| **Record (Registro)** | Entrada individual que mapeia um nome a um valor (IP, hostname, etc.) |
| **TTL (Time To Live)** | Tempo (em segundos) que o resolver/cliente mantém o resultado em cache |
| **DNS Resolver** | Servidor intermediário que resolve queries recursivamente (ex: 8.8.8.8, ISP resolver) |
| **Name Server (NS)** | Servidor autoritativo que responde queries para uma zona específica |
| **Root Server** | Primeiro nível da hierarquia DNS (13 clusters globais: a.root-servers.net a m.root-servers.net) |
| **TLD Server** | Servidor do Top-Level Domain (.com, .org, .br) |

### 1.3 Fluxo de Resolução DNS

```
┌──────────┐       ┌──────────────┐       ┌────────────┐       ┌─────────────┐
│  Cliente  │──────▶│ DNS Resolver  │──────▶│ Root Server │──────▶│ TLD Server  │
│ (browser) │       │  (recursivo)  │       │  (.)        │       │ (.com)       │
└──────────┘       └──────────────┘       └────────────┘       └─────────────┘
                          │                                            │
                          │         ┌─────────────────────┐            │
                          │◀────────│ Authoritative NS     │◀───────────┘
                          │         │ (Route 53 hosted zone)│
                          │         └─────────────────────┘
                          │
                          ▼
                   Retorna IP ao cliente
                   (cacheia por TTL segundos)
```

### 1.4 TTL — Estratégias para a Prova

| TTL | Vantagem | Desvantagem | Quando usar |
|-----|----------|-------------|-------------|
| **Alto (ex: 86400s = 24h)** | Menos queries → menor custo, menor latência | Mudanças demoram a propagar | Registros estáveis |
| **Baixo (ex: 60s)** | Propagação rápida de mudanças | Mais queries → maior custo | Antes de migrações/mudanças |
| **0** | Sempre consulta autoritativo | Máximo de queries/custo | Raramente recomendado |

> **Dica de prova:** Antes de migrar um recurso, reduza o TTL com antecedência (ex: 24h antes),
> faça a mudança, depois restaure o TTL alto.

---

## 2. Hosted Zones: Public vs Private

### 2.1 Public Hosted Zone

- Responde queries originadas da **internet pública**
- Criada automaticamente ao registrar um domínio no Route 53
- Contém records acessíveis por qualquer resolver público

### 2.2 Private Hosted Zone

- Responde queries **apenas dentro de VPCs associadas**
- Usada para resolução de nomes internos (ex: db.internal.empresa.com)
- Pode ser associada a múltiplas VPCs (inclusive cross-account)
- Requer `enableDnsHostnames` e `enableDnsSupport` = true na VPC

### 2.3 Tabela Comparativa

| Característica | Public Hosted Zone | Private Hosted Zone |
|---------------|-------------------|-------------------|
| Acessível da internet | ✅ Sim | ❌ Não |
| Acessível de VPCs | ✅ Sim | ✅ Sim (VPCs associadas) |
| Requer VPC | ❌ | ✅ Mínimo 1 VPC |
| Caso de uso | Sites públicos, APIs | Recursos internos, microserviços |
| Cross-account | N/A | ✅ Via RAM ou CLI |

### 2.4 Custos

| Item | Custo |
|------|-------|
| Hosted Zone | **$0.50/mês** por zona (primeiras 25 zonas) |
| Queries (Standard) | **$0.40** por milhão de queries |
| Queries (Latency/Geo/IP-based) | **$0.70** por milhão de queries |
| Queries Alias para recursos AWS | **$0.00** (GRATUITO) |
| Health Checks (básico) | **$0.50/mês** por check |
| Health Checks (com opções extras) | Até **$2.00/mês** por check |
| Registro de domínio | Varia ($12-$40+/ano dependendo do TLD) |

---

## 3. Record Types (Tipos de Registro)

### 3.1 Tabela Completa de Record Types

| Tipo | Nome Completo | Valor | Exemplo | Uso |
|------|--------------|-------|---------|-----|
| **A** | Address | IPv4 | `192.0.2.1` | Mapear nome → IPv4 |
| **AAAA** | IPv6 Address | IPv6 | `2001:db8::1` | Mapear nome → IPv6 |
| **CNAME** | Canonical Name | Hostname | `app.example.com` | Alias para outro nome (NÃO no apex) |
| **NS** | Name Server | Hostname do NS | `ns-123.awsdns-45.com` | Delegar autoridade da zona |
| **MX** | Mail Exchange | Prioridade + hostname | `10 mail.example.com` | Roteamento de email |
| **TXT** | Text | Texto livre | `"v=spf1 include:..."` | Validação (SPF, DKIM, DMARC, verificação de domínio) |
| **SOA** | Start of Authority | Metadados da zona | Serial, refresh, retry... | Informações administrativas da zona |
| **SRV** | Service | Prioridade+peso+porta+host | `10 5 5060 sip.ex.com` | Localização de serviços (SIP, LDAP) |
| **CAA** | Certification Authority Auth | Flags+tag+CA | `0 issue "letsencrypt.org"` | Controlar quais CAs emitem certificados |

### 3.2 Regras Importantes para a Prova

- **CNAME** não pode ser criado no apex do domínio (zone apex / naked domain)
  - ❌ `example.com → algo.com` (inválido como CNAME)
  - ✅ `www.example.com → algo.com` (válido)
- **NS** records são criados automaticamente e não devem ser alterados sem necessidade
- **SOA** é criado automaticamente — contém email do admin e serial da zona
- **MX** usa prioridade numérica (menor = maior prioridade)

---

## 4. Alias vs CNAME — Diferença Crítica

### 4.1 Conceito

- **CNAME:** Record DNS padrão que aponta um nome para outro nome (hostname → hostname)
- **Alias:** Extensão proprietária do Route 53 que aponta um nome diretamente para um recurso AWS

### 4.2 Tabela Comparativa COMPLETA

| Característica | Alias Record | CNAME Record |
|---------------|-------------|-------------|
| **Apex domain (zone apex)** | ✅ Suportado (`example.com`) | ❌ NÃO suportado |
| **Custo de query** | ✅ GRATUITO | 💰 Cobrado normalmente |
| **TTL** | Gerenciado pela AWS (não configurável) | Configurável pelo usuário |
| **Health Check nativo** | ✅ Sim (avalia saúde do target) | ❌ Não (precisa criar separado) |
| **Targets** | Apenas recursos AWS específicos | Qualquer hostname (AWS ou externo) |
| **Tipo de record** | A ou AAAA | CNAME |
| **Resolução** | Direto para IP do recurso | Requer resolução adicional |
| **Funciona com** | Route 53 apenas | Qualquer provedor DNS |

### 4.3 Targets Suportados pelo Alias Record

| Target AWS | Suportado | Observação |
|-----------|-----------|-----------|
| **Elastic Load Balancer (ALB/NLB/CLB)** | ✅ | Caso de uso mais comum |
| **CloudFront Distribution** | ✅ | CDN global |
| **S3 Website Endpoint** | ✅ | Bucket configurado como static website |
| **API Gateway** | ✅ | Regional ou Edge-optimized |
| **Global Accelerator** | ✅ | Anycast IP |
| **VPC Interface Endpoint** | ✅ | PrivateLink |
| **Outro record na MESMA hosted zone** | ✅ | Encadeamento de records |
| **Elastic Beanstalk environment** | ✅ | Via CNAME do EB |
| **EC2 instance** | ❌ NÃO | Use A record com IP diretamente |
| **RDS endpoint** | ❌ NÃO | Use CNAME padrão |
| **Recurso em OUTRA conta** | ❌ NÃO | Deve estar na mesma conta ou cross-account configurado |

### 4.4 Regra de Ouro para a Prova

```
┌─────────────────────────────────────────────────────────┐
│  SEMPRE use ALIAS quando:                                │
│  1. Apontar para recurso AWS suportado                   │
│  2. Especialmente no apex domain (example.com)           │
│  3. Quiser economizar custo (queries gratuitas)          │
│                                                          │
│  Use CNAME quando:                                       │
│  1. Apontar para recurso externo (não-AWS)               │
│  2. Subdomínio para hostname arbitrário                  │
│  3. Precisar de TTL customizado                          │
│                                                          │
│  ⚠️  Alias NUNCA aponta para:                            │
│  - EC2 instance diretamente                              │
│  - RDS endpoint                                          │
│  - Hostname em outra hosted zone de outra conta          │
└─────────────────────────────────────────────────────────┘
```

---

## 5. Routing Policies (Políticas de Roteamento)

### 5.1 Simple Routing (Simples)

- Roteia tráfego para **um único recurso**
- Pode retornar **múltiplos valores** (IPs) em um único record → cliente escolhe aleatoriamente
- **NÃO suporta Health Checks**
- Se múltiplos IPs, o cliente pode receber um IP de recurso não saudável

```
┌──────────┐     ┌─────────┐     ┌──────────────────┐
│  Cliente  │────▶│Route 53 │────▶│ 1 ou mais IPs    │
└──────────┘     └─────────┘     │ (escolha random)  │
                                  └──────────────────┘
```

**Quando usar:** Recurso único, cenários simples sem necessidade de failover.

---

### 5.2 Weighted Routing (Ponderado)

- Distribui tráfego entre múltiplos recursos com base em **pesos (weights)**
- Cada record recebe um peso numérico (0-255)
- Fórmula: `% tráfego = peso_record / soma_todos_pesos`
- **Suporta Health Checks** — records não saudáveis são excluídos

| Peso Record A | Peso Record B | Peso Record C | % A | % B | % C |
|:---:|:---:|:---:|:---:|:---:|:---:|
| 70 | 20 | 10 | 70% | 20% | 10% |
| 1 | 1 | 1 | 33% | 33% | 33% |
| 0 | 0 | 1 | 0% | 0% | 100% |

**Regras especiais:**
- Peso `0` = NÃO recebe tráfego
- Se TODOS os pesos forem `0` = distribui igualmente entre todos
- Pesos não precisam somar 100

**Casos de uso:**
- **Blue-green deployment:** 90% blue / 10% green → gradualmente inverter
- **A/B testing:** enviar 5% do tráfego para nova versão
- **Migração gradual:** mover tráfego de on-premises para AWS

```
                    Peso: 70 ──▶ ┌─────────────┐
┌──────────┐      ┌─────────┐   │  ALB us-east │
│  Cliente  │────▶│Route 53 │───▶└─────────────┘
└──────────┘      └─────────┘
                        │  Peso: 20 ──▶ ┌─────────────┐
                        │───────────────▶│  ALB eu-west │
                        │                └─────────────┘
                        │  Peso: 10 ──▶ ┌─────────────┐
                        └───────────────▶│  ALB ap-south│
                                         └─────────────┘
```

---

### 5.3 Latency-based Routing (Baseado em Latência)

- Roteia para a **região AWS com menor latência** para o usuário
- Latência é medida entre o usuário e as regiões AWS (não entre regiões)
- A AWS mantém tabela de latência atualizada automaticamente
- **Suporta Health Checks** — se região com menor latência falhar, usa próxima

**Importante para a prova:**
- Latência ≠ distância geográfica (infraestrutura de rede importa)
- Um usuário no Brasil pode ter menor latência para us-east-1 do que para sa-east-1

**Quando usar:** Aplicações multi-region onde performance é prioridade.

```
┌────────────────┐         ┌─────────┐
│ Usuário Brasil │────────▶│         │──▶ sa-east-1 (120ms) ✅ menor
└────────────────┘         │Route 53 │
┌────────────────┐         │(latency)│──▶ us-east-1 (180ms)
│ Usuário Europa │────────▶│         │──▶ eu-west-1 (30ms) ✅ menor
└────────────────┘         └─────────┘
```

---

### 5.4 Failover Routing (Ativo-Passivo)

- Configura record **Primary** (ativo) e **Secondary** (passivo/standby)
- Health Check é **OBRIGATÓRIO** no Primary
- Se Primary falhar → tráfego vai automaticamente para Secondary
- Secondary pode ter Health Check (opcional, mas recomendado)
- Suporta apenas **2 records** (1 primary + 1 secondary)

```
                                    ┌─────────────────────┐
                    Health ✅       │  PRIMARY             │
              ┌────────────────────▶│  (ALB us-east-1)     │
              │                     └─────────────────────┘
┌─────────┐   │
│Route 53 │───┤
└─────────┘   │                     ┌─────────────────────┐
              │     Health ❌ ──────▶│  SECONDARY           │
              └────────────────────▶│  (S3 static website) │
                  (se primary falha) └─────────────────────┘
```

**Casos de uso:**
- Disaster Recovery (DR) com site estático no S3
- Active-passive entre regiões
- Failover para página de manutenção

---

### 5.5 Geolocation Routing (Geolocalização)

- Roteia com base na **localização geográfica do usuário** (país, continente)
- Hierarquia de matching: Estado (EUA) → País → Continente → Default
- **DEVE configurar record "Default"** para usuários não mapeados
- Diferente de Latency (não considera performance, considera LOCALIZAÇÃO)
- **Suporta Health Checks**

**Casos de uso:**
- **Compliance:** dados de usuários europeus devem ficar na EU
- **Localização:** conteúdo em idioma/moeda local
- **Restrição de acesso:** bloquear acesso de certos países
- **Distribuição de carga por região geográfica**

| Localização do usuário | Record configurado | Destino |
|----------------------|-------------------|---------|
| Brasil | País: BR | ALB sa-east-1 |
| França | Continente: EU | ALB eu-west-1 |
| Japão | País: JP | ALB ap-northeast-1 |
| Qualquer outro | Default | ALB us-east-1 |

---

### 5.6 Geoproximity Routing (Geoproximidade)

- Roteia com base na **distância geográfica** entre usuário e recurso
- Permite ajustar alcance com **bias** (viés): -99 a +99
- **Bias positivo (+):** AUMENTA a área de alcance → atrai mais tráfego
- **Bias negativo (-):** DIMINUI a área de alcance → repele tráfego
- **REQUER Route 53 Traffic Flow** (visual editor)

```
        bias = 0 (padrão)              bias = +25 em us-east-1
   ┌─────────┬─────────┐          ┌──────────────┬────────┐
   │us-east-1│eu-west-1│          │  us-east-1   │eu-west │
   │  (50%)  │  (50%)  │          │    (70%)     │ (30%)  │
   └─────────┴─────────┘          └──────────────┴────────┘
   Divisão igualitária             us-east atrai mais tráfego
```

**Diferença Geolocation vs Geoproximity:**

| Aspecto | Geolocation | Geoproximity |
|---------|------------|-------------|
| Base da decisão | País/Continente fixo | Distância + bias |
| Granularidade | Limites políticos | Coordenadas geográficas |
| Ajustável | Não | Sim (bias) |
| Traffic Flow | Não requer | REQUER |
| Uso principal | Compliance, idioma | Shift de tráfego entre regiões |

---

### 5.7 IP-based Routing (Baseado em IP)

- Roteia com base no **CIDR de origem** do cliente
- Você define blocos CIDR e mapeia para endpoints específicos
- Útil quando você **conhece os IPs** dos seus usuários/parceiros
- Routing mais preciso e previsível

**Casos de uso:**
- Rotear ISPs específicos para endpoints otimizados
- Rotear escritórios corporativos (CIDR conhecido) para endpoints privados
- Otimizar custos de rede roteando por topologia conhecida

| CIDR do Cliente | Destino |
|----------------|---------|
| `203.0.113.0/24` | ALB us-east-1 (ISP A) |
| `198.51.100.0/24` | ALB eu-west-1 (ISP B) |
| Default | ALB us-east-1 |

---

### 5.8 Multi-Value Answer Routing

- Retorna **até 8 records saudáveis** em resposta a uma query
- Cada record tem seu próprio **Health Check**
- Records não saudáveis são REMOVIDOS da resposta
- Cliente escolhe aleatoriamente entre os IPs retornados
- **NÃO é um substituto para ELB** — é DNS-level, não application-level

**Diferença Multi-Value vs Simple:**

| Aspecto | Simple | Multi-Value |
|---------|--------|-------------|
| Health Check | ❌ Não suporta | ✅ Por record |
| Records não saudáveis | Retornados mesmo assim | Removidos da resposta |
| Máximo de valores | Sem limite | 8 por query |
| Garantia de saúde | Nenhuma | Apenas IPs saudáveis |

```
┌──────────┐      ┌─────────┐      Saudáveis:
│  Cliente  │────▶│Route 53 │────▶ IP-1 ✅  IP-2 ✅  IP-3 ❌  IP-4 ✅
└──────────┘      └─────────┘      Resposta: [IP-1, IP-2, IP-4]
                  (multi-value)     (máx 8 retornados)
```

---

## 6. Health Checks (Verificações de Saúde)

### 6.1 Tipos de Health Check

#### 6.1.1 Endpoint Health Check

Monitora um endpoint diretamente (servidor, ALB, etc.)

| Parâmetro | Valor |
|-----------|-------|
| Protocolos | HTTP, HTTPS, TCP |
| Checkers globais | ~15 localizações ao redor do mundo |
| Intervalo padrão | 30 segundos |
| Intervalo rápido (fast) | 10 segundos (custo maior) |
| Threshold | 3 falhas consecutivas = unhealthy (configurável) |
| HTTP check | Verifica status code 2xx ou 3xx |
| String matching | Verifica se os primeiros 5120 bytes da resposta contêm texto esperado |
| Timeout | 4s (TCP), 4s (HTTP/HTTPS — inclui string matching) |

**Funcionamento:**
- 15+ checkers de diferentes regiões fazem requests ao endpoint
- Se >18% dos checkers reportam healthy → endpoint é **Healthy**
- Se ≤18% → endpoint é **Unhealthy**
- Você pode selecionar QUAIS regiões farão os checks

**⚠️ IMPORTANTE:** Os health checkers vêm de IPs públicos da AWS.
- O Security Group / NACL do recurso DEVE permitir tráfego dos IPs dos health checkers
- Lista de IPs disponível em: https://ip-ranges.amazonaws.com/ip-ranges.json

#### 6.1.2 Calculated Health Check

- **Combina** resultados de múltiplos health checks (child health checks)
- Operadores: AND, OR, ou threshold (ex: pelo menos 2 de 3 healthy)
- Até **256 child health checks**
- Útil para verificar saúde de sistema complexo sem criar um único endpoint de health

```
┌────────────────────────────────────┐
│     CALCULATED HEALTH CHECK        │
│   (healthy se 2 de 3 = healthy)    │
├────────────────────────────────────┤
│                                    │
│  ┌──────┐  ┌──────┐  ┌──────┐    │
│  │ HC-1 │  │ HC-2 │  │ HC-3 │    │
│  │  ✅  │  │  ✅  │  │  ❌  │    │
│  └──────┘  └──────┘  └──────┘    │
│                                    │
│  Resultado: ✅ HEALTHY (2/3)       │
└────────────────────────────────────┘
```

#### 6.1.3 CloudWatch Alarm Health Check

- Monitora um **CloudWatch Alarm** ao invés de endpoint direto
- Essencial para **recursos privados** (dentro de VPC, sem IP público)
- Health checkers do Route 53 estão na internet → não alcançam recursos privados

**Padrão para recursos privados:**
```
┌─────────────────┐     ┌────────────────┐     ┌─────────────────┐
│ Recurso Privado │────▶│ CloudWatch     │────▶│ Route 53         │
│ (RDS, EC2 priv) │     │ Metric + Alarm │     │ Health Check     │
└─────────────────┘     └────────────────┘     │ (tipo CW Alarm)  │
                                                └─────────────────┘
```

### 6.2 Custos de Health Check

| Tipo | Custo/mês |
|------|-----------|
| Endpoint (AWS) | $0.50 |
| Endpoint (non-AWS) | $0.75 |
| Opções adicionais (HTTPS, string matching, fast interval, latency measurement) | +$1.00-$2.00 |
| Calculated | $0.50 |

---

## 7. Health Check + Routing Policies

### 7.1 Como Health Checks Afetam Cada Policy

| Routing Policy | Suporta HC? | Comportamento quando unhealthy |
|---------------|-------------|-------------------------------|
| **Simple** | ❌ NÃO | Retorna todos os IPs mesmo se unhealthy |
| **Weighted** | ✅ SIM | Remove record unhealthy; redistribui peso |
| **Latency** | ✅ SIM | Pula para próxima região com menor latência |
| **Failover** | ✅ OBRIGATÓRIO (primary) | Muda para secondary |
| **Geolocation** | ✅ SIM | Usa record "default" se local unhealthy |
| **Geoproximity** | ✅ SIM | Roteia para próximo recurso saudável |
| **IP-based** | ✅ SIM | Usa default se CIDR match unhealthy |
| **Multi-Value** | ✅ SIM (por record) | Remove IP unhealthy da resposta |

### 7.2 Boas Práticas

1. **Sempre configure Health Checks** em políticas que os suportam
2. **Failover:** HC é OBRIGATÓRIO no primary, recomendado no secondary
3. **Recursos privados:** Use CloudWatch Alarm → Health Check
4. **Abra firewalls:** SG/NACL devem permitir IPs dos health checkers
5. **Combine com alarmes:** Configure SNS para notificar quando HC muda de estado

---

## 8. Domain Registration vs DNS Hosting

### 8.1 Conceito

São **duas funções separadas** que podem usar provedores diferentes:

| Função | Descrição | Provedor |
|--------|-----------|----------|
| **Domain Registrar** | Onde você COMPRA/registra o domínio | Route 53, GoDaddy, Namecheap, etc. |
| **DNS Hosting** | Onde ficam os records (hosted zone) | Route 53, Cloudflare, etc. |

### 8.2 Cenários Comuns

**Cenário 1:** Registrar e DNS no Route 53 (padrão)
- Registra domínio no Route 53 → zona criada automaticamente

**Cenário 2:** Registrar externo + DNS no Route 53
- Compra domínio no GoDaddy
- Cria hosted zone no Route 53
- Atualiza NS records no GoDaddy para apontar para os name servers do Route 53

**Cenário 3:** Registrar no Route 53 + DNS externo
- Compra domínio no Route 53
- Altera NS records para apontar para outro provedor DNS

### 8.3 Como Usar Registrar Externo com Route 53

```
1. Criar Public Hosted Zone no Route 53
2. Route 53 atribui 4 Name Servers (NS records)
3. No registrar externo (GoDaddy/Namecheap):
   - Atualizar NS records para os 4 NS do Route 53
4. Agora Route 53 é autoritativo para o domínio
```

> **Dica de prova:** Se a questão fala "domínio registrado em terceiro" + "usar Route 53 para DNS"
> → Resposta: atualizar NS records no registrar para apontar para Route 53.

---

## 9. DNSSEC (DNS Security Extensions)

### 9.1 Problema que Resolve

- **DNS Spoofing / Cache Poisoning:** atacante injeta records falsos no resolver
- Sem DNSSEC, não há como verificar autenticidade das respostas DNS

### 9.2 Como Funciona

- Adiciona **assinaturas criptográficas** aos records DNS
- Permite que resolvers VALIDEM que a resposta veio do autoritativo correto
- Usa par de chaves: KSK (Key Signing Key) e ZSK (Zone Signing Key)

### 9.3 DNSSEC no Route 53

| Aspecto | Detalhes |
|---------|---------|
| Suporte | ✅ Para Public Hosted Zones |
| Private Zones | ❌ NÃO suportado |
| KSK Management | Route 53 gerencia via AWS KMS (CMK) |
| Ativação | Habilitar DNSSEC signing na hosted zone |
| Chain of Trust | Criar DS record no registrar (domínio pai) |

### 9.4 Passos para Habilitar

1. Criar KMS Key (assimétrica, ECC_NIST_P256) em **us-east-1**
2. Habilitar DNSSEC signing na hosted zone
3. Criar DS (Delegation Signer) record no registrar do domínio pai
4. Testar validação com ferramentas como `dig +dnssec`

> **Para a prova:** DNSSEC protege contra spoofing/poisoning. Não criptografa dados,
> apenas garante integridade e autenticidade das respostas DNS.

---

## 10. Route 53 Resolver (DNS Híbrido)

### 10.1 Problema que Resolve

Em ambientes híbridos (AWS + on-premises), servidores em cada lado precisam resolver nomes do outro:
- EC2 na AWS precisa resolver `server.corp.internal` (on-premises)
- Servidores on-premises precisam resolver `api.aws.empresa.com` (AWS)

### 10.2 Componentes

| Componente | Direção | Função |
|-----------|---------|--------|
| **Inbound Endpoint** | On-premises → AWS | Permite DNS on-premises encaminhar queries para Route 53 |
| **Outbound Endpoint** | AWS → On-premises | Permite Route 53 encaminhar queries para DNS on-premises |
| **Resolver Rules** | — | Define quais domínios encaminhar e para onde |

### 10.3 Arquitetura

```
┌─────────────────────────────────┐     ┌─────────────────────────────────┐
│         ON-PREMISES              │     │              AWS VPC             │
│                                  │     │                                  │
│  ┌──────────────┐               │     │         ┌────────────────┐      │
│  │ DNS Server    │───────────────┼─────┼────────▶│ INBOUND        │      │
│  │ (corp.local)  │               │     │         │ ENDPOINT       │      │
│  └──────────────┘               │     │         │ (ENI na VPC)   │      │
│         ▲                        │     │         └────────────────┘      │
│         │                        │     │                                  │
│         │                        │     │         ┌────────────────┐      │
│         └────────────────────────┼─────┼─────────│ OUTBOUND       │      │
│                                  │     │         │ ENDPOINT       │      │
│                                  │     │         │ (ENI na VPC)   │      │
│                                  │     │         └────────────────┘      │
└─────────────────────────────────┘     └─────────────────────────────────┘
         ▲                                          │
         │  VPN / Direct Connect                    │
         └──────────────────────────────────────────┘
```

### 10.4 Resolver Rules (Regras de Encaminhamento)

| Tipo | Descrição |
|------|-----------|
| **Forward Rule** | Encaminha queries de domínio específico para IP de DNS target |
| **System Rule** | Usa o comportamento padrão do Route 53 Resolver |
| **Shared Rules** | Pode compartilhar via AWS RAM com outras contas |

**Exemplo:**
- Rule: `corp.internal` → encaminhar para DNS on-premises (10.0.0.53)
- Rule: `aws.empresa.com` → resolver localmente (system rule)

### 10.5 Detalhes para a Prova

- Cada endpoint requer **mínimo 2 IPs** (em 2 AZs para HA)
- Endpoints são **ENIs na VPC** — consomem IPs da subnet
- Conectividade requer **VPN ou Direct Connect**
- Custo: ~$0.125/hora por endpoint + $0.40 por milhão de queries

---

## 11. Traffic Flow

### 11.1 O que é

- **Editor visual** para criar políticas de roteamento complexas
- Permite combinar múltiplas routing policies em uma árvore de decisão
- Gera **Traffic Policy** (template) que pode ser aplicada a múltiplos records
- Suporta **versionamento** de policies

### 11.2 Quando Usar

- Geoproximity routing (REQUER Traffic Flow)
- Combinações complexas de routing (ex: Geolocation → Weighted → Failover)
- Gerenciar routing policies para múltiplos domínios com mesmo padrão
- Necessidade de visualização gráfica das regras

### 11.3 Componentes

| Componente | Descrição |
|-----------|-----------|
| **Traffic Policy** | Template/documento que define a lógica de routing |
| **Policy Record** | Aplicação de uma Traffic Policy a um record específico |
| **Policy Version** | Versão específica (suporta múltiplas versões) |

### 11.4 Custo

- **$50.00/mês** por policy record (caro!)
- Justifica-se apenas para cenários complexos
- Traffic Policy em si não tem custo (apenas o policy record ativo)

### 11.5 Exemplo de Árvore de Decisão

```
                    ┌─────────────┐
                    │  DNS Query   │
                    │ example.com  │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │ Geolocation  │
                    └──────┬──────┘
                     │     │     │
              ┌──────┘     │     └──────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │ América  │ │  Europa   │ │  Default  │
        └────┬─────┘ └────┬─────┘ └────┬─────┘
             │             │             │
        ┌────▼─────┐ ┌────▼─────┐ ┌────▼─────┐
        │ Weighted │ │ Failover │ │  Simple   │
        │ 80/20   │ │ P + S    │ │           │
        └────┬─────┘ └────┬─────┘ └──────────┘
          │     │       │     │
          ▼     ▼       ▼     ▼
       ALB-1  ALB-2  ALB-EU  S3-EU
```

---

## 12. Diagrama de Arquitetura: Failover Multi-Region com Route 53

### 12.1 Cenário

Aplicação web em duas regiões com failover automático e DR:

```
                         ┌─────────────────────────────┐
                         │        ROUTE 53              │
                         │   Failover Routing Policy    │
                         │                             │
                         │  Primary: us-east-1 (HC ✅)  │
                         │  Secondary: eu-west-1 (HC)   │
                         └──────────┬──────────────────┘
                                    │
                    ┌───────────────┼───────────────┐
                    │ (healthy)     │               │ (if primary fails)
                    ▼                               ▼
    ┌───────────────────────────┐   ┌───────────────────────────┐
    │       us-east-1           │   │       eu-west-1            │
    │  ┌─────────────────────┐  │   │  ┌─────────────────────┐  │
    │  │   ALB (Primary)     │  │   │  │   ALB (Secondary)   │  │
    │  └──────────┬──────────┘  │   │  └──────────┬──────────┘  │
    │             │              │   │             │              │
    │  ┌──────────▼──────────┐  │   │  ┌──────────▼──────────┐  │
    │  │  Auto Scaling Group │  │   │  │  Auto Scaling Group │  │
    │  │  (EC2 instances)    │  │   │  │  (EC2 instances)    │  │
    │  └──────────┬──────────┘  │   │  └──────────┬──────────┘  │
    │             │              │   │             │              │
    │  ┌──────────▼──────────┐  │   │  ┌──────────▼──────────┐  │
    │  │  RDS Primary        │  │   │  │  RDS Read Replica   │  │
    │  │  (Multi-AZ)         │──┼───┼─▶│  (Cross-Region)     │  │
    │  └─────────────────────┘  │   │  └─────────────────────┘  │
    └───────────────────────────┘   └───────────────────────────┘
                                           │
                                    (promote to primary
                                     em caso de DR)
```

### 12.2 Componentes do Failover

| Componente | Papel |
|-----------|-------|
| Route 53 Failover | Detecta falha e redireciona DNS |
| Health Check (Primary) | Monitora ALB da região primária |
| ALB + ASG (ambas regiões) | Servem a aplicação |
| RDS Cross-Region Replica | Dados replicados para DR |
| RTO | Depende do TTL + tempo de detecção do HC (~60-90s) |
| RPO | Depende do lag de replicação do RDS |

### 12.3 Variação com CloudFront + S3 (Static Failover)

```
┌─────────────┐     ┌─────────────┐     ┌────────────────────┐
│   Route 53   │────▶│ CloudFront  │────▶│  Origin Group       │
│  (Alias)     │     │             │     │  Primary: ALB       │
└─────────────┘     └─────────────┘     │  Secondary: S3      │
                                         │  (sorry page)       │
                                         └────────────────────┘
```

---

## 13. Palavras-chave da Prova SAA-C03

### 13.1 Cenários e Respostas (Mínimo 15)

| # | Cenário na Prova | Resposta |
|---|-----------------|----------|
| 1 | "Apontar apex domain (example.com) para ALB" | **Alias record** (CNAME não funciona no apex) |
| 2 | "Menor latência para usuários globais" | **Latency-based routing** |
| 3 | "DR com site estático quando aplicação falha" | **Failover routing** (primary=ALB, secondary=S3) |
| 4 | "Migração gradual de tráfego para nova versão" | **Weighted routing** (ex: 90/10 → 50/50 → 0/100) |
| 5 | "Compliance: dados europeus devem ficar na EU" | **Geolocation routing** (EU → eu-west-1) |
| 6 | "Shift gradual de tráfego entre regiões" | **Geoproximity routing** com bias |
| 7 | "Health check para recurso privado (RDS em VPC)" | **CloudWatch Alarm** → Route 53 Health Check |
| 8 | "Domínio registrado no GoDaddy, DNS na AWS" | Atualizar **NS records** no GoDaddy para Route 53 |
| 9 | "Múltiplos IPs saudáveis sem load balancer" | **Multi-Value routing** com health checks |
| 10 | "Proteger DNS contra spoofing" | **DNSSEC** |
| 11 | "DNS híbrido: on-prem resolver nomes AWS" | Route 53 **Resolver Inbound Endpoint** |
| 12 | "DNS híbrido: AWS resolver nomes on-prem" | Route 53 **Resolver Outbound Endpoint** + Forward Rule |
| 13 | "Rotear por ISP/CIDR de origem do cliente" | **IP-based routing** |
| 14 | "A/B testing com 5% na versão nova" | **Weighted routing** (peso 95 vs peso 5) |
| 15 | "Active-active com health checks distribuindo carga" | **Multi-Value routing** (não é LB, mas distribui) |
| 16 | "Routing complexo combinando geo + weighted + failover" | **Traffic Flow** (visual editor) |
| 17 | "Custo zero para queries DNS apontando para ALB" | **Alias record** (queries gratuitas para recursos AWS) |
| 18 | "Record tipo A no apex domain para CloudFront" | **Alias record** tipo A apontando para distribuição CF |
| 19 | "Failover automático com detecção em menos de 1 min" | Health Check com **Fast interval (10s)** + threshold baixo |
| 20 | "Conteúdo localizado por idioma/país do usuário" | **Geolocation routing** |

### 13.2 Termos-Chave e Associações Rápidas

| Termo na Prova | Pense em... |
|---------------|-------------|
| "apex domain" / "naked domain" / "zone apex" | Alias (não CNAME) |
| "lowest latency" / "best performance" | Latency-based routing |
| "active-passive" / "disaster recovery" | Failover routing |
| "blue-green" / "canary" / "gradual migration" | Weighted routing |
| "country-based" / "compliance" / "data residency" | Geolocation routing |
| "shift traffic" / "bias" / "expand region reach" | Geoproximity + Traffic Flow |
| "private resource health" / "health check VPC" | CloudWatch Alarm HC |
| "hybrid DNS" / "on-premises resolve AWS" | Route 53 Resolver (Inbound) |
| "AWS resolve on-premises names" | Route 53 Resolver (Outbound) |
| "DNS spoofing" / "cache poisoning" | DNSSEC |
| "100% availability SLA" | Route 53 |
| "distribute without load balancer" | Multi-Value routing |
| "known client IPs" / "ISP routing" | IP-based routing |
| "free DNS queries" | Alias record |
| "visual routing editor" / "complex policy" | Traffic Flow |

### 13.3 Pegadinhas Comuns

1. **Alias NÃO aponta para EC2** — use A record com IP público
2. **CNAME não funciona no apex** — sempre Alias no apex
3. **Geoproximity REQUER Traffic Flow** — não pode ser configurado sem ele
4. **Failover REQUER HC no primary** — é mandatório, não opcional
5. **Multi-Value NÃO é load balancer** — é DNS-level, máx 8 IPs
6. **Health Checkers precisam de acesso** — abrir SG/NACL para IPs dos checkers
7. **Simple routing NÃO suporta HC** — se precisar de HC, use Multi-Value
8. **Private Hosted Zone precisa de VPC settings** — enableDnsHostnames + enableDnsSupport
9. **TTL do Alias é controlado pela AWS** — você não pode alterá-lo
10. **DNSSEC apenas para Public Zones** — Private Zones não suportam

---

## 14. Resumo Visual — Árvore de Decisão para Routing Policy

```
Precisa rotear DNS?
│
├── Recurso único, sem requisitos especiais?
│   └── ✅ SIMPLE
│
├── Distribuir tráfego por peso/percentual?
│   └── ✅ WEIGHTED
│
├── Melhor performance/latência global?
│   └── ✅ LATENCY-BASED
│
├── Active-passive / DR?
│   └── ✅ FAILOVER
│
├── Rotear por localização do usuário (país/compliance)?
│   └── ✅ GEOLOCATION
│
├── Shift gradual de tráfego entre regiões com bias?
│   └── ✅ GEOPROXIMITY (+ Traffic Flow)
│
├── Rotear por CIDR/IP de origem?
│   └── ✅ IP-BASED
│
└── Múltiplos IPs com health check (sem ELB)?
    └── ✅ MULTI-VALUE
```

---

## 15. Referência Rápida de Custos

| Recurso | Custo |
|---------|-------|
| Hosted Zone | $0.50/mês |
| Standard Queries | $0.40/milhão |
| Latency/Geo/IP Queries | $0.70/milhão |
| Alias Queries (AWS targets) | GRÁTIS |
| Health Check (básico) | $0.50/mês |
| Health Check (fast + extras) | até $2.00/mês |
| Traffic Flow Policy Record | $50.00/mês |
| Domain Registration (.com) | ~$12-13/ano |
| Resolver Endpoint | ~$0.125/hora por direção |
| DNSSEC (KMS key) | $1.00/mês (CMK) |

---

*Última atualização: Julho 2026 — Baseado no exam guide SAA-C03*
