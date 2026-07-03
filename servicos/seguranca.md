# Segurança — KMS, Secrets Manager e SSM

## KMS — Key Management Service

### Tipos de Chave
| Tipo | Gerenciado por | Rotação |
|------|---------------|---------|
| AWS Managed Keys | AWS | Automática (anual) |
| Customer Managed Keys (CMK) | Cliente | Manual ou automática |
| Customer Provided Keys | Cliente | Cliente gerencia |

### Envelope Encryption
1. KMS gera um **Data Key** (DEK)
2. DEK criptografa os dados
3. KMS criptografa o DEK com a CMK
4. DEK criptografado é armazenado junto com os dados
5. Para descriptografar: KMS descriptografa o DEK, DEK descriptografa os dados

### Key Policies
- Toda CMK tem uma key policy (resource-based)
- Sem key policy, ninguém acessa a chave (nem root)

## Secrets Manager vs SSM Parameter Store — DIFERENÇA CRÍTICA

| | Secrets Manager | SSM Parameter Store |
|-|----------------|---------------------|
| Custo | ~$0,40/segredo/mês | Gratuito (Standard) |
| Rotação automática | ✅ Nativa (Lambda) | ❌ Manual/Lambda custom |
| Integração RDS | ✅ Nativa | ❌ Manual |
| Cross-account | ✅ | Com RAM |
| Casos de uso | Credentials de banco, API keys | Configurações, parâmetros |

**Regra prática:** Use Secrets Manager quando precisar de rotação automática. Use SSM Parameter Store para configurações gerais e quando custo importa.

## WAF vs Shield

| | WAF | Shield |
|-|-----|--------|
| Protege contra | Ataques camada 7 (SQL injection, XSS) | DDoS |
| Camada | 7 (HTTP/HTTPS) | 3/4 e 7 |
| Standard | N/A | Gratuito (automático) |
| Advanced | Pago | Pago ($3.000/mês) |
| Recursos protegidos | ALB, API Gateway, CloudFront | CloudFront, Route 53, ALB, EC2 |
