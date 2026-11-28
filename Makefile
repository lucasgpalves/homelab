.PHONY: help networks up down restart ps logs check-env tls-certs \
	up-infra up-apps \
	db gitea zabbix grafana drone semaphore nginx dnsmasq vault

COMPOSE := docker compose
NETWORKS := homelab-net gitea-net zabbix-net vault-net semaphore-net

help:
	@echo "Homelab — alvos disponíveis:"
	@echo "  make networks   - cria as redes Docker externas"
	@echo "  make check-env  - verifica se os .env necessários existem"
	@echo "  make tls-certs  - gera CA/certificados mkcert (*.lab.home.arpa)"
	@echo "  make up         - sobe o ambiente completo (redes + stacks)"
	@echo "  make up-infra   - sobe dnsmasq, db e nginx"
	@echo "  make up-apps    - sobe gitea, zabbix, grafana, drone, semaphore"
	@echo "  make down       - para todos os stacks (redes preservadas)"
	@echo "  make restart    - reinicia o ambiente"
	@echo "  make ps         - lista containers"
	@echo "  make logs STACK=<nome>  - logs de um stack (ex.: zabbix)"
	@echo "  make <stack>    - sobe um stack isolado"

tls-certs:
	@bash nginx/generate-certs.sh

networks:
	@for net in $(NETWORKS); do \
		docker network inspect $$net >/dev/null 2>&1 \
			|| (echo "Criando rede $$net" && docker network create $$net); \
	done
	@echo "Redes prontas: $(NETWORKS)"

check-env:
	@missing=0; \
	for f in db/.env gitea/.env zabbix/.env grafana/.env; do \
		if [ ! -f $$f ]; then \
			echo "Faltando: $$f"; \
			missing=1; \
		fi; \
	done; \
	if [ ! -f drone/.env ]; then \
		echo "Aviso: drone/.env não encontrado (copie de .env.drone.example)"; \
	fi; \
	if [ ! -f semaphore/.env ]; then \
		echo "Aviso: semaphore/.env não encontrado (copie de .env.semaphore.example)"; \
	fi; \
	if [ ! -f nginx/.env ]; then \
		echo "Aviso: nginx/.env não encontrado (copie de .env.nginx.example)"; \
	fi; \
	if [ ! -f vaultwarden/.env ]; then \
		echo "Aviso: drone/.env não encontrado (copie de .env.drone.example)"; \
	fi; \
	if [ $$missing -ne 0 ]; then \
		echo "Crie os .env obrigatórios antes de subir o ambiente."; \
		exit 1; \
	fi; \
	echo "Arquivos .env obrigatórios OK."

up-infra: networks
	@if [ ! -f nginx/certs/homelab.pem ] || [ ! -f nginx/certs/homelab-key.pem ]; then \
		echo "Certificados TLS ausentes — gerando com mkcert..."; \
		bash nginx/generate-certs.sh; \
	fi
	@$(COMPOSE) -f dnsmasq/compose.yaml --project-directory dnsmasq up -d
	@$(COMPOSE) -f db/compose.yaml --project-directory db up -d
	@$(COMPOSE) -f nginx/compose.yaml --project-directory nginx up -d
	@$(COMPOSE) -f vaultwarden/compose.yaml --project-directory vaultwarden up -d

up-apps: check-env
	@$(COMPOSE) -f gitea/compose.yaml --project-directory gitea up -d
	@$(COMPOSE) -f zabbix/compose.yaml --project-directory zabbix up -d
	@$(COMPOSE) -f grafana/compose.yaml --project-directory grafana up -d
	@$(COMPOSE) -f drone/compose.yaml --project-directory drone up -d
	@$(COMPOSE) -f semaphore/compose.yaml --project-directory semaphore up -d

up: check-env up-infra up-apps
	@echo "Ambiente iniciado."
	@$(MAKE) --no-print-directory ps

down:
	@for stack in semaphore drone grafana zabbix gitea vault nginx db dnsmasq; do \
		echo "<< $$stack"; \
		$(COMPOSE) -f $$stack/compose.yaml --project-directory $$stack down || true; \
	done
	@echo "Stacks parados (redes preservadas)."

restart: down up

ps:
	@docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

logs:
ifndef STACK
	@echo "Uso: make logs STACK=<nome>   (ex.: make logs STACK=zabbix)"
	@exit 1
endif
	@$(COMPOSE) -f $(STACK)/compose.yaml --project-directory $(STACK) logs -f --tail=100

db dnsmasq vaultwarden nginx: networks
	@$(COMPOSE) -f $@/compose.yaml --project-directory $@ up -d

gitea zabbix grafana: networks check-env
	@$(COMPOSE) -f $@/compose.yaml --project-directory $@ up -d

drone semaphore: networks
	@$(COMPOSE) -f $@/compose.yaml --project-directory $@ up -d
