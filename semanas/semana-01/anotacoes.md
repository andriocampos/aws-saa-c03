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

## EC2 — Em andamento 🔄

### Próximos passos
- Ler material expandido: `servicos/ec2.md`
- Estudar famílias de instância, opções de compra, EBS
- Fazer quiz de EC2 quando terminar
