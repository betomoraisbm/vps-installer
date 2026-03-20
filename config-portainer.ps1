# ============================================
# SCRIPT DE CONFIGURACAO DO PORTAINER
# Docker & Portainer VPS
# ============================================

$ErrorActionPreference = "Continue"

$PortainerConfig = @{
    DataPath = "$env:ProgramData\Portainer"
    Port = "9000"
    SSLEnabled = $false
    Domain = ""
}

function Show-Banner {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "       BETO MORAIS                   " -ForegroundColor Cyan
    Write-Host "    CONFIGURACAO DO PORTAINER          " -ForegroundColor Cyan
    Write-Host "   Docker & Portainer VPS Installer    " -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Test-PortainerRunning {
    $container = docker ps --format "{{{{.Names}}}}" | Where-Object { $_ -eq "portainer" }
    return ($null -ne $container)
}

function Get-PortainerStatus {
    if (Test-PortainerRunning) {
        return "Rodando"
    }
    $existing = docker ps -a --format "{{{{.Names}}}}" | Where-Object { $_ -eq "portainer" }
    if ($existing) {
        return "Parado"
    }
    return "Nao instalado"
}

function Show-PortainerStatus {
    Write-Host "[STATUS DO PORTAINER]" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host "  Status: " -NoNewline
    $status = Get-PortainerStatus
    switch ($status) {
        "Rodando" { Write-Host $status -ForegroundColor Green }
        "Parado" { Write-Host $status -ForegroundColor Yellow }
        "Nao instalado" { Write-Host $status -ForegroundColor Red }
    }

    Write-Host "  Porta: $($PortainerConfig.Port)"
    Write-Host "  SSL: " -NoNewline
    if ($PortainerConfig.SSLEnabled) {
        Write-Host "Habilitado" -ForegroundColor Green
    } else {
        Write-Host "Desabilitado" -ForegroundColor Gray
    }
    Write-Host "  Diretorio de dados: $($PortainerConfig.DataPath)"
    Write-Host "  Dominio: " -NoNewline
    if ($PortainerConfig.Domain) {
        Write-Host $PortainerConfig.Domain -ForegroundColor Green
    } else {
        Write-Host "Nao configurado" -ForegroundColor Gray
    }
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host ""
}

function Install-Portainer {
    Show-Banner
    Write-Host "[INSTALACAO DO PORTAINER]" -ForegroundColor Yellow
    Write-Host ""

    $existing = docker ps -a --format "{{{{.Names}}}}" | Where-Object { $_ -eq "portainer" }
    if ($existing) {
        Write-Host "[INFO] Portainer ja existe. Removendo versao anterior..." -ForegroundColor Yellow
        docker stop portainer --silent 2>$null
        docker rm portainer --force --silent 2>$null
    }

    if (!(Test-Path $PortainerConfig.DataPath)) {
        New-Item -ItemType Directory -Path $PortainerConfig.DataPath -Force | Out-Null
    }

    Write-Host "[INFO] Baixando e instalando Portainer..." -ForegroundColor Yellow

    docker volume create portainer_data --silent 2>$null

    $port = $PortainerConfig.Port
    docker run -d `
        --name portainer `
        --restart unless-stopped `
        -p 8000:8000 `
        -p $port":9000" `
        -v \\.\pipe\docker_engine:\\.\pipe\docker_engine `
        -v portainer_data:/data `
        portainer/portainer-ce:latest

    Start-Sleep -Seconds 5

    if (Test-PortainerRunning) {
        Write-Host "[OK] Portainer instalado com sucesso!" -ForegroundColor Green
        Write-Host "[INFO] Acesse: http://localhost:$port" -ForegroundColor Cyan
        Write-Host "[INFO] Na primeira vez, defina a senha do admin" -ForegroundColor Yellow
        return $true
    }
    else {
        Write-Host "[ERRO] Falha ao iniciar Portainer!" -ForegroundColor Red
        Write-Host "[INFO] Logs do container:" -ForegroundColor Yellow
        docker logs portainer 2>&1 | Select-Object -First 20
        return $false
    }
}

function Start-PortainerService {
    Show-Banner
    Write-Host "[INICIANDO PORTAINER]" -ForegroundColor Yellow
    Write-Host ""

    if (Test-PortainerRunning) {
        Write-Host "[INFO] Portainer ja esta rodando!" -ForegroundColor Green
        return $true
    }

    $existing = docker ps -a --format "{{{{.Names}}}}" | Where-Object { $_ -eq "portainer" }
    if (-not $existing) {
        Write-Host "[ERRO] Portainer nao esta instalado!" -ForegroundColor Red
        return $false
    }

    Write-Host "[INFO] Iniciando container..." -ForegroundColor Yellow
    docker start portainer

    Start-Sleep -Seconds 3

    if (Test-PortainerRunning) {
        Write-Host "[OK] Portainer iniciado!" -ForegroundColor Green
        Write-Host "[INFO] Acesse: http://localhost:$($PortainerConfig.Port)" -ForegroundColor Cyan
        return $true
    }
    else {
        Write-Host "[ERRO] Falha ao iniciar Portainer!" -ForegroundColor Red
        return $false
    }
}

function Stop-PortainerService {
    Show-Banner
    Write-Host "[PARANDO PORTAINER]" -ForegroundColor Yellow
    Write-Host ""

    if (-not (Test-PortainerRunning)) {
        Write-Host "[INFO] Portainer ja esta parado!" -ForegroundColor Yellow
        return $true
    }

    Write-Host "[INFO] Parando container..." -ForegroundColor Yellow
    docker stop portainer

    Start-Sleep -Seconds 3

    if (-not (Test-PortainerRunning)) {
        Write-Host "[OK] Portainer parado!" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "[ERRO] Falha ao parar Portainer!" -ForegroundColor Red
        return $false
    }
}

function Restart-PortainerService {
    Show-Banner
    Write-Host "[REINICIANDO PORTAINER]" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "[INFO] Reiniciando container..." -ForegroundColor Yellow
    docker restart portainer

    Start-Sleep -Seconds 5

    if (Test-PortainerRunning) {
        Write-Host "[OK] Portainer reiniciado!" -ForegroundColor Green
        Write-Host "[INFO] Acesse: http://localhost:$($PortainerConfig.Port)" -ForegroundColor Cyan
        return $true
    }
    else {
        Write-Host "[ERRO] Falha ao reiniciar Portainer!" -ForegroundColor Red
        return $false
    }
}

function Update-Portainer {
    Show-Banner
    Write-Host "[ATUALIZANDO PORTAINER]" -ForegroundColor Yellow
    Write-Host ""

    if (-not (Test-PortainerRunning)) {
        Write-Host "[INFO] Portainer esta parado. Iniciando atualizacao..." -ForegroundColor Yellow
    }

    $wasRunning = Test-PortainerRunning

    if ($wasRunning) {
        Write-Host "[INFO] Parando Portainer..." -ForegroundColor Yellow
        docker stop portainer
    }

    Write-Host "[INFO] Baixando nova versao..." -ForegroundColor Yellow
    docker pull portainer/portainer-ce:latest

    if ($wasRunning) {
        Write-Host "[INFO] Iniciando nova versao..." -ForegroundColor Yellow
        docker start portainer

        Start-Sleep -Seconds 5

        if (Test-PortainerRunning) {
            Write-Host "[OK] Portainer atualizado com sucesso!" -ForegroundColor Green
            return $true
        }
    }

    Write-Host "[OK] Atualizacao concluida!" -ForegroundColor Green
    return $true
}

function Remove-Portainer {
    Show-Banner
    Write-Host "[REMOCAO DO PORTAINER]" -ForegroundColor Red
    Write-Host ""
    Write-Host "ATENCAO: Isso ira remover o container e TODOS os dados!" -ForegroundColor Red
    Write-Host ""

    $confirm = Read-Host "Tem certeza? (SIM para confirmar)"
    if ($confirm -ne "SIM") {
        Write-Host "[INFO] Operacao cancelada!" -ForegroundColor Yellow
        return $false
    }

    Show-Banner
    Write-Host "[INFO] Removendo Portainer..." -ForegroundColor Yellow

    if (Test-PortainerRunning) {
        docker stop portainer
    }

    docker rm portainer --force 2>$null
    docker volume rm portainer_data 2>$null

    Write-Host "[OK] Portainer removido!" -ForegroundColor Green
    return $true
}

function Backup-PortainerData {
    Show-Banner
    Write-Host "[BACKUP DOS DADOS]" -ForegroundColor Yellow
    Write-Host ""

    $backupDir = Read-Host "Diretorio para salvar o backup"
    if (-not $backupDir) {
        $backupDir = "$env:USERPROFILE\Desktop"
    }

    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = "$backupDir\portainer_backup_$timestamp.tar"

    Write-Host "[INFO] Criando backup..." -ForegroundColor Yellow

    try {
        docker run --rm `
            -v portainer_data:/data `
            -v "$backupDir`:/backup" `
            alpine tar -cvf /backup/portainer_backup_$timestamp.tar -C /data .

        if (Test-Path $backupFile) {
            Write-Host "[OK] Backup criado: $backupFile" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "[ERRO] Falha ao criar backup!" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "[ERRO] Falha ao criar backup: $_" -ForegroundColor Red
        return $false
    }
}

function Restore-PortainerData {
    Show-Banner
    Write-Host "[RESTAURACAO DOS DADOS]" -ForegroundColor Yellow
    Write-Host ""

    $backupFile = Read-Host "Caminho do arquivo de backup"
    if (-not $backupFile) {
        Write-Host "[ERRO] Caminho do backup e obrigatorio!" -ForegroundColor Red
        return $false
    }

    if (-not (Test-Path $backupFile)) {
        Write-Host "[ERRO] Arquivo de backup nao encontrado!" -ForegroundColor Red
        return $false
    }

    Write-Host "[INFO] Restaurando dados..." -ForegroundColor Yellow

    try {
        $wasRunning = Test-PortainerRunning
        if ($wasRunning) {
            docker stop portainer
        }

        docker volume rm portainer_data 2>$null
        docker volume create portainer_data 2>$null

        docker run --rm `
            -v portainer_data:/data `
            -v "$((Split-Path $backupFile -Parent).Replace('\','/'))`:/backup" `
            alpine tar -xvf "/backup/$(Split-Path $backupFile -Leaf)" -C /data

        if ($wasRunning) {
            docker start portainer
        }

        Write-Host "[OK] Dados restaurados com sucesso!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "[ERRO] Falha ao restaurar dados: $_" -ForegroundColor Red
        return $false
    }
}

function Show-Menu {
    Show-Banner
    Show-PortainerStatus

    Write-Host "[MENU DE OPCAO]" -ForegroundColor Cyan
    Write-Host "1. Instalar Portainer" -ForegroundColor Yellow
    Write-Host "2. Iniciar Portainer" -ForegroundColor Green
    Write-Host "3. Parar Portainer" -ForegroundColor Red
    Write-Host "4. Reiniciar Portainer" -ForegroundColor Yellow
    Write-Host "5. Atualizar Portainer" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "6. Criar backup" -ForegroundColor Magenta
    Write-Host "7. Restaurar backup" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "8. Remover Portainer" -ForegroundColor Red
    Write-Host "0. Sair" -ForegroundColor Gray
    Write-Host ""
}

function Main {
    while ($true) {
        Show-Menu
        $choice = Read-Host "Escolha uma opcao"

        switch ($choice) {
            "1" {
                $result = Install-Portainer
                if ($result) {
                    Write-Host ""
                    Read-Host "Pressione ENTER para continuar"
                }
            }
            "2" {
                $result = Start-PortainerService
                Write-Host ""
                Read-Host "Pressione ENTER para continuar"
            }
            "3" {
                $result = Stop-PortainerService
                Write-Host ""
                Read-Host "Pressione ENTER para continuar"
            }
            "4" {
                $result = Restart-PortainerService
                Write-Host ""
                Read-Host "Pressione ENTER para continuar"
            }
            "5" {
                $result = Update-Portainer
                Write-Host ""
                Read-Host "Pressione ENTER para continuar"
            }
            "6" {
                $result = Backup-PortainerData
                Write-Host ""
                Read-Host "Pressione ENTER para continuar"
            }
            "7" {
                $result = Restore-PortainerData
                Write-Host ""
                Read-Host "Pressione ENTER para continuar"
            }
            "8" {
                $result = Remove-Portainer
                Write-Host ""
                Read-Host "Pressione ENTER para continuar"
            }
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
