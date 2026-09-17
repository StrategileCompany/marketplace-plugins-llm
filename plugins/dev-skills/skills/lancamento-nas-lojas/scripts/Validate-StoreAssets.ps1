<#
.SYNOPSIS
  Valida assets graficos das lojas (icone, feature graphic, screenshots) quanto a
  DIMENSAO e CANAL ALPHA — as duas causas mais comuns de bloqueio no upload.

.DESCRIPTION
  Le cada imagem (PNG/JPG/JPEG) via System.Drawing (sem dependencia externa;
  funciona no Windows PowerShell 5.1 e no PowerShell 7 em Windows) e reporta
  largura x altura, se o arquivo carrega canal alpha e a proporcao (lado maior /
  lado menor). Com -Spec, valida contra a especificacao de um slot de loja e marca
  PASS/FAIL por arquivo.

  Nao altera nenhum arquivo. So le.

.PARAMETER Path
  Arquivo de imagem OU pasta. Pasta = valida todas as imagens (nao recursivo por
  padrao; use -Recurse).

.PARAMETER Spec
  Especificacao a validar. Um de:
    play-icon    512x512  (alpha PERMITIDO)
    apple-icon   1024x1024 (alpha PROIBIDO)
    play-feature 1024x500 (alpha PROIBIDO)
    play-phone   9:16, lado maior <= 2x o menor, cada lado 320..3840 (alpha PROIBIDO)
    apple-6.9    1290x2796 ou 1320x2868 (retrato/paisagem) (alpha PROIBIDO)
    apple-6.5    1284x2778 / 1242x2688 (alpha PROIBIDO)
    apple-ipad   2064x2752 / 2048x2732 (alpha PROIBIDO)
  Sem -Spec: so reporta (todas as linhas viram PASS informativo).

.PARAMETER Recurse
  Percorre subpastas.

.OUTPUTS
  Linhas TAB-separadas:
    IMG\t<arquivo>\t<w>x<h>\talpha=<True|False>\tratio=<r>\t<PASS|FAIL: motivo>
    RESUMO\t<total>\t<pass>\t<fail>
  Exit: 0 = tudo PASS · 2 = houve FAIL · 3 = nenhuma imagem encontrada · 1 = erro.

.EXAMPLE
  Validate-StoreAssets.ps1 -Path .\playstore-assets\screenshots\phone -Spec play-phone
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Path,
  [ValidateSet('play-icon','apple-icon','play-feature','play-phone','apple-6.9','apple-6.5','apple-ipad')]
  [string]$Spec,
  [switch]$Recurse
)

$ErrorActionPreference = 'Stop'

try { Add-Type -AssemblyName System.Drawing } catch {
  Write-Output "ERRO`tSystem.Drawing indisponivel: $($_.Exception.Message)"
  exit 1
}

# Especificacoes por slot. Dims = lista de "WxH" aceitos (ambas orientacoes).
# AlphaAllowed = se o canal alpha e permitido. Ratio = valida proporcao/limites.
$specs = @{
  'play-icon'    = @{ Dims = @('512x512');                         AlphaAllowed = $true  }
  'apple-icon'   = @{ Dims = @('1024x1024');                       AlphaAllowed = $false }
  'play-feature' = @{ Dims = @('1024x500');                        AlphaAllowed = $false }
  'apple-6.9'    = @{ Dims = @('1290x2796','2796x1290','1320x2868','2868x1320'); AlphaAllowed = $false }
  'apple-6.5'    = @{ Dims = @('1284x2778','2778x1284','1242x2688','2688x1242'); AlphaAllowed = $false }
  'apple-ipad'   = @{ Dims = @('2064x2752','2752x2064','2048x2732','2732x2048'); AlphaAllowed = $false }
  'play-phone'   = @{ Ratio = $true; MinSide = 320; MaxSide = 3840; MaxRatio = 2.0; AlphaAllowed = $false }
}

function Get-ImageInfo([string]$file) {
  # Le via MemoryStream para nao manter lock no arquivo.
  $bytes = [System.IO.File]::ReadAllBytes($file)
  $ms = New-Object System.IO.MemoryStream(,$bytes)
  try {
    $img = [System.Drawing.Image]::FromStream($ms, $false, $false)
    try {
      [pscustomobject]@{
        Width  = $img.Width
        Height = $img.Height
        Alpha  = [System.Drawing.Image]::IsAlphaPixelFormat($img.PixelFormat)
      }
    } finally { $img.Dispose() }
  } finally { $ms.Dispose() }
}

function Format-Num([double]$n) {
  return [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.###}', $n)
}

function Test-Spec($info, $specDef) {
  $w = $info.Width; $h = $info.Height; $alpha = $info.Alpha
  $reasons = @()
  if ($specDef.Dims) {
    if ($specDef.Dims -notcontains "${w}x${h}") {
      $reasons += "dimensao ${w}x${h} != esperado ($($specDef.Dims -join ', '))"
    }
  }
  if ($specDef.Ratio) {
    $long = [Math]::Max($w,$h); $short = [Math]::Min($w,$h)
    $r = if ($short -gt 0) { [Math]::Round($long / $short, 3) } else { 0 }
    if ($short -lt $specDef.MinSide -or $long -gt $specDef.MaxSide) {
      $reasons += "lado fora de $($specDef.MinSide)..$($specDef.MaxSide)px"
    }
    if ($r -gt $specDef.MaxRatio) {
      $reasons += "ratio $(Format-Num $r) > $(Format-Num $specDef.MaxRatio) (lado maior passa de 2x o menor; use padding edge-extend)"
    }
  }
  if (-not $specDef.AlphaAllowed -and $alpha) {
    $reasons += "tem canal alpha (achatar p/ 24-bit; so o icone da Play pode ter alpha)"
  }
  return ,$reasons
}

# Coleta os arquivos-alvo.
$targets = @()
if (Test-Path -LiteralPath $Path -PathType Leaf) {
  $targets = @(Get-Item -LiteralPath $Path)
} elseif (Test-Path -LiteralPath $Path -PathType Container) {
  $targets = Get-ChildItem -LiteralPath $Path -File -Recurse:$Recurse |
    Where-Object { $_.Extension -match '(?i)\.(png|jpg|jpeg)$' } |
    Sort-Object FullName
} else {
  Write-Output "ERRO`tcaminho nao encontrado: $Path"
  exit 1
}

if (-not $targets -or $targets.Count -eq 0) {
  Write-Output "NADA`tnenhuma imagem (.png/.jpg/.jpeg) em: $Path"
  exit 3
}

$specDef = if ($Spec) { $specs[$Spec] } else { $null }
$pass = 0; $fail = 0

foreach ($t in $targets) {
  try {
    $info = Get-ImageInfo $t.FullName
  } catch {
    $fail++
    Write-Output ("IMG`t{0}`t?`talpha=?`tratio=?`tFAIL: nao foi possivel ler ({1})" -f $t.Name, $_.Exception.Message)
    continue
  }
  $long = [Math]::Max($info.Width,$info.Height); $short = [Math]::Min($info.Width,$info.Height)
  $ratio = if ($short -gt 0) { [Math]::Round($long / $short, 3) } else { 0 }
  $verdict = 'PASS'
  if ($specDef) {
    $reasons = Test-Spec $info $specDef
    if ($reasons.Count -gt 0) { $verdict = "FAIL: " + ($reasons -join ' | ') }
  }
  if ($verdict -eq 'PASS') { $pass++ } else { $fail++ }
  Write-Output ("IMG`t{0}`t{1}x{2}`talpha={3}`tratio={4}`t{5}" -f `
    $t.Name, $info.Width, $info.Height, $info.Alpha, (Format-Num $ratio), $verdict)
}

Write-Output ("RESUMO`t{0}`t{1}`t{2}" -f $targets.Count, $pass, $fail)
if ($fail -gt 0) { exit 2 } else { exit 0 }
