# Meu Homelab

## Contexto

Eu possuía um notebook ocioso em casa e decidi instalá-lo com o **Ubuntu Server 22.04**, transformando-o em um *mini-servidor* dedicado. A escolha por esta versão se deu por ser mais leve que a 24.04, além de apresentar maior maturidade e estabilidade para ambientes de laboratório.

O objetivo foi sair do uso exclusivo de máquinas virtuais e passar a trabalhar com um servidor real, permitindo uma experiência mais próxima de cenários produtivos.

---

## E agora?

Após a instalação, surgiu a principal dúvida: **qual projeto priorizar**?  
Virtualização, observabilidade, containers, pipelines CI/CD — havia muitos caminhos possíveis.

Diante disso, optei por iniciar com a implantação de serviços essenciais, focando nos seguintes pilares:

- **Versionamento de código com Git**
- **Pipelines de CI/CD**
- **Orquestração com Docker**
- **Proxy reverso com Nginx**

---

## Configurações do servidor e definição de serviços

Após a instalação, a primeira etapa foi a configuração de um **IP estático via Netplan**, garantindo previsibilidade na comunicação entre os serviços:

```bash
sudo vi /etc/netplan/config.yaml && sudo netplan apply
```

Também configurei o acesso remoto via **VSCode Remote-SSH**, facilitando a edição de arquivos e a administração do ambiente de forma centralizada.

---

## Decisão de ferramentas

O servidor possui hardware limitado — **i5 6ª geração, 8 GB de RAM e 128 GB de armazenamento** — o que exigiu a escolha de soluções leves e eficientes.

---

### Git — Gitea

Para o gerenciamento de repositórios Git, optei pelo **Gitea**, uma alternativa extremamente leve e funcional ao GitLab Server.  
Outras opções avaliadas foram **Forgejo** e **Apache Allura**.

---

### CI/CD — Drone CI

Para automação de pipelines, escolhi o **Drone CI**, principalmente por:

- Baixo consumo de recursos
- Facilidade de integração com Gitea
- Simplicidade de implantação via Docker

Ele se mostrou uma alternativa mais enxuta quando comparado a Jenkins, GitLab Runners e Argo Workflows.

---

### Observações

Tanto o Gitea quanto o Drone disponibilizam arquivos `docker-compose.yaml` em sua documentação oficial, o que acelerou significativamente o processo de implantação.  
Além disso, a documentação do Drone já apresentava exemplos prontos de integração com o Gitea.

---

## Implantação da infraestrutura

### dnsmasq

Para facilitar o acesso aos serviços, configurei o **dnsmasq** como resolvedor local, registrando o domínio:

```
homelab.local
```

Isso permitiu a padronização dos acessos internos, eliminando a necessidade de memorizar IPs.

---

### Nginx

O **Nginx** foi adotado como proxy reverso para centralizar os acessos HTTP/HTTPS aos serviços, atuando como camada de entrada para todo o ambiente.

---

## Implantação dos serviços

O comando base utilizado foi:

```bash
cd nome-servico/ && docker compose up -d
```

Entretanto, respeitei uma ordem lógica de implantação.

---

### Gitea

Iniciei pelo Gitea, pois algumas configurações iniciais precisavam ser realizadas diretamente pela interface web:

```bash
cd gitea/ && docker compose up -d
```

---

### GLPI

Implantei o **GLPI** com o objetivo de simular um ambiente de Service Desk e gerenciamento de ativos, permitindo futuramente a criação de integrações via API e automações.

---

### Zabbix e Grafana

Zabbix e Grafana foram configurados em conjunto para compor a camada de observabilidade, permitindo testes de integração, coleta de métricas e visualização de dados.

---

### Drone CI

A configuração do Drone foi a etapa mais trabalhosa, principalmente devido a problemas com:

- OAuth
- Resolução DNS interna do Docker
- Redirecionamento de autenticação via `.env`

Após ajustes no resolvedor DNS e nas variáveis de ambiente, o serviço passou a operar corretamente.

---

### Semaphore

O Semaphore foi implantado com o objetivo futuro de:

- Integrar com o Gitea
- Acionar pipelines baseadas em tags
- Provisionar containers automaticamente utilizando Ansible

---

## Troubleshooting

### Docker Swarm e Secrets

Inicialmente tentei utilizar **Docker Swarm** com **Secrets**, porém não obtive sucesso.  
Por praticidade, optei temporariamente por utilizar variáveis de ambiente.

Para validar se a variável estava sendo carregada:

```bash
docker exec -it nome-container bash
set | grep GITEA_CLIENT_SECRET
```

---

### Zabbix + MySQL

Ao utilizar MySQL como banco do Zabbix Server, o container encerrava poucos segundos após a inicialização, indicando erro na tabela `users`.

Após diversas tentativas, identifiquei que esse é um problema conhecido.  
A solução mais simples foi migrar para **PostgreSQL**, atualmente o banco mais estável e melhor suportado pelo Zabbix.
