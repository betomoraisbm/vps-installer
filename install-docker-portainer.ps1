# ============================================
# INSTALADOR COMPLETO PARA PRODUÇÃO
# BETO MORAIS
# ============================================

$ErrorActionPreference = "Continue"

$Global:Config = @{
    Domain = ""
    Email = ""
    PostgresPassword = "BetoM2025!?"
    RedisPassword = "BetoR2025!?"
    MinIOUser = "betominio"
    MinIOPass = "BetoM2025!?"
}

function Show-Banner {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "       BETO MORAIS                   " -ForegroundColor Cyan
    Write-Host "  INSTALADOR COMPLETO PRODUÇÃO        " -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Apps: Typebot, N8N, Evolution API," -ForegroundColor Yellow
    Write-Host "      Wuzapi, OpenClaw" -ForegroundColor Yellow
    Write-Host ""
}

function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Write-Step {
    param([string]$Message, [string]$Type = "INFO")
    $colors = @{
        "INFO" = "Yellow"
        "OK" = "Green"
        "ERROR" = "Red"
        "SKIP" = "Gray"
    }
    $color = $colors[$Type]
    if ($Type -eq "OK") {
        Write-Host "[OK] $Message" -ForegroundColor $color
    } elseif ($Type -eq "ERROR") {
        Write-Host "[ERROR] $Message" -ForegroundColor $color
    } elseif ($Type -eq "SKIP") {
        Write-Host "[SKIP] $Message" -ForegroundColor $color
    } else {
        Write-Host "[INFO] $Message" -ForegroundColor $color
    }
}

function Test-Docker {
    if (!(Test-CommandExists "docker")) {
        Write-Step "Docker não está instalado!" "ERROR"
        Write-Host "Execute a opção 1 primeiro para instalar o Docker." -ForegroundColor Yellow
        return $false
    }
    return $true
}

function Install-Docker {
    Show-Banner
    Write-Host "[INSTALANDO DOCKER]" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    if (Test-CommandExists "docker") {
        Write-Step "Docker já está instalado!" "SKIP"
        docker --version
        Read-Host "Pressione ENTER para continuar"
        return
    }

    Write-Step "Baixando script de instalação..."

    try {
        $installScript = @"
Write-Host 'Instalando Docker...'
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -ErrorAction SilentlyContinue
Set-ExecutionPolicy Bypass -Scope Process -Force
Invoke-WebRequest -Uri https://get.docker.com -OutFile docker-install.ps1 -UseBasicParsing
& ./docker-install.ps1
Remove-Item docker-install.ps1 -Force -ErrorAction SilentlyContinue
Write-Host 'Docker instalado com sucesso!'
"@

        $tempScript = "$env:TEMP\docker_install_$(Get-Random).ps1"
        $installScript | Out-File -FilePath $tempScript -Encoding UTF8
        & $tempScript

        if (Test-CommandExists "docker") {
            Write-Step "Docker instalado com sucesso!" "OK"
            docker --version
        } else {
            Write-Step "Falha ao instalar Docker!" "ERROR"
        }
    }
    catch {
        Write-Step "Erro: $_" "ERROR"
    }

    Read-Host "Pressione ENTER para continuar"
}

function Install-PostgreSQL {
    Show-Banner
    Write-Host "[POSTGRESQL]" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    if (!(Test-Docker)) {
        Read-Host "Pressione ENTER para continuar"
        return
    }

    $exists = docker ps -a --format '{{.Names}}' | Where-Object { $_ -eq "postgres" }
    if ($exists) {
        Write-Step "PostgreSQL já existe!" "SKIP"
        $running = docker ps --format '{{.Names}}' | Where-Object { $_ -eq "postgres" }
        if ($running) {
            Write-Host "Status: Executando" -ForegroundColor Green
        } else {
            Write-Host "Status: Parado" -ForegroundColor Red
        }
        Read-Host "Pressione ENTER para continuar"
        return
    }

    Write-Step "Criando rede docker_beto..." - "INFO"
    docker network create docker_beto --silent 2>$null

    Write-Step "Criando volume..." - "INFO"
    docker volume create postgres_data --silent 2>$null

    Write-Step "Instalando PostgreSQL..." - "INFO"
    $pass = $Global:Config.PostgresPassword

    docker run -d `
        --name postgres `
        --restart unless-stopped `
        --network docker_beto `
        -e POSTGRES_PASSWORD=$pass `
        -e POSTGRES_DB=beto `
        -v postgres_data:/var/lib/postgresql/data `
        -p 5432:5432 `
        postgres:15-alpine

    Start-Sleep -Seconds 5

    $running = docker ps --format '{{.Names}}' | Where-Object { $_ -eq "postgres" }
    if ($running) {
        Write-Step "PostgreSQL instalado com sucesso!" "OK"
        Write-Host "Porta: 5432" -ForegroundColor Cyan
        Write-Host "Senha: $pass" -ForegroundColor Cyan
    } else {
        Write-Step "Falha ao instalar PostgreSQL!" "ERROR"
    }

    Read-Host "Pressione ENTER para continuar"
}

function Install-Redis {
    Show-Banner
    Write-Host "[REDIS]" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    if (!(Test-Docker)) {
        Read-Host "Pressione ENTER para continuar"
        return
    }

    $exists = docker ps -a --format '{{.Names}}' | Where-Object { $_ -eq "redis" }
    if ($exists) {
        Write-Step "Redis já existe!" "SKIP"
        $running = docker ps --format '{{.Names}}' | Where-Object { $_ -eq "redis" }
        if ($running) {
            Write-Host "Status: Executando" -ForegroundColor Green
        } else {
            Write-Host "Status: Parado" -ForegroundColor Red
        }
        Read-Host "Pressione ENTER para continuar"
        return
    }

    Write-Step "Criando volume..." - "INFO"
    docker volume create redis_data --silent 2>$null

    Write-Step "Instalando Redis..." - "INFO"
    $pass = $Global:Config.RedisPassword

    docker run -d `
        --name redis `
        --restart unless-stopped `
        --network docker_beto `
        -e REDIS_PASSWORD=$pass `
        -v redis_data:/data `
        -p 6379:6379 `
        redis:7-alpine redis-server --requirepass $pass

    Start-Sleep -Seconds 3

    $running = docker ps --format '{{.Names}}' | Where-Object { $_ -eq "redis" }
    if ($running) {
        Write-Step "Redis instalado com sucesso!" "OK"
        Write-Host "Porta: 6379" -ForegroundColor Cyan
        Write-Host "Senha: $pass" -ForegroundColor Cyan
    } else {
        Write-Step "Falha ao instalar Redis!" "ERROR"
    }

    Read-Host "Pressione ENTER para continuar"
}

function Install-MinIO {
    Show-Banner
    Write-Host "[MINIO]" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    if (!(Test-Docker)) {
        Read-Host "Pressione ENTER para continuar"
        return
    }

    $exists = docker ps -a --format '{{.Names}}' | Where-Object { $_ -eq "minio" }
    if ($exists) {
        Write-Step "MinIO já existe!" "SKIP"
        $running = docker ps --format '{{.Names}}' | Where-Object { $_ -eq "minio" }
        if ($running) {
            Write-Host "Status: Executando" -ForegroundColor Green
        } else {
            Write-Host "Status: Parado" -ForegroundColor Red
        }
        Read-Host "Pressione ENTER para continuar"
        return
    }

    Write-Step "Criando volume..." - "INFO"
    docker volume create minio_data --silent 2>$null

    Write-Step "Instalando MinIO..." - "INFO"
    $user = $Global:Config.MinIOUser
    $pass = $Global:Config.MinIOPass

    docker run -d `
        --name minio `
        --restart unless-stopped `
        --network docker_beto `
        -p 9000:9000 `
        -p 9001:9001 `
        -e MINIO_ROOT_USER=$user `
        -e MINIO_ROOT_PASSWORD=$pass `
        -v minio_data=/data `
        minio/minio:latest server /data --console-address ":9001"

    Start-Sleep -Seconds 5

    $running = docker ps --format '{{.Names}}' | Where-Object { $_ -eq "minio" }
    if ($running) {
        Write-Step "MinIO instalado com sucesso!" "OK"
        Write-Host "API: http://localhost:9000" -ForegroundColor Cyan
        Write-Host "Console: http://localhost:9001" -ForegroundColor Cyan
        Write-Host "Usuário: $user" -ForegroundColor Cyan
        Write-Host "Senha: $pass" -ForegroundColor Cyan
    } else {
        Write-Step "Falha ao instalar MinIO!" "ERROR"
    }

    Read-Host "Pressione ENTER para continuar"
}

function Install-NginxProxyManager {
    Show-Banner
    Write-Host "[NGINX PROXY MANAGER]" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    if (!(Test-Docker)) {
        Read-Host "Pressione ENTER para continuar"
        return
    }

    $exists = docker ps -a --format '{{.Names}}' | Where-Object { $_ -eq "nginx-proxy-manager" }
    if ($exists) {
        Write-Step "Nginx Proxy Manager já existe!" "SKIP"
        $running = docker ps --format '{{.Names}}' | Where-Object { $_ -eq "nginx-proxy-manager" }
        if ($running) {
            Write-Host "Status: Executando" -ForegroundColor Green
        } else {
            Write-Host "Status: Parado" -ForegroundColor Red
        }
        Read-Host "Pressione ENTER para continuar"
        return
    }

    $npmDir = "$env:ProgramData\NginxProxyManager"
    if (!(Test-Path $npmDir)) {
        New-Item -ItemType Directory -Path "$npmDir\data" -Force | Out-Null
        New-Item -ItemType Directory -Path "$npmDir\letsencrypt" -Force | Out-Null
    }

    $dockerCompose = @"
version: '3.8'
services:
  nginx-proxy-manager:
    image: jc21/nginx-proxy-manager:latest
    container_name: nginx-proxy-manager
    restart: unless-stopped
    ports:
      - '80:80'
      - '443:443'
      - '81:81'
    environment:
      - DB_MYSQL_HOST=nginx-proxy-manager-db
      - DB_MYSQL_PORT=3306
      - DB_MYSQL_USER=npm
      - DB_MYSQL_PASSWORD=npm_password
      - DB_MYSQL_NAME=npm
    volumes:
      - $($npmDir.Replace('\','/'))/data:/data
      - $($npmDir.Replace('\','/'))/letsencrypt:/etc/letsencrypt
    networks:
      - docker_beto

  nginx-proxy-manager-db:
    image: jc21/mariadb:latest
    container_name: nginx-proxy-manager-db
    restart: unless-stopped
    environment:
      - MYSQL_ROOT_PASSWORD=npm_root_password
      - MYSQL_DATABASE=npm
      - MYSQL_USER=npm
      - MYSQL_PASSWORD=npm_password
    volumes:
      - $($npmDir.Replace('\','/'))/data/mysql:/var/lib/mysql
    networks:
      - docker_beto

networks:
  docker_beto:
    external: true
"@

    Write-Step "Criando docker-compose.yml..." - "INFO"
    $composeFile = "$npmDir\docker-compose.yml"
    $dockerCompose | Out-File -FilePath $composeFile -Encoding UTF8

    Write-Step "Iniciando containers..." - "INFO"
    Set-Location $npmDir
    docker-compose up -d

    Start-Sleep -Seconds 15

    $running = docker ps --format '{{.Names}}' | Where-Object { $_ -eq "nginx-proxy-manager" }
    if ($running) {
        Write-Step "Nginx Proxy Manager instalado!" "OK"
        Write-Host "Acesso: http://localhost:81" -ForegroundColor Cyan
        Write-Host "Email: admin@example.com" -ForegroundColor Cyan
        Write-Host "Senha: changeme" -ForegroundColor Cyan
    } else {
        Write-Step "Verificando status..." - "INFO"
        docker ps -a --filter "name=nginx" --format '{{.Names}}: {{.Status}}'
    }

    Read-Host "Pressione ENTER para continuar"
}

function Install-Portainer {
    Show-Banner
    Write-Host "[PORTAINER]" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    if (!(Test-Docker)) {
        Read-Host "Pressione ENTER para continuar"
        return
    }

    $exists = docker ps -a --format '{{.Names}}' | Where-Object { $_ -eq "portainer" }
    if ($exists) {
        Write-Step "Portainer já existe!" "SKIP"
        $running = docker ps --format '{{.Names}}' | Where-Object { $_ -eq "portainer" }
        if ($running) {
            Write-Host "Status: Executando" -ForegroundColor Green
        } else {
            Write-Host "Status: Parado" -ForegroundColor Red
        }
        Read-Host "Pressione ENTER para continuar"
        return
    }

    Write-Step "Criando volume..." - "INFO"
    docker volume create portainer_data --silent 2>$null

    Write-Step "Instalando Portainer..." - "INFO"

    docker run -d `
        --name portainer `
        --restart unless-stopped `
        --network docker_beto `
        -p 8000:8000 `
        -p 9000:9000 `
        -v \\.\pipe\docker_engine:\\.\pipe\docker_engine `
        -v portainer_data:/data `
        portainer/portainer-ce:latest

    Start-Sleep -Seconds 5

    $running = docker ps --format '{{.Names}}' | Where-Object { $_ -eq "portainer" }
    if ($running) {
        Write-Step "Portainer instalado!" "OK"
        Write-Host "Acesso: http://localhost:9000" -ForegroundColor Cyan
    } else {
        Write-Step "Falha ao iniciar Portainer!" "ERROR"
    }

    Read-Host "Pressione ENTER para continuar"
}

function Install-Typebot {
    Show-Banner
    Write-Host "[TYPEBOT]" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    if (!(Test-Docker)) {
        Read-Host "Pressione ENTER para continuar"
        return
    }

    $exists = docker ps -a --format '{{.Names}}' | Where-Object { $_ -eq "typebot" }
    if ($exists) {
        Write-Step "Typebot já existe!" "SKIP"
        Read-Host "Pressione ENTER para continuar"
        return
    }

    $typebotDir = "$env:ProgramData\Typebot"
    if (!(Test-Path "$typebotDir\data")) {
        New-Item -ItemType Directory -Path "$typebotDir\data" -Force | Out-Null
    }

    Write-Step "Criando volume MinIO..." - "INFO"
    docker volume create typebot_s3 --silent 2>$null

    Write-Step "Instalando Typebot..." - "INFO"

    $domain = Read-Host "Digite o domínio (ex: typebot.seusite.com) ou ENTER para pular"
    $email = if ($domain) { Read-Host "Digite o email para SSL" }

    docker run -d `
        --name typebot `
        --restart unless-stopped `
        --network docker_beto `
        -p 3000:3000 `
        -e DATABASE_URL="postgresql://postgres:$($Global:Config.PostgresPassword)@postgres:5432/beto?schema=public" `
        -e NEXTAUTH_URL="http://localhost:3000" `
        -e NEXT_PUBLIC_URL="http://localhost:3000" `
        -e S3_ACCESS_KEY="$($Global:Config.MinIOUser)" `
        -e S3_SECRET_KEY="$($Global:Config.MinIOPass)" `
        -e S3_BUCKET="typebot" `
        -e S3_URL="http://minio:9000" `
        -v typebot_s3:/etc/storage `
        typebot/typebot:latest

    Start-Sleep -Seconds 10

    $running = docker ps --format '{{.Names}}' | Where-Object { $_ -eq "typebot" }
    if ($running) {
        Write-Step "Typebot instalado!" "OK"
        Write-Host "Acesso: http://localhost:3000" -ForegroundColor Cyan
        if ($domain) {
            Write-Host "Domínio: $domain" -ForegroundColor Cyan
        }
    } else {
        Write-Step "Verifique os logs com: docker logs typebot" "ERROR"
    }

    Read-Host "Pressione ENTER para continuar"
}

function Install-N8N {
    Show-Banner
    Write-Host "[N8N]" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    if (!(Test-Docker)) {
        Read-Host "Pressione ENTER para continuar"
        return
    }

    $exists = docker ps -a --format '{{.Names}}' | Where-Object { $_ -eq "n8n" }
    if ($exists) {
        Write-Step "N8N já existe!" "SKIP"
        Read-Host "Pressione ENTER para continuar"
        return
    }

    Write-Step "Criando volume..." - "INFO"
    docker volume create n8n_data --silent 2>$null

    Write-Step "Instalando N8N..." - "INFO"

    $domain = Read-Host "Digite o domínio (ex: n8n.seusite.com) ou ENTER para pular"
    $email = if ($domain) { Read-Host "Digite o email para SSL" }

    docker run -d `
        --name n8n `
        --restart unless-stopped `
        --network docker_beto `
        -p 5678:5678 `
        -e WEBHOOK_URL="http://localhost:5678" `
        -e DB_TYPE="postgresdb" `
        -e DB_POSTGRESDB_HOST="postgres" `
        -e DB_POSTGRESDB_PORT="5432" `
        -e DB_POSTGRESDB_DATABASE="beto" `
        -e DB_POSTGRESDB_USER="postgres" `
        -e DB_POSTGRESDB_PASSWORD="$($Global:Config.PostgresPassword)" `
        -v n8n_data:/home/node/.n8n `
        n8nio/n8n:latest

    Start-Sleep -Seconds 10

    $running = docker ps --format '{{.Names}}' | Where-Object { $_ -eq "n8n" }
    if ($running) {
        Write-Step "N8N instalado!" "OK"
        Write-Host "Acesso: http://localhost:5678" -ForegroundColor Cyan
        if ($domain) {
            Write-Host "Domínio: $domain" -ForegroundColor Cyan
        }
    } else {
        Write-Step "Verifique os logs com: docker logs n8n" "ERROR"
    }

    Read-Host "Pressione ENTER para continuar"
}

function Install-EvolutionAPI {
    Show-Banner
    Write-Host "[EVOLUTION API]" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    if (!(Test-Docker)) {
        Read-Host "Pressione ENTER para continuar"
        return
    }

    $exists = docker ps -a --format '{{.Names}}' | Where-Object { $_ -eq "evolution-api" }
    if ($exists) {
        Write-Step "Evolution API já existe!" "SKIP"
        Read-Host "Pressione ENTER para continuar"
        return
    }

    Write-Step "Criando volume..." - "INFO"
    docker volume create evolution_data --silent 2>$null

    Write-Step "Instalando Evolution API..." - "INFO"

    $domain = Read-Host "Digite o domínio (ex: api.seusite.com) ou ENTER para pular"
    $email = if ($domain) { Read-Host "Digite o email para SSL" }

    docker run -d `
        --name evolution-api `
        --restart unless-stopped `
        --network docker_beto `
        -p 8080:8080 `
        -e DATABASE_ENABLED=true `
        -e DATABASE_PROVIDER=postgresql `
        -e DATABASE_HOST=postgres `
        -e DATABASE_PORT=5432 `
        -e DATABASE_NAME=beto `
        -e DATABASE_USER=postgres `
        -e DATABASE_PASSWORD="$($Global:Config.PostgresPassword)" `
        -e CACHE_REDIS_ENABLED=true `
        -e CACHE_REDIS_HOST=redis `
        -e CACHE_REDIS_PORT=6379 `
        -e CACHE_REDIS_PASSWORD="$($Global:Config.RedisPassword)" `
        -v evolution_data:/evolution/instances `
        atendai/evolution-api:latest

    Start-Sleep -Seconds 10

    $running = docker ps --format '{{.Names}}' | Where-Object { $_ -eq "evolution-api" }
    if ($running) {
        Write-Step "Evolution API instalado!" "OK"
        Write-Host "Acesso: http://localhost:8080" -ForegroundColor Cyan
        Write-Host "Documentação: http://localhost:8080/docs" -ForegroundColor Cyan
    } else {
        Write-Step "Verifique os logs com: docker logs evolution-api" "ERROR"
    }

    Read-Host "Pressione ENTER para continuar"
}

function Install-Wuzapi {
    Show-Banner
    Write-Host "[WUZAPI]" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    if (!(Test-Docker)) {
        Read-Host "Pressione ENTER para continuar"
        return
    }

    $exists = docker ps -a --format '{{.Names}}' | Where-Object { $_ -eq "wuzapi" }
    if ($exists) {
        Write-Step "Wuzapi já existe!" "SKIP"
        Read-Host "Pressione ENTER para continuar"
        return
    }

    Write-Step "Criando volume..." - "INFO"
    docker volume create wuzapi_data --silent 2>$null

    Write-Step "Instalando Wuzapi..." - "INFO"

    $domain = Read-Host "Digite o domínio (ex: wuzapi.seusite.com) ou ENTER para pular"
    $email = if ($domain) { Read-Host "Digite o email para SSL" }

    docker run -d `
        --name wuzapi `
        --restart unless-stopped `
        --network docker_beto `
        -p 3001:3000 `
        -e DATABASE_URL="sqlite:///wuzapi.db" `
        -v wuzapi_data:/app/data `
        ghcr.io/christerclock/wuzapi:latest

    Start-Sleep -Seconds 10

    $running = docker ps --format '{{.Names}}' | Where-Object { $_ -eq "wuzapi" }
    if ($running) {
        Write-Step "Wuzapi instalado!" "OK"
        Write-Host "Acesso: http://localhost:3001" -ForegroundColor Cyan
    } else {
        Write-Step "Verifique os logs com: docker logs wuzapi" "ERROR"
    }

    Read-Host "Pressione ENTER para continuar"
}

function Install-OpenClaw {
    Show-Banner
    Write-Host "[OPENCLAW]" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    if (!(Test-Docker)) {
        Read-Host "Pressione ENTER para continuar"
        return
    }

    $exists = docker ps -a --format '{{.Names}}' | Where-Object { $_ -eq "openclaw" }
    if ($exists) {
        Write-Step "OpenClaw já existe!" "SKIP"
        Read-Host "Pressione ENTER para continuar"
        return
    }

    Write-Step "Criando volume..." - "INFO"
    docker volume create openclaw_data --silent 2>$null

    Write-Step "Instalando OpenClaw..." - "INFO"

    $domain = Read-Host "Digite o domínio (ex: openclaw.seusite.com) ou ENTER para pular"
    $email = if ($domain) { Read-Host "Digite o email para SSL" }

    docker run -d `
        --name openclaw `
        --restart unless-stopped `
        --network docker_beto `
        -p 3002:3000 `
        -e DATABASE_URL="postgresql://postgres:$($Global:Config.PostgresPassword)@postgres:5432/beto?schema=public" `
        -v openclaw_data:/app/data `
        ghcr.io/christerclock/openclaw:latest

    Start-Sleep -Seconds 10

    $running = docker ps --format '{{.Names}}' | Where-Object { $_ -eq "openclaw" }
    if ($running) {
        Write-Step "OpenClaw instalado!" "OK"
        Write-Host "Acesso: http://localhost:3002" -ForegroundColor Cyan
    } else {
        Write-Step "Verifique os logs com: docker logs openclaw" "ERROR"
    }

    Read-Host "Pressione ENTER para continuar"
}

function Show-Status {
    Show-Banner
    Write-Host "[STATUS DOS SERVIÇOS]" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    $services = @(
        @{Name="Docker"; Check={Test-CommandExists "docker"}}
        @{Name="PostgreSQL"; Check={docker ps --format '{{.Names}}' | Where-Object {$_ -eq "postgres"}}}
        @{Name="Redis"; Check={docker ps --format '{{.Names}}' | Where-Object {$_ -eq "redis"}}}
        @{Name="MinIO"; Check={docker ps --format '{{.Names}}' | Where-Object {$_ -eq "minio"}}}
        @{Name="Nginx Proxy Manager"; Check={docker ps --format '{{.Names}}' | Where-Object {$_ -eq "nginx-proxy-manager"}}}
        @{Name="Portainer"; Check={docker ps --format '{{.Names}}' | Where-Object {$_ -eq "portainer"}}}
        @{Name="Typebot"; Check={docker ps --format '{{.Names}}' | Where-Object {$_ -eq "typebot"}}}
        @{Name="N8N"; Check={docker ps --format '{{.Names}}' | Where-Object {$_ -eq "n8n"}}}
        @{Name="Evolution API"; Check={docker ps --format '{{.Names}}' | Where-Object {$_ -eq "evolution-api"}}}
        @{Name="Wuzapi"; Check={docker ps --format '{{.Names}}' | Where-Object {$_ -eq "wuzapi"}}}
        @{Name="OpenClaw"; Check={docker ps --format '{{.Names}}' | Where-Object {$_ -eq "openclaw"}}}
    )

    foreach ($service in $services) {
        $isRunning = & $service.Check
        $status = if ($isRunning) { "OK" } else { "PARADO" }
        $color = if ($isRunning) { "Green" } else { "Red" }

        Write-Host "$($service.Name): " -NoNewline
        Write-Host $status -ForegroundColor $color
    }

    Write-Host ""
    Read-Host "Pressione ENTER para continuar"
}

function Show-MainMenu {
    Show-Banner
    Write-Host "[MENU PRINCIPAL]" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "--- INFRAESTRUTURA ---" -ForegroundColor Yellow
    Write-Host "1. Instalar Docker" -ForegroundColor Cyan
    Write-Host "2. Instalar PostgreSQL" -ForegroundColor Cyan
    Write-Host "3. Instalar Redis" -ForegroundColor Cyan
    Write-Host "4. Instalar MinIO" -ForegroundColor Cyan
    Write-Host "5. Instalar Nginx Proxy Manager" -ForegroundColor Cyan
    Write-Host "6. Instalar Portainer" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "--- APLICACOS ---" -ForegroundColor Yellow
    Write-Host "7. Instalar Typebot" -ForegroundColor Green
    Write-Host "8. Instalar N8N" -ForegroundColor Green
    Write-Host "9. Instalar Evolution API" -ForegroundColor Green
    Write-Host "10. Instalar Wuzapi" -ForegroundColor Green
    Write-Host "11. Instalar OpenClaw" -ForegroundColor Green
    Write-Host ""

    Write-Host "--- UTILIDADES ---" -ForegroundColor Yellow
    Write-Host "12. Ver Status dos Servicos" -ForegroundColor Magenta
    Write-Host ""

    Write-Host "0. Sair" -ForegroundColor Gray
    Write-Host ""
}

function Main {
    while ($true) {
        Show-MainMenu
        $choice = Read-Host "Escolha uma opcao"

        switch ($choice) {
            "1" { Install-Docker }
            "2" { Install-PostgreSQL }
            "3" { Install-Redis }
            "4" { Install-MinIO }
            "5" { Install-NginxProxyManager }
            "6" { Install-Portainer }
            "7" { Install-Typebot }
            "8" { Install-N8N }
            "9" { Install-EvolutionAPI }
            "10" { Install-Wuzapi }
            "11" { Install-OpenClaw }
            "12" { Show-Status }
            "0" {
                Show-Banner
                Write-Host "Obrigado!" -ForegroundColor Cyan
                exit
            }
            default {
                Write-Host "[ERRO] Opcao invalida!" -ForegroundColor Red
                Start-Sleep -Seconds 2
            }
        }
    }
}

Main
