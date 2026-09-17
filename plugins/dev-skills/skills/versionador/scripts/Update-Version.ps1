#Requires -Version 5.1
<#
.SYNOPSIS
    Atualiza o numero de versao (formato yyyy.MM.dd.HHmm) em projetos C#/.NET.

.DESCRIPTION
    1. Gera a nova versao a partir da data/hora atual (fuso America/Sao_Paulo por
       padrao) no formato yyyy.MM.dd.HHmm (ex.: 2026.06.14.0048).
    2. Detecta a versao atual lendo <AssemblyVersion>...</AssemblyVersion> dos .csproj.
    3. Substitui a versao antiga pela nova nos arquivos que CARREGAM versao por
       definicao (.csproj, .js, .html, .webmanifest, .json...).
    4. Arquivos de prosa e de codigo (.md, .txt, .yml, .cs...) nunca sao alterados.

    A troca e feita a nivel de BYTES: como a versao antiga e a nova sao ASCII e
    do mesmo tamanho, o resto do arquivo e preservado byte-a-byte, sem mexer em
    encoding nem BOM.

.PARAMETER Root
    Raiz do projeto.

.PARAMETER Version
    Forca a nova versao (default: data/hora atual).

.PARAMETER Current
    Forca a versao antiga (pula a deteccao no .csproj).

.PARAMETER TimeZone
    Fuso para gerar a versao (default: America/Sao_Paulo; cai para o fuso de
    Brasilia no Windows PowerShell 5.1).

.OUTPUTS
    Linhas separadas por TAB: VERSAO_ANTIGA, VERSAO_NOVA, FONTE, RESUMO,
    CHANGED<TAB>caminho<TAB>n, ou NADA_A_FAZER.
    Codigos de saida: 0 = ok; 3 = nada a fazer; 2 = erro/ambiguo.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\Update-Version.ps1 -Root C:\proj\MeuApp
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Root,
    [string]$Version,
    [string]$Current,
    [string]$TimeZone = 'America/Sao_Paulo'
)

$ErrorActionPreference = 'Stop'

$VersionFmtRegex      = '^\d{4}\.\d{2}\.\d{2}\.\d{4}$'
$AssemblyVersionRegex = '<AssemblyVersion>\s*([0-9][0-9.]*)\s*</AssemblyVersion>'

# `.claude` cobre os worktrees de outras branches (.claude/worktrees/<nome>/).
$ExcludeDirs = @('.git','.claude','bin','obj','node_modules','.vs','packages','dist','build',
                 '.idea','TestResults','.next','coverage')

# Arquivos que CARREGAM versao por definicao: substituicao automatica.
$VersionExt = @('.csproj','.props','.targets','.js','.mjs','.cjs','.ts','.jsx','.tsx',
                '.html','.htm','.webmanifest','.json','.config','.xml')

# Trava: nunca substituir nestas extensoes, mesmo que entrem em $VersionExt.
$NuncaSubstituirExt = @('.md','.txt','.yml','.yaml','.cs','.razor','.cshtml','.css','.scss')

function Get-NowVersion {
    param([string]$Tz)
    $now = $null
    foreach ($id in @($Tz, 'E. South America Standard Time')) {
        if ([string]::IsNullOrEmpty($id)) { continue }
        try {
            $tzi = [System.TimeZoneInfo]::FindSystemTimeZoneById($id)
            $now = [System.TimeZoneInfo]::ConvertTime([System.DateTimeOffset]::Now, $tzi)
            break
        } catch { }
    }
    if ($null -eq $now) { $now = [System.DateTimeOffset]::Now }
    return $now.ToString('yyyy.MM.dd.HHmm', [System.Globalization.CultureInfo]::InvariantCulture)
}

function Get-ProjectFiles {
    param([string]$RootPath)
    $rootFull = $RootPath.TrimEnd('\','/')
    Get-ChildItem -LiteralPath $rootFull -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object {
        $rel = $_.FullName.Substring($rootFull.Length)
        $parts = $rel -split '[\\/]+' | Where-Object { $_ -ne '' }
        $excluded = $false
        foreach ($p in $parts) {
            if ($ExcludeDirs -contains $p) { $excluded = $true; break }
        }
        -not $excluded
    }
}

function Get-CurrentVersions {
    param([string]$RootPath)
    $map = @{}
    Get-ProjectFiles -RootPath $RootPath | Where-Object { $_.Extension -ieq '.csproj' } | ForEach-Object {
        try { $text = [System.IO.File]::ReadAllText($_.FullName) } catch { return }
        foreach ($m in [regex]::Matches($text, $AssemblyVersionRegex)) {
            $v = $m.Groups[1].Value.Trim()
            if (-not $map.ContainsKey($v)) { $map[$v] = @() }
            $map[$v] += $_.FullName
        }
    }
    return $map
}

function Invoke-ByteReplace {
    # Substitui $oldBytes por $newBytes (mesmo tamanho) dentro de $data, in-place.
    # Retorna a quantidade de ocorrencias.
    param([byte[]]$Data, [byte[]]$OldBytes, [byte[]]$NewBytes)
    $count = 0
    $n = $OldBytes.Length
    if ($n -eq 0) { return 0 }
    $limit = $Data.Length - $n
    for ($i = 0; $i -le $limit; $i++) {
        if ($Data[$i] -ne $OldBytes[0]) { continue }
        $match = $true
        for ($j = 1; $j -lt $n; $j++) {
            if ($Data[$i + $j] -ne $OldBytes[$j]) { $match = $false; break }
        }
        if ($match) {
            for ($j = 0; $j -lt $n; $j++) { $Data[$i + $j] = $NewBytes[$j] }
            $count++
            $i += $n - 1
        }
    }
    return $count
}

function Invoke-ProjectReplace {
    param([string]$RootPath, [string]$Old, [string]$New, [string[]]$Extensions)
    $oldBytes = [System.Text.Encoding]::ASCII.GetBytes($Old)
    $newBytes = [System.Text.Encoding]::ASCII.GetBytes($New)
    $changed = @()
    Get-ProjectFiles -RootPath $RootPath | Where-Object {
        $ext = $_.Extension.ToLower()
        ($Extensions -contains $ext) -and (-not ($NuncaSubstituirExt -contains $ext))
    } | ForEach-Object {
        try { $data = [System.IO.File]::ReadAllBytes($_.FullName) } catch { return }
        $count = Invoke-ByteReplace -Data $data -OldBytes $oldBytes -NewBytes $newBytes
        if ($count -gt 0) {
            try { [System.IO.File]::WriteAllBytes($_.FullName, $data) }
            catch { [Console]::Error.WriteLine("AVISO: nao foi possivel escrever $($_.FullName): $($_.Exception.Message)"); return }
            $changed += [pscustomobject]@{ Path = $_.FullName; Count = $count }
        }
    }
    return $changed
}

# ------------------------- fluxo principal -------------------------

if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    [Console]::Error.WriteLine("ERRO: pasta nao encontrada: $Root")
    exit 2
}
$rootResolved = (Resolve-Path -LiteralPath $Root).Path

# Nova versao
if ([string]::IsNullOrEmpty($Version)) { $new = Get-NowVersion -Tz $TimeZone } else { $new = $Version }
if ($new -notmatch $VersionFmtRegex) {
    [Console]::Error.WriteLine("ERRO: versao nova '$new' nao segue o formato yyyy.MM.dd.HHmm")
    exit 2
}

# Versao atual
if (-not [string]::IsNullOrEmpty($Current)) {
    $old = $Current
    $sources = @('(informado via -Current)')
} else {
    $found = Get-CurrentVersions -RootPath $rootResolved
    if ($found.Count -eq 0) {
        [Console]::Error.WriteLine("ERRO: nenhum <AssemblyVersion> encontrado nos .csproj. Use -Current para informar a versao atual.")
        exit 2
    }
    if ($found.Count -gt 1) {
        [Console]::Error.WriteLine("ERRO: encontrei mais de uma versao nos .csproj (ambiguo):")
        foreach ($k in ($found.Keys | Sort-Object)) {
            [Console]::Error.WriteLine(("  {0}  ->  {1}" -f $k, ($found[$k] -join ', ')))
        }
        [Console]::Error.WriteLine("Use -Current para escolher qual substituir.")
        exit 2
    }
    $old = @($found.Keys)[0]
    $sources = $found[$old]
}

Write-Output ("VERSAO_ANTIGA`t{0}" -f $old)
Write-Output ("VERSAO_NOVA`t{0}" -f $new)
foreach ($s in $sources) { Write-Output ("FONTE`t{0}" -f $s) }

if ($old -eq $new) {
    Write-Output "NADA_A_FAZER`tversao antiga e nova sao iguais (mesmo minuto). Aguarde 1 minuto ou use -Version."
    exit 3
}

$changed = @(Invoke-ProjectReplace -RootPath $rootResolved -Old $old -New $new -Extensions $VersionExt)

if ($changed.Count -eq 0) {
    Write-Output "NADA_A_FAZER`ta versao antiga nao foi encontrada em nenhum arquivo."
    exit 3
}

$total = [int](($changed | Measure-Object -Property Count -Sum).Sum)
Write-Output ("RESUMO`t{0} arquivo(s) de versao, {1} ocorrencia(s) de {2} -> {3}" -f $changed.Count, $total, $old, $new)
foreach ($c in ($changed | Sort-Object Path)) {
    Write-Output ("CHANGED`t{0}`t{1}" -f $c.Path, $c.Count)
}

exit 0
