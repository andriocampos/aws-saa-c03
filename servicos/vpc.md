# VPC — Virtual Private Cloud

## Componentes Essenciais

- **VPC:** rede virtual isolada logicamente, por região
- **Subnet:** subdivisão da VPC, por AZ
- **Route Table:** controla roteamento de tráfego
- **Internet Gateway (IGW):** acesso público à internet (entrada e saída)
- **NAT Gateway:** saída para internet de subnets privadas (sem entrada)

## Subnet Pública vs Privada

| | Pública | Privada |
|-|---------|---------|
| Route Table | rota para IGW | sem rota para IGW |
| Acesso direto da internet | ✅ | ❌ |
| Acesso à internet (saída) | via IGW | via NAT Gateway |

## NAT Gateway vs NAT Instance

| | NAT Gateway | NAT Instance |
|-|-------------|--------------|
| Gerenciamento | AWS gerencia | Você gerencia |
| Alta disponibilidade | automático | manual com script |
| Bandwidth | até 100 Gbps | depende do tipo de instância |
| Custo | mais caro | mais barato |
| Uso recomendado | produção | dev/lab |

## Security Groups vs NACLs — DIFERENÇA CRÍTICA

| | Security Group | NACL |
|-|---------------|------|
| Nível | Instância (ENI) | Subnet |
| Stateful | ✅ Sim | ❌ Não |
| Regras de saída | automáticas (stateful) | devem ser configuradas |
| Allow e Deny | apenas Allow | Allow e Deny |
| Avaliação | todas as regras | ordem numérica (primeiro match) |

## Conectividade

| Tipo | Descrição |
|------|-----------|
| VPC Peering | Conexão direta entre VPCs, não transitiva |
| Transit Gateway | Hub central para múltiplas VPCs e on-premises |
| VPC Endpoint Gateway | Acesso privado a S3 e DynamoDB |
| VPC Endpoint Interface (PrivateLink) | Acesso privado a outros serviços AWS |
| Site-to-Site VPN | Túnel criptografado over internet |
| Direct Connect | Conexão dedicada física, menor latência |

## Diferenças Críticas

- **VPC Peering vs Transit Gateway:** Peering é 1:1 e não transitivo; TGW é hub-and-spoke e transitivo
- **NAT Gateway vs IGW:** IGW permite tráfego de entrada e saída; NAT Gateway só saída (masquerade)
- **Interface Endpoint vs Gateway Endpoint:** Gateway Endpoint é gratuito (S3/DynamoDB); Interface Endpoint tem custo por hora
