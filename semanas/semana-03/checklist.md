# Semana 03 — Alta Disponibilidade (ELB + ASG + Route 53)
> 16/07 a 22/07/2026

## Checklist de Estudo

### Elastic Load Balancing
- [ ] Assistir aulas de ELB no curso
- [ ] ALB: camada 7, roteamento por path/host/headers, target groups, sticky sessions
- [ ] NLB: camada 4, TCP/UDP, IP estático por AZ, preserve source IP
- [ ] GLB: camada 3, firewalls e appliances de rede, GENEVE protocol
- [ ] Cross-Zone Load Balancing
- [ ] Connection Draining / Deregistration Delay
- [ ] Access Logs

### Auto Scaling Groups
- [ ] Assistir aulas de ASG no curso
- [ ] Launch Templates vs Launch Configurations
- [ ] Scaling Policies: Target Tracking, Step, Scheduled, Predictive
- [ ] Cooldown period e warm-up
- [ ] Health checks: EC2 vs ELB
- [ ] Lifecycle Hooks
- [ ] Instance Refresh
- [ ] Scale-in protection

### Route 53
- [ ] Assistir aulas de Route 53 no curso
- [ ] Hosted Zones: public vs private
- [ ] Record types: A, AAAA, CNAME, Alias, MX, TXT
- [ ] Alias vs CNAME — DIFERENÇA CRÍTICA
- [ ] Routing Policies: Simple, Weighted, Latency, Failover, Geolocation, Geoproximity, Multi-Value
- [ ] Health Checks: endpoint, calculated, CloudWatch alarm
- [ ] TTL

### Prática
- [ ] Criar ALB com target group de EC2 instances
- [ ] Configurar ASG com launch template
- [ ] Testar scale-out por CPU
- [ ] Lab: `lab-02-ec2-com-alb`

## Simulado da Semana
- [ ] 20 questões de ELB/ASG — Tutorials Dojo
- [ ] 20 questões de Route 53 — Tutorials Dojo
- [ ] Revisar todos os erros

## Horas Estudadas
| Dia | Horas | Observações |
|-----|-------|-------------|
| Qua 16/07 | | |
| Qui 17/07 | | |
| Sex 18/07 | | |
| Sáb 19/07 | | |
| Dom 20/07 | | |
| Seg 21/07 | | |
| Ter 22/07 | | |
| **Total** | | |
