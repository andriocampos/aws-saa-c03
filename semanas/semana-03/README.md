# Semana 03 — Alta Disponibilidade
> 16/07 a 22/07/2026 | Semana 3 de 10

## Objetivo
Arquitetar soluções escaláveis e tolerantes a falhas com ELB, ASG e Route 53.

## Serviços desta semana
| Serviço | Arquivo de referência |
|---------|----------------------|
| ELB + ASG | [../../servicos/elb-asg.md](../../servicos/elb-asg.md) |
| Route 53 | [../../servicos/route53.md](../../servicos/route53.md) |

## Labs relacionados
- [Lab 02 — EC2 com ALB e Auto Scaling](../../laboratorios/lab-02-ec2-com-alb/README.md)

## Arquivos desta semana
- [checklist.md](./checklist.md)
- [anotacoes.md](./anotacoes.md)

## Dica da semana
ALB vs NLB: ALB é camada 7 (HTTP), NLB é camada 4 (TCP/UDP) com IP estático.
Route 53 Routing Policies: entenda QUANDO usar cada uma — Failover vs Multi-Value é armadilha comum.
