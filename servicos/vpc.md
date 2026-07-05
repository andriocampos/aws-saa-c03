# VPC — Virtual Private Cloud

> Rede virtual **isolada logicamente** dentro da AWS, por **região**. É o fundamento de toda a arquitetura de rede na nuvem AWS.

---

## 1. Conceitos Fundamentais

### VPC — Visão Geral

- Uma VPC é uma rede virtual dedicada à sua conta AWS
- Escopo: **regional** (abrange todas as AZs da região)
- Cada conta possui uma **Default VPC** por região (criada automaticamente)
- Você pode criar até **5 VPCs por região** (soft limit, pode aumentar)
- Uma VPC precisa de um bloco CIDR IPv4 (obrigatório)

### Default VPC vs Custom VPC

| Aspecto | Default VPC | Custom VPC |
|---------|-------------|------------|
| **Criação** | Automática (uma por região) | Manual |
| **CIDR** | `172.31.0.0/16` | Você define (/16 a /28) |
| **Subnets** | Uma pública por AZ (auto-criada) | Você cria manualmente |
| **Internet Gateway** | Já anexado | Você cria e anexa |
| **Route Table** | Rota para IGW (0.0.0.0/0) | Só rota local |
| **Public IP** | Auto-assign habilitado | Desabilitado por padrão |
| **DNS hostnames** | Habilitado | Desabilitado por padrão |
| **Uso recomendado** | Testes rápidos, labs | Produção, workloads reais |

> ⚠️ **Na prova:** Se a questão diz "instância EC2 lançada sem especificar VPC", ela vai para a **Default VPC** e terá IP público automaticamente.

### CIDR Notation — Cálculo de Subnets

CIDR (Classless Inter-Domain Routing) define o range de IPs da VPC e subnets.

```
Formato: x.x.x.x/n

/n = número de bits fixos (network portion)
Bits de host = 32 - n
Total de IPs = 2^(32-n)
```

### Tabela de referência CIDR

| CIDR | Bits de host | Total de IPs | IPs utilizáveis* | Uso típico |
|------|:---:|:---:|:---:|------|
| `/16` | 16 | 65.536 | 65.531 | VPC inteira (máximo permitido) |
| `/17` | 15 | 32.768 | 32.763 | Metade de um /16 |
| `/18` | 14 | 16.384 | 16.379 | Subnet grande |
| `/19` | 13 | 8.192 | 8.187 | Subnet grande |
| `/20` | 12 | 4.096 | 4.091 | Subnet média |
| `/21` | 11 | 2.048 | 2.043 | Subnet média |
| `/22` | 10 | 1.024 | 1.019 | Subnet média |
| `/23` | 9 | 512 | 507 | Subnet pequena |
| `/24` | 8 | 256 | 251 | Subnet padrão |
| `/25` | 7 | 128 | 123 | Subnet pequena |
| `/26` | 6 | 64 | 59 | Subnet muito pequena |
| `/27` | 5 | 32 | 27 | Subnet mínima prática |
| `/28` | 4 | 16 | 11 | Menor subnet permitida |

*IPs utilizáveis = Total - 5 (reservados pela AWS)

### IPs Reservados pela AWS (5 por subnet)

Para uma subnet `10.0.1.0/24`:

| IP | Reservado para | Descrição |
|----|---------------|-----------|
| `10.0.1.0` | Network address | Endereço de rede |
| `10.0.1.1` | VPC Router | Gateway padrão da subnet |
| `10.0.1.2` | DNS Server | Mapeado para Amazon DNS |
| `10.0.1.3` | Future use | Reservado para uso futuro |
| `10.0.1.255` | Broadcast | Broadcast (AWS não suporta, mas reserva) |

> 📝 **Exemplo de cálculo:** Subnet /24 = 256 IPs - 5 reservados = **251 IPs disponíveis**
> Subnet /28 = 16 IPs - 5 reservados = **11 IPs disponíveis**

### CIDR secundários

- Você pode adicionar **até 4 CIDRs secundários** a uma VPC (total de 5)
- Os CIDRs não podem se sobrepor
- Útil quando o range original fica pequeno

### Exemplo prático: planejamento de VPC

```
VPC CIDR: 10.0.0.0/16 (65.536 IPs)

Subnet Pública AZ-a:  10.0.1.0/24   (251 IPs disponíveis)
Subnet Pública AZ-b:  10.0.2.0/24   (251 IPs disponíveis)
Subnet Privada AZ-a:  10.0.10.0/24  (251 IPs disponíveis)
Subnet Privada AZ-b:  10.0.20.0/24  (251 IPs disponíveis)
Subnet DB AZ-a:       10.0.100.0/24 (251 IPs disponíveis)
Subnet DB AZ-b:       10.0.200.0/24 (251 IPs disponíveis)
```

---

## 2. Subnets

### Características

- Escopo: **uma AZ** (uma subnet não pode abranger múltiplas AZs)
- Uma subnet pertence a exatamente uma Route Table
- Cada subnet tem seu próprio bloco CIDR (subset do CIDR da VPC)
- O CIDR da subnet não pode sobrepor outras subnets na mesma VPC

### Subnet Pública vs Privada

| Aspecto | Subnet Pública | Subnet Privada |
|---------|---------------|----------------|
| **Route Table** | Tem rota `0.0.0.0/0 → IGW` | NÃO tem rota para IGW |
| **IP Público** | Instâncias recebem IP público (auto-assign) | Sem IP público |
| **Acesso da internet** | ✅ Entrada e saída | ❌ Sem acesso direto |
| **Acesso à internet** | Direto via IGW | Via NAT Gateway (só saída) |
| **Recursos típicos** | ALB, NAT GW, Bastion Host | EC2 apps, RDS, ElastiCache |

### Como tornar uma Subnet pública — 3 requisitos

```
┌─────────────────────────────────────────────────────────────┐
│  SUBNET PÚBLICA = 3 condições obrigatórias:                 │
│                                                             │
│  1. Internet Gateway anexado à VPC                          │
│  2. Route Table com rota: 0.0.0.0/0 → IGW                  │
│  3. Instância com Public IP ou Elastic IP                   │
│                                                             │
│  ⚠️  Se QUALQUER uma faltar → sem acesso à internet         │
└─────────────────────────────────────────────────────────────┘
```

### Design Multi-AZ (Alta Disponibilidade)

```
                        VPC (10.0.0.0/16)
    ┌──────────────────────────────────────────────────────┐
    │                                                      │
    │   AZ-a (us-east-1a)          AZ-b (us-east-1b)      │
    │   ┌──────────────────┐       ┌──────────────────┐   │
    │   │ Pub: 10.0.1.0/24 │       │ Pub: 10.0.2.0/24 │   │
    │   │   [ALB] [NAT GW] │       │   [ALB] [NAT GW] │   │
    │   ├──────────────────┤       ├──────────────────┤   │
    │   │ Priv: 10.0.10.0/24│      │ Priv: 10.0.20.0/24│  │
    │   │   [EC2 App]       │      │   [EC2 App]       │  │
    │   ├──────────────────┤       ├──────────────────┤   │
    │   │ DB: 10.0.100.0/24│       │ DB: 10.0.200.0/24│   │
    │   │   [RDS Primary]   │      │   [RDS Standby]   │  │
    │   └──────────────────┘       └──────────────────┘   │
    │                                                      │
    └──────────────────────────────────────────────────────┘
```

> 📝 **Best Practice:** Sempre distribua recursos em pelo menos **2 AZs** para alta disponibilidade.

---

## 3. Internet Gateway (IGW)

### Características

- **Um IGW por VPC** (relação 1:1)
- **Altamente disponível** e redundante (gerenciado pela AWS)
- Escala horizontalmente — sem limite de bandwidth
- Não é um ponto único de falha
- Suporta IPv4 e IPv6
- Faz **NAT** para instâncias com IP público (traduz IP privado ↔ público)

### Como habilitar acesso à internet

```
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│  1. Criar Internet Gateway                                   │
│  2. Anexar IGW à VPC (Attach)                               │
│  3. Criar/editar Route Table da subnet                       │
│  4. Adicionar rota: 0.0.0.0/0 → IGW-id                     │
│  5. Garantir que instância tem IP público ou Elastic IP      │
│  6. Security Group permite tráfego necessário               │
│  7. NACL permite tráfego necessário                         │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Diagrama: fluxo de tráfego com IGW

```
Internet
    │
    ▼
┌────────┐       ┌──────────────┐       ┌──────────────┐
│  IGW   │◄─────►│ Route Table  │◄─────►│   Subnet     │
│        │       │ 0.0.0.0/0→IGW│       │  (pública)   │
└────────┘       └──────────────┘       │  ┌────────┐  │
                                        │  │  EC2   │  │
                                        │  │ IP Pub │  │
                                        │  └────────┘  │
                                        └──────────────┘
```

> ⚠️ **Na prova:** "Instância em subnet pública não acessa internet" → verificar: IGW existe? Rota para IGW? IP público? SG permite saída? NACL permite?

---

## 4. NAT Gateway vs NAT Instance

### NAT Gateway

- Serviço **gerenciado pela AWS**
- Permite que instâncias em subnets **privadas** acessem a internet (somente saída)
- Criado em uma **subnet pública** (precisa de Elastic IP)
- Escala automaticamente até **100 Gbps**
- Alta disponibilidade **dentro de uma AZ**

### NAT Instance (legacy)

- É uma **instância EC2** com AMI especial (amzn-ami-vpc-nat)
- Você gerencia tudo: patching, scaling, HA
- Deve desabilitar **Source/Destination Check**
- Pode ser usada como bastion host simultaneamente

### Tabela comparativa COMPLETA

| Aspecto | NAT Gateway | NAT Instance |
|---------|-------------|--------------|
| **Gerenciamento** | AWS (managed) | Você (self-managed) |
| **Disponibilidade** | HA dentro da AZ (redundância interna) | Single instance (manual HA com scripts) |
| **Multi-AZ HA** | Criar 1 NAT GW por AZ | ASG + scripts em múltiplas AZs |
| **Bandwidth** | Até 100 Gbps (escala automática) | Depende do tipo de instância |
| **Performance** | Otimizado para NAT | Limitado pela instância |
| **Custo** | Por hora + por GB processado | Por hora da instância + rede |
| **Elastic IP** | Obrigatório (1 por NAT GW) | Obrigatório |
| **Security Groups** | ❌ Não suporta (use NACL) | ✅ Suporta |
| **NACLs** | ✅ Aplica-se à subnet | ✅ Aplica-se à subnet |
| **Port Forwarding** | ❌ Não suporta | ✅ Suporta (iptables) |
| **Bastion Host** | ❌ Não pode ser usado | ✅ Pode ser usado como bastion |
| **Source/Dest Check** | N/A (managed) | Deve ser DESABILITADO |
| **Timeout idle** | 350s (TCP) | Configurável |
| **IP público fixo** | Sim (EIP) | Sim (EIP) |
| **Manutenção/Patching** | AWS | Você |
| **CloudWatch metrics** | Automático | Requer configuração |
| **Uso recomendado** | ✅ Produção | Dev/testes ou port forwarding |

### Arquitetura HA: NAT Gateway por AZ

```
                         Internet
                            │
                   ┌────────┴────────┐
                   │       IGW       │
                   └────────┬────────┘
                            │
          ┌─────────────────┼─────────────────┐
          │                 │                 │
    ┌─────┴─────┐    ┌─────┴─────┐    ┌─────┴─────┐
    │  Pub AZ-a │    │  Pub AZ-b │    │  Pub AZ-c │
    │ [NAT GW-a]│    │ [NAT GW-b]│    │ [NAT GW-c]│
    │  EIP: x.a │    │  EIP: x.b │    │  EIP: x.c │
    └─────┬─────┘    └─────┬─────┘    └─────┬─────┘
          │                 │                 │
    ┌─────┴─────┐    ┌─────┴─────┐    ┌─────┴─────┐
    │ Priv AZ-a │    │ Priv AZ-b │    │ Priv AZ-c │
    │  [EC2]    │    │  [EC2]    │    │  [EC2]    │
    │ RT: 0.0.0.0│   │ RT: 0.0.0.0│   │ RT: 0.0.0.0│
    │  → NAT-a  │    │  → NAT-b  │    │  → NAT-c  │
    └───────────┘    └───────────┘    └───────────┘
```

> 📝 **Best Practice:** Criar **um NAT Gateway por AZ** para evitar tráfego cross-AZ e garantir que se uma AZ cair, as outras continuam com acesso à internet.

> ⚠️ **Na prova:** "Alta disponibilidade para NAT" → **NAT Gateway em cada AZ** com route table apontando para o NAT GW local.

---

## 5. Route Tables

### Características

- Cada subnet é associada a **exatamente uma** Route Table
- Uma Route Table pode ser associada a **múltiplas** subnets
- A **Main Route Table** é usada por subnets sem associação explícita
- Rotas são avaliadas pela **rota mais específica** (longest prefix match)
- Rota local (`10.0.0.0/16 → local`) é automática e não pode ser removida

### Estrutura de uma Route Table

| Destination | Target | Descrição |
|-------------|--------|-----------|
| `10.0.0.0/16` | local | Tráfego interno da VPC (automático) |
| `0.0.0.0/0` | igw-xxxxx | Rota padrão para internet (subnet pública) |
| `0.0.0.0/0` | nat-xxxxx | Rota padrão via NAT (subnet privada) |
| `10.1.0.0/16` | pcx-xxxxx | VPC Peering para outra VPC |
| `pl-xxxxx` | vpce-xxxxx | Prefix list para VPC Endpoint |

### Longest Prefix Match (rota mais específica vence)

```
Rotas na Route Table:
  10.0.0.0/16  → local
  10.0.1.0/24  → pcx-12345
  0.0.0.0/0    → igw-abc

Pacote destino: 10.0.1.50
  Match 10.0.0.0/16? Sim (/16)
  Match 10.0.1.0/24? Sim (/24) ← MAIS ESPECÍFICA = VENCE
  Match 0.0.0.0/0?   Sim (/0)

Resultado: pacote vai para pcx-12345
```

### Route Propagation

- Permite que rotas do **Virtual Private Gateway (VGW)** sejam propagadas automaticamente
- Usado com Site-to-Site VPN e Direct Connect
- Evita criar rotas estáticas manualmente
- Habilitado por Route Table

### Exemplo: Route Tables de arquitetura típica

```
Route Table PÚBLICA (associada a subnets públicas):
┌─────────────────┬──────────────┐
│ Destination     │ Target       │
├─────────────────┼──────────────┤
│ 10.0.0.0/16    │ local        │
│ 0.0.0.0/0      │ igw-abc123   │
└─────────────────┴──────────────┘

Route Table PRIVADA AZ-a (associada a subnet privada AZ-a):
┌─────────────────┬──────────────┐
│ Destination     │ Target       │
├─────────────────┼──────────────┤
│ 10.0.0.0/16    │ local        │
│ 0.0.0.0/0      │ nat-gw-az-a  │
└─────────────────┴──────────────┘

Route Table PRIVADA AZ-b (associada a subnet privada AZ-b):
┌─────────────────┬──────────────┐
│ Destination     │ Target       │
├─────────────────┼──────────────┤
│ 10.0.0.0/16    │ local        │
│ 0.0.0.0/0      │ nat-gw-az-b  │
└─────────────────┴──────────────┘
```

---

## 6. Security Groups vs NACLs

### Security Groups (SGs)

- Operam no nível da **instância (ENI)**
- **Stateful**: se o tráfego de entrada é permitido, a resposta de saída é automática
- Só permitem regras de **ALLOW** (não existe DENY)
- **Todas as regras** são avaliadas antes de decidir
- Default SG: bloqueia todo inbound, permite todo outbound entre membros do mesmo SG
- Uma instância pode ter até **5 SGs** associados

### NACLs (Network Access Control Lists)

- Operam no nível da **subnet**
- **Stateless**: regras de entrada e saída são avaliadas independentemente
- Permitem regras de **ALLOW e DENY**
- Regras avaliadas em **ordem numérica** (primeiro match decide)
- Default NACL: permite TODO tráfego (inbound e outbound)
- Custom NACL: bloqueia TODO tráfego por padrão

### Tabela comparativa COMPLETA

| Aspecto | Security Group | NACL |
|---------|---------------|------|
| **Nível** | Instância (ENI) | Subnet |
| **Stateful/Stateless** | ✅ Stateful | ❌ Stateless |
| **Tipos de regra** | Somente ALLOW | ALLOW e DENY |
| **Avaliação** | Todas as regras (união) | Ordem numérica (primeiro match) |
| **Regras de retorno** | Automáticas (stateful) | Devem ser explícitas |
| **Ephemeral ports** | Não precisa configurar | DEVE permitir (1024-65535) |
| **Default (novo)** | Deny all inbound, Allow all outbound* | Allow all inbound e outbound |
| **Custom (novo)** | Deny all inbound/outbound | Deny all inbound e outbound |
| **Associação** | Até 5 SGs por ENI | 1 NACL por subnet |
| **Aplicação** | Apenas se associado à instância | Toda instância na subnet |
| **Regra deny IP** | ❌ Impossível | ✅ Use NACL para bloquear IP |
| **Uso principal** | Controle granular por recurso | Bloqueio de IPs, camada extra |

*O default SG permite tráfego entre membros do mesmo SG.

### Ephemeral Ports (Portas Efêmeras) — CRUCIAL para NACLs

```
Cliente faz request:
  Source Port: 49152 (efêmera, aleatória)
  Dest Port: 443 (HTTPS)

Servidor responde:
  Source Port: 443
  Dest Port: 49152 (porta efêmera do cliente)

Como NACL é STATELESS, você DEVE permitir:
  INBOUND:  porta 443 (request chegando)
  OUTBOUND: portas 1024-65535 (resposta voltando para porta efêmera)
```

| Sistema Operacional | Range de Ephemeral Ports |
|---------------------|--------------------------|
| Linux | 32768 - 60999 |
| Windows | 49152 - 65535 |
| NAT Gateway | 1024 - 65535 |
| ELB | 1024 - 65535 |

> 📝 **Na prova:** Para ser seguro, permita **1024-65535** nas regras de saída da NACL.

### Default NACL vs Custom NACL

```
DEFAULT NACL (criada com a VPC):
┌──────┬──────────┬──────────┬───────┬──────────┬────────┐
│ Rule │ Type     │ Protocol │ Port  │ Source   │ Action │
├──────┼──────────┼──────────┼───────┼──────────┼────────┤
│ 100  │ All IPv4 │ All      │ All   │ 0.0.0.0/0│ ALLOW  │
│ *    │ All IPv4 │ All      │ All   │ 0.0.0.0/0│ DENY   │
└──────┴──────────┴──────────┴───────┴──────────┴────────┘
(permite tudo por padrão — outbound igual)

CUSTOM NACL (criada por você):
┌──────┬──────────┬──────────┬───────┬──────────┬────────┐
│ Rule │ Type     │ Protocol │ Port  │ Source   │ Action │
├──────┼──────────┼──────────┼───────┼──────────┼────────┤
│ *    │ All IPv4 │ All      │ All   │ 0.0.0.0/0│ DENY   │
└──────┴──────────┴──────────┴───────┴──────────┴────────┘
(bloqueia tudo por padrão — você adiciona regras ALLOW)
```

### Exemplo prático: NACL para web server

```
INBOUND Rules:
┌──────┬──────────┬──────────┬────────────┬────────────┬────────┐
│ Rule │ Type     │ Protocol │ Port Range │ Source     │ Action │
├──────┼──────────┼──────────┼────────────┼────────────┼────────┤
│ 100  │ HTTP     │ TCP      │ 80         │ 0.0.0.0/0 │ ALLOW  │
│ 110  │ HTTPS    │ TCP      │ 443        │ 0.0.0.0/0 │ ALLOW  │
│ 120  │ SSH      │ TCP      │ 22         │ 10.0.0.0/16│ ALLOW  │
│ 130  │ Custom   │ TCP      │ 1024-65535 │ 0.0.0.0/0 │ ALLOW  │
│ *    │ All      │ All      │ All        │ 0.0.0.0/0 │ DENY   │
└──────┴──────────┴──────────┴────────────┴────────────┴────────┘

OUTBOUND Rules:
┌──────┬──────────┬──────────┬────────────┬────────────┬────────┐
│ Rule │ Type     │ Protocol │ Port Range │ Destination│ Action │
├──────┼──────────┼──────────┼────────────┼────────────┼────────┤
│ 100  │ HTTP     │ TCP      │ 80         │ 0.0.0.0/0 │ ALLOW  │
│ 110  │ HTTPS    │ TCP      │ 443        │ 0.0.0.0/0 │ ALLOW  │
│ 120  │ Custom   │ TCP      │ 1024-65535 │ 0.0.0.0/0 │ ALLOW  │
│ *    │ All      │ All      │ All        │ 0.0.0.0/0 │ DENY   │
└──────┴──────────┴──────────┴────────────┴────────────┴────────┘
```

> ⚠️ **Na prova:** "Bloquear um IP específico" → **NACL** (Security Groups não têm DENY).

### Ordem de processamento do tráfego

```
Tráfego INBOUND:
Internet → IGW → Route Table → NACL (inbound) → Security Group (inbound) → EC2

Tráfego OUTBOUND:
EC2 → Security Group (outbound) → NACL (outbound) → Route Table → IGW → Internet

⚠️  NACL é avaliada ANTES do Security Group (inbound)
⚠️  Security Group é avaliado ANTES da NACL (outbound)
```

---

## 7. VPC Peering

### Características

- Conexão de rede **privada** entre duas VPCs usando a infraestrutura AWS
- Tráfego fica na rede interna da AWS (não passa pela internet pública)
- **NÃO transitivo** — se A↔B e B↔C, A NÃO fala com C automaticamente
- Funciona **cross-account** e **cross-region**
- CIDRs **NÃO podem se sobrepor**
- Pode referenciar Security Groups da VPC pareada (same region only)
- Sem limite de bandwidth (mesma infraestrutura de rede da AWS)
- Sem single point of failure (altamente disponível)

### Não transitivo — CONCEITO CRÍTICO

```
    VPC-A (10.0.0.0/16)
        │
        │ Peering A↔B
        │
    VPC-B (10.1.0.0/16)
        │
        │ Peering B↔C
        │
    VPC-C (10.2.0.0/16)

❌ VPC-A NÃO consegue falar com VPC-C através de B!
✅ Para A falar com C: precisa de peering direto A↔C
```

### Para peering funcionar com N VPCs

```
3 VPCs = 3 peerings necessários  (A↔B, A↔C, B↔C)
4 VPCs = 6 peerings necessários
5 VPCs = 10 peerings necessários
N VPCs = N*(N-1)/2 peerings

→ Para muitas VPCs, considere Transit Gateway!
```

### Configuração de Route Tables

Ambas as VPCs devem ter rotas apontando para o peering:

```
VPC-A Route Table (10.0.0.0/16):
┌─────────────────┬──────────────┐
│ Destination     │ Target       │
├─────────────────┼──────────────┤
│ 10.0.0.0/16    │ local        │
│ 10.1.0.0/16    │ pcx-abc123   │  ← Rota para VPC-B
└─────────────────┴──────────────┘

VPC-B Route Table (10.1.0.0/16):
┌─────────────────┬──────────────┐
│ Destination     │ Target       │
├─────────────────┼──────────────┤
│ 10.1.0.0/16    │ local        │
│ 10.0.0.0/16    │ pcx-abc123   │  ← Rota para VPC-A
└─────────────────┴──────────────┘
```

### Passos para configurar VPC Peering

1. Criar peering connection request (VPC-A → VPC-B)
2. Aceitar o request (na conta/VPC-B)
3. Atualizar Route Tables em **AMBAS** as VPCs
4. Atualizar Security Groups para permitir tráfego da outra VPC
5. (Opcional) Habilitar DNS resolution para a VPC pareada

### Limitações

- Não suporta edge-to-edge routing (não pode usar IGW/NAT/VGW da outra VPC)
- Máximo de 125 peerings ativos por VPC (soft limit)
- CIDRs não podem overlap
- Não suporta roteamento transitivo

> ⚠️ **Na prova:** "Conexão privada entre 2 VPCs sem roteamento transitivo" → **VPC Peering**. "Conectar muitas VPCs com roteamento transitivo" → **Transit Gateway**.

---

## 8. VPC Endpoints

> Permitem acessar serviços AWS **sem passar pela internet pública** — tráfego fica na rede privada da AWS.

### Tipos de Endpoints

| Aspecto | Gateway Endpoint | Interface Endpoint (PrivateLink) |
|---------|-----------------|----------------------------------|
| **Serviços suportados** | Apenas **S3** e **DynamoDB** | 100+ serviços AWS e serviços de terceiros |
| **Como funciona** | Entrada na Route Table | ENI com IP privado na subnet |
| **Custo** | ✅ **Gratuito** | 💰 Por hora + por GB processado |
| **Onde fica** | Nível de VPC (Route Table) | Nível de subnet (ENI) |
| **Security Group** | ❌ Não (usa endpoint policy) | ✅ Sim (associa SG à ENI) |
| **DNS** | Não altera DNS | Cria DNS privado (private DNS) |
| **On-premises** | ❌ Não acessível de VPN/DX | ✅ Acessível via VPN/DX |
| **Cross-region** | ❌ Mesma região | ❌ Mesma região |
| **Alta disponibilidade** | ✅ Automática | Crie em múltiplas AZs |
| **Endpoint Policy** | ✅ Sim | ✅ Sim |

### Gateway Endpoint — Detalhes

```
Route Table da subnet privada:
┌────────────────────────┬──────────────┐
│ Destination            │ Target       │
├────────────────────────┼──────────────┤
│ 10.0.0.0/16           │ local        │
│ 0.0.0.0/0             │ nat-gw-xxx   │
│ pl-xxxxx (S3 prefixes)│ vpce-abc123  │  ← Gateway Endpoint
└────────────────────────┴──────────────┘
```

### Interface Endpoint (PrivateLink) — Detalhes

```
┌─────────────────────────────────────────────────────┐
│  VPC (10.0.0.0/16)                                  │
│                                                     │
│  Subnet Privada AZ-a                                │
│  ┌───────────────────────────────────────────┐      │
│  │  [EC2 App]                                │      │
│  │      │                                    │      │
│  │      │ DNS: sqs.us-east-1.amazonaws.com   │      │
│  │      │ resolve para → 10.0.1.55 (ENI)    │      │
│  │      ▼                                    │      │
│  │  [ENI - vpce-xxx] (10.0.1.55)            │      │
│  │      │ Security Group aplicado            │      │
│  └──────┼────────────────────────────────────┘      │
│         │                                           │
│         ▼                                           │
│    AWS SQS Service (via PrivateLink)                │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Endpoint Policies

- Controlam **quais ações** podem ser feitas através do endpoint
- Não substituem IAM policies (ambas devem permitir)
- Úteis para restringir acesso a buckets específicos do S3

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowSpecificBucket",
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::meu-bucket-app/*"
    }
  ]
}
```

### Quando usar cada tipo

| Cenário | Solução |
|---------|---------|
| EC2 privado acessa S3 | Gateway Endpoint (gratuito) |
| EC2 privado acessa DynamoDB | Gateway Endpoint (gratuito) |
| EC2 privado acessa SQS, SNS, KMS, etc. | Interface Endpoint |
| Acesso de on-premises via VPN/DX | Interface Endpoint |
| Lambda em VPC acessa serviço AWS | Interface Endpoint |

> ⚠️ **Na prova:** "Acesso privado a S3 sem custo adicional" → **Gateway Endpoint**. "Acesso privado a outros serviços AWS" → **Interface Endpoint**.

---

## 9. Transit Gateway (TGW)

> Hub central de rede para conectar múltiplas VPCs, VPNs e Direct Connects com **roteamento transitivo**.

### Características

- Arquitetura **hub-and-spoke** (estrela)
- **Roteamento transitivo** (diferente de VPC Peering)
- Suporta **milhares** de conexões
- Funciona cross-region (**Inter-Region Peering** entre TGWs)
- Funciona cross-account (via **AWS RAM - Resource Access Manager**)
- Suporta: VPCs, Site-to-Site VPN, Direct Connect Gateway, TGW Peering
- Suporta **IP Multicast** (único serviço AWS que suporta)
- Bandwidth: até **50 Gbps** por conexão VPC

### Diagrama: Hub-and-Spoke

```
                    ┌──────────────┐
                    │   On-Prem    │
                    │  Data Center │
                    └──────┬───────┘
                           │ Site-to-Site VPN
                           │ ou Direct Connect
                    ┌──────┴───────┐
                    │              │
        ┌───────────┤  TRANSIT GW  ├───────────┐
        │           │              │           │
        │           └──────┬───────┘           │
        │                  │                   │
   ┌────┴────┐      ┌─────┴─────┐      ┌─────┴────┐
   │  VPC-A  │      │   VPC-B   │      │  VPC-C   │
   │10.0.0/16│      │10.1.0/16  │      │10.2.0/16 │
   └─────────┘      └───────────┘      └──────────┘

✅ Todas as VPCs se comunicam entre si (transitivo)
✅ On-premises acessa todas as VPCs
✅ Uma única conexão VPN/DX serve para tudo
```

### Route Tables do Transit Gateway

- O TGW tem suas **próprias route tables** (separadas das VPCs)
- Permite **segmentação de rede** (isolamento entre VPCs)
- Cada attachment (VPC, VPN) é associado a uma route table do TGW

```
TGW Route Table "compartilhada":
┌─────────────────┬────────────────────┐
│ Destination     │ Attachment         │
├─────────────────┼────────────────────┤
│ 10.0.0.0/16    │ vpc-a-attachment   │
│ 10.1.0.0/16    │ vpc-b-attachment   │
│ 10.2.0.0/16    │ vpc-c-attachment   │
│ 192.168.0.0/16 │ vpn-attachment     │
└─────────────────┴────────────────────┘

TGW Route Table "isolada" (para VPC sensível):
┌─────────────────┬────────────────────┐
│ Destination     │ Attachment         │
├─────────────────┼────────────────────┤
│ 10.2.0.0/16    │ vpc-c-attachment   │
│ 192.168.0.0/16 │ vpn-attachment     │  ← só fala com on-prem
└─────────────────┴────────────────────┘
```

### TGW vs VPC Peering

| Aspecto | Transit Gateway | VPC Peering |
|---------|----------------|-------------|
| **Roteamento** | Transitivo | Não transitivo |
| **Escalabilidade** | Milhares de VPCs | N*(N-1)/2 conexões |
| **Complexidade** | Hub centralizado | Mesh (muitas conexões) |
| **Bandwidth** | 50 Gbps por VPC attachment | Sem limite definido |
| **Custo** | Por hora + por GB | Custo de transferência de dados |
| **Cross-region** | TGW Peering | VPC Peering cross-region |
| **On-premises** | VPN/DX no TGW | Não aplicável |
| **Multicast** | ✅ Suporta | ❌ Não suporta |
| **Uso ideal** | Muitas VPCs, topologia complexa | Poucas VPCs, conexão simples |

### Equal Cost Multi-Path (ECMP)

- Permite **agregar bandwidth** de múltiplos túneis VPN
- Cada túnel VPN = 1.25 Gbps
- Com ECMP no TGW: múltiplos túneis = bandwidth somada
- Exemplo: 4 conexões VPN com ECMP = 4 × 2.5 Gbps = **10 Gbps**

> ⚠️ **Na prova:** "Conectar dezenas de VPCs com roteamento transitivo" → **Transit Gateway**. "Suportar multicast na AWS" → **Transit Gateway**.

---

## 10. Site-to-Site VPN

> Conexão criptografada **IPsec** entre rede on-premises e VPC AWS através da internet pública.

### Componentes

| Componente | Lado | Descrição |
|------------|------|-----------|
| **Virtual Private Gateway (VGW)** | AWS | Gateway VPN no lado da AWS, anexado à VPC |
| **Customer Gateway (CGW)** | On-premises | Representação do device/software VPN do cliente |
| **VPN Connection** | Meio | 2 túneis IPsec (HA) entre VGW e CGW |

### Características

- **2 túneis** por conexão VPN (para alta disponibilidade)
- Cada túnel = **1.25 Gbps** máximo
- Criptografia IPsec
- Trafega pela **internet pública** (diferente de Direct Connect)
- Setup rápido (minutos)
- Suporta **route propagation** (rotas do VGW propagadas para Route Tables)
- Custo: por hora de conexão + transferência de dados

### Diagrama

```
On-Premises                              AWS
┌─────────────┐                  ┌───────────────────┐
│  Rede Corp  │                  │       VPC         │
│ 192.168.0/16│                  │   10.0.0.0/16     │
│             │     Internet     │                   │
│  ┌───────┐  │   ┌─────────┐   │  ┌─────────────┐  │
│  │  CGW  │──┼───┤ Túnel 1 ├───┼──┤     VGW     │  │
│  │       │──┼───┤ Túnel 2 ├───┼──┤             │  │
│  └───────┘  │   └─────────┘   │  └─────────────┘  │
│ IP público  │    IPsec/IKE     │   Anexado à VPC   │
└─────────────┘                  └───────────────────┘
```

### Route Propagation

```
VPC Route Table (com propagation habilitado):
┌─────────────────┬──────────────┬───────────────┐
│ Destination     │ Target       │ Propagated?   │
├─────────────────┼──────────────┼───────────────┤
│ 10.0.0.0/16    │ local        │ Não           │
│ 192.168.0.0/16 │ vgw-abc123   │ ✅ Sim (auto) │
└─────────────────┴──────────────┴───────────────┘
```

### VPN CloudHub

- Conecta **múltiplos sites on-premises** entre si através da AWS
- Usa um **único VGW** com múltiplas conexões VPN (cada site = 1 CGW)
- Os sites se comunicam entre si via o VGW (hub-and-spoke)
- Tráfego entre sites passa pela internet (criptografado)
- Baixo custo, fácil de configurar

```
         Site A (CGW-A)
              │
              │  VPN
              ▼
        ┌───────────┐
        │    VGW    │ ◄── Anexado à VPC
        │  (Hub)    │
        └───────────┘
         ▲         ▲
    VPN  │         │  VPN
         │         │
   Site B (CGW-B)  Site C (CGW-C)

✅ Sites A, B, C se comunicam entre si via VGW
✅ Todos acessam a VPC também
```

### VPN com Transit Gateway

- Alternativa ao VGW: anexar a VPN diretamente ao **Transit Gateway**
- Vantagem: ECMP para agregar bandwidth
- Vantagem: roteamento transitivo para múltiplas VPCs

> ⚠️ **Na prova:** "Conexão rápida e criptografada com on-premises" → **Site-to-Site VPN**. "Múltiplos escritórios conectados via AWS" → **VPN CloudHub**. "Mais bandwidth que 1.25 Gbps na VPN" → **TGW + ECMP**.

---

## 11. Direct Connect (DX)

> Conexão de rede **dedicada e privada** entre data center on-premises e AWS, sem passar pela internet pública.

### Características

- Conexão **física** via fibra óptica (não usa internet)
- **Latência consistente e baixa** (diferente de VPN que varia)
- Bandwidth: **1 Gbps, 10 Gbps** (dedicated) ou **50 Mbps a 10 Gbps** (hosted)
- Lead time: **semanas a meses** para provisionar (não é instantâneo!)
- NÃO é criptografada por padrão (é privada, mas sem encryption)
- Alta throughput para workloads com grande volume de dados

### Tipos de conexão

| Tipo | Bandwidth | Porta | Parceiro |
|------|-----------|-------|----------|
| **Dedicated** | 1 Gbps ou 10 Gbps ou 100 Gbps | Porta física exclusiva no DX Location | Direto com AWS |
| **Hosted** | 50 Mbps até 10 Gbps | Porta compartilhada via parceiro | Via AWS Partner |

### Virtual Interfaces (VIFs)

| VIF | Conecta a | Caso de uso |
|-----|-----------|-------------|
| **Private VIF** | VPC (via VGW ou DX Gateway) | Acessar recursos privados na VPC |
| **Public VIF** | Serviços públicos AWS (S3, Glacier, etc.) | Acessar endpoints públicos via DX (não internet) |
| **Transit VIF** | Transit Gateway | Acessar múltiplas VPCs via TGW |

### Diagrama: Direct Connect

```
On-Premises          DX Location             AWS Region
┌──────────┐      ┌──────────────┐      ┌──────────────────────┐
│          │      │              │      │                      │
│  Router  │──────│  AWS Router  │──────│   VGW → VPC          │
│  (CGW)   │ fibra│  (DX port)  │      │   ou                 │
│          │ ótica│              │      │   DX Gateway → VPCs  │
│          │      │  Cross-      │      │   ou                 │
│          │      │  connect     │      │   TGW → VPCs         │
└──────────┘      └──────────────┘      └──────────────────────┘
                                         Private VIF → VPC
                                         Public VIF → S3, etc.
                                         Transit VIF → TGW
```

### DX Gateway

- Permite conectar **uma DX a múltiplas VPCs** em diferentes **regiões**
- Evita precisar de uma DX por região
- Funciona com Private VIF e Transit VIF
- NÃO é um serviço de roteamento transitivo entre VPCs

```
On-Premises
    │
    │  Direct Connect (1 conexão física)
    ▼
┌─────────────┐
│ DX Gateway  │ (global)
└──────┬──────┘
       │
  ┌────┼─────────────────────┐
  │    │                     │
  ▼    ▼                     ▼
VGW   VGW                   VGW
VPC-A VPC-B                 VPC-C
us-east-1                   eu-west-1
```

### Link Aggregation Group (LAG)

- Agrupa **múltiplas conexões DX** em uma interface lógica
- Todas as conexões devem ter a **mesma bandwidth**
- Máximo de **4 conexões** por LAG (2 mínimo ativas para funcionar)
- Aumenta throughput e fornece resiliência

### Alta Disponibilidade e Resiliência

```
MÁXIMA RESILIÊNCIA (Mission Critical):
┌──────────┐     DX 1     ┌──────────────┐     ┌─────────┐
│          │──────────────►│ DX Location A│────►│         │
│  On-Prem │     DX 2     │              │     │   AWS   │
│          │──────────────►│              │────►│         │
│          │               └──────────────┘     │         │
│          │     DX 3     ┌──────────────┐     │         │
│          │──────────────►│ DX Location B│────►│         │
│          │     DX 4     │              │     │         │
│          │──────────────►│              │────►│         │
└──────────┘               └──────────────┘     └─────────┘

2 DX Locations + 2 conexões por location = tolerante a falha de location

ALTA RESILIÊNCIA (Produção):
1 DX + 1 VPN como backup (failover)

RESILIÊNCIA BÁSICA:
2 conexões DX no mesmo DX Location
```

### Encryption no Direct Connect

DX **NÃO** é criptografado nativamente. Opções:

| Método | Descrição | Quando usar |
|--------|-----------|-------------|
| **MACsec (802.1AE)** | Criptografia Layer 2 na conexão física | DX dedicado 10/100 Gbps, criptografia de alta performance |
| **VPN over DX** | Túnel IPsec sobre a conexão DX (Public VIF) | Qualquer DX, compliance exige criptografia end-to-end |

```
VPN over DX:
On-Prem → DX (Public VIF) → VGW → VPC
           └── túnel IPsec sobre o DX ──┘
           (combina: baixa latência DX + criptografia VPN)
```

### DX vs VPN — Comparação

| Aspecto | Direct Connect | Site-to-Site VPN |
|---------|---------------|------------------|
| **Meio** | Fibra dedicada (privado) | Internet pública |
| **Setup time** | Semanas/meses | Minutos |
| **Latência** | Consistente, baixa | Variável |
| **Bandwidth** | 1-100 Gbps | 1.25 Gbps por túnel |
| **Criptografia** | Não (sem MACsec/VPN) | Sim (IPsec) |
| **Custo** | Alto (porta + dados) | Baixo (hora + dados) |
| **Resiliência** | DX + backup VPN | 2 túneis por conexão |
| **Uso ideal** | Grande volume, baixa latência | Backup, POC, baixo volume |

> ⚠️ **Na prova:** "Conexão com latência consistente e alta throughput" → **Direct Connect**. "Backup para DX" → **Site-to-Site VPN**. "DX com criptografia" → **MACsec** ou **VPN over DX (Public VIF)**.

---

## 12. VPC Flow Logs

> Capturam informações sobre o tráfego IP **entrando e saindo** de interfaces de rede na VPC.

### Níveis de captura

| Nível | O que captura | Granularidade |
|-------|--------------|---------------|
| **VPC** | Todo tráfego da VPC | Todas as ENIs de todas as subnets |
| **Subnet** | Tráfego da subnet | Todas as ENIs da subnet |
| **ENI** | Tráfego de uma interface | Uma ENI específica |

### Destinos de entrega

| Destino | Caso de uso |
|---------|-------------|
| **CloudWatch Logs** | Análise em tempo real, alarmes, metric filters |
| **S3** | Armazenamento de longo prazo, análise com Athena |
| **Kinesis Data Firehose** | Streaming para ferramentas de terceiros |

### Campos do Flow Log (formato padrão)

```
<version> <account-id> <interface-id> <srcaddr> <dstaddr> <srcport> <dstport> <protocol> <packets> <bytes> <start> <end> <action> <log-status>
```

| Campo | Descrição |
|-------|-----------|
| `version` | Versão do formato (2) |
| `account-id` | ID da conta AWS |
| `interface-id` | ID da ENI (eni-xxxxx) |
| `srcaddr` | IP de origem |
| `dstaddr` | IP de destino |
| `srcport` | Porta de origem |
| `dstport` | Porta de destino |
| `protocol` | Número do protocolo (6=TCP, 17=UDP, 1=ICMP) |
| `packets` | Número de pacotes |
| `bytes` | Número de bytes |
| `start` | Timestamp início da janela |
| `end` | Timestamp fim da janela |
| `action` | ACCEPT ou REJECT |
| `log-status` | OK, NODATA, SKIPDATA |

### Exemplos de análise

```
# Tráfego ACEITO na porta 443:
2 123456789012 eni-abc123 10.0.1.50 52.94.76.5 49152 443 6 25 5000 1620000000 1620000060 ACCEPT OK

# Tráfego REJEITADO (tentativa SSH bloqueada):
2 123456789012 eni-abc123 203.0.113.50 10.0.1.50 12345 22 6 3 180 1620000000 1620000060 REJECT OK
```

### Troubleshooting com Flow Logs

| Sintoma | O que verificar no Flow Log |
|---------|----------------------------|
| Request chega mas resposta não volta | Inbound=ACCEPT, Outbound=REJECT → **NACL bloqueando saída** |
| Request nem chega | Inbound=REJECT → **SG ou NACL bloqueando entrada** |
| Tráfego unidirecional | Apenas uma direção ACCEPT → **NACL** (stateless) |
| Tudo ACCEPT mas não funciona | Flow Logs OK → problema é no **SO** ou **aplicação** |

### O que Flow Logs NÃO capturam

- Tráfego para DNS da Amazon (169.254.169.253)
- Tráfego para metadata (169.254.169.254)
- DHCP traffic
- Tráfego para o endereço do VPC router
- Tráfego do Amazon Windows License Activation

> ⚠️ **Na prova:** "Analisar tráfego rejeitado na VPC" → **VPC Flow Logs**. "Query em logs de rede armazenados no S3" → **Athena + VPC Flow Logs no S3**.

---

## 13. Bastion Host vs Systems Manager Session Manager

### Bastion Host (Jump Box)

- Instância EC2 em **subnet pública** que serve como ponto de entrada para subnet privada
- Security Group do bastion: permite SSH (22) ou RDP (3389) de IPs autorizados
- Security Group das instâncias privadas: permite SSH/RDP apenas do bastion

```
Internet
    │
    │ SSH (porta 22)
    ▼
┌──────────────┐ Subnet Pública
│ Bastion Host │
│ (IP público) │
└──────┬───────┘
       │ SSH (porta 22)
       ▼
┌──────────────┐ Subnet Privada
│ EC2 Private  │
│ (sem IP pub) │
└──────────────┘
```

### Systems Manager Session Manager

- Acesso shell **sem abrir portas** (sem SSH, sem porta 22)
- Sem necessidade de bastion host ou IP público
- Funciona via **SSM Agent** (pré-instalado em AMIs Amazon Linux 2+)
- Requer: IAM Role na instância com permissão `ssm:StartSession`
- Logging centralizado (CloudWatch Logs, S3)
- Funciona em instâncias privadas (via VPC Endpoint ou NAT)

### Comparação completa

| Aspecto | Bastion Host | Session Manager |
|---------|-------------|-----------------|
| **Porta SSH aberta** | ✅ Necessária (22) | ❌ Não precisa |
| **IP público** | Necessário no bastion | Não precisa |
| **Security Group** | Deve permitir SSH | Sem portas inbound |
| **Key pair** | Necessário (.pem) | Não precisa |
| **Custo extra** | EC2 do bastion | Sem custo (já incluso no SSM) |
| **Logging** | Manual (configure) | ✅ Automático (CloudWatch/S3) |
| **Controle de acesso** | SG + chaves SSH | IAM policies |
| **Auditoria** | Difícil | ✅ CloudTrail + sessão gravada |
| **Acesso por browser** | ❌ Precisa SSH client | ✅ Console AWS |
| **Multi-plataforma** | SSH (Linux), RDP (Windows) | Shell para ambos |

> ⚠️ **Na prova:** "Acesso seguro a instâncias privadas sem abrir porta SSH" → **Session Manager**. "Reduzir superfície de ataque" → **Session Manager** (elimina bastion e porta 22).

---

## 14. IPv6 em VPCs

### Características

- AWS suporta **dual-stack** (IPv4 + IPv6 simultaneamente)
- IPv6 na AWS é **público** por padrão (todos os IPs são globalmente roteáveis)
- Não existe IPv6 privado na AWS (não tem NAT para IPv6)
- O bloco IPv6 da VPC é um **/56** (atribuído pela AWS ou BYOIP)
- Subnets recebem **/64**
- Não pode desabilitar IPv4 (IPv6 é sempre adicional)

### Egress-Only Internet Gateway

- Equivalente ao NAT Gateway, mas para **IPv6**
- Permite tráfego de **saída** para a internet IPv6
- Bloqueia tráfego de **entrada** (stateful)
- Usado em subnets privadas com IPv6

```
Comparação:
┌─────────────────────────────────────────────────────┐
│  IPv4:                                              │
│  Subnet Privada → NAT Gateway → IGW → Internet     │
│  (saída: ✅ | entrada: ❌)                           │
│                                                     │
│  IPv6:                                              │
│  Subnet Privada → Egress-Only IGW → Internet       │
│  (saída: ✅ | entrada: ❌)                           │
│                                                     │
│  ⚠️  IPv6 NÃO usa NAT Gateway                       │
└─────────────────────────────────────────────────────┘
```

### Route Table com IPv6

```
┌───────────────────────┬──────────────────────┐
│ Destination           │ Target               │
├───────────────────────┼──────────────────────┤
│ 10.0.0.0/16          │ local                │
│ 2600:1f18:xxxx::/56  │ local                │
│ 0.0.0.0/0            │ nat-gw-xxx (IPv4)    │
│ ::/0                 │ eigw-xxx (IPv6)      │  ← Egress-only IGW
└───────────────────────┴──────────────────────┘
```

### Troubleshooting IPv6

| Problema | Causa | Solução |
|----------|-------|---------|
| EC2 não consegue IPv4 para internet | Sem NAT GW ou sem rota | Adicionar NAT GW + rota 0.0.0.0/0 |
| EC2 não consegue IPv6 para internet | Sem Egress-only IGW | Criar Egress-only IGW + rota ::/0 |
| EC2 não consegue IPv4 nem IPv6 | Subnet sem rota para qualquer GW | Verificar route table |
| "Cannot launch instance" com IPv6 | Subnet sem bloco IPv6 | Associar CIDR IPv6 à subnet |

> ⚠️ **Na prova:** "IPv6 + subnet privada + acesso à internet somente saída" → **Egress-Only Internet Gateway**. Nunca use NAT para IPv6.

---

## 15. AWS Network Firewall

> Serviço gerenciado de firewall que fornece filtragem de tráfego **stateful e stateless** no nível de VPC.

### Características

- Firewall gerenciado pela AWS (escala automaticamente)
- Protege toda a VPC (diferente de SG que é por instância)
- Suporta regras **stateless** (como NACL) e **stateful** (como SG)
- Inspeção de tráfego em **Layer 3 a Layer 7**
- Suporta: filtragem por IP, porta, protocolo, domain name, regex em payload
- Integra com **Firewall Manager** para governança multi-account
- Logs enviados para: S3, CloudWatch Logs, Kinesis Data Firehose

### Componentes

| Componente | Descrição |
|------------|-----------|
| **Firewall** | Recurso que conecta a VPC ao firewall policy |
| **Firewall Policy** | Conjunto de rule groups (stateless + stateful) |
| **Rule Group** | Coleção de regras (stateless OU stateful) |
| **Firewall Subnet** | Subnet dedicada onde o endpoint do firewall reside |

### Onde posicionar o Network Firewall

```
Internet
    │
    ▼
┌────────┐
│  IGW   │
└────┬───┘
     │
     ▼
┌─────────────────────┐  ← Firewall Subnet (dedicada)
│  Network Firewall   │
│  Endpoint           │
└─────────┬───────────┘
          │
     ┌────┴──────────────────────┐
     │                           │
     ▼                           ▼
┌──────────────┐          ┌──────────────┐
│ Subnet Pub   │          │ Subnet Priv  │
│ [ALB]        │          │ [EC2 App]    │
└──────────────┘          └──────────────┘
```

### Regras Stateless vs Stateful

| Aspecto | Stateless Rules | Stateful Rules |
|---------|----------------|----------------|
| **Avaliação** | Cada pacote individualmente | Tracked connections |
| **Ordem** | Prioridade numérica | Ordem definida ou strict |
| **Ações** | Pass, Drop, Forward to Stateful | Pass, Drop, Alert |
| **Uso típico** | Filtragem rápida por IP/porta | Deep packet inspection |
| **Performance** | Mais rápido | Mais flexível |

### Casos de uso

- Filtragem de tráfego de saída (egress filtering) por domain
- Prevenção de intrusão (IPS)
- Filtragem de URL / FQDN
- Compliance e controle de tráfego centralizado
- Bloquear comunicação com IPs/domínios maliciosos

> ⚠️ **Na prova:** "Filtragem de tráfego na VPC por domain name ou deep packet inspection" → **AWS Network Firewall**. "Firewall centralizado para múltiplas VPCs" → **Network Firewall + Transit Gateway**.

---

## 16. PrivateLink — Exposição de Serviços

> Permite expor um serviço de uma VPC para **outra VPC** (ou milhares de VPCs) de forma privada, sem peering, VPN, ou internet.

### Arquitetura

```
VPC do CONSUMER (Cliente)          VPC do PROVIDER (Serviço)
┌─────────────────────────┐        ┌─────────────────────────┐
│                         │        │                         │
│  [EC2 App]              │        │  [EC2/ECS App]          │
│      │                  │        │      │                  │
│      ▼                  │        │      ▼                  │
│  ┌─────────────────┐    │        │  ┌─────────────────┐    │
│  │ Interface       │    │ Private│  │ Network Load    │    │
│  │ Endpoint (ENI)  │◄───┼────────┼──│ Balancer (NLB)  │    │
│  │ vpce-xxx        │    │  Link  │  │ ou GWLB         │    │
│  └─────────────────┘    │        │  └─────────────────┘    │
│                         │        │         │               │
│  IP privado: 10.0.1.55 │        │  Endpoint Service       │
│                         │        │  (vpce-svc-xxx)         │
└─────────────────────────┘        └─────────────────────────┘
```

### Como funciona

1. **Provider** cria um NLB (ou Gateway LB) na sua VPC
2. **Provider** cria um **Endpoint Service** apontando para o NLB
3. **Consumer** cria um **Interface Endpoint** apontando para o Endpoint Service
4. Tráfego flui: Consumer ENI → PrivateLink → NLB → Backend

### Características

- O consumer acessa o serviço via **IP privado** (ENI na sua subnet)
- NÃO precisa de VPC Peering, VPN, IGW ou NAT
- Escala para **milhares de consumers**
- Cross-account e cross-VPC
- Provider precisa **aceitar** as connection requests (ou auto-accept)
- O **NLB é obrigatório** no lado do provider (ou Gateway LB)
- Também pode usar **Gateway Load Balancer Endpoint** para appliances

### NLB vs ALB no PrivateLink

| | NLB | ALB |
|-|-----|-----|
| **Suporte a PrivateLink** | ✅ Direto | ❌ Precisa de NLB na frente |
| **Motivo** | PrivateLink requer Layer 4 (NLB) | ALB é Layer 7, não compatível diretamente |

### Comparação: formas de expor serviço

| Método | Escalabilidade | Segurança | Complexidade |
|--------|:---:|:---:|:---:|
| **PrivateLink** | ✅ Milhares de VPCs | ✅ Privado (sem internet) | Média |
| **VPC Peering** | ⚠️ N*(N-1)/2 conexões | ✅ Privado | Alta (muitas VPCs) |
| **Internet (ALB público)** | ✅ Ilimitado | ⚠️ Exposto à internet | Baixa |
| **Transit Gateway** | ✅ Transitivo | ✅ Privado | Média |

> ⚠️ **Na prova:** "Expor serviço para centenas de VPCs de clientes sem peering" → **PrivateLink (NLB + Endpoint Service)**. "SaaS provider quer oferecer acesso privado" → **PrivateLink**.

---

## 17. Diagrama de Arquitetura Multi-Tier Completo

```
                              Internet
                                 │
                                 ▼
                          ┌──────────────┐
                          │     IGW      │
                          └──────┬───────┘
                                 │
                ┌────────────────┼────────────────┐
                │                │                │
                ▼                │                ▼
    ┌─ AZ-a ────────────────┐   │   ┌─ AZ-b ────────────────┐
    │                        │   │   │                        │
    │  ┌─ Subnet Pública ─┐ │   │   │  ┌─ Subnet Pública ─┐ │
    │  │                   │ │   │   │  │                   │ │
    │  │  [NAT Gateway-a]  │ │   │   │  │  [NAT Gateway-b]  │ │
    │  │  [ALB Node]       │ │   │   │  │  [ALB Node]       │ │
    │  │                   │ │   │   │  │                   │ │
    │  └─────────┬─────────┘ │   │   │  └─────────┬─────────┘ │
    │            │            │   │   │            │            │
    │  ┌─ Subnet Privada ──┐ │   │   │  ┌─ Subnet Privada ──┐ │
    │  │  (Aplicação)      │ │   │   │  │  (Aplicação)      │ │
    │  │                   │ │   │   │  │                   │ │
    │  │  [EC2 App-1]      │ │   │   │  │  [EC2 App-2]      │ │
    │  │  [EC2 App-3]      │ │   │   │  │  [EC2 App-4]      │ │
    │  │                   │ │   │   │  │                   │ │
    │  │  SG: allow 443    │ │   │   │  │  SG: allow 443    │ │
    │  │  from ALB SG      │ │   │   │  │  from ALB SG      │ │
    │  └─────────┬─────────┘ │   │   │  └─────────┬─────────┘ │
    │            │            │   │   │            │            │
    │  ┌─ Subnet DB ───────┐ │   │   │  ┌─ Subnet DB ───────┐ │
    │  │                   │ │   │   │  │                   │ │
    │  │  [RDS Primary]    │ │   │   │  │  [RDS Standby]    │ │
    │  │                   │ │   │   │  │  (Multi-AZ)       │ │
    │  │  SG: allow 3306   │ │   │   │  │  SG: allow 3306   │ │
    │  │  from App SG      │ │   │   │  │  from App SG      │ │
    │  └───────────────────┘ │   │   │  └───────────────────┘ │
    │                        │   │   │                        │
    └────────────────────────┘   │   └────────────────────────┘
                                 │
                          ┌──────┴───────┐
                          │  S3 Bucket   │
                          │ (via Gateway │
                          │  Endpoint)   │
                          └──────────────┘

Conectividade externa:
┌───────────────┐     ┌──────────────────┐
│  On-Premises  │────►│  Transit Gateway │────► VPC
│  Data Center  │ DX  │  ou VGW (VPN)    │
└───────────────┘     └──────────────────┘

Resumo de Security Groups:
┌──────────────────────────────────────────────────────────────┐
│  ALB SG:     Inbound 443 from 0.0.0.0/0                     │
│  App SG:     Inbound 443 from ALB-SG                        │
│  DB SG:      Inbound 3306 from App-SG                       │
│  Bastion SG: Inbound 22 from Corporate-IP/32                │
└──────────────────────────────────────────────────────────────┘

Route Tables:
┌──────────────────────────────────────────────────────────────┐
│  Public RT:  0.0.0.0/0 → IGW                                │
│  Private RT: 0.0.0.0/0 → NAT-GW (local AZ)                 │
│              pl-xxx (S3) → vpce-xxx (Gateway Endpoint)       │
│  DB RT:      Apenas rota local (sem internet)                │
└──────────────────────────────────────────────────────────────┘
```

### Princípios da arquitetura

1. **Multi-AZ**: todos os tiers replicados em 2+ AZs
2. **Least privilege**: SGs referenciam outros SGs (não IPs)
3. **Camadas isoladas**: subnets separadas por função (pub/app/db)
4. **NAT por AZ**: cada AZ tem seu NAT Gateway
5. **Sem IP público**: instâncias de app e DB nunca expostas
6. **Endpoint privado**: S3 via Gateway Endpoint (sem internet)
7. **Defense in depth**: SGs + NACLs em cada camada

---

## 18. Palavras-chave da Prova SAA-C03

| Cenário na prova | Resposta |
|-----------------|----------|
| "Instância privada precisa baixar patches da internet" | NAT Gateway na subnet pública + rota 0.0.0.0/0 |
| "Alta disponibilidade para NAT" | NAT Gateway em cada AZ com route table separada |
| "Bloquear IP específico atacando a aplicação" | NACL com regra DENY para o IP (SG não tem DENY) |
| "Conexão privada entre 2 VPCs" | VPC Peering (se não precisa de trânsito) |
| "Conectar 50 VPCs com roteamento transitivo" | Transit Gateway |
| "Acesso privado a S3 sem custo adicional" | Gateway Endpoint (gratuito) |
| "Acesso privado a SQS/SNS/KMS de instância privada" | Interface Endpoint (PrivateLink) |
| "Conexão com on-premises de baixa latência e alto throughput" | Direct Connect |
| "Backup para Direct Connect" | Site-to-Site VPN (como failover) |
| "Criptografia no Direct Connect" | MACsec (L2) ou VPN over DX (IPsec sobre Public VIF) |
| "Expor serviço SaaS para centenas de VPCs de clientes" | PrivateLink (NLB + Endpoint Service) |
| "Acesso seguro a EC2 privado sem porta SSH aberta" | Systems Manager Session Manager |
| "Múltiplos escritórios conectados via AWS" | VPN CloudHub (1 VGW + múltiplos CGWs) |
| "IPv6 em subnet privada com acesso à internet somente saída" | Egress-Only Internet Gateway |
| "Analisar tráfego rejeitado na VPC" | VPC Flow Logs (REJECT action) |
| "Query em logs de rede para investigação" | VPC Flow Logs → S3 + Amazon Athena |
| "Filtrar tráfego por domain name na VPC" | AWS Network Firewall |
| "Firewall centralizado para múltiplas VPCs" | Network Firewall + Transit Gateway |
| "Instância não acessa internet apesar de estar em subnet pública" | Verificar: IGW? Rota 0.0.0.0/0→IGW? IP público? SG outbound? NACL? |
| "Mais bandwidth que 1.25 Gbps na VPN" | Transit Gateway com ECMP (múltiplos túneis) |
| "Multicast na AWS" | Transit Gateway (único serviço que suporta) |
| "On-premises acessar múltiplas VPCs em diferentes regiões com 1 DX" | DX Gateway |
| "Subnet privada acessa DynamoDB sem internet" | Gateway Endpoint para DynamoDB (gratuito) |
| "EC2 em VPC precisa acessar serviço em outra VPC sem peering" | PrivateLink (Interface Endpoint para Endpoint Service) |
| "Reduzir custo de transferência entre AZs" | NAT Gateway na mesma AZ que as instâncias |
| "Resolver DNS de VPC peered" | Habilitar DNS resolution no peering |

---

## 19. Resumo Visual — Conectividade VPC

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│  DENTRO DA VPC:                                                         │
│  ┌─────────────┐  ┌──────────┐  ┌──────────────┐  ┌────────────────┐  │
│  │ Route Table │  │ SG/NACL  │  │ IGW/NAT GW   │  │ VPC Endpoints  │  │
│  │ (roteamento)│  │(filtering)│  │ (internet)   │  │ (serviços AWS) │  │
│  └─────────────┘  └──────────┘  └──────────────┘  └────────────────┘  │
│                                                                         │
│  VPC ↔ VPC:                                                             │
│  ┌────────────────┐  ┌─────────────────┐  ┌────────────────────────┐  │
│  │ VPC Peering    │  │ Transit Gateway  │  │ PrivateLink            │  │
│  │ (1:1, não      │  │ (hub, transitivo,│  │ (serviço exposto,      │  │
│  │  transitivo)   │  │  VPN/DX/VPC)     │  │  NLB obrigatório)      │  │
│  └────────────────┘  └─────────────────┘  └────────────────────────┘  │
│                                                                         │
│  VPC ↔ ON-PREMISES:                                                     │
│  ┌────────────────┐  ┌─────────────────┐  ┌────────────────────────┐  │
│  │ Site-to-Site   │  │ Direct Connect  │  │ DX + VPN (criptografia │  │
│  │ VPN (internet, │  │ (fibra dedicada,│  │  + baixa latência)     │  │
│  │  rápido setup) │  │  semanas setup) │  │                        │  │
│  └────────────────┘  └─────────────────┘  └────────────────────────┘  │
│                                                                         │
│  SEGURANÇA:                                                             │
│  ┌────────────────┐  ┌─────────────────┐  ┌────────────────────────┐  │
│  │ Security Group │  │ NACL            │  │ Network Firewall       │  │
│  │ (instância,    │  │ (subnet,        │  │ (VPC, L3-L7,           │  │
│  │  stateful)     │  │  stateless)     │  │  domain filtering)     │  │
│  └────────────────┘  └─────────────────┘  └────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```
