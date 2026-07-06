# Semana 01 — Anotações

## IAM ✅ (concluído em 05/07)

### Progresso
- Material expandido: `servicos/iam.md` (770 linhas)
- Guia com analogias: `servicos/iam-guia-didatico.md` (602 linhas)
- Quiz: `simulados/quiz-iam.py` (30 questões)
- Material de reforço: `simulados/reforco-iam-erros.md`

### Resultados dos simulados
| Tentativa | Score | Data |
|-----------|:-----:|------|
| Quiz 1 (30 questões) | 76% | 05/07 |
| Quiz 2 (15 questões) | 93% | 05/07 |

### Pontos que precisei reforçar
- Identity Center vs Directory Service (SSO = Identity Center, não AD)
- Ferramentas de auditoria: Report (status) vs Advisor (uso) vs Analyzer (exposição)
- STS durações: AssumeRole = 1h padrão (não 15min)
- aws:PrincipalOrgID para dar acesso a toda a Organization
- Permission Set cria Role na conta destino

### Conceitos dominados
- Lógica de avaliação (Deny vence)
- Trust Policy vs Permission Policy
- Cross-account (Resource-based mantém permissões, AssumeRole perde)
- Permission Boundaries (interseção)
- SCPs (afeta root da conta-membro, não afeta Management Account)
- ABAC (controle por tags)
- Conditions (AND entre chaves, OR entre valores)

---

## EC2 ✅ (concluído em 06/07)

### Resultados do simulado
| Tentativa | Score | Data |
|-----------|:-----:|------|
| Quiz EC2 (30 questões) | 93% | 06/07 |

### Erros (apenas 2)
- ENI vs ENA vs EFA: confundi com Direct Connect/VPN. Correto: ENI=NIC virtual, ENA=100Gbps, EFA=HPC OS-bypass
- io2 Block Express vs io2 standard: não sabia o limite. io2 standard=64K IOPS, Block Express=256K IOPS

### Conceitos dominados
- Famílias de instância (P/G=GPU, C=compute, R=memory, T=burstable, M=general)
- Opções de compra (RI Standard vs Convertible, Spot Fleet, Savings Plans)
- EBS completo (gp2 vs gp3, io2, st1/sc1, Multi-Attach, snapshots)
- Instance Store (efêmero, milhões IOPS)
- Placement Groups (Cluster=HPC, Spread=HA max 7/AZ, Partition=big data)
- Hibernate (RAM em EBS criptografado, max 150GB, max 60 dias)
- Security Groups (stateful), Elastic IP (5/região), User Data (root, 1º boot)
- Golden AMI, AMI cross-region copy
- T3 burst credits + unlimited mode
- Billing (stopped = cobra EBS + EIP não associado)

---

## Semana 01 — CONCLUÍDA ✅

Próximo: Semana 02 (VPC + S3)
