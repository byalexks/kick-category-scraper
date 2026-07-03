param(
    [string]$Category = "League of Legends",
    [string]$Language = "es",
    [switch]$Setup,
    [switch]$UpdateFollowers
)

$baseDir = "C:\projets\research\kick-lol"
$catSlug = $Category -replace '[^a-zA-Z0-9]', '-' -replace '-+', '-' -replace '^-|-$', ''
$langSlug = $Language -replace '[^a-zA-Z0-9]', '_'
$dataFile = "$baseDir\streamers-$catSlug-$langSlug.json"
$outputFile = "$baseDir\streamers-$catSlug-$langSlug.md"
$credFile = "$baseDir\.kick-credentials.json"

# Lenguajes a detectar (separados por coma: "es,en,pt")
$targetLangs = $Language -split ',' | ForEach-Object { $_.Trim().ToLower() }
$langLabel = ($targetLangs -join '/').ToUpper()

# keywords por idioma
$langKeywords = @{
    es = @{
        title = '\b(español|spanish|castellano|latino|habla|en\s+vivo|desde\s+cero|reto|subir|bronce|plata|oro|esmeralda|diamante|maestro|retador|soloq|directo|argentina|mexico|colombia|chile|peru|venezuela|charla|viciando|parcha|parchate|estoy|jugando|jugar|vamos|amigos|jaja|juego|xd)\b'
        bio = '\b(español|spanish|castellano|latino|habla|ESpañol)\b'
    }
    pt = @{
        title = '\b(português|portuguese|brasil|brasileiro|jogando|jogo|jogar|rumo|ranqueada|conversinha|ao\s+vivo|desafiante|maestria|inscreva|mestre|directo|tudo|gratis|inscrever|canal|stream)\b'
        bio = '\b(português|portuguese|brasil|brasileiro)\b'
    }
    en = @{
        title = '\b(english\s*(only|speaking|stream)|speak\s*english|native\s*english)\b'
        bio = '\b(english|eng|\busa\b|\buk\b)\b'
    }
}
$excludePt = $targetLangs -notcontains 'pt'

if ($Setup) {
    $id = Read-Host "Client ID"
    $secret = Read-Host "Client Secret" -AsSecureString
    $s = (New-Object PSCredential "u", $secret).GetNetworkCredential().Password
    @{client_id = $id; client_secret = $s} | ConvertTo-Json | Set-Content $credFile
    Write-Host "Guardado en $credFile" -ForegroundColor Green
    exit 0
}

$CLIENT_ID = ""
$CLIENT_SECRET = ""
if (-not $CLIENT_ID) { $CLIENT_ID = [Environment]::GetEnvironmentVariable("KICK_CLIENT_ID") }
if (-not $CLIENT_SECRET) { $CLIENT_SECRET = [Environment]::GetEnvironmentVariable("KICK_CLIENT_SECRET") }
if (-not $CLIENT_ID -and (Test-Path $credFile)) {
    $c = Get-Content -Raw $credFile | ConvertFrom-Json
    $CLIENT_ID = $c.client_id; $CLIENT_SECRET = $c.client_secret
}
if (-not $CLIENT_ID) {
    Write-Host "Necesitas Client ID y Secret de Kick Dev"
    Write-Host "1. Ve a https://dev.kick.com y crea una App"
    Write-Host "2. Luego ejecuta: .\kick-lol-es.ps1 -Setup"
    exit 1
}

function Get-KickToken {
    param($id, $secret)
    try {
        $r = Invoke-RestMethod -Uri "https://id.kick.com/oauth/token" -Method Post `
            -Body @{grant_type = "client_credentials"; client_id = $id; client_secret = $secret} `
            -ContentType "application/x-www-form-urlencoded"
        return $r.access_token
    } catch { Write-Host "  Token error: $_" -ForegroundColor Red; return $null }
}

function Invoke-KickApi {
    param($url, $token)
    try { return Invoke-RestMethod -Uri $url -Headers @{Authorization = "Bearer $token"} -Method Get }
    catch { return $null }
}

function Get-ChannelDescriptions {
    param($slugs, $token)
    $result = @{}
    if (-not $slugs -or $slugs.Count -eq 0) { return $result }
    $batchSize = 45
    for ($i = 0; $i -lt $slugs.Count; $i += $batchSize) {
        $batch = $slugs[$i..[Math]::Min($i+$batchSize-1, $slugs.Count-1)]
        $q = ($batch | ForEach-Object { "slug=$_" }) -join "&"
        try {
            $ch = Invoke-KickApi "https://api.kick.com/public/v1/channels?$q" $token
            if ($ch -and $ch.data) {
                foreach ($c in $ch.data) {
                    if ($c.channel_description) { $result[$c.slug] = $c.channel_description }
                }
            }
        } catch { }
    }
    return $result
}

function Test-Idioma {
    param($title, $bio, $langCode)
    foreach ($lang in $targetLangs) {
        if ($langCode -eq $lang) { return $true }
        $kw = $langKeywords[$lang]
        if (-not $kw) { continue }
        if ($title -match $kw.title) { return $true }
        if ($bio -and $bio -match $kw.bio) { return $true }
    }
    return $false
}

Write-Host "=== Kick $langLabel Streamers [$Category] ===" -ForegroundColor Cyan
$token = Get-KickToken $CLIENT_ID $CLIENT_SECRET
if (-not $token) { exit 1 }
Write-Host "  Token OK" -ForegroundColor Green

Write-Host "Categoria $Category..." -ForegroundColor Gray
$catEncoded = [uri]::EscapeDataString($Category)
$cats = Invoke-KickApi "https://api.kick.com/public/v2/categories?name=$catEncoded&limit=5" $token
$catObj = $null
if ($cats -and $cats.data) { foreach ($c in $cats.data) { if ($c.name -eq $Category) { $catObj = $c; break } } }
if (-not $catObj) { Write-Host "  No encontrada" -ForegroundColor Red; exit 1 }
Write-Host "  ID: $($catObj.id)" -ForegroundColor Green

$db = @(); $knownSlugs = @{}
if (Test-Path $dataFile) {
    $db = Get-Content -Raw $dataFile | ConvertFrom-Json
    foreach ($e in $db) { $knownSlugs[$e.slug] = $true }
    Write-Host "  DB: $($db.Count) canales" -ForegroundColor Gray
}

# Obtener TODOS los streams (sin filtro idioma), con paginacion
Write-Host "Streams $Category en vivo..." -ForegroundColor Gray
$allLiveStreams = @()
$cursor = $null
do {
    $url = "https://api.kick.com/public/v2/livestreams?category_id=$($catObj.id)&limit=500"
    if ($cursor) { $url += "&cursor=$cursor" }
    $page = Invoke-KickApi $url $token
    if ($page -and $page.data) {
        $allLiveStreams += $page.data
        $cursor = $page.pagination.next_cursor
        Write-Host "  Pagina: $($allLiveStreams.Count) streams (cursor: $cursor)" -ForegroundColor DarkGray
    } else { $cursor = $null }
} while ($cursor)

Write-Host "  Total streams: $($allLiveStreams.Count)" -ForegroundColor Green

$newChannels = @()
$candidates = @()
foreach ($s in $allLiveStreams) {
    $slug = $s.channel.slug
    $title = $s.title
    $lang = $s.language_code
    $viewers = $s.viewer_count
    $username = $s.broadcaster_user.username

    if ($knownSlugs.ContainsKey($slug)) { continue }

    # Primera pasada: detectar por lang y title (sin bio)
    if ($excludePt -and $lang -eq "pt") { continue }
    if ($targetLangs -contains $lang) { $candidates += $s; continue }
    if ($title -match $langKeywords.es.title) { $candidates += $s; continue }
    if ($excludePt -and ($title -match $langKeywords.pt.title)) { continue }
    # (otros idiomas se evaluan en segunda pasada con bio)

    # Guardar para segunda pasada con bio
    $candidates += $s
}

# Segunda pasada: obtener bio por lote para los que no se detectaron solo con titulo
$needBio = $candidates | Where-Object { -not ($targetLangs -contains $_.language_code) -and $_.title -notmatch $langKeywords.es.title }
$bioMap = Get-ChannelDescriptions ($needBio | ForEach-Object { $_.channel.slug }) $token

foreach ($s in $candidates) {
    $slug = $s.channel.slug
    $title = $s.title
    $lang = $s.language_code
    $viewers = $s.viewer_count
    $username = $s.broadcaster_user.username

    if ($knownSlugs.ContainsKey($slug)) { continue }

    $bio = if ($bioMap.ContainsKey($slug)) { $bioMap[$slug] } else { "" }
    if (-not (Test-Idioma $title $bio $lang)) { continue }

    $knownSlugs[$slug] = $true

    $entry = @{
        slug = $slug
        channel = $username
        title = $title
        language = $lang
        viewers = $viewers
        followers = $null
        url = "https://kick.com/$slug"
        addedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }
    $newChannels += $entry
    Write-Host "  [+] $username ($viewers v) - $title" -ForegroundColor Green
}

# Obtener seguidores via cloudscraper para canales nuevos
if ($newChannels.Count -gt 0) {
    Write-Host "Followers via cloudscraper..." -ForegroundColor Gray
    $newSlugs = $newChannels | ForEach-Object { $_.slug }
    $pythonScript = Join-Path $baseDir "get_followers.py"
    $jsonOut = python $pythonScript @newSlugs 2>&1
    $followersMap = $jsonOut | ConvertFrom-Json
    if ($followersMap) {
        foreach ($ch in $newChannels) {
            $f = $followersMap.$($ch.slug)
            if ($f -ne $null) { $ch.followers = [int]$f }
        }
    }
}

# Actualizar seguidores de canales existentes via cloudscraper
if ($UpdateFollowers) {
    Write-Host "Actualizando seguidores de canales existentes..." -ForegroundColor Gray
    $stale = $db | Where-Object { $_.followers -eq $null -or $_.followers -eq 0 }
    if ($stale.Count -gt 0) {
        $staleSlugs = $stale | ForEach-Object { $_.slug }
        $jsonOut = python $pythonScript @staleSlugs 2>&1
        $followersMap = $jsonOut | ConvertFrom-Json
        if ($followersMap) {
            $updated = 0
            foreach ($ch in $db) {
                $f = $followersMap.$($ch.slug)
                if ($f -ne $null) { $ch.followers = [int]$f; $updated++ }
            }
            Write-Host "  Seguidores actualizados: $updated" -ForegroundColor DarkGray
        }
    }
}

$allChannels = @($db; $newChannels)
$allChannels | ConvertTo-Json -Depth 5 | Set-Content $dataFile
Write-Host " DB: $($allChannels.Count) canales" -ForegroundColor Cyan

# MD Report
$report = "# Streamers $Category ($langLabel) - Kick"
$report += "`n> $(Get-Date -Format 'yyyy-MM-dd HH:mm') | Total: $($allChannels.Count)`n"
$report += "`n## Canales"
$report += "`n| # | Canal | Viewers | Seguidores | Stream Title | URL |"
$report += "`n|---|-------|---------|-----------|-------------|-----|"
$i = 1
foreach ($ch in $allChannels) {
    $f = if ($ch.followers -and $ch.followers -gt 0) { $ch.followers } else { "?" }
    $report += "`n| $i | $($ch.channel) | $($ch.viewers) | $f | $($ch.title) | [Link]($($ch.url)) |"
    $i++
}
if ($newChannels.Count -gt 0) {
    $report += "`n`n## Nuevos ($($newChannels.Count))"
    foreach ($ch in $newChannels) {
        $f = if ($ch.followers -and $ch.followers -gt 0) { $ch.followers } else { "?" }
        $report += "`n- **$($ch.channel)** ($f seguidores) - [$($ch.title)]($($ch.url))"
    }
}
$report | Set-Content $outputFile
Write-Host "  Reporte: $outputFile" -ForegroundColor Cyan
Write-Host "  Nuevos: $($newChannels.Count) | Total: $($allChannels.Count)" -ForegroundColor $(if ($newChannels.Count -gt 0) { "Green" } else { "Yellow" })
