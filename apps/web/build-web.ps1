# Build de PUBLICAÇÃO do setes-app web (Plesk) — D-F146/D-F147 + gate socrático da F2b (F2B-SOC-09).
# O build sem as URLs das APIs do produto NÃO pode ser gerado: o app abriria só a tela de erro de
# configuração DEPOIS do upload (nenhum usuário entraria no ERP). Este script recusa ANTES.
#
# Uso (na pasta apps/web):
#   .\build-web.ps1 -ApiUrl https://api.exemplo.com.br -NfseApiUrl https://nfse.exemplo.com.br
#   (ou defina API_URL e NFSE_API_URL no ambiente)
# Depois do build: publicar `build/web` com `Cache-Control: no-cache` em index.html,
# flutter_bootstrap.js e main.dart.js (D-F147) e avisar os usuários para recarregar.
param(
  [string]$ApiUrl = $env:API_URL,
  [string]$NfseApiUrl = $env:NFSE_API_URL
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Test-ApiUrl([string]$name, [string]$value) {
  if ([string]::IsNullOrWhiteSpace($value)) { throw "$name vazia — informe -$($name -replace '_','') ou a variável de ambiente $name" }
  $uri = $null
  if (-not [Uri]::TryCreate($value.Trim(), [UriKind]::Absolute, [ref]$uri) -or ($uri.Scheme -ne 'https' -and $uri.Scheme -ne 'http') -or [string]::IsNullOrEmpty($uri.Host)) {
    throw "$name não é uma URL http/https com host: $value"
  }
  if ($uri.Scheme -eq 'http' -and $uri.Host -ne 'localhost' -and $uri.Host -ne '127.0.0.1') {
    throw "$name com http:// fora de localhost — a publicação usa https://: $value"
  }
}

Test-ApiUrl 'API_URL' $ApiUrl
Test-ApiUrl 'NFSE_API_URL' $NfseApiUrl

flutter build web --release "--dart-define=API_URL=$($ApiUrl.Trim())" "--dart-define=NFSE_API_URL=$($NfseApiUrl.Trim())"
if ($LASTEXITCODE -ne 0) { throw "flutter build web falhou ($LASTEXITCODE)" }
Write-Host 'build/web pronto — publicar com no-cache em index.html, flutter_bootstrap.js e main.dart.js (D-F147).'
