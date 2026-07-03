# DynamoDB

## Conceitos Fundamentais

- NoSQL serverless, totalmente gerenciado, multi-AZ por padrão
- Latência de milissegundos (DAX para microssegundos)
- **Partition Key (Hash Key):** obrigatória, determina a partição física
- **Sort Key (Range Key):** opcional, permite múltiplos itens com mesma partition key
- Item máximo: 400KB

## Capacity Modes

| | Provisioned | On-Demand |
|-|-------------|-----------|
| Configuração | Define RCU e WCU | Automático |
| Custo | Menor (previsível) | Maior (por request) |
| Auto Scaling | ✅ Disponível | ✅ Automático |
| Quando usar | Tráfego previsível e estável | Tráfego imprevisível ou novo |

## Cálculos de RCU e WCU

### RCU (Read Capacity Unit)
- **1 RCU** = 1 leitura strongly consistent de **até 4KB/s**
- **1 RCU** = 2 leituras eventually consistent de **até 4KB/s**
- **2 RCU** = 1 leitura transacional de até 4KB/s

**Exemplo:** ler 10 itens de 6KB cada, strongly consistent:
- 6KB ÷ 4KB = 1,5 → arredonda para **2 RCU por item**
- 10 × 2 = **20 RCU necessários**

### WCU (Write Capacity Unit)
- **1 WCU** = 1 escrita de **até 1KB/s**
- **2 WCU** = 1 escrita transacional de até 1KB/s

**Exemplo:** escrever 5 itens de 4,5KB cada:
- 4,5KB ÷ 1KB = 4,5 → arredonda para **5 WCU por item**
- 5 × 5 = **25 WCU necessários**

## Indexes

| | GSI | LSI |
|-|-----|-----|
| Nome completo | Global Secondary Index | Local Secondary Index |
| Partition Key | Diferente da tabela | Mesma da tabela |
| Sort Key | Qualquer | Diferente da tabela |
| Criação | A qualquer momento | Apenas na criação da tabela |
| Consistência | Eventually consistent | Strongly ou eventually |
| Throughput próprio | ✅ Sim | ❌ Compartilha com a tabela |
| Limite por tabela | 20 | 5 |

## DynamoDB Streams
- Captura sequência ordenada de modificações nos itens (insert, update, delete)
- Retenção: 24 horas
- Integra com Lambda para processamento em tempo real
- Casos de uso: replicação, auditoria, notificações, analytics

## DAX — DynamoDB Accelerator
- Cache in-memory para DynamoDB
- Latência de **microssegundos** (vs milissegundos sem cache)
- Totalmente compatível com a API do DynamoDB (sem mudança no código)
- Recomendado para: reads intensivos, hot partitions
- **Não recomendado para:** writes intensivos, strongly consistent reads obrigatórios

## TTL — Time to Live
- Define um atributo de expiração (epoch timestamp) nos itens
- Itens expirados são deletados automaticamente (assíncrono, pode demorar 48h)
- Sem custo de WCU para deleções por TTL
- Caso de uso: sessões, dados temporários, carrinhos abandonados

## Global Tables
- Replicação multi-region, multi-master (leitura e escrita em qualquer região)
- Requer On-Demand capacity ou Auto Scaling habilitado
- Requer DynamoDB Streams habilitado
- Resolução de conflitos: last-writer-wins

## Transactions
- Operações ACID em múltiplos itens e tabelas
- `TransactWriteItems` e `TransactGetItems`
- Custo: 2× WCU ou 2× RCU (por ser transacional)

## Diferenças Críticas

- **GSI vs LSI:** GSI tem partition key diferente e pode ser criado depois; LSI tem mesma partition key e só pode ser criado com a tabela
- **DAX vs ElastiCache:** DAX é específico para DynamoDB (API compatível); ElastiCache é genérico para qualquer banco
- **Provisioned vs On-Demand:** Provisioned é mais barato para tráfego previsível; On-Demand é ideal para workloads esporádicos
