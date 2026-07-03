# CloudFront + Global Accelerator

## CloudFront

### Arquitetura
- **Edge Locations:** ~400+ PoPs ao redor do mundo — servem conteúdo do cache
- **Regional Edge Caches:** camada intermediária entre origem e Edge Locations — cache maior e menos frequente
- **Origin:** onde o CloudFront busca o conteúdo quando não está em cache (S3, ALB, EC2, HTTP custom)

### OAC vs OAI
| | OAC (Origin Access Control) | OAI (Origin Access Identity) |
|-|-----------------------------|-----------------------------|
| Status | ✅ Atual (recomendado) | ⚠️ Legado |
| Suporte | S3, MediaStore | Apenas S3 |
| Suporte a SSE-KMS | ✅ | ❌ |

Ambos permitem que CloudFront acesse bucket S3 privado sem expor o bucket à internet.

### Cache Behaviors
- Regras baseadas em URL path que definem como o CloudFront trata cada tipo de conteúdo
- Exemplo: `/api/*` → sem cache (TTL=0) | `/static/*` → cache por 1 dia
- Cada behavior pode ter origin diferente, cache policy diferente

### TTL e Cache
- **Minimum TTL:** tempo mínimo de cache independente do header
- **Maximum TTL:** limite superior do TTL
- **Default TTL:** usado quando a origem não envia headers de cache
- **Cache Invalidation:** remove objetos do cache manualmente (cobrado por path, `/images/*` = 1 invalidation)

### Geo Restriction
- **Allowlist:** apenas países da lista podem acessar
- **Blocklist:** países da lista são bloqueados
- Usa banco de dados de geolocalização de IP

### Signed URLs vs Signed Cookies — DIFERENÇA CRÍTICA
| | Signed URL | Signed Cookie |
|-|-----------|---------------|
| Acesso a | 1 objeto específico | Múltiplos objetos |
| Casos de uso | Download de arquivo específico, streaming individual | Acesso a área premium, múltiplos arquivos |
| Compatibilidade | Qualquer client | Apenas browsers (suporte a cookies) |

### CloudFront Functions vs Lambda@Edge
| | CloudFront Functions | Lambda@Edge |
|-|---------------------|-------------|
| Runtime | JavaScript (ES5.1) | Node.js, Python |
| Tempo máximo de execução | < 1ms | 5s (viewer) / 30s (origin) |
| Acesso à rede | ❌ | ✅ |
| Acesso ao corpo da requisição | ❌ | ✅ |
| Eventos suportados | Viewer Request/Response | Viewer + Origin Request/Response |
| Custo | Muito menor | Maior |
| Escala | Milhões de req/s | Milhares de req/s |

**Quando usar CloudFront Functions:** header manipulation, URL rewrites, validação de tokens simples
**Quando usar Lambda@Edge:** lógica complexa, acesso a recursos externos, autenticação avançada

---

## Global Accelerator

- 2 **Anycast IPs estáticos** globais — os mesmos IPs funcionam em qualquer região
- Tráfego entra na rede AWS pelo Edge Location mais próximo do usuário
- Roteia internamente pela rede privada da AWS (mais estável e rápido que a internet pública)
- Suporta TCP e UDP (camada 4)
- Failover automático entre regiões em ~30s

## CloudFront vs Global Accelerator — DIFERENÇA CRÍTICA

| | CloudFront | Global Accelerator |
|-|------------|-------------------|
| O que faz | Cache de conteúdo (CDN) | Roteamento de rede otimizado |
| Protocolo | HTTP/HTTPS | TCP/UDP (qualquer protocolo) |
| Cache | ✅ Sim | ❌ Não |
| Latência melhora por | Cache próximo ao usuário | Rede privada AWS |
| IP fixo | ❌ DNS dinâmico | ✅ 2 IPs Anycast fixos |
| Casos de uso | Sites, APIs, vídeo, assets estáticos | Jogos, IoT, VoIP, apps não-HTTP |
| Failover | Por origin health check | Automático por região (~30s) |

> **Regra prática:** Se o conteúdo pode ser cacheado → CloudFront. Se precisar de IP fixo ou protocolo não-HTTP → Global Accelerator.
