# Semana 06 — Integração + CDN
> 06/08 a 12/08/2026 | Semana 6 de 10

## Objetivo
Desacoplar arquiteturas com mensageria e acelerar entrega de conteúdo com CloudFront.

## Serviços desta semana
| Serviço | Arquivo de referência |
|---------|----------------------|
| SQS, SNS, EventBridge, Kinesis | [../../servicos/mensageria.md](../../servicos/mensageria.md) |
| CloudFront + Global Accelerator | [../../servicos/cloudfront.md](../../servicos/cloudfront.md) |

## Arquivos desta semana
- [checklist.md](./checklist.md)
- [anotacoes.md](./anotacoes.md)

## Dica da semana
CloudFront vs Global Accelerator é armadilha clássica.
CloudFront = cache HTTP. Global Accelerator = roteamento TCP/UDP com IP fixo.
SQS vs Kinesis: SQS para filas de trabalho; Kinesis para streaming com replay.
