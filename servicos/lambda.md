# Lambda

## Limites Importantes

| Parâmetro | Limite |
|-----------|--------|
| Timeout máximo | 15 minutos |
| RAM | 128 MB a 10 GB |
| Pacote de deploy (zip) | 50 MB |
| Pacote descomprimido | 250 MB |
| /tmp storage | 512 MB a 10 GB |
| Variáveis de ambiente | 4 KB |
| Concorrência padrão | 1.000 por região |

## Concorrência

- **Reserved Concurrency:** reserva X execuções para uma função (limita e garante)
- **Provisioned Concurrency:** pré-inicializa instâncias para eliminar cold starts
- Cold start: primeira execução ou após inatividade — VPC piora o cold start

## Triggers Comuns

S3, DynamoDB Streams, Kinesis, SQS, SNS, API Gateway, ALB, EventBridge, Cognito, CloudFront (Lambda@Edge)

## Lambda@Edge vs CloudFront Functions

| | Lambda@Edge | CloudFront Functions |
|-|-------------|---------------------|
| Runtime | Node.js, Python | JavaScript |
| Tempo máximo | 5-30 segundos | < 1ms |
| Eventos | Viewer + Origin request/response | Viewer request/response |
| Acesso a rede | ✅ Sim | ❌ Não |
| Custo | Maior | Menor |

## Boas Práticas

- Código fora do handler é reutilizado entre invocações (warm instances)
- Usar variáveis de ambiente para configuração
- Usar Layers para dependências compartilhadas entre funções
- RDS Proxy para evitar esgotamento de conexões com bancos relacionais
