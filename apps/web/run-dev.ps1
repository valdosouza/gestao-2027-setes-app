# Dev server do setes-app web — porta e URL da API vêm do .env desta pasta.
# Uso: .\run-dev.ps1   (crie o .env a partir do .env.example se não existir)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not (Test-Path '.env')) {
  Write-Error 'Arquivo .env não encontrado — copie o .env.example para .env e ajuste.'
}

$webPort = $null
foreach ($line in Get-Content '.env') {
  if ($line -match '^\s*WEB_PORT\s*=\s*(\d+)\s*$') { $webPort = $Matches[1] }
}
if ($null -eq $webPort) {
  Write-Error 'WEB_PORT não definido no .env'
}

# API_URL (e demais defines) entram via --dart-define-from-file — o Flutter
# lê o formato .env diretamente; AppConfig.baseApiUrl consome API_URL.
flutter run -d web-server --web-port $webPort --dart-define-from-file=.env
