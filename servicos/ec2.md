# EC2 — Elastic Compute Cloud

## Famílias de Instância

| Família | Uso | Exemplos |
|---------|-----|----------|
| C (Compute) | CPU intensivo | HPC, servidores de jogos |
| R (RAM) | Memória intensiva | Bancos em memória, big data |
| M (General) | Balanceado | Servidores de aplicação |
| T (Burstable) | Uso geral com burst | Dev, testes, pequenas apps |
| I (I/O) | Storage intensivo | Bancos NoSQL, data warehousing |
| G/P | GPU | ML, deep learning, rendering |

## Opções de Compra

| Tipo | Desconto | Quando usar |
|------|----------|-------------|
| On-Demand | — | Workloads imprevisíveis |
| Reserved (1-3 anos) | até 72% | Workloads estáveis e previsíveis |
| Savings Plans | até 66% | Flexibilidade de instância/região |
| Spot | até 90% | Tolerante a interrupções (batch, CI/CD) |
| Dedicated Host | — | Licenças por socket/core |
| Dedicated Instance | — | Isolamento físico sem gerenciar host |

## EBS — Elastic Block Store

| Tipo | IOPS | Throughput | Uso |
|------|------|-----------|-----|
| gp3 | até 16.000 | 1.000 MB/s | Boot, apps gerais (RECOMENDADO) |
| gp2 | até 16.000 | — | Boot, apps gerais (legado) |
| io2 | até 64.000 | — | Bancos de dados críticos |
| io1 | até 64.000 | — | Bancos de dados (legado) |
| st1 | — | 500 MB/s | Big data, data warehouses |
| sc1 | — | 250 MB/s | Arquivos de acesso infrequente |

- **Instance Store:** ephemeral, alta I/O, dados perdidos ao parar a instância
- **EBS Multi-Attach:** apenas io1/io2, múltiplas instâncias na mesma AZ

## Placement Groups

| Tipo | Característica | Uso |
|------|---------------|-----|
| Cluster | Mesma AZ, baixa latência | HPC, aplicações de baixa latência |
| Spread | Instâncias em hardware distinto | Aplicações críticas, máx 7 por AZ |
| Partition | Grupos de instâncias em hardware distinto | HDFS, HBase, Cassandra |

## Diferenças Críticas

- **Security Groups:** stateful — resposta é permitida automaticamente
- **NACLs:** stateless — regras de entrada E saída devem ser configuradas explicitamente
- **EBS vs Instance Store:** EBS persiste após stop; Instance Store perde dados ao stop/terminate
