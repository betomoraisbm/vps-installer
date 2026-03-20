#!/bin/bash

# ============================================
# INSTALADOR COMPLETO PARA PRODUÇÃO
# BETO MORAIS
# Ubuntu 24.04
# ============================================

set -e

# Cores
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GRAY='\033[0;90m'
NC='\033[0m'

# Configurações globais
POSTGRES_PASSWORD="BetoM2025!?"
REDIS_PASSWORD="BetoR2025!?"
MINIO_USER="betominio"
MINIO_PASSWORD="BetoM2025!?"

# Rede Docker
NETWORK_NAME="docker_beto"

show_banner() {
    clear
    echo -e "${CYAN}========================================"
    echo -e "       BETO MORAIS                   "
    echo -e "  INSTALADOR COMPLETO PRODUÇÃO        "
    echo -e "========================================${NC}"
    echo ""
    echo -e "Apps: Typebot, N8N, Evolution API,"
    echo -e "      Wuzapi, OpenClaw"
    echo ""
}

write_step() {
    local message="$1"
    local type="${2:-INFO}"
    case "$type" in
        OK)
            echo -e "[OK] $message"
            ;;
        ERROR)
            echo -e "[ERROR] $message"
            ;;
        SKIP)
            echo -e "[SKIP] $message"
            ;;
        *)
            echo -e "[INFO] $message"
            ;;
    esac
}

test_docker() {
    docker --version &>/dev/null
}

create_network() {
    if ! docker network inspect "$NETWORK_NAME" &>/dev/null; then
        docker network create "$NETWORK_NAME" 2>/dev/null || true
    fi
}

# ============================================
# INSTALAR TUDO
# ============================================
install_all() {
    show_banner
    echo -e "${CYAN}[INSTALAR TUDO]${NC}"
    echo -e "========================================"
    echo ""
    echo -e "Este processo vai instalar:"
    echo -e "  - Docker"
    echo -e "  - Portainer"
    echo -e "  - Nginx Proxy Manager"
    echo -e "  - PostgreSQL"
    echo -e "  - Redis"
    echo -e "  - MinIO"
    echo ""
    read -p "Pressione ENTER para continuar ou Ctrl+C para cancelar"

    install_docker
    create_network
    install_postgres
    install_redis
    install_minio
    install_nginx_pm
    install_portainer

    show_banner
    echo -e "${CYAN}[INSTALAÇÃO COMPLETA]${NC}"
    echo -e "========================================"
    echo ""
    echo -e "${GREEN}Tudo instalado com sucesso!${NC}"
    echo ""
    echo -e "Próximos passos:"
    echo -e "  1. Configure o Nginx Proxy Manager em: http://IP:81"
    echo -e "  2. Crie os Proxy Hosts para seus apps"
    echo ""
    read -p "Pressione ENTER para continuar"
}

# ============================================
# INSTALAR DOCKER
# ============================================
install_docker() {
    show_banner
    echo -e "${CYAN}[DOCKER]${NC}"
    echo -e "========================================"
    echo ""

    if docker --version &>/dev/null; then
        write_step "Docker já está instalado: $(docker --version)" "SKIP"
        read -p "Pressione ENTER para continuar"
        return
    fi

    write_step "Atualizando sistema..." "INFO"
    apt-get update -qq

    write_step "Instalando dependências..." "INFO"
    apt-get install -y -qq ca-certificates curl gnupg lsb-release

    write_step "Adicionando repositório Docker..." "INFO"
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    write_step "Instalando Docker..." "INFO"
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    write_step "Iniciando Docker..." "INFO"
    systemctl enable docker
    systemctl start docker

    write_step "Docker instalado com sucesso!" "OK"
    docker --version

    read -p "Pressione ENTER para continuar"
}

# ============================================
# INSTALAR POSTGRESQL
# ============================================
install_postgres() {
    show_banner
    echo -e "${CYAN}[POSTGRESQL]${NC}"
    echo -e "========================================"
    echo ""

    if docker ps -a --format '{{.Names}}' | grep -q "^postgres$"; then
        write_step "PostgreSQL já existe!" "SKIP"
        read -p "Pressione ENTER para continuar"
        return
    fi

    create_network

    write_step "Criando volume para PostgreSQL..." "INFO"
    docker volume create postgres_data &>/dev/null || true

    write_step "Instalando PostgreSQL 15..." "INFO"
    docker run -d \
        --name postgres \
        --restart unless-stopped \
        --network "$NETWORK_NAME" \
        -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
        -e POSTGRES_DB=beto \
        -v postgres_data:/var/lib/postgresql/data \
        postgres:15-alpine

    write_step "Aguardando PostgreSQL iniciar..." "INFO"
    sleep 5

    write_step "PostgreSQL instalado!" "OK"
    echo "  Host: postgres"
    echo "  Porta: 5432"
    echo "  Database: beto"
    echo "  Senha: $POSTGRES_PASSWORD"

    read -p "Pressione ENTER para continuar"
}

# ============================================
# INSTALAR REDIS
# ============================================
install_redis() {
    show_banner
    echo -e "${CYAN}[REDIS]${NC}"
    echo -e "========================================"
    echo ""

    if docker ps -a --format '{{.Names}}' | grep -q "^redis$"; then
        write_step "Redis já existe!" "SKIP"
        read -p "Pressione ENTER para continuar"
        return
    fi

    create_network

    write_step "Criando volume para Redis..." "INFO"
    docker volume create redis_data &>/dev/null || true

    write_step "Instalando Redis 7..." "INFO"
    docker run -d \
        --name redis \
        --restart unless-stopped \
        --network "$NETWORK_NAME" \
        -p 6379:6379 \
        -e REDIS_PASSWORD="$REDIS_PASSWORD" \
        -v redis_data:/data \
        redis:7-alpine \
        redis-server --requirepass "$REDIS_PASSWORD"

    write_step "Redis instalado!" "OK"
    echo "  Host: redis"
    echo "  Porta: 6379"
    echo "  Senha: $REDIS_PASSWORD"

    read -p "Pressione ENTER para continuar"
}

# ============================================
# INSTALAR MINIO
# ============================================
install_minio() {
    show_banner
    echo -e "${CYAN}[MINIO]${NC}"
    echo -e "========================================"
    echo ""

    if docker ps -a --format '{{.Names}}' | grep -q "^minio$"; then
        write_step "MinIO já existe!" "SKIP"
        read -p "Pressione ENTER para continuar"
        return
    fi

    create_network

    write_step "Criando volume para MinIO..." "INFO"
    docker volume create minio_data &>/dev/null || true

    write_step "Instalando MinIO..." "INFO"
    docker run -d \
        --name minio \
        --restart unless-stopped \
        --network "$NETWORK_NAME" \
        -p 9002:9000 \
        -p 9003:9001 \
        -e MINIO_ROOT_USER="$MINIO_USER" \
        -e MINIO_ROOT_PASSWORD="$MINIO_PASSWORD" \
        -v minio_data:/data \
        minio/minio:latest server /data --console-address ":9001"

    write_step "MinIO instalado!" "OK"
    echo "  API: http://localhost:9002"
    echo "  Console: http://localhost:9003"
    echo "  Usuário: $MINIO_USER"
    echo "  Senha: $MINIO_PASSWORD"

    read -p "Pressione ENTER para continuar"
}

# ============================================
# INSTALAR NGINX PROXY MANAGER
# ============================================
install_nginx_pm() {
    show_banner
    echo -e "${CYAN}[NGINX PROXY MANAGER]${NC}"
    echo -e "========================================"
    echo ""

    if docker ps -a --format '{{.Names}}' | grep -q "^nginx-proxy-manager$"; then
        write_step "Nginx Proxy Manager já existe!" "SKIP"
        read -p "Pressione ENTER para continuar"
        return
    fi

    create_network

    write_step "Criando volume para Nginx Proxy Manager..." "INFO"
    docker volume create npm_data &>/dev/null || true
    docker volume create npm_letsencrypt &>/dev/null || true

    write_step "Instalando Nginx Proxy Manager..." "INFO"
    docker run -d \
        --name nginx-proxy-manager \
        --restart unless-stopped \
        --network "$NETWORK_NAME" \
        -p 80:80 \
        -p 81:81 \
        -p 443:443 \
        -v npm_data:/data \
        -v npm_letsencrypt:/etc/letsencrypt \
        jc21/nginx-proxy-manager:latest

    write_step "Aguardando Nginx Proxy Manager iniciar..." "INFO"
    sleep 10

    write_step "Alterando senha do admin..." "INFO"
    local npm_api="http://localhost:81"
    local new_password="admin@2026"

    local token=$(curl -s -X POST "$npm_api/api/tokens" \
        -H "Content-Type: application/json" \
        -d '{"identity":"admin@example.com","secret":"changeme"}' | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

    if [ -n "$token" ]; then
        curl -s -X PUT "$npm_api/api/users/1" \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json" \
            -d "{\"name\":\"Admin\",\"email\":\"admin@example.com\",\"password\":\"$new_password\"}" > /dev/null
        write_step "Senha alterada com sucesso!" "OK"
    else
        write_step "Não foi possível alterar senha automaticamente." "WARN"
    fi

    write_step "Nginx Proxy Manager instalado!" "OK"
    echo "  Admin UI: http://localhost:81"
    echo "  Email: admin@example.com"
    echo "  Senha: $new_password"

    read -p "Pressione ENTER para continuar"
}

# ============================================
# INSTALAR PORTAINER
# ============================================
install_portainer() {
    show_banner
    echo -e "${CYAN}[PORTAINER]${NC}"
    echo -e "========================================"
    echo ""

    read -p "Digite o domínio para o Portainer (ex: portainer.seudominio.com): " PORTAINER_DOMAIN

    if docker ps -a --format '{{.Names}}' | grep -q "^portainer$"; then
        write_step "Portainer já existe!" "SKIP"
        read -p "Pressione ENTER para continuar"
        return
    fi

    create_network

    write_step "Criando volume para Portainer..." "INFO"
    docker volume create portainer_data &>/dev/null || true

    write_step "Instalando Portainer..." "INFO"
    docker run -d \
        --name portainer \
        --restart unless-stopped \
        --network "$NETWORK_NAME" \
        -p 9000:9000 \
        -p 9443:9443 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:latest

    write_step "Portainer instalado!" "OK"
    echo "  URL: https://${PORTAINER_DOMAIN}"
    echo ""
    echo "  Domínio: ${PORTAINER_DOMAIN}"

    configure_proxy_host "$PORTAINER_DOMAIN" "portainer" "9000"

    read -p "Pressione ENTER para continuar"
}

configure_proxy_host() {
    local domain=$1
    local target_host=$2
    local target_port=$3

    write_step "Configurando Proxy Host no NPM..." "INFO"

    local email="admin@example.com"
    local password="admin@2026"
    local npm_api="http://localhost:81"
    local max_attempts=5
    local attempt=1

    write_step "Aguardando NPM ficar pronto..." "INFO"
    while [ $attempt -le $max_attempts ]; do
        local token=$(curl -s -X POST "$npm_api/api/tokens" \
            -H "Content-Type: application/json" \
            -d "{\"identity\":\"$email\",\"secret\":\"$password\"}" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

        if [ -n "$token" ]; then
            break
        fi
        write_step "Tentativa $attempt/$max_attempts - aguardando..." "WARN"
        sleep 5
        attempt=$((attempt + 1))
    done

    if [ -z "$token" ]; then
        write_step "Erro ao autenticar no NPM. Configure manualmente." "ERROR"
        return 1
    fi

    local result=$(curl -s -X POST "$npm_api/api/proxy-hosts" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d "{
            \"domain_names\": [\"$domain\"],
            \"forward_host\": \"$target_host\",
            \"forward_port\": $target_port,
            \"ssl_enabled\": true,
            \"ssl_forced\": true,
            \"allow_websocket\": true
        }")

    if echo "$result" | grep -q "id"; then
        write_step "Proxy Host configurado com sucesso!" "OK"
    else
        write_step "Proxy Host pode já existir ou houve erro. Continue manualmente." "WARN"
    fi
}

# ============================================
# INSTALAR TYPEBOT
# ============================================
install_typebot() {
    show_banner
    echo -e "${CYAN}[TYPEBOT]${NC}"
    echo -e "========================================"
    echo ""

    if ! docker --version &>/dev/null; then
        write_step "Docker não está instalado!" "ERROR"
        echo "Execute a opção 1 primeiro."
        read -p "Pressione ENTER para continuar"
        return
    fi

    if docker ps -a --format '{{.Names}}' | grep -q "^typebot$"; then
        write_step "Typebot já existe!" "SKIP"
        read -p "Pressione ENTER para continuar"
        return
    fi

    create_network

    write_step "Criando volume para Typebot..." "INFO"
    docker volume create typebot_data &>/dev/null || true
    docker volume create typebot_s3 &>/dev/null || true

    echo -n "Digite o domínio (ex: typebot.seusite.com) ou ENTER para pular: "
    read -r domain

    write_step "Instalando Typebot..." "INFO"
    if [ -n "$domain" ]; then
        email=""
        echo -n "Digite o email para SSL: "
        read -r email
    fi

    docker run -d \
        --name typebot \
        --restart unless-stopped \
        --network "$NETWORK_NAME" \
        -p 3000:3000 \
        -e DATABASE_URL="postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/beto?schema=public" \
        -e NEXTAUTH_URL="http://localhost:3000" \
        -e NEXT_PUBLIC_URL="http://localhost:3000" \
        -e S3_ACCESS_KEY="$MINIO_USER" \
        -e S3_SECRET_KEY="$MINIO_PASSWORD" \
        -e S3_BUCKET="typebot" \
        -e S3_URL="http://minio:9000" \
        -v typebot_data:/app/.next/cache \
        -v typebot_s3:/etc/storage \
        typebot/typebot:latest

    write_step "Aguardando Typebot iniciar..." "INFO"
    sleep 10

    if docker ps --format '{{.Names}}' | grep -q "^typebot$"; then
        write_step "Typebot instalado!" "OK"
        echo "  Acesso: http://localhost:3000"
        [ -n "$domain" ] && echo "  Domínio: $domain"
    else
        write_step "Falha ao iniciar. Verifique: docker logs typebot" "ERROR"
    fi

    read -p "Pressione ENTER para continuar"
}

# ============================================
# INSTALAR N8N
# ============================================
install_n8n() {
    show_banner
    echo -e "${CYAN}[N8N]${NC}"
    echo -e "========================================"
    echo ""

    if ! docker --version &>/dev/null; then
        write_step "Docker não está instalado!" "ERROR"
        echo "Execute a opção 1 primeiro."
        read -p "Pressione ENTER para continuar"
        return
    fi

    if docker ps -a --format '{{.Names}}' | grep -q "^n8n$"; then
        write_step "N8N já existe!" "SKIP"
        read -p "Pressione ENTER para continuar"
        return
    fi

    create_network

    echo -n "Digite o domínio (ex: n8n.seusite.com) ou ENTER para pular: "
    read -r domain

    write_step "Instalando N8N..." "INFO"
    docker run -d \
        --name n8n \
        --restart unless-stopped \
        --network "$NETWORK_NAME" \
        -p 5678:5678 \
        -e WEBHOOK_URL="http://localhost:5678" \
        -e DB_TYPE="postgresdb" \
        -e DB_POSTGRES_HOST="postgres" \
        -e DB_POSTGRES_PORT="5432" \
        -e DB_POSTGRES_DATABASE="beto" \
        -e DB_POSTGRES_USER="postgres" \
        -e DB_POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
        -v n8n_data:/home/node/.n8n \
        n8nio/n8n:latest

    write_step "Aguardando N8N iniciar..." "INFO"
    sleep 10

    if docker ps --format '{{.Names}}' | grep -q "^n8n$"; then
        write_step "N8N instalado!" "OK"
        echo "  Acesso: http://localhost:5678"
        [ -n "$domain" ] && echo "  Domínio: $domain"
    else
        write_step "Falha ao iniciar. Verifique: docker logs n8n" "ERROR"
    fi

    read -p "Pressione ENTER para continuar"
}

# ============================================
# INSTALAR EVOLUTION API
# ============================================
install_evolution_api() {
    show_banner
    echo -e "${CYAN}[EVOLUTION API]${NC}"
    echo -e "========================================"
    echo ""

    if ! docker --version &>/dev/null; then
        write_step "Docker não está instalado!" "ERROR"
        echo "Execute a opção 1 primeiro."
        read -p "Pressione ENTER para continuar"
        return
    fi

    if docker ps -a --format '{{.Names}}' | grep -q "^evolution-api$"; then
        write_step "Evolution API já existe!" "SKIP"
        read -p "Pressione ENTER para continuar"
        return
    fi

    create_network

    echo -n "Digite o domínio (ex: api.seusite.com) ou ENTER para pular: "
    read -r domain

    write_step "Instalando Evolution API..." "INFO"
    docker run -d \
        --name evolution-api \
        --restart unless-stopped \
        --network "$NETWORK_NAME" \
        -p 8080:8080 \
        -e DATABASE_URL="postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/beto" \
        -e DATABASE_PROVIDER=POSTGRESQL \
        -e CACHE_URL="redis://:${REDIS_PASSWORD}@redis:6379" \
        -e CACHE_PROVIDER=REDIS \
        -v evolution_instances:/evolution/instances \
        atendai/evolution-api:latest

    write_step "Aguardando Evolution API iniciar..." "INFO"
    sleep 10

    if docker ps --format '{{.Names}}' | grep -q "^evolution-api$"; then
        write_step "Evolution API instalado!" "OK"
        echo "  Acesso: http://localhost:8080"
        echo "  API Docs: http://localhost:8080/docs"
        [ -n "$domain" ] && echo "  Domínio: $domain"
    else
        write_step "Falha ao iniciar. Verifique: docker logs evolution-api" "ERROR"
    fi

    read -p "Pressione ENTER para continuar"
}

# ============================================
# INSTALAR WUZAPI
# ============================================
install_wuzapi() {
    show_banner
    echo -e "${CYAN}[WUZAPI]${NC}"
    echo -e "========================================"
    echo ""

    if ! docker --version &>/dev/null; then
        write_step "Docker não está instalado!" "ERROR"
        echo "Execute a opção 1 primeiro."
        read -p "Pressione ENTER para continuar"
        return
    fi

    if docker ps -a --format '{{.Names}}' | grep -q "^wuzapi$"; then
        write_step "Wuzapi já existe!" "SKIP"
        read -p "Pressione ENTER para continuar"
        return
    fi

    create_network

    echo -n "Digite o domínio (ex: wuzapi.seusite.com) ou ENTER para pular: "
    read -r domain

    write_step "Instalando Wuzapi..." "INFO"
    docker run -d \
        --name wuzapi \
        --restart unless-stopped \
        --network "$NETWORK_NAME" \
        -p 3001:3000 \
        -v wuzapi_data:/app/data \
        uye restraints/wuzapi:latest

    write_step "Aguardando Wuzapi iniciar..." "INFO"
    sleep 10

    if docker ps --format '{{.Names}}' | grep -q "^wuzapi$"; then
        write_step "Wuzapi instalado!" "OK"
        echo "  Acesso: http://localhost:3001"
        [ -n "$domain" ] && echo "  Domínio: $domain"
    else
        write_step "Falha ao iniciar. Verifique: docker logs wuzapi" "ERROR"
    fi

    read -p "Pressione ENTER para continuar"
}

# ============================================
# INSTALAR OPENCLAW
# ============================================
install_openclaw() {
    show_banner
    echo -e "${CYAN}[OPENCLAW]${NC}"
    echo -e "========================================"
    echo ""

    if ! docker --version &>/dev/null; then
        write_step "Docker não está instalado!" "ERROR"
        echo "Execute a opção 1 primeiro."
        read -p "Pressione ENTER para continuar"
        return
    fi

    if docker ps -a --format '{{.Names}}' | grep -q "^openclaw$"; then
        write_step "OpenClaw já existe!" "SKIP"
        read -p "Pressione ENTER para continuar"
        return
    fi

    create_network

    echo -n "Digite o domínio (ex: openclaw.seusite.com) ou ENTER para pular: "
    read -r domain

    write_step "Instalando OpenClaw..." "INFO"
    docker run -d \
        --name openclaw \
        --restart unless-stopped \
        --network "$NETWORK_NAME" \
        -p 3002:3000 \
        -e DATABASE_URL="postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/beto" \
        -v openclaw_data:/app/data \
        openclaw/openclaw:latest

    write_step "Aguardando OpenClaw iniciar..." "INFO"
    sleep 10

    if docker ps --format '{{.Names}}' | grep -q "^openclaw$"; then
        write_step "OpenClaw instalado!" "OK"
        echo "  Acesso: http://localhost:3002"
        [ -n "$domain" ] && echo "  Domínio: $domain"
    else
        write_step "Falha ao iniciar. Verifique: docker logs openclaw" "ERROR"
    fi

    read -p "Pressione ENTER para continuar"
}

# ============================================
# VER STATUS
# ============================================
show_status() {
    show_banner
    echo -e "${CYAN}[STATUS DOS SERVIÇOS]${NC}"
    echo -e "========================================"
    echo ""

    if ! docker --version &>/dev/null; then
        write_step "Docker não está instalado" "ERROR"
        echo ""
        read -p "Pressione ENTER para continuar"
        return
    fi

    local containers=("postgres" "redis" "minio" "nginx-proxy-manager" "portainer" "typebot" "n8n" "evolution-api" "wuzapi" "openclaw")

    for container in "${containers[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            echo -e "  ${GREEN}[OK]${NC} $container - $(docker ps --filter "name=$container" --format '{{.Status}}')"
        elif docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
            echo -e "  ${YELLOW}[PARADO]${NC} $container - $(docker ps -a --filter "name=$container" --format '{{.Status}}')"
        else
            echo -e "  ${GRAY}[--]${NC} $container - Não instalado"
        fi
    done

    echo ""
    read -p "Pressione ENTER para continuar"
}

# ============================================
# MENU PRINCIPAL
# ============================================
show_menu() {
    show_banner
    echo -e "${CYAN}[MENU PRINCIPAL]${NC}"
    echo -e "========================================"
    echo ""
    echo -e "--- INSTALAÇÃO COMPLETA ---"
    echo -e "1. INSTALAR TUDO (Docker + Portainer + NPM + PostgreSQL + Redis + MinIO)"
    echo ""
    echo -e "--- INFRAESTRUTURA ---"
    echo -e "2. Instalar Docker"
    echo -e "3. Instalar PostgreSQL"
    echo -e "4. Instalar Redis"
    echo -e "5. Instalar MinIO"
    echo -e "6. Instalar Nginx Proxy Manager"
    echo -e "7. Instalar Portainer"
    echo ""
    echo -e "--- APLICAÇÕES ---"
    echo -e "8. Instalar Typebot"
    echo -e "9. Instalar N8N"
    echo -e "10. Instalar Evolution API"
    echo -e "11. Instalar Wuzapi"
    echo -e "12. Instalar OpenClaw"
    echo ""
    echo -e "--- UTILIDADES ---"
    echo -e "13. Ver Status dos Serviços"
    echo ""
    echo -e "0. Sair"
    echo ""
}

# ============================================
# MAIN
# ============================================
main() {
    while true; do
        show_menu
        echo -n "Escolha uma opção: "
        read -r choice

        case "$choice" in
            1) install_all ;;
            2) install_docker ;;
            3) install_postgres ;;
            4) install_redis ;;
            5) install_minio ;;
            6) install_nginx_pm ;;
            7) install_portainer ;;
            8) install_typebot ;;
            9) install_n8n ;;
            10) install_evolution_api ;;
            11) install_wuzapi ;;
            12) install_openclaw ;;
            13) show_status ;;
            0)
                show_banner
                echo -e "${CYAN}Obrigado!${NC}"
                exit
                ;;
            *)
                echo -e "${RED}[ERRO] Opção inválida!${NC}"
                sleep 2
                ;;
        esac
    done
}

main
