# Route 53

## Conceitos Fundamentais

- **Hosted Zone:** container para records DNS de um domínio
  - **Public Hosted Zone:** responde queries da internet
  - **Private Hosted Zone:** responde queries dentro de uma VPC
- **TTL:** tempo que o resultado fica em cache no cliente. Reduzir antes de migrações.

## Record Types

| Record | Aponta para | Exemplo |
|--------|------------|---------|
| A | IPv4 | `1.2.3.4` |
| AAAA | IPv6 | `::1` |
| CNAME | outro hostname | `app.site.com → alb.aws.com` |
| Alias | recurso AWS | `site.com → alb.us-east-1.amazonaws.com` |
| MX | servidor de email | — |
| TXT | texto (validação) | SPF, DMARC, verificação de domínio |
| NS | name servers da zona | — |

## Alias vs CNAME — DIFERENÇA CRÍTICA

| | Alias | CNAME |
|-|-------|-------|
| Aponta para | Recursos AWS (ALB, CloudFront, S3, etc.) | Qualquer hostname |
| Apex do domínio (`site.com`) | ✅ Suportado | ❌ Não suportado |
| Custo de query | ✅ Gratuito | 💰 Cobrado |
| TTL | Gerenciado pela AWS | Configurável |
| Health Check nativo | ✅ | ❌ |

> **Regra:** Sempre use Alias para apontar para recursos AWS. Use CNAME para recursos externos.

## Routing Policies

| Política | Descrição | Quando usar |
|---------|-----------|-------------|
| **Simple** | Retorna um ou mais IPs aleatoriamente | Único recurso, sem health check |
| **Weighted** | Distribui % do tráfego por record | A/B testing, migração gradual |
| **Latency** | Roteia para a região com menor latência | Apps multi-region |
| **Failover** | Primary ativo, Secondary em standby | Disaster recovery |
| **Geolocation** | Roteia por país/continente/default | Compliance, conteúdo localizado |
| **Geoproximity** | Roteia por proximidade geográfica com bias | Shift de tráfego entre regiões |
| **Multi-Value** | Retorna até 8 IPs saudáveis aleatoriamente | Distribuição simples com health check |

### Weighted Routing
- Record com peso `0` = não recebe tráfego
- Todos com peso `0` = distribuição igual entre todos

### Failover Routing
- **Primary:** recebe tráfego quando saudável
- **Secondary:** recebe tráfego quando primary falha
- Requer health check no primary

### Geolocation vs Geoproximity
- **Geolocation:** baseado em onde o usuário **está** (país/continente)
- **Geoproximity:** baseado em distância geográfica com **bias** ajustável (precisa do Route 53 Traffic Flow)

### Multi-Value vs Simple
- **Simple:** pode retornar múltiplos IPs, mas sem health check
- **Multi-Value:** retorna apenas IPs de instâncias **saudáveis** (não é load balancer, mas distribui a carga)

## Health Checks

| Tipo | O que monitora |
|------|---------------|
| Endpoint | HTTP/HTTPS/TCP direto ao recurso |
| Calculated | Combina resultados de múltiplos health checks |
| CloudWatch Alarm | Monitora alarme do CloudWatch (para recursos privados) |

- Health checks de endpoints: verificam de múltiplas regiões AWS
- Para recursos **privados** (dentro de VPC): usar CloudWatch Alarm + Calculated health check

## Diferenças Críticas

- **CNAME no apex (`site.com`):** inválido. Use Alias.
- **Geolocation vs Latency:** Geolocation é por origem do usuário; Latency é por performance de rede
- **Failover vs Multi-Value:** Failover é active-passive; Multi-Value é active-active com health checks
