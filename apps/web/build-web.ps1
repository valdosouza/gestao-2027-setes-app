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
#
# D-PV16 (= Q-PV18 (a), Valdo 2026-10-18): ANTES do build, o catálogo de privilégios do ambiente de DESTINO é conferido contra a
# lista única do setes-api que vai junto (`scripts/check-privilege-catalog.ts` — só leitura, sessão READ ONLY). Alarme = PARA: o
# app publicado com um botão cujo par não está no catálogo esconde o botão até do admin (o C1) — e publicar o app não reinicia o
# setes-api, então o alarme do boot não apareceria. O seed dos pares vai ao banco ANTES do app.
#   -SetesApiDir   pasta do setes-api publicado junto (padrão: ..\..\..\setes-api, o irmão do setes-app)
#   -CatalogEnvFile  .env do ambiente de DESTINO (padrão: o .env do -SetesApiDir — avisado; na Onda 4 informe o do destino).
#                  O .env VENCE as variáveis do shell (DOTENV_CONFIG_OVERRIDE) — DB_* do ambiente nunca desviam a conferência.
#   -CheckOnly     só as conferências (URLs + catálogo + app), sem o build
# Também confere o APP DESTA ÁRVORE contra a lista do setes-api irmão (a cerca da D-PV9 com SETES_APP_DIR = esta árvore): o
# setes-api ao lado tem de ser a versão que vai junto. Ordem da publicação: seed dos pares -> setes-api -> app.
param(
  [string]$ApiUrl = $env:API_URL,
  [string]$NfseApiUrl = $env:NFSE_API_URL,
  [string]$SetesApiDir = (Join-Path $PSScriptRoot '..\..\..\setes-api'),
  [string]$CatalogEnvFile = '',
  [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
# caminhos relativos valem a partir de onde o script foi chamado (resolvidos ANTES de trocar de pasta)
if (-not [string]::IsNullOrWhiteSpace($CatalogEnvFile) -and -not [IO.Path]::IsPathRooted($CatalogEnvFile)) {
  $CatalogEnvFile = Join-Path (Get-Location).Path $CatalogEnvFile
}
if (-not [IO.Path]::IsPathRooted($SetesApiDir)) { $SetesApiDir = Join-Path (Get-Location).Path $SetesApiDir }
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
  # R5-ADV-08: a MESMA regra de host do app (AppConfig.urlProblems) + o que o navegador recusa
  if ($uri.HostNameType -eq [UriHostNameType]::IPv6) {
    if ([Net.IPAddress]::Parse($uri.Host.Trim('[', ']')).Equals([Net.IPAddress]::IPv6Any)) { throw "$name com endereco nao especificado (::): $v" }
  } elseif ($uri.HostNameType -eq [UriHostNameType]::IPv4) {
    if ($uri.Host -eq '0.0.0.0') { throw "$name com endereco nao especificado (0.0.0.0): $v" }
  } else {
    if ($uri.Host -cnotmatch '^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$') { throw "$name com host fora da forma DNS (ponto final, sublinhado...): $v" }
    if ($uri.Host.Split('.')[-1] -match '^(\d+|0x[0-9a-f]*)$') { throw "$name com host que termina em numero e nao e IPv4 valido (o navegador recusa): $v" }
  }
}

Test-ApiUrl 'API_URL' $ApiUrl
Test-ApiUrl 'NFSE_API_URL' $NfseApiUrl

# D-PV16: o catálogo de privilégios do destino cobre a lista única E o app desta árvore só consome pares da lista
# (nunca pula em silêncio — sem o setes-api ao lado, para)
function Test-PrivilegeCatalog([string]$apiDir, [string]$envFile) {
  $script = Join-Path $apiDir 'scripts\check-privilege-catalog.ts'
  if (-not (Test-Path -LiteralPath $script)) { throw "setes-api nao encontrado em $apiDir (scripts\check-privilege-catalog.ts) - informe -SetesApiDir" }
  $usingDefault = [string]::IsNullOrWhiteSpace($envFile)
  $envPath = if ($usingDefault) { Join-Path $apiDir '.env' } else { $envFile }
  if (-not (Test-Path -LiteralPath $envPath)) { throw "arquivo de ambiente do catalogo nao encontrado: $envPath - informe -CatalogEnvFile" }
  $envPath = (Resolve-Path -LiteralPath $envPath).Path
  if ($usingDefault) { Write-Warning "catalogo conferido contra o .env do setes-api irmao ($envPath) - na publicacao para outro ambiente informe -CatalogEnvFile" }
  $appRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
  $saved = @{ path = $env:DOTENV_CONFIG_PATH; override = $env:DOTENV_CONFIG_OVERRIDE; app = $env:SETES_APP_DIR }
  Push-Location $apiDir
  try {
    $env:DOTENV_CONFIG_PATH = $envPath
    $env:DOTENV_CONFIG_OVERRIDE = 'true'
    & npm run --silent check:privileges
    $catalog = $LASTEXITCODE
    $fence = 0
    if ($catalog -eq 0) {
      $env:SETES_APP_DIR = $appRoot
      & npm test --silent -- src/__tests__/privilege-catalog-fence.test.ts
      $fence = $LASTEXITCODE
    }
  } finally {
    Pop-Location
    $env:DOTENV_CONFIG_PATH = $saved.path
    $env:DOTENV_CONFIG_OVERRIDE = $saved.override
    $env:SETES_APP_DIR = $saved.app
  }
  if ($catalog -eq 1) { throw "catalogo de privilegios com ALARME - aplique o seed dos pares no destino ANTES de publicar o app (D-PV16)" }
  if ($catalog -ne 0) { throw "conferencia do catalogo NAO rodou (saida $($catalog): banco inacessivel, .env do destino sem DB_* ou erro de leitura) - a publicacao para" }
  if ($fence -ne 0) { throw "o app desta arvore consome par fora da lista do setes-api irmao (cerca D-PV9, saida $fence) - o setes-api ao lado tem de ser a versao publicada junto" }
}

Test-PrivilegeCatalog $SetesApiDir $CatalogEnvFile
if ($CheckOnly) { Write-Host 'conferencias OK (URLs + catalogo de privilegios + app contra a lista) - build nao executado (-CheckOnly).'; return }

flutter build web --release "--dart-define=API_URL=$($ApiUrl.Trim())" "--dart-define=NFSE_API_URL=$($NfseApiUrl.Trim())"
if ($LASTEXITCODE -ne 0) { throw "flutter build web falhou ($LASTEXITCODE)" }
Write-Host 'build/web pronto - publicar com no-cache em index.html, flutter_bootstrap.js e main.dart.js (D-F147).'
