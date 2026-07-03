# Laboratórios Práticos

> Cada lab tem instruções para o console AWS e código Terraform documentado.
> Faça os labs na **primeira vez pelo console** para visualizar a interface.
> Use o **Terraform para repetir** o lab rapidamente ou destruir e recriar.

## Pré-requisitos

- [ ] AWS CLI configurado (`aws configure`)
- [ ] Terraform instalado (`terraform version`)
- [ ] AWS Free Tier ativo
- [ ] Alerta de billing configurado no CloudWatch (recomendado)

---

## Índice dos Labs

| Lab | Semana | Serviços | Custo estimado |
|-----|--------|----------|----------------|
| [Lab 01 — VPC Básica](./lab-01-vpc-basica/README.md) | Semana 02 | VPC, IGW, NAT GW, Subnets | ~$0.045/h (NAT GW) |
| [Lab 02 — EC2 com ALB e ASG](./lab-02-ec2-com-alb/README.md) | Semana 03 | ALB, ASG, EC2, Launch Template | ~$0.016/h (ALB) |
| [Lab 03 — S3 Site Estático](./lab-03-s3-estatico/README.md) | Semana 02 | S3, Lifecycle, Versioning | Praticamente gratuito |
| [Lab 04 — IAM Roles e Políticas](./lab-04-iam-roles/README.md) | Semana 01 | IAM, Roles, Policies | Gratuito |
| [Lab 05 — RDS Multi-AZ](./lab-05-rds-multi-az/README.md) | Semana 04 | RDS MySQL, Multi-AZ, Read Replica | ~$0.02/h (db.t3.micro) |

> ⚠️ **NAT Gateway e RDS Multi-AZ geram custo por hora.** Destrua os recursos imediatamente após o lab.

---

## Como usar o Terraform

### Fluxo padrão de cada lab

```bash
# Acesse a pasta do lab
cd laboratorios/lab-01-vpc-basica/terraform

# Copie o exemplo de variáveis
cp terraform.tfvars.example terraform.tfvars

# Edite as variáveis conforme necessário
nano terraform.tfvars

# Veja o plano (o que será criado) — sem criar nada
terraform plan

# Crie os recursos na AWS
terraform apply

# Após o lab: DESTRUA TUDO para evitar custo
terraform destroy
```

### Comandos úteis

```bash
# Ver o estado atual dos recursos
terraform show

# Ver outputs após o apply
terraform output

# Formatar o código
terraform fmt

# Validar a configuração
terraform validate
```

### Arquivos de cada lab

| Arquivo | Função |
|---------|--------|
| `providers.tf` | Define o provider AWS e versão do Terraform |
| `variables.tf` | Declara todas as variáveis com descrições |
| `main.tf` | Recursos AWS com comentários explicativos |
| `outputs.tf` | Valores exportados após o apply |
| `terraform.tfvars.example` | Template de variáveis — copie para `terraform.tfvars` |
| `.gitignore` | Exclui `.tfstate`, `.terraform/` e `terraform.tfvars` do git |

### Atenção à senha do RDS (Lab 05)
Nunca coloque senhas no `terraform.tfvars`. Use variável de ambiente:

```bash
export TF_VAR_db_password="SuaSenhaForte123!"
terraform apply
```

---

## Custo Total Estimado (todos os labs, ~2h cada)

| Lab | Custo aprox. (2h) |
|-----|-------------------|
| Lab 01 (com NAT GW) | ~$0.09 |
| Lab 02 (com ALB) | ~$0.03 |
| Lab 03 (S3) | ~$0.00 |
| Lab 04 (IAM) | ~$0.00 |
| Lab 05 (RDS Multi-AZ) | ~$0.04 |
| **Total** | **~$0.16** |

> Configure um budget alert no AWS Budgets para evitar surpresas.
