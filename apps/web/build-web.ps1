# Build de PUBLICAÇÃO do setes-app web (Plesk) — D-F146/D-F147 + gates da F2b (F2B-SOC-09, F2B-RG-01/RG-02).
# O build sem as URLs das APIs do produto (ou com uma URL que o app recusaria na abertura) NÃO pode ser gerado: o app
# abriria só a tela de erro de configuração DEPOIS do upload (nenhum usuário entraria no ERP). Este script recusa ANTES,
# com a MESMA regra do app (AppConfig.urlProblems) e, por ser PUBLICAÇÃO, sem loopback: https, host de verdade, sem
# credenciais, porta em 1–65535, sem consulta nem fragmento. (Arquivo com BOM: o Windows PowerShell 5.1 lê .ps1 sem BOM
# pela página ANSI e os acentos quebrariam o parse.)
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
  if ([string]::IsNullOrWhiteSpace($value)) { throw "$name vazia - informe o parametro ou a variavel de ambiente $name" }
  $v = $value.Trim()
  $uri = $null
  if (-not [Uri]::TryCreate($v, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https' -or [string]::IsNullOrEmpty($uri.Host)) {
    throw "$name tem de ser uma URL https com host (publicacao): $v"
  }
  if ($uri.IsLoopback -or $uri.Host -eq 'localhost') { throw "$name aponta para loopback (o localhost de cada usuario) - publicacao exige o host da API: $v" }
  if (-not [string]::IsNullOrEmpty($uri.UserInfo)) { throw "$name com credenciais na URL: $v" }
  if (-not [string]::IsNullOrEmpty($uri.Query) -or -not [string]::IsNullOrEmpty($uri.Fragment)) { throw "$name com consulta ou fragmento (o app recusa): $v" }
  if ($uri.Port -lt 1 -or $uri.Port -gt 65535) { throw "$name com porta fora de 1-65535: $v" }
}

Test-ApiUrl 'API_URL' $ApiUrl
Test-ApiUrl 'NFSE_API_URL' $NfseApiUrl

flutter build web --release "--dart-define=API_URL=$($ApiUrl.Trim())" "--dart-define=NFSE_API_URL=$($NfseApiUrl.Trim())"
if ($LASTEXITCODE -ne 0) { throw "flutter build web falhou ($LASTEXITCODE)" }
Write-Host 'build/web pronto - publicar com no-cache em index.html, flutter_bootstrap.js e main.dart.js (D-F147).'
