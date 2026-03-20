# ============================================
# INSTALADOR COMPLETO PARA PRODUÇÃO
# BETO MORAIS
# ============================================

$ErrorActionPreference = "Continue"

$Global:DomainConfig = @{
    Domain = ""
    Email = ""
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

function Install-Docker {
    Show-Banner
    Write-Host "[PASSO 1/6] Instalando Docker..." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    if (Test-CommandExists "docker") {
        Write-Step "Docker ja esta instalado" "SKIP"
        docker --version
        return $true
    }

    Write-Step "Baixando e instalando Docker..."

    try {
        $dockerInstallScript = @"
Start-Process -FilePath "powershell" -ArgumentList "-Command `"Invoke-WebRequest -Uri 'https://get.docker.com' -OutFile 'docker-install.ps1'; & ./docker-install.ps1; Remove-Item docker-install.ps1 -Force`'" -Wait -NoNewWindow
"@

        $tempScript = "$env:TEMP\docker_install_$(Get-Random).ps1"
        $dockerInstallScript | Out-File -FilePath $tempScript -Encoding UTF8

        $waitScript = @"
Invoke-WebRequest -Uri 'https://get.docker.com' -OutFile 'docker-install.ps1' -UseBasicParsing
Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -File docker-install.ps1' -Wait
Remove-Item docker-install.ps1 -Force -ErrorAction SilentlyContinue
"@

        $waitScript | Out-File -FilePath "$env:TEMP\docker_install_wait.ps1" -Encoding UTF8

        Write-Step "Aguarde... instalacao pode levar alguns minutos"
        & "$env:TEMP\docker_install_wait.ps1"

        Start-Sleep -Seconds 5

        if (Test-CommandExists "docker") {
            Write-Step "Docker instalado com sucesso" "OK"
            return $true
        }

        $msiPath = "$env:TEMP\docker-desktop-installer.exe"
        Invoke-WebRequest -Uri "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe" -OutFile $msiPath -UseBasicParsing
        Start-Process $msiPath -Wait
        Remove-Item $msiPath -Force -ErrorAction SilentlyContinue

        Start-Sleep -Seconds 10

        if (Test-CommandExists "docker") {
            Write-Step "Docker Desktop instalado com sucesso" "OK"
            return $true
        }

        Write-Step "Falha ao instalar Docker" "ERROR"
        return $false
    }
    catch {
        Write-Step "Erro: $_" "ERROR"
        return $false
    }
}

function Install-PostgreSQL {
    Show-Banner
    Write-Host "[PASSO 2/6] Instalando PostgreSQL..." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    $containerName = "postgres_db"

    $existing = docker ps -a --format '{{.Names}}' | Where-Object { $_ -eq $containerName }
    if ($existing) {
        Write-Step "PostgreSQL ja esta instalado" "SKIP"
        return $true
    }

    Write-Step "Criando container PostgreSQL..."

    $postgresPassword = "PgSecure@2024!"

    docker volume create postgres_data --silent 2>$null

    docker run -d `
        --name $containerName `
        --restart unless-stopped `
        -e POSTGRES_PASSWORD=$postgresPassword `
        -e POSTGRES_USER=admin `
        -e POSTGRES_DB=production `
        -v postgres_data:/var/lib/postgresql/data `
        -p 5432:5432 `
        postgres:latest

    Start-Sleep -Seconds 5

    $running = docker ps --format '{{.Names}}' | Where-Object { $_ -eq $containerName }
    if ($running) {
        Write-Step "PostgreSQL instalado com sucesso" "OK"
        Write-Step "Host: localhost:5432" "INFO"
        Write-Step "Usuario: admin / Senha: $postgresPassword" "INFO"
        return $true
    }

    Write-Step "Falha ao instalar PostgreSQL" "ERROR"
    return $false
}

function Install-Redis {
    Show-Banner
    Write-Host "[PASSO 3/6] Instalando Redis..." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    $containerName = "redis_cache"

    $existing = docker ps -a --format '{{.Names}}' | Where-Object { $_ -eq $containerName }
    if ($existing) {
        Write-Step "Redis ja esta instalado" "SKIP"
        return $true
    }

    Write-Step "Criando container Redis..."

    docker run -d `
        --name $containerName `
        --restart unless-stopped `
        -p 6379:6379 `
        -v redis_data:/data `
        redis:latest redis --appendonly yes

    Start-Sleep -Seconds 5

    $running = docker ps --format '{{.Names}}' | Where-Object { $_ -eq $containerName }
    if ($running) {
        Write-Step "Redis instalado com sucesso" "OK"
        Write-Step "Host: localhost:6379" "INFO"
        return $true
    }

    Write-Step "Falha ao instalar Redis" "ERROR"
    return $false
}

function Install-MinIO {
    Show-Banner
    Write-Host "[PASSO 4/6] Instalando MinIO..." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    $containerName = "minio_storage"

    $existing = docker ps -a --format '{{.Names}}' | Where-Object { $_ -eq $containerName }
    if ($existing) {
        Write-Step "MinIO ja esta instalado" "SKIP"
        return $true
    }

    Write-Step "Criando container MinIO..."

    docker volume create minio_data --silent 2>$null

    docker run -d `
        --name $containerName `
        --restart unless-stopped `
        -p 9000:9000 `
        -p 9001:9001 `
        -e MINIO_ROOT_USER=admin `
        -e MINIO_ROOT_PASSWORD="MinioSecure@2024!" `
        -v minio_data:/data `
        minio/minio:latest server /data --console-address ":9001"

    Start-Sleep -Seconds 5

    $running = docker ps --format '{{.Names}}' | Where-Object { $_ -eq $containerName }
    if ($running) {
        Write-Step "MinIO instalado com sucesso" "OK"
        Write-Step "API: http://localhost:9000" "INFO"
        Write-Step "Console: http://localhost:9001" "INFO"
        Write-Step "Usuario: admin / Senha: MinioSecure@2024!" "INFO"
        return $true
    }

    Write-Step "Falha ao instalar MinIO" "ERROR"
    return $false
}

function Install-NginxProxyManager {
    Show-Banner
    Write-Host "[PASSO 5/6] Instalando Nginx Proxy Manager..." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    $containerName = "nginx-proxy-manager"

    $existing = docker ps -a --format '{{.Names}}' | Where-Object { $_ -eq $containerName }
    if ($existing) {
        Write-Step "Nginx Proxy Manager ja esta instalado" "SKIP"
        return $true
    }

    Write-Step "Criando container Nginx Proxy Manager..."

    docker volume create nginx_proxy_data --silent 2>$null
    docker volume create nginx_proxy_letsencrypt --silent 2>$null

    docker run -d `
        --name $containerName `
        --restart unless-stopped `
        -p 80:80 `
        -p 443:443 `
        -p 81:81 `
        -v nginx_proxy_data:/data `
        -v nginx_proxy_letsencrypt:/etc/letsencrypt `
        jc21/nginx-proxy-manager:latest

    Start-Sleep -Seconds 10

    $running = docker ps --format '{{.Names}}' | Where-Object { $_ -eq $containerName }
    if ($running) {
        Write-Step "Nginx Proxy Manager instalado com sucesso" "OK"
        Write-Step "Admin UI: http://localhost:81" "INFO"
        Write-Step "Usuario: admin@example.com / Senha: changeme" "INFO"
        return $true
    }

    Write-Step "Falha ao instalar Nginx Proxy Manager" "ERROR"
    return $false
}

function Install-Portainer {
    Show-Banner
    Write-Host "[PASSO 6/6] Instalando Portainer..." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    $containerName = "portainer"

    $existing = docker ps -a --format '{{.Names}}' | Where-Object { $_ -eq $containerName }
    if ($existing) {
        Write-Step "Portainer ja esta instalado" "SKIP"
        return $true
    }

    Write-Step "Criando container Portainer..."

    docker volume create portainer_data --silent 2>$null

    docker run -d `
        --name $containerName `
        --restart unless-stopped `
        -p 8000:8000 `
        -p 9000:9000 `
        -v \\.\pipe\docker_engine:\\.\pipe\docker_engine `
        -v portainer_data:/data `
        portainer/portainer-ce:latest

    Start-Sleep -Seconds 5

    $running = docker ps --format '{{.Names}}' | Where-Object { $_ -eq $containerName }
    if ($running) {
        Write-Step "Portainer instalado com sucesso" "OK"
        Write-Step "URL: http://localhost:9000" "INFO"
        return $true
    }

    Write-Step "Falha ao instalar Portainer" "ERROR"
    return $false
}

function Install-All {
    Show-Banner
    Write-Host "[INSTALACAO COMPLETA]" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Este processo vai instalar:" -ForegroundColor Yellow
    Write-Host "  - Docker" -ForegroundColor Gray
    Write-Host "  - PostgreSQL" -ForegroundColor Gray
    Write-Host "  - Redis" -ForegroundColor Gray
    Write-Host "  - MinIO" -ForegroundColor Gray
    Write-Host "  - Nginx Proxy Manager" -ForegroundColor Gray
    Write-Host "  - Portainer" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Tempo estimado: 10-30 minutos" -ForegroundColor Yellow
    Write-Host ""

    $confirm = Read-Host "Pressione ENTER para continuar ou Ctrl+C para cancelar"

    Write-Step "Iniciando instalacao..." "INFO"

    $result = Install-Docker
    if (!$result) {
        Write-Step "ERRO: Falha na instalacao do Docker" "ERROR"
        Read-Host "Pressione ENTER para continuar"
        return
    }

    $result = Install-PostgreSQL
    if (!$result) {
        Write-Step "ERRO: Falha na instalacao do PostgreSQL" "ERROR"
        Read-Host "Pressione ENTER para continuar"
        return
    }

    $result = Install-Redis
    if (!$result) {
        Write-Step "ERRO: Falha na instalacao do Redis" "ERROR"
        Read-Host "Pressione ENTER para continuar"
        return
    }

    $result = Install-MinIO
    if (!$result) {
        Write-Step "ERRO: Falha na instalacao do MinIO" "ERROR"
        Read-Host "Pressione ENTER para continuar"
        return
    }

    $result = Install-NginxProxyManager
    if (!$result) {
        Write-Step "ERRO: Falha na instalacao do Nginx Proxy Manager" "ERROR"
        Read-Host "Pressione ENTER para continuar"
        return
    }

    $result = Install-Portainer
    if (!$result) {
        Write-Step "ERRO: Falha na instalacao do Portainer" "ERROR"
        Read-Host "Pressione ENTER para continuar"
        return
    }

    Show-Banner
    Write-Host ""
    Write-Host "[SUCESSO!] Instalacao completa!" -ForegroundColor Green
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "ACESSOS:" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Portainer:     http://localhost:9000" -ForegroundColor Yellow
    Write-Host "Nginx PM:      http://localhost:81" -ForegroundColor Yellow
    Write-Host "MinIO Console: http://localhost:9001" -ForegroundColor Yellow
    Write-Host "PostgreSQL:    localhost:5432" -ForegroundColor Yellow
    Write-Host "Redis:         localhost:6379" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "PROXIMOS PASSOS:" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Altere as senhas padrao!" -ForegroundColor Red
    Write-Host "2. Configure o Nginx Proxy Manager" -ForegroundColor Yellow
    Write-Host "3. Instale seus apps (scripts separados)" -ForegroundColor Yellow
    Write-Host ""

    Read-Host "Pressione ENTER para continuar"
}

function Show-Status {
    Show-Banner
    Write-Host "[STATUS] Servicos Instalados" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    $services = @(
        @{Name="Docker"; Check={Test-CommandExists "docker"}},
        @{Name="PostgreSQL"; Check={docker ps --format '{{.Names}}' | Where-Object {$_ -eq "postgres_db"}}},
        @{Name="Redis"; Check={docker ps --format '{{.Names}}' | Where-Object {$_ -eq "redis_cache"}}},
        @{Name="MinIO"; Check={docker ps --format '{{.Names}}' | Where-Object {$_ -eq "minio_storage"}}},
        @{Name="Nginx Proxy Manager"; Check={docker ps --format '{{.Names}}' | Where-Object {$_ -eq "nginx-proxy-manager"}}},
        @{Name="Portainer"; Check={docker ps --format '{{.Names}}' | Where-Object {$_ -eq "portainer"}}}
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
    Write-Host "1. Instalar toda a estrutura base" -ForegroundColor Yellow
    Write-Host "   (Docker + PostgreSQL + Redis + MinIO + NPM + Portainer)"
    Write-Host ""
    Write-Host "2. Ver status dos servicos" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "0. Sair" -ForegroundColor Gray
    Write-Host ""
}

function Main {
    while ($true) {
        Show-MainMenu
        $choice = Read-Host "Escolha uma opcao"

        switch ($choice) {
            "1" { Install-All }
            "2" { Show-Status }
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
