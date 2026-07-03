# Semana 05 — Serverless
> 30/07 a 05/08/2026

## Checklist de Estudo

### Lambda
- [ ] Assistir aulas de Lambda no curso
- [ ] Modelo: event-driven, stateless
- [ ] Limites: timeout 15min, RAM 128MB-10GB, pacote 50MB zip / 250MB unzipped
- [ ] Triggers: S3, DynamoDB Streams, Kinesis, SQS, SNS, API Gateway, ALB, EventBridge
- [ ] Execution Role (IAM role)
- [ ] Environment Variables (plain text e encrypted via KMS)
- [ ] Layers (dependências compartilhadas, até 5 por função)
- [ ] Lambda@Edge vs CloudFront Functions
- [ ] Concurrency: Reserved vs Provisioned
- [ ] VPC Integration
- [ ] Lambda Destinations (sucesso e falha)
- [ ] Aliases e versões

### API Gateway
- [ ] REST API vs HTTP API vs WebSocket API — DIFERENÇA CRÍTICA
- [ ] Stages e deployments
- [ ] Throttling: 10.000 req/s padrão
- [ ] Usage Plans e API Keys
- [ ] Cache (TTL configurável)
- [ ] CORS configuration
- [ ] Authorizers: Lambda Authorizer, Cognito User Pool

### DynamoDB (aprofundamento)
- [ ] Partition Key e Sort Key
- [ ] Provisioned (RCU/WCU) vs On-Demand
- [ ] Cálculos de RCU e WCU
- [ ] GSI (Global Secondary Index)
- [ ] LSI (Local Secondary Index)
- [ ] DynamoDB Streams + Lambda
- [ ] DAX (cache in-memory, microsegundos)
- [ ] TTL
- [ ] Transactions (ACID)
- [ ] Global Tables (multi-region, multi-master)

### Outros Serverless
- [ ] Step Functions: Standard vs Express Workflows
- [ ] AppSync: GraphQL managed
- [ ] Cognito User Pools vs Identity Pools — DIFERENÇA CRÍTICA

### Prática
- [ ] Criar função Lambda com trigger S3
- [ ] Criar API Gateway + Lambda (CRUD simples)
- [ ] Criar tabela DynamoDB com GSI
- [ ] Testar DynamoDB Streams + Lambda

## Simulado da Semana
- [ ] 20 questões de Lambda/API Gateway — Tutorials Dojo
- [ ] 20 questões de DynamoDB — Tutorials Dojo
- [ ] Revisar todos os erros

## Horas Estudadas
| Dia | Horas | Observações |
|-----|-------|-------------|
| Qua 30/07 | | |
| Qui 31/07 | | |
| Sex 01/08 | | |
| Sáb 02/08 | | |
| Dom 03/08 | | |
| Seg 04/08 | | |
| Ter 05/08 | | |
| **Total** | | |
