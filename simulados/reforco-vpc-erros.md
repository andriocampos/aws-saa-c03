# 🔴 Reforço VPC — Gaps Identificados no Quiz

**Data:** 07/07/2026  
**Resultado:** 9 questões erradas em 3 áreas críticas  
**Objetivo:** Dominar os conceitos para acertar 85%+ no próximo quiz

---

# PARTE 1: Direct Connect (DX) e VPN — Detalhes que Caem na Prova

## 1.1 Timeline de Provisioning

### 🎯 Conceito-Chave: DX é uma FIBRA FÍSICA. Leva tempo real para instalar.

```
╔══════════════════════════════════════════════════════════════════╗
║              TIMELINE DE PROVISIONING                            ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  VPN Site-to-Site:                                              ║
║  ┌──────┐                                                       ║
║  │██████│ MINUTOS (configuração de software apenas)             ║
║  └──────┘                                                       ║
║                                                                  ║
║  DX Hosted Connection:                                          ║
║  ┌──────────────────────┐                                       ║
║  │██████████████████████│ DIAS a SEMANAS                        ║
║  └──────────────────────┘ (parceiro já tem fibra no DX Location)║
║                                                                  ║
║  DX Dedicated Connection:                                       ║
║  ┌─────────────────────────────────────────────────────┐        ║
║  │█████████████████████████████████████████████████████│        ║
║  └─────────────────────────────────────────────────────┘        ║
║  SEMANAS a MESES (instalar fibra física do zero)                ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

### 🏠 Analogia: Tipos de Internet em Casa

| Tipo | Analogia | Tempo |
|------|----------|-------|
| **VPN** | Contratar streaming (ativa na hora, usa internet existente) | **Minutos** |
| **DX Hosted** | Mudar para fibra (técnico vem ligar na caixa do prédio) | **Dias-Semanas** |
| **DX Dedicated** | Construir estrada privada até sua casa | **Semanas-Meses** |

### Por que DX demora?

1. **Cross-connect físico** no DX Location (data center de colocação)
2. **Fibra dedicada** entre seu rack e o rack da AWS
3. **LOA-CFA** (Letter of Authorization) — documento para autorizar conexão
4. **Testes de camada 1/2/3** — verificar sinal óptico, BGP, etc.

---

## 1.2 Bandwidth — Limites Reais

### 🎯 Conceito-Chave: VPN = 1.25 Gbps por túnel (NÃO 10 Gbps!)

```
╔══════════════════════════════════════════════════════════════╗
║                    BANDWIDTH MÁXIMO                          ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  VPN (1 túnel):        ████░░░░░░░░░░░░░░  1.25 Gbps       ║
║                                                              ║
║  DX Hosted (mínimo):   █░░░░░░░░░░░░░░░░░  50 Mbps         ║
║  DX Hosted (máximo):   ████████░░░░░░░░░░  10 Gbps         ║
║                                                              ║
║  DX Dedicated (1G):    ████████░░░░░░░░░░  1 Gbps          ║
║  DX Dedicated (10G):   ████████████████░░  10 Gbps         ║
║  DX Dedicated (100G):  ██████████████████  100 Gbps        ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

| Serviço | Bandwidth | Observação |
|---------|-----------|------------|
| **VPN Site-to-Site** | **1.25 Gbps/túnel** | Limitado pelo overhead IPSec |
| **VPN com ECMP (TGW)** | Até **50 Gbps** | Múltiplos túneis agregados |
| **DX Hosted** | 50 Mbps, 100 Mbps, 200 Mbps, 300 Mbps, 400 Mbps, 500 Mbps, 1 Gbps, 2 Gbps, 5 Gbps, 10 Gbps | Via parceiro APN |
| **DX Dedicated** | 1 Gbps, 10 Gbps, 100 Gbps | Porta física exclusiva |

### 🏠 Analogia: Estradas

- **VPN** = Rua de bairro (1 faixa, velocidade limitada)
- **DX Hosted** = Via compartilhada (você aluga faixas conforme necessidade)
- **DX Dedicated** = Rodovia privada (todas as faixas são suas)

---

## 1.3 Criptografia no Direct Connect

### 🚨 PONTO CRÍTICO: DX **NÃO** é criptografado por padrão!

```
╔══════════════════════════════════════════════════════════════════╗
║  DX sem criptografia (padrão):                                  ║
║                                                                  ║
║  Seu DC ════════════════════════════════════ AWS                 ║
║           fibra dedicada, mas dados em TEXTO CLARO              ║
║                                                                  ║
╠══════════════════════════════════════════════════════════════════╣
║  Opção 1: MACsec (Layer 2)                                     ║
║                                                                  ║
║  Seu DC ═══[MACsec]═══════════════════════ AWS                  ║
║           criptografia na camada 2 (Ethernet)                   ║
║           ⚠️  Apenas 10 Gbps e 100 Gbps dedicados              ║
║           ⚠️  Nativo, sem overhead de túnel                     ║
║                                                                  ║
╠══════════════════════════════════════════════════════════════════╣
║  Opção 2: VPN over DX (IPSec, Layer 3)                         ║
║                                                                  ║
║  Seu DC ═══[túnel IPSec dentro do DX]═════ AWS                  ║
║           VPN Site-to-Site rodando SOBRE a conexão DX           ║
║           ✅ Qualquer velocidade de DX                          ║
║           ⚠️  Limitado a 1.25 Gbps por túnel (overhead IPSec)  ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

### Quando usar cada opção de criptografia?

| Critério | MACsec | VPN over DX |
|----------|--------|-------------|
| **Camada** | Layer 2 (Ethernet) | Layer 3 (IP/IPSec) |
| **Velocidades suportadas** | 10 Gbps, 100 Gbps | Qualquer (mas max 1.25 Gbps/túnel) |
| **Tipo de DX** | Apenas Dedicated | Dedicated ou Hosted |
| **Overhead de performance** | Mínimo | Significativo (~20-30%) |
| **Complexidade** | Baixa (nativo no hardware) | Média (configurar VPN) |
| **Caso de uso** | Alta performance + segurança | Compliance que exige IPSec |
| **Disponibilidade** | Nem todos DX Locations | Todos DX Locations |

### 🏠 Analogia: Segurança no Transporte

- **DX sem criptografia** = Caminhão aberto na estrada privada (ninguém acessa a estrada, mas a carga está exposta)
- **MACsec** = Caminhão blindado (proteção total, velocidade máxima)
- **VPN over DX** = Caminhão com cofre dentro (mais seguro, mas ocupa espaço da carga)

---

## 1.4 Tabela Comparativa Completa: DX vs VPN

| # | Critério | VPN Site-to-Site | Direct Connect |
|---|----------|-----------------|----------------|
| 1 | **Bandwidth máximo** | 1.25 Gbps/túnel | 100 Gbps (dedicated) |
| 2 | **Latência** | Variável (internet pública) | Consistente e baixa |
| 3 | **Jitter** | Alto (internet) | Baixo (fibra dedicada) |
| 4 | **Custo inicial** | Baixo (~$0.05/h) | Alto (porta + cross-connect) |
| 5 | **Custo mensal** | Baixo | Alto (porta: $0.30-$22/h) |
| 6 | **Custo de transferência** | Padrão egress | Menor que egress padrão |
| 7 | **Tempo de setup** | Minutos | Semanas a meses |
| 8 | **Criptografia** | Sim (IPSec nativo) | NÃO (precisa MACsec ou VPN over DX) |
| 9 | **Redundância nativa** | 2 túneis por conexão | Não (precisa 2 conexões) |
| 10 | **SLA** | Sem SLA dedicado | 99.9% (1 DX) / 99.99% (resiliência máxima) |
| 11 | **Protocolo de roteamento** | Estático ou BGP | BGP obrigatório |
| 12 | **Caminho dos dados** | Internet pública | Fibra privada |
| 13 | **Resiliência a falhas** | Failover rápido | Failover lento (minutos) |
| 14 | **Multi-region** | 1 VPN por região | DX Gateway (1 conexão → várias regiões) |
| 15 | **Escalabilidade** | ECMP com TGW (múltiplos túneis) | LAG (até 4 portas) |
| 16 | **Caso de uso ideal** | Backup, conexão rápida, POC | Produção, grande volume, baixa latência |
| 17 | **Compliance** | Dados passam pela internet | Dados nunca tocam internet |

---

## 1.5 DX Gateway vs VGW (Virtual Private Gateway)

```
╔══════════════════════════════════════════════════════════════════════╗
║  CENÁRIO 1: VGW (Virtual Private Gateway) — Single Region          ║
║                                                                      ║
║  Seu DC ──── DX ──── VGW ──── VPC (us-east-1)                      ║
║                                                                      ║
║  ⚠️  1 VGW = 1 VPC = 1 região                                      ║
╠══════════════════════════════════════════════════════════════════════╣
║  CENÁRIO 2: DX Gateway — Multi-Region                              ║
║                                                                      ║
║                         ┌──── VGW ──── VPC (us-east-1)              ║
║                         │                                            ║
║  Seu DC ── DX ── DX GW ├──── VGW ──── VPC (eu-west-1)             ║
║                         │                                            ║
║                         └──── VGW ──── VPC (ap-southeast-1)         ║
║                                                                      ║
║  ✅ 1 DX conexão → múltiplas regiões via DX Gateway                ║
║  ✅ Até 10 VGWs por DX Gateway                                     ║
║  ⚠️  VPCs NÃO se comunicam entre si (não é transitivo)             ║
╠══════════════════════════════════════════════════════════════════════╣
║  CENÁRIO 3: DX Gateway + Transit Gateway — Full Mesh               ║
║                                                                      ║
║  Seu DC ── DX ── DX GW ──── TGW ──┬── VPC A                       ║
║                                     ├── VPC B                       ║
║                                     └── VPC C                       ║
║                                                                      ║
║  ✅ Comunicação transitiva entre VPCs                               ║
║  ✅ Hub-and-spoke na nuvem                                          ║
╚══════════════════════════════════════════════════════════════════════╝
```

### Quando usar cada?

| Cenário | Solução |
|---------|---------|
| 1 VPC, 1 região | VGW direto |
| Múltiplas VPCs, múltiplas regiões, sem comunicação entre VPCs | DX Gateway + VGWs |
| Múltiplas VPCs que precisam se comunicar + on-premises | DX Gateway + Transit Gateway |

---

## 1.6 Arquitetura de Resiliência: DX Primary + VPN Backup

```
╔══════════════════════════════════════════════════════════════════╗
║  ARQUITETURA DE RESILIÊNCIA (DX + VPN Failover)                 ║
║                                                                  ║
║                    ┌─── DX Connection 1 ───┐                    ║
║                    │    (PRIMÁRIO)          │                    ║
║   Seu Data ────────┤                       ├──── VGW ── VPC    ║
║   Center           │                       │     ou             ║
║                    └─── VPN (BACKUP) ──────┘     TGW            ║
║                         (via Internet)                           ║
║                                                                  ║
║  Prioridade BGP:                                                ║
║  • DX = AS_PATH mais curto (preferido)                          ║
║  • VPN = AS_PATH mais longo (backup)                            ║
║                                                                  ║
║  Failover:                                                      ║
║  • DX cai → BGP detecta → tráfego migra para VPN               ║
║  • Tempo de failover: segundos (BFD) a minutos                  ║
║                                                                  ║
╠══════════════════════════════════════════════════════════════════╣
║  RESILIÊNCIA MÁXIMA (SLA 99.99%):                               ║
║                                                                  ║
║              ┌── DX 1 (Location A) ──┐                          ║
║   Seu DC ───┤                        ├── DX GW ── VGW ── VPC  ║
║              └── DX 2 (Location B) ──┘                          ║
║                                                                  ║
║  ✅ 2 conexões em 2 DX Locations diferentes                     ║
║  ✅ Sobrevive à falha de um DX Location inteiro                 ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## 1.7 ECMP com Transit Gateway

### 🎯 Conceito-Chave: ECMP permite somar bandwidth de múltiplos túneis VPN

```
╔══════════════════════════════════════════════════════════════════╗
║  SEM ECMP (VGW): máximo 1.25 Gbps                              ║
║                                                                  ║
║  Seu DC ═══ Túnel 1 (1.25 Gbps) ═══╗                           ║
║          ═══ Túnel 2 (standby)  ═══╬═══ VGW ═══ VPC            ║
║                                     ╝                            ║
║  ⚠️  Apenas 1 túnel ativo (active/passive)                      ║
║                                                                  ║
╠══════════════════════════════════════════════════════════════════╣
║  COM ECMP (Transit Gateway): até 50 Gbps                       ║
║                                                                  ║
║  Seu DC ═══ VPN 1: Túnel A (1.25 Gbps) ═══╗                    ║
║          ═══ VPN 1: Túnel B (1.25 Gbps) ═══╣                    ║
║          ═══ VPN 2: Túnel A (1.25 Gbps) ═══╬═══ TGW ═══ VPCs  ║
║          ═══ VPN 2: Túnel B (1.25 Gbps) ═══╣                    ║
║          ═══ ...                        ═══╝                    ║
║                                                                  ║
║  ✅ Todos os túneis ATIVOS simultaneamente                      ║
║  ✅ Load balancing automático (Equal Cost Multi-Path)           ║
║  ✅ Até 50 Gbps agregados                                      ║
╚══════════════════════════════════════════════════════════════════╝
```

### Requisitos para ECMP:
1. **Transit Gateway** (VGW NÃO suporta ECMP)
2. **BGP** (roteamento dinâmico obrigatório)
3. **Múltiplas conexões VPN** apontando para o mesmo TGW
4. **Rotas com mesmo custo** (equal cost)

### 🏠 Analogia: Pedágio

- **VGW** = Pedágio com 2 cabines, mas só 1 funciona por vez
- **TGW com ECMP** = Pedágio com 40 cabines, todas funcionando ao mesmo tempo

---

## 1.8 Flashcards — Parte 1

| ❌ ERREI | ✅ CERTO |
|----------|----------|
| DX provisiona em minutos/horas | DX Dedicated leva **semanas a meses** (é fibra física!) |
| VPN suporta 10 Gbps | VPN suporta **1.25 Gbps por túnel** (com ECMP no TGW: até 50 Gbps) |
| DX é criptografado | DX **NÃO** é criptografado por padrão. Opções: **MACsec** (L2, 10/100G) ou **VPN over DX** (IPSec) |
| DX Hosted é igual a Dedicated | Hosted: via parceiro, dias-semanas, 50M-10G. Dedicated: porta exclusiva, semanas-meses, 1/10/100G |
| VGW conecta múltiplas regiões | VGW = 1 VPC, 1 região. Para multi-region: **DX Gateway** |
| ECMP funciona com VGW | ECMP requer **Transit Gateway** (VGW é active/passive) |
| 1 conexão DX dá SLA 99.99% | SLA 99.99% requer **2 conexões em 2 DX Locations diferentes** |
| MACsec funciona em qualquer velocidade | MACsec apenas em **10 Gbps e 100 Gbps Dedicated** |

---

# PARTE 2: Serviços de Conectividade — PrivateLink, RAM e OAC

## 2.1 AWS PrivateLink (Endpoint Services)

### 🎯 Conceito-Chave: PrivateLink EXPÕE um serviço específico para outra VPC/conta SEM abrir toda a rede.

### O que é?
- Permite que um **Provider** (quem tem o serviço) exponha APENAS aquele serviço
- O **Consumer** (quem quer usar) cria um endpoint na SUA VPC
- Tráfego NUNCA sai da rede AWS (backbone privado)
- NÃO precisa VPC Peering, NÃO precisa Transit Gateway

### Como funciona — Diagrama Completo

```
╔══════════════════════════════════════════════════════════════════════════╗
║  PROVIDER (Conta A / VPC A)              CONSUMER (Conta B / VPC B)    ║
║                                                                          ║
║  ┌────────────┐     ┌──────────────┐     ┌──────────────────┐          ║
║  │ Aplicação  │     │  Endpoint    │     │ Interface        │          ║
║  │ (EC2/ECS/  │────▶│  Service     │◀────│ Endpoint (ENI)   │          ║
║  │  Lambda)   │     │              │     │                  │          ║
║  └────────────┘     └──────────────┘     └──────────────────┘          ║
║        │                   ▲                      ▲                      ║
║        ▼                   │                      │                      ║
║  ┌────────────┐           │                      │                      ║
║  │    NLB     │───────────┘           Consumer usa IP privado           ║
║  │ (Network   │                       da própria VPC para               ║
║  │  Load      │                       acessar o serviço                 ║
║  │  Balancer) │                                                          ║
║  └────────────┘                                                          ║
║                                                                          ║
║  FLUXO:                                                                  ║
║  1. Provider cria NLB → registra targets (aplicação)                    ║
║  2. Provider cria Endpoint Service → associa ao NLB                     ║
║  3. Consumer cria Interface Endpoint na sua VPC                         ║
║  4. Provider APROVA a conexão (ou auto-aceita)                          ║
║  5. Consumer acessa via IP privado do endpoint (ENI na subnet)          ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
```

### Quando usar PrivateLink vs outras opções?

| Cenário | Solução | Por quê? |
|---------|---------|----------|
| Expor **1 serviço** para outra conta | **PrivateLink** | Não expõe toda a rede, apenas o serviço |
| 2 VPCs precisam comunicação **full** (todas as portas/IPs) | **VPC Peering** | Comunicação completa entre VPCs |
| 100+ VPCs precisam se comunicar | **Transit Gateway** | Hub-and-spoke, escalável |
| Acessar serviço AWS (S3, DynamoDB) pela rede privada | **VPC Endpoint** (Gateway ou Interface) | Acesso privado a serviços AWS |

### 🏠 Analogia: Restaurante

- **VPC Peering** = Derrubar a parede entre dois apartamentos (acesso total)
- **PrivateLink** = Instalar um passa-pratos na parede (só passa o que você quer)
- **Transit Gateway** = Corredor de hotel conectando todos os quartos

---

## 2.2 AWS RAM (Resource Access Manager)

### 🎯 Conceito-Chave: RAM COMPARTILHA recursos da AWS entre contas. Não cria conexão de rede — compartilha o RECURSO em si.

### O que o RAM compartilha?

| Recurso | Descrição | Caso de uso |
|---------|-----------|-------------|
| **Subnets** | Compartilha subnet entre contas | Contas diferentes lançam EC2 na MESMA subnet |
| **Transit Gateway** | Compartilha TGW entre contas | Conta central gerencia TGW, outras contas anexam VPCs |
| **Route53 Resolver Rules** | Compartilha regras DNS | DNS centralizado para organização |
| **License Manager** | Compartilha licenças | Licenças BYOL entre contas |
| **AWS Network Firewall** | Compartilha políticas | Segurança centralizada |
| **Prefix Lists** | Compartilha listas de IP | Regras de SG/NACL consistentes |

### Como funciona — Diagrama

```
╔══════════════════════════════════════════════════════════════════════╗
║  AWS RAM — Compartilhamento de Subnet                               ║
║                                                                      ║
║  OWNER (Conta A)                                                     ║
║  ┌─────────────────────────────────────┐                            ║
║  │ VPC (10.0.0.0/16)                   │                            ║
║  │ ┌─────────────────────────────────┐ │                            ║
║  │ │ Subnet compartilhada            │ │                            ║
║  │ │ (10.0.1.0/24)                   │ │                            ║
║  │ │                                 │ │                            ║
║  │ │  EC2 (Conta A)  EC2 (Conta B)  │ │                            ║
║  │ │  ┌──┐           ┌──┐           │ │                            ║
║  │ │  │  │           │  │           │ │                            ║
║  │ │  └──┘           └──┘           │ │                            ║
║  │ └─────────────────────────────────┘ │                            ║
║  └─────────────────────────────────────┘                            ║
║                                                                      ║
║  FLUXO:                                                              ║
║  1. Owner cria Resource Share no RAM                                 ║
║  2. Owner adiciona subnet ao share                                   ║
║  3. Owner convida Participant (Conta B) ou compartilha via AWS Org  ║
║  4. Participant ACEITA o share                                       ║
║  5. Participant pode lançar EC2, RDS, etc. NA subnet compartilhada  ║
║                                                                      ║
║  ⚠️  REGRAS IMPORTANTES:                                            ║
║  • Owner mantém controle da VPC/subnet/route table/NACL             ║
║  • Participant NÃO pode modificar a subnet                          ║
║  • Participant gerencia SEUS recursos (EC2, SG, etc.)               ║
║  • Security Groups são per-account (isolamento)                     ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
```

### RAM vs VPC Peering vs Transit Gateway

| Critério | RAM (Subnet sharing) | VPC Peering | Transit Gateway |
|----------|---------------------|-------------|-----------------|
| **O que faz** | Compartilha subnet entre contas | Conecta 2 VPCs | Conecta N VPCs (hub) |
| **Rede** | MESMA subnet | VPCs separadas, roteamento | VPCs separadas, roteamento |
| **CIDR overlap** | N/A (mesma subnet) | NÃO permitido | NÃO permitido |
| **Custo** | Sem custo adicional | Transferência inter-AZ/region | $0.05/h + transferência |
| **Escala** | Até 100 participantes | Até 125 peerings/VPC | Até 5000 attachments |
| **Caso de uso** | Equipes na mesma subnet, simplicidade | 2-3 VPCs, comunicação full | Muitas VPCs, topologia complexa |

### 🏠 Analogia: Escritório

- **RAM** = Compartilhar a MESMA sala de reunião entre departamentos
- **VPC Peering** = Construir uma porta entre 2 escritórios
- **Transit Gateway** = Recepção central que conecta todos os andares

---

## 2.3 OAC (Origin Access Control)

### 🎯 Conceito-Chave: OAC permite CloudFront acessar S3 PRIVADO. NÃO usa VPC Endpoint porque CloudFront é EDGE (não está na VPC).

### Por que NÃO usar VPC Endpoint para CloudFront → S3?

```
╔══════════════════════════════════════════════════════════════════╗
║  ❌ ERRADO: VPC Endpoint para CloudFront → S3                   ║
║                                                                  ║
║  CloudFront (Edge Location)                                      ║
║       │                                                          ║
║       │  ⚠️ CloudFront NÃO está dentro de uma VPC!             ║
║       │  ⚠️ VPC Endpoints são para recursos DENTRO da VPC!     ║
║       ✗                                                          ║
║       │                                                          ║
║  [VPC Endpoint] ← NÃO FUNCIONA AQUI                            ║
║                                                                  ║
╠══════════════════════════════════════════════════════════════════╣
║  ✅ CORRETO: OAC (Origin Access Control)                        ║
║                                                                  ║
║  Usuário → CloudFront (Edge) ──[OAC]──→ S3 (bucket privado)    ║
║                                                                  ║
║  • CloudFront assina requests com SigV4                         ║
║  • S3 bucket policy permite APENAS o CloudFront                 ║
║  • Bucket pode ficar 100% privado (Block Public Access = ON)    ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

### OAC vs OAI (antigo)

| Critério | OAI (Origin Access Identity) | OAC (Origin Access Control) |
|----------|------------------------------|----------------------------|
| **Status** | ⚠️ Legado (deprecated) | ✅ Recomendado |
| **SSE-KMS** | ❌ Não suporta | ✅ Suporta |
| **POST/PUT para S3** | ❌ Não suporta | ✅ Suporta |
| **S3 em outra região** | Limitado | ✅ Todas as regiões |
| **Assinatura** | Método próprio | SigV4 (padrão AWS) |
| **Lambda@Edge** | Precisa workaround | Funciona nativamente |

### Bucket Policy com OAC (exemplo)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontServicePrincipal",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::meu-bucket-privado/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::123456789012:distribution/EDFDVBD6EXAMPLE"
        }
      }
    }
  ]
}
```

### 🏠 Analogia: Entrega de Encomenda

- **VPC Endpoint** = Portaria interna do prédio (só moradores/funcionários usam)
- **OAC** = Crachá especial do entregador (CloudFront é o entregador que vem de FORA, mas tem permissão para acessar o depósito)
- **OAI** = Crachá antigo que não abre as portas novas (deprecated)

---

## 2.4 Tabela de Decisão Rápida: "Quero X → Use Y"

| Quero... | Use... | NÃO use... |
|----------|--------|------------|
| Expor 1 serviço para outra conta de forma privada | **PrivateLink** | Transit Gateway (overkill) |
| Compartilhar subnet entre contas na mesma org | **RAM** | VPC Peering (cria rede separada) |
| CloudFront acessar S3 privado | **OAC** | VPC Endpoint (CF não está na VPC) |
| Conectar 2 VPCs com comunicação full | **VPC Peering** | PrivateLink (é por serviço) |
| Conectar 50+ VPCs entre si | **Transit Gateway** | VPC Peering (N² conexões) |
| Acessar S3 de dentro da VPC sem internet | **VPC Gateway Endpoint** | OAC (é para CloudFront) |
| Acessar DynamoDB de dentro da VPC | **VPC Gateway Endpoint** | Interface Endpoint |
| Acessar outros serviços AWS pela rede privada | **VPC Interface Endpoint** | NAT Gateway (custa mais) |
| DNS centralizado para várias contas | **RAM + Route53 Resolver** | Replicar regras manualmente |
| Compartilhar Transit Gateway entre contas | **RAM** | Criar TGW em cada conta |

---

## 2.5 Flashcards — Parte 2

| ❌ ERREI | ✅ CERTO |
|----------|----------|
| Para expor serviço a outra conta, uso Transit Gateway | Para expor 1 serviço específico: **PrivateLink** (NLB → Endpoint Service → Interface Endpoint) |
| Para compartilhar subnets, uso Transit Gateway | Para compartilhar subnets entre contas: **RAM** (Resource Access Manager) |
| CloudFront acessa S3 privado via VPC Endpoint | CloudFront acessa S3 privado via **OAC** (CloudFront é EDGE, não está na VPC) |
| PrivateLink dá acesso total entre VPCs | PrivateLink expõe **apenas 1 serviço** (passa-pratos, não derruba parede) |
| RAM cria conexão de rede entre contas | RAM **compartilha o recurso em si** (mesma subnet, mesmo TGW) — não cria nova rede |
| OAI é a forma atual de proteger S3+CloudFront | OAI é **legado**. Use **OAC** (suporta KMS, PUT, todas regiões) |
| VPC Gateway Endpoint funciona para qualquer serviço | Gateway Endpoint: apenas **S3 e DynamoDB**. Outros serviços: Interface Endpoint |

---

# PARTE 3: Custos de Rede e IPv6

## 3.1 Regras Completas de Custo de Tráfego na AWS

### 🎯 Conceito-Chave: IP privado na mesma AZ = GRÁTIS. Qualquer outra coisa = CUSTA.

```
╔══════════════════════════════════════════════════════════════════════╗
║  MAPA DE CUSTOS DE TRÁFEGO NA AWS                                   ║
║                                                                      ║
║  ┌──────────────── Região us-east-1 ───────────────────────┐       ║
║  │                                                          │       ║
║  │  ┌─── AZ-a ───────────┐    ┌─── AZ-b ───────────┐     │       ║
║  │  │                     │    │                     │     │       ║
║  │  │  EC2 ←──→ EC2      │    │  EC2                │     │       ║
║  │  │  (IP privado)       │    │                     │     │       ║
║  │  │  💰 GRÁTIS          │    │                     │     │       ║
║  │  │                     │    │                     │     │       ║
║  │  │  EC2 ←──→ EC2      │    │                     │     │       ║
║  │  │  (IP público)       │    │                     │     │       ║
║  │  │  💰 $0.01/GB cada   │    │                     │     │       ║
║  │  │      lado           │    │                     │     │       ║
║  │  └─────────┬───────────┘    └──────────┬──────────┘     │       ║
║  │            │                            │                │       ║
║  │            └────── inter-AZ ────────────┘                │       ║
║  │                   💰 $0.01/GB cada lado                  │       ║
║  │                   ($0.02 total round-trip)               │       ║
║  │                                                          │       ║
║  └──────────────────────────────────────────────────────────┘       ║
║                           │                                          ║
║                     inter-Region                                     ║
║                    💰 $0.02/GB                                       ║
║                           │                                          ║
║                    ┌──────┴──────┐                                   ║
║                    │  eu-west-1  │                                   ║
║                    └─────────────┘                                   ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
```

### Tabela Completa de Custos de Tráfego

| # | Cenário | Custo IN | Custo OUT | Total |
|---|---------|----------|-----------|-------|
| 1 | Mesma AZ, **IP privado** | **GRÁTIS** | **GRÁTIS** | **$0.00** |
| 2 | Mesma AZ, **IP público/Elastic IP** | $0.01/GB | $0.01/GB | **$0.02/GB** |
| 3 | **Inter-AZ** (qualquer IP) | $0.01/GB | $0.01/GB | **$0.02/GB** |
| 4 | **Inter-Region** | Grátis (ingress) | $0.02/GB | **$0.02/GB** |
| 5 | **Egress para Internet** | Grátis (ingress) | $0.09/GB* | **$0.09/GB** |
| 6 | **NAT Gateway** (processamento) | — | $0.045/GB | **+ $0.045/GB** |
| 7 | **NAT Gateway** (inter-AZ) | — | +$0.01/GB | **+ $0.01/GB** |
| 8 | **VPC Peering** (mesma AZ) | **GRÁTIS** | **GRÁTIS** | **$0.00** |
| 9 | **VPC Peering** (inter-AZ) | $0.01/GB | $0.01/GB | **$0.02/GB** |
| 10 | **VPC Peering** (inter-Region) | $0.02/GB | $0.02/GB | **$0.02/GB** |
| 11 | **Transit Gateway** (processamento) | — | $0.02/GB | **+ $0.02/GB** |
| 12 | **VPC Gateway Endpoint** (S3/DynamoDB) | **GRÁTIS** | **GRÁTIS** | **$0.00** |
| 13 | **VPC Interface Endpoint** (por hora) | $0.01/h/AZ | — | **$0.01/h/AZ + $0.01/GB** |
| 14 | **PrivateLink** (processamento) | — | $0.01/GB | **$0.01/GB** |
| 15 | **Direct Connect** (egress) | — | $0.02/GB* | **Menor que internet** |

*Preços variam por região. Valores de us-east-1 como referência.

### 🚨 Armadilhas de Custo para a Prova

```
╔══════════════════════════════════════════════════════════════════╗
║  ARMADILHA 1: IP público na mesma AZ                            ║
║                                                                  ║
║  EC2-A (10.0.1.5) ←→ EC2-B (10.0.1.10)   = GRÁTIS             ║
║  EC2-A (54.x.x.x) ←→ EC2-B (54.y.y.y)    = $0.02/GB!! 💸     ║
║                                                                  ║
║  🎯 REGRA: Sempre use IP PRIVADO para comunicação intra-VPC    ║
║                                                                  ║
╠══════════════════════════════════════════════════════════════════╣
║  ARMADILHA 2: NAT Gateway em outra AZ                           ║
║                                                                  ║
║  EC2 (AZ-a) → NAT GW (AZ-b) → Internet                        ║
║  Custo: $0.045/GB (NAT) + $0.01/GB (inter-AZ) = $0.055/GB!    ║
║                                                                  ║
║  🎯 REGRA: 1 NAT Gateway POR AZ                                ║
║                                                                  ║
╠══════════════════════════════════════════════════════════════════╣
║  ARMADILHA 3: S3 via NAT Gateway                                ║
║                                                                  ║
║  EC2 → NAT GW → Internet → S3  = $0.045/GB (NAT) + egress     ║
║  EC2 → Gateway Endpoint → S3   = GRÁTIS! 🎉                    ║
║                                                                  ║
║  🎯 REGRA: Sempre use VPC Gateway Endpoint para S3/DynamoDB    ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## 3.2 IPv6 na AWS

### 🎯 Conceito-Chave: NAT Gateway NÃO suporta IPv6. Para IPv6 outbound: use Egress-Only Internet Gateway.

### Por que NAT não funciona com IPv6?

```
╔══════════════════════════════════════════════════════════════════╗
║  IPv4: Endereços privados (RFC 1918) precisam de NAT           ║
║                                                                  ║
║  EC2 (10.0.1.5) → NAT GW (traduz para IP público) → Internet  ║
║                                                                  ║
║  ✅ NAT traduz IP privado → IP público                         ║
║                                                                  ║
╠══════════════════════════════════════════════════════════════════╣
║  IPv6: TODOS os endereços são públicos (não existe NAT!)       ║
║                                                                  ║
║  EC2 (2001:db8::1) → ??? → Internet                           ║
║                                                                  ║
║  ❌ NAT NÃO faz sentido (IP já é público!)                     ║
║  ✅ Egress-Only IGW: permite SAÍDA, bloqueia ENTRADA           ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

### IPv6 — Componentes na AWS

| Componente | IPv4 | IPv6 |
|-----------|------|------|
| **Endereços privados** | Sim (10.x, 172.x, 192.168.x) | NÃO (todos são públicos/globais) |
| **NAT Gateway** | ✅ Traduz privado→público | ❌ NÃO SUPORTA |
| **Internet Gateway** | Saída + Entrada | Saída + Entrada |
| **Egress-Only IGW** | N/A | ✅ Saída SIM, Entrada NÃO |
| **VPC mode** | Obrigatório | Dual-stack (IPv4 + IPv6) |

### Dual-Stack na AWS

```
╔══════════════════════════════════════════════════════════════════╗
║  VPC Dual-Stack                                                  ║
║  ┌────────────────────────────────────────────┐                 ║
║  │ IPv4 CIDR: 10.0.0.0/16                    │                 ║
║  │ IPv6 CIDR: 2001:db8::/56 (Amazon-provided)│                 ║
║  │                                            │                 ║
║  │  ┌─── Subnet Pública ──────────────────┐  │                 ║
║  │  │ EC2: 10.0.1.5 + 2001:db8::1         │  │                 ║
║  │  │      ↕ IGW (IPv4 e IPv6)            │  │                 ║
║  │  └─────────────────────────────────────┘  │                 ║
║  │                                            │                 ║
║  │  ┌─── Subnet Privada ──────────────────┐  │                 ║
║  │  │ EC2: 10.0.2.5 + 2001:db8::2         │  │                 ║
║  │  │      IPv4: → NAT Gateway → Internet │  │                 ║
║  │  │      IPv6: → Egress-Only IGW → Out  │  │                 ║
║  │  └─────────────────────────────────────┘  │                 ║
║  └────────────────────────────────────────────┘                 ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

### 🏠 Analogia: Telefone

- **IPv4 com NAT** = Ramal interno (precisa da telefonista/NAT para ligar para fora)
- **IPv6** = Celular com número público (todo mundo pode te ligar diretamente)
- **Egress-Only IGW** = Celular no modo "não perturbe" (você liga para fora, mas chamadas de fora são bloqueadas)

---

## 3.3 NAT Gateway HA (Alta Disponibilidade)

### 🎯 Conceito-Chave: 1 NAT Gateway serve apenas 1 AZ. Para HA: 1 NAT por AZ.

### Por que 1 NAT para todas as AZs é ERRADO?

```
╔══════════════════════════════════════════════════════════════════╗
║  ❌ ERRADO: 1 NAT Gateway para todas as AZs                    ║
║                                                                  ║
║  ┌── AZ-a ──┐    ┌── AZ-b ──┐    ┌── AZ-c ──┐                ║
║  │  EC2     │    │  EC2     │    │  EC2     │                  ║
║  │    │     │    │    │     │    │    │     │                  ║
║  └────┼─────┘    └────┼─────┘    └────┼─────┘                  ║
║       │               │               │                         ║
║       └───────────────┼───────────────┘                         ║
║                       ▼                                          ║
║              ┌── NAT GW (AZ-a) ──┐                              ║
║              │   SINGLE POINT     │                              ║
║              │   OF FAILURE! 💀   │                              ║
║              └────────────────────┘                              ║
║                       │                                          ║
║  Problemas:                                                      ║
║  • Se AZ-a cair, TODAS as AZs perdem internet                  ║
║  • Tráfego inter-AZ extra ($0.01/GB de AZ-b e AZ-c)           ║
║                                                                  ║
╠══════════════════════════════════════════════════════════════════╣
║  ✅ CORRETO: 1 NAT Gateway POR AZ                              ║
║                                                                  ║
║  ┌── AZ-a ──────┐  ┌── AZ-b ──────┐  ┌── AZ-c ──────┐       ║
║  │  EC2         │  │  EC2         │  │  EC2         │         ║
║  │    │         │  │    │         │  │    │         │         ║
║  │    ▼         │  │    ▼         │  │    ▼         │         ║
║  │  NAT GW (a) │  │  NAT GW (b) │  │  NAT GW (c) │         ║
║  │    │         │  │    │         │  │    │         │         ║
║  └────┼─────────┘  └────┼─────────┘  └────┼─────────┘         ║
║       │                  │                  │                    ║
║       └──────────────────┼──────────────────┘                    ║
║                          ▼                                       ║
║                    Internet Gateway                               ║
║                                                                  ║
║  Benefícios:                                                     ║
║  ✅ Se AZ-a cair, AZ-b e AZ-c continuam funcionando            ║
║  ✅ Sem custo inter-AZ (tráfego fica na mesma AZ)              ║
║  ✅ Melhor performance (sem gargalo central)                    ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

### Custos do NAT Gateway

| Item | Custo | Observação |
|------|-------|------------|
| **Por hora** | $0.045/h (~$32/mês) | Por NAT Gateway |
| **Processamento** | $0.045/GB | Por GB processado |
| **Inter-AZ** (se NAT em outra AZ) | +$0.01/GB | Evitável com 1 NAT/AZ |
| **3 NATs (HA completo)** | ~$97/mês (fixo) | + processamento |

### Configuração de Route Tables para HA

```
Route Table da Subnet Privada em AZ-a:
┌─────────────────────────────────────┐
│ Destination     │ Target            │
├─────────────────┼───────────────────┤
│ 10.0.0.0/16    │ local             │
│ 0.0.0.0/0      │ nat-gw-AZ-A      │  ← NAT na MESMA AZ
└─────────────────────────────────────┘

Route Table da Subnet Privada em AZ-b:
┌─────────────────────────────────────┐
│ Destination     │ Target            │
├─────────────────┼───────────────────┤
│ 10.0.0.0/16    │ local             │
│ 0.0.0.0/0      │ nat-gw-AZ-B      │  ← NAT na MESMA AZ
└─────────────────────────────────────┘
```

### 🏠 Analogia: Portaria do Condomínio

- **1 NAT para todas AZs** = 1 portaria para 3 torres (se a portaria fechar, ninguém sai)
- **1 NAT por AZ** = 1 portaria por torre (se uma fechar, as outras continuam normais)
- **Custo extra inter-AZ** = Taxa de estacionamento para usar a portaria da torre vizinha

---

## 3.4 Dicas de Otimização de Custo para a Prova

### Top 10 Dicas que Caem no Exame

| # | Dica | Economia |
|---|------|----------|
| 1 | Comunicação intra-AZ sempre com **IP privado** | Elimina $0.02/GB |
| 2 | **VPC Gateway Endpoint** para S3/DynamoDB | Elimina custo de NAT ($0.045/GB) |
| 3 | **1 NAT por AZ** | Elimina $0.01/GB inter-AZ |
| 4 | **S3 Transfer Acceleration** só quando necessário | Evita custo extra |
| 5 | **VPC Peering** na mesma AZ | Grátis (vs TGW $0.02/GB) |
| 6 | **Interface Endpoints** por AZ usada (não todas) | Evita $0.01/h por AZ não usada |
| 7 | **Direct Connect** para alto volume (vs VPN/internet) | Egress mais barato |
| 8 | **CloudFront** para egress global | Custo menor que egress direto |
| 9 | **Colocar recursos na mesma AZ** quando possível | Elimina inter-AZ |
| 10 | **NAT Gateway vs NAT Instance** | NAT Instance mais barato para dev/test |

---

## 3.5 Flashcards — Parte 3

| ❌ ERREI | ✅ CERTO |
|----------|----------|
| IP público na mesma AZ é grátis igual IP privado | IP público na mesma AZ custa **$0.02/GB**. Só IP PRIVADO é grátis! |
| NAT Gateway suporta IPv6 | NAT Gateway **NÃO suporta IPv6**. Use **Egress-Only Internet Gateway** |
| 1 NAT Gateway serve para todas as AZs | 1 NAT por AZ para **HA** e para **evitar custo inter-AZ** ($0.01/GB) |
| Egress-Only IGW é para IPv4 | Egress-Only IGW é para **IPv6** (permite saída, bloqueia entrada) |
| VPC Gateway Endpoint tem custo por GB | Gateway Endpoint (S3/DynamoDB) é **GRÁTIS** (sem custo hora nem GB) |
| NAT Gateway custa só processamento | NAT Gateway: **$0.045/h** (fixo) + **$0.045/GB** (processamento) |
| IPv6 tem endereços privados | IPv6 na AWS: **todos os endereços são públicos/globais** |
| Inter-AZ é grátis | Inter-AZ: **$0.01/GB cada direção** ($0.02 total) |

---

# PARTE 4: Resumo Consolidado e Plano de Ação

## 4.1 Todos os Flashcards Consolidados

### 🔴 Direct Connect / VPN

| # | ❌ ERREI | ✅ CERTO |
|---|----------|----------|
| 1 | DX provisiona em minutos/horas | DX Dedicated: **semanas a meses**. DX Hosted: **dias a semanas**. VPN: **minutos**. |
| 2 | VPN suporta 10 Gbps | VPN: **1.25 Gbps/túnel**. Com ECMP no TGW: até 50 Gbps. |
| 3 | DX é criptografado por padrão | DX **NÃO** é criptografado. Opções: **MACsec** (L2, 10/100G) ou **VPN over DX** (IPSec). |
| 4 | DX Hosted = DX Dedicated | Hosted: via parceiro, menores velocidades (50M-10G). Dedicated: porta exclusiva (1/10/100G). |
| 5 | VGW conecta múltiplas regiões | VGW = 1 VPC. Multi-region = **DX Gateway**. |
| 6 | ECMP funciona com VGW | ECMP requer **Transit Gateway**. VGW é active/passive. |
| 7 | 1 DX dá SLA 99.99% | 99.99% requer **2 conexões em 2 DX Locations diferentes**. |
| 8 | MACsec funciona em qualquer velocidade | MACsec: apenas **10 Gbps e 100 Gbps Dedicated**. |

### 🟡 Serviços de Conectividade

| # | ❌ ERREI | ✅ CERTO |
|---|----------|----------|
| 9 | Expor serviço a outra conta → Transit Gateway | Expor 1 serviço → **PrivateLink** (NLB → Endpoint Service → Interface Endpoint). |
| 10 | Compartilhar subnets → Transit Gateway | Compartilhar subnets → **RAM** (Resource Access Manager). |
| 11 | CloudFront → S3 privado via VPC Endpoint | CloudFront → S3 privado via **OAC** (CF é edge, NÃO está na VPC). |
| 12 | PrivateLink dá acesso total entre VPCs | PrivateLink expõe **apenas 1 serviço** específico. |
| 13 | RAM cria conexão de rede | RAM **compartilha o recurso** (não cria rede nova). |
| 14 | OAI é o recomendado para CloudFront+S3 | OAI é legado. **OAC** é o recomendado (suporta KMS, PUT). |
| 15 | Gateway Endpoint funciona para qualquer serviço | Gateway Endpoint: **apenas S3 e DynamoDB**. |

### 🔵 Custos e IPv6

| # | ❌ ERREI | ✅ CERTO |
|---|----------|----------|
| 16 | IP público mesma AZ = grátis | IP público mesma AZ: **$0.02/GB**. Só IP privado mesma AZ é grátis! |
| 17 | NAT Gateway suporta IPv6 | NAT GW **não suporta IPv6**. Use **Egress-Only IGW**. |
| 18 | 1 NAT para todas as AZs = HA | 1 NAT/AZ = HA + sem custo inter-AZ. 1 NAT total = **SPOF**! |
| 19 | Egress-Only IGW é para IPv4 | Egress-Only IGW: **IPv6** (saída sim, entrada não). |
| 20 | VPC Gateway Endpoint custa por GB | Gateway Endpoint (S3/DynamoDB): **$0.00** (grátis!). |
| 21 | NAT GW: só custo de processamento | NAT GW: **$0.045/h** (fixo) + **$0.045/GB** (dados). |
| 22 | IPv6 tem endereços privados | IPv6 AWS: **todos públicos/globais** (sem RFC1918 equivalente). |
| 23 | Inter-AZ é grátis | Inter-AZ: **$0.01/GB cada direção**. |

---

## 4.2 Tabela de Decisão Rápida para a Prova

### "Quando a questão falar em..." → Use isso:

| Palavra-chave na questão | Resposta provável | Armadilha comum |
|--------------------------|-------------------|-----------------|
| "Conexão dedicada", "latência consistente" | **Direct Connect** | Não confundir com VPN |
| "Rápido de implementar", "backup", "criptografado" | **VPN Site-to-Site** | Não confundir com DX |
| "Expor serviço para outra conta", "privado" | **PrivateLink** | Não usar TGW |
| "Compartilhar subnet/recurso entre contas" | **RAM** | Não usar VPC Peering |
| "CloudFront + S3 privado" | **OAC** | Não usar VPC Endpoint |
| "S3 sem internet de dentro da VPC" | **Gateway Endpoint** | Não usar NAT |
| "Múltiplas VPCs se comunicando" | **Transit Gateway** | N² peerings = errado |
| "2 VPCs comunicação full" | **VPC Peering** | Não usar PrivateLink |
| "IPv6 saída sem entrada" | **Egress-Only IGW** | Não usar NAT GW |
| "Redundância DX 99.99%" | **2 conexões + 2 DX Locations** | 1 DX = 99.9% apenas |
| "Mais bandwidth VPN" | **ECMP + Transit Gateway** | VGW não suporta ECMP |
| "DX com criptografia high-performance" | **MACsec** (10/100G) | VPN over DX limita a 1.25G |
| "DX com criptografia qualquer velocidade" | **VPN over DX** (IPSec) | MACsec = só 10/100G |
| "Multi-region com DX" | **DX Gateway** | VGW = 1 região apenas |
| "Custo otimizado comunicação intra-VPC" | **IP privado + mesma AZ** | IP público = custo |
| "HA para NAT" | **1 NAT por AZ** | 1 NAT total = SPOF |
| "Reduzir custo S3 transfer" | **Gateway Endpoint** | NAT = $0.045/GB |

---

## 4.3 Mapa Mental — Conexão com AWS

```
                         ┌─────────────────────────────────────┐
                         │       CONEXÃO COM A AWS              │
                         └──────────────┬──────────────────────┘
                                        │
                    ┌───────────────────┼───────────────────┐
                    │                   │                   │
              ┌─────▼─────┐     ┌──────▼──────┐    ┌──────▼──────┐
              │    VPN     │     │     DX      │    │  Internet   │
              │            │     │             │    │  (pública)  │
              │ • Minutos  │     │ • Semanas+  │    │             │
              │ • 1.25Gbps │     │ • 100Gbps   │    │ • IGW       │
              │ • IPSec    │     │ • Sem cripto│    │ • NAT GW    │
              │ • Internet │     │ • Fibra     │    │ • Egress-   │
              │            │     │             │    │   Only IGW  │
              └─────┬──────┘     └──────┬──────┘    └─────────────┘
                    │                   │
                    │              ┌────┼────┐
                    │              │    │    │
                    │         ┌────▼┐ ┌▼───┐ ┌▼────────┐
                    │         │VGW  │ │DX  │ │DX GW +  │
                    │         │(1   │ │GW  │ │TGW      │
                    │         │VPC) │ │(N  │ │(full    │
                    │         │     │ │VPC)│ │mesh)    │
                    │         └─────┘ └────┘ └─────────┘
                    │
              ┌─────▼──────────────────┐
              │  TGW + ECMP            │
              │  (múltiplos túneis     │
              │   = mais bandwidth)    │
              └────────────────────────┘
```

---

## 4.4 Plano de Ação

### 📅 Cronograma de Revisão

| Dia | Ação | Meta |
|-----|------|------|
| **Hoje (07/07)** | ✅ Ler este documento completo | Entender todos os conceitos |
| **09/07 (D+2)** | 📖 Reler flashcards + tabelas de decisão | Fixar na memória |
| **10/07 (D+3)** | 🎯 Refazer quiz de VPC | Meta: **85%+** (antes: ~70%) |
| **12/07 (D+5)** | 🔄 Revisar apenas os que ainda errar | Focar nos gaps restantes |
| **14/07 (D+7)** | 🏆 Quiz final de VPC | Meta: **90%+** |

### 📝 Checklist de Estudo

- [ ] Li e entendi a Parte 1 (DX/VPN)
- [ ] Memorizei: VPN=1.25Gbps, DX Dedicated=semanas/meses
- [ ] Sei a diferença MACsec vs VPN over DX
- [ ] Li e entendi a Parte 2 (PrivateLink/RAM/OAC)
- [ ] Sei quando usar PrivateLink vs Peering vs TGW
- [ ] Entendo por que OAC e não VPC Endpoint para CloudFront
- [ ] Li e entendi a Parte 3 (Custos/IPv6)
- [ ] Sei que IP público na mesma AZ NÃO é grátis
- [ ] Sei que NAT não funciona com IPv6 → Egress-Only IGW
- [ ] Sei que preciso 1 NAT por AZ para HA
- [ ] Revisei todos os 23 flashcards
- [ ] Consigo responder a tabela de decisão rápida sem consultar

### 🧠 Técnica de Memorização

1. **Leia os flashcards em voz alta** (memória auditiva)
2. **Cubra a coluna "CERTO"** e tente lembrar (recall ativo)
3. **Desenhe os diagramas** em papel (memória visual/motora)
4. **Ensine para alguém** (ou explique para o pato de borracha 🦆)
5. **Associe com as analogias** (memória de longo prazo)

---

## 🎯 Resumo Final — As 3 Lições Mais Importantes

```
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║  1️⃣  DX é FÍSICO → demora SEMANAS/MESES                         ║
║     VPN é SOFTWARE → demora MINUTOS                             ║
║     (Estrada privada vs streaming online)                       ║
║                                                                  ║
║  2️⃣  PrivateLink = expor SERVIÇO (passa-pratos)                 ║
║     RAM = compartilhar RECURSO (mesma sala)                     ║
║     OAC = CloudFront→S3 (crachá do entregador)                 ║
║     NÃO confundir com TGW/Peering/VPC Endpoint!                ║
║                                                                  ║
║  3️⃣  GRÁTIS = IP privado + mesma AZ                             ║
║     IPv6 = Egress-Only IGW (não NAT!)                          ║
║     HA = 1 NAT por AZ (não 1 total!)                           ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

---

*Documento gerado em 07/07/2026. Próxima revisão: 09/07/2026.*
*Meta: de ~70% → 85%+ no próximo quiz. Você consegue! 💪*
