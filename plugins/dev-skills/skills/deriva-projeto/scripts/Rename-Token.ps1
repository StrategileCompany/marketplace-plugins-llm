#Requires -Version 5.1
<#
.SYNOPSIS
    Substitui tokens no CONTEUDO dos arquivos e, opcionalmente, nos NOMES de pastas e arquivos.

.DESCRIPTION
    A substituicao preserva o encoding de cada arquivo. Arquivos UTF-8 validos sao lidos e
    escritos como UTF-8 (preservando o BOM, se havia); os demais sao tratados como Latin-1
    (28591), que faz round-trip de todos os 256 valores de byte. Em nenhum dos casos o final de
    linha e convertido. Isso evita os dois modos classicos de corromper um repositorio misto:
    reescrever tudo como UTF-8 (destroi acento em arquivo Windows-1252) e reescrever tudo como
    Latin-1 (destroi acento em arquivo UTF-8 quando o texto novo tem caractere nao-ASCII).

    Renomeia pastas/arquivos do mais profundo para o mais raso, para nao invalidar caminhos.

    Funciona no Windows PowerShell 5.1 e no PowerShell 7 (Windows, macOS e Linux).

.PARAMETER Path
    Raiz do repositorio. Default: diretorio atual.

.PARAMETER Map
    Pares "De=Para" separados por ponto e virgula, APLICADOS NA ORDEM DADA. Coloque os tokens
    mais longos primeiro, para que um curto nao coma um longo.
    Ex.: "Meu Sistema=Novo Sistema;MeuSistema=NovoSistema;meusistema=novosistema"

.PARAMETER WholeWord
    Substitui apenas ocorrencias que nao estejam colados a letra ou digito nas bordas.
    Use com token curto (ex.: "rv"), que colado forma outra palavra ("server").

.PARAMETER Include
    Extensoes cujo conteudo sera reescrito. O default cobre codigo, projeto, config, infra e prosa.

.PARAMETER IncludeName
    Nomes de arquivo sem extensao a incluir tambem (Dockerfile, Makefile...).

.PARAMETER ExcludeFile
    Padroes de nome de arquivo a nao tocar no conteudo. Default: bundles minificados e sourcemaps.

.PARAMETER ExcludeDir
    Pastas que nao sao percorridas. Inclui .claude por default: worktrees ali dentro sao copias
    inteiras do repositorio, e reescrever o conteudo delas e sempre erro.

.PARAMETER RenamePaths
    Tambem renomeia pastas e arquivos cujo nome contenha algum token.

.PARAMETER DryRun
    So relata o que faria.

.EXAMPLE
    ./Rename-Token.ps1 -Map "MeuSistema=NovoSistema;meusistema=novosistema" -RenamePaths -DryRun
    ./Rename-Token.ps1 -Map "MeuSistema=NovoSistema;meusistema=novosistema" -RenamePaths
#>
[CmdletBinding()]
param(
    [string]$Path = ".",
    [Parameter(Mandatory = $true)][string]$Map,
    [switch]$WholeWord,
    [string[]]$Include = @(
        '.cs', '.razor', '.cshtml', '.vb', '.fs', '.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs', '.vue',
        '.svelte', '.py', '.go', '.java', '.kt', '.kts', '.swift', '.dart', '.rb', '.php', '.rs', '.scala',
        '.sql', '.kql', '.ps1', '.psm1', '.psd1', '.sh', '.bat', '.cmd',
        '.csproj', '.fsproj', '.vbproj', '.sln', '.slnx', '.props', '.targets', '.json', '.jsonc', '.yml',
        '.yaml', '.toml', '.ini', '.config', '.xml', '.resx', '.plist', '.gradle', '.properties',
        '.editorconfig', '.gitignore', '.gitattributes', '.dockerignore', '.tf', '.tfvars', '.bicep',
        '.bicepparam', '.http', '.html', '.htm', '.css', '.scss', '.sass', '.less', '.webmanifest', '.svg',
        '.md', '.txt', '.rst', '.adoc'
    ),
    [string[]]$IncludeName = @('Dockerfile', 'Makefile', 'Procfile', 'Jenkinsfile', 'CODEOWNERS'),
    [string[]]$ExcludeFile = @('*.min.js', '*.min.css', '*.map'),
    [string[]]$ExcludeDir = @('.git', 'bin', 'obj', '.vs', '.idea', 'node_modules', '.claude', 'dist',
                              'target', '.next', '.nuxt', '__pycache__', '.venv', 'venv', 'TestResults'),
    [switch]$RenamePaths,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
# Get-Item expande caminhos curtos 8.3 do Windows (C:\Users\FULANO~1); Resolve-Path nao.
# Precisa bater com o FullName da varredura, senao o caminho relativo sai torto.
$root = (Get-Item -LiteralPath $Path).FullName.TrimEnd('\', '/')

function Get-Rel([string]$full) {
    if ($full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
        return $full.Substring($root.Length).TrimStart('\', '/')
    }
    return $full
}

# ------------------------------------------------------------------- pares ---
$pares = New-Object 'System.Collections.Generic.List[object]'
foreach ($p in ($Map -split ';')) {
    if (-not $p.Trim()) { continue }
    $i = $p.IndexOf('=')
    if ($i -lt 1) { throw "Par invalido em -Map: '$p'. Use De=Para." }
    $de = $p.Substring(0, $i)
    $para = $p.Substring($i + 1)
    if (-not $de.Trim()) { throw "Par invalido em -Map: '$p'. O lado esquerdo nao pode ser vazio." }
    if ($para -match '[?]$' -and $para.Length -eq 1) { throw "Par '$p' ainda tem o placeholder '?' do inventario. Preencha o lado direito." }
    $regex = $null
    if ($WholeWord) { $regex = New-Object System.Text.RegularExpressions.Regex ('(?<![A-Za-z0-9])' + [regex]::Escape($de) + '(?![A-Za-z0-9])') }
    $pares.Add([pscustomobject]@{ De = $de; Para = $para; Regex = $regex })
}

# Um par cujo lado esquerdo e substring do lado direito de outro par aplicado ANTES reescreve o
# que o primeiro acabou de produzir. Erro silencioso e caro de diagnosticar; falha aqui.
for ($i = 0; $i -lt $pares.Count; $i++) {
    for ($j = $i + 1; $j -lt $pares.Count; $j++) {
        if ($pares[$i].Para.IndexOf($pares[$j].De, [StringComparison]::Ordinal) -ge 0) {
            throw ("Ordem invalida em -Map: '" + $pares[$j].De + "' aparece dentro do resultado de '" +
                   $pares[$i].De + "' -> '" + $pares[$i].Para + "', e seria aplicado em cima dele. " +
                   "Reordene (mais longos/especificos primeiro) ou ajuste o par.")
        }
    }
}

function Convert-Texto([string]$texto) {
    foreach ($p in $pares) {
        if ($p.Regex) { $texto = $p.Regex.Replace($texto, $p.Para.Replace('$', '$$')) }
        else { $texto = $texto.Replace($p.De, $p.Para) }
    }
    return $texto
}

# Texto novo com caractere nao-ASCII nao cabe em arquivo Latin-1 sem decidir o encoding de saida;
# e em nome de arquivo/pasta cria problema de normalizacao entre sistemas. Melhor recusar.
$naoAscii = @($pares | Where-Object { $_.Para -match '[^\x00-\x7F]' })

Write-Output "Substituicoes (nesta ordem):"
foreach ($p in $pares) { Write-Output ("  '" + $p.De + "'  ->  '" + $p.Para + "'") }
if ($WholeWord) { Write-Output "Modo palavra inteira: ocorrencia colada a letra/digito nao e substituida." }
if ($naoAscii.Count -gt 0) {
    Write-Output ""
    Write-Output "[!!] Estes pares tem caractere nao-ASCII no lado direito:"
    foreach ($p in $naoAscii) { Write-Output ("     '" + $p.De + "' -> '" + $p.Para + "'") }
    Write-Output "     Arquivo UTF-8 aceita; arquivo Latin-1 seria reescrito com o byte errado, e nome"
    Write-Output "     de arquivo com acento varia de normalizacao entre sistemas. Use o equivalente sem"
    Write-Output "     acento no identificador (namespace, pasta, chave) e ajuste o nome de exibicao a mao."
    if ($RenamePaths) { throw "Nao renomeio caminhos com caractere nao-ASCII. Remova -RenamePaths ou ajuste o -Map." }
}
if ($DryRun) { Write-Output "MODO DRY-RUN: nada sera alterado." }
Write-Output ""

# --------------------------------------------------------------- varredura ---
# Percorre a arvore uma vez, podando as pastas ignoradas e os pontos de reparse
# (junctions/symlinks), que podem criar ciclos ou apontar para fora do repositorio.
function Get-Arvore {
    $arquivos = New-Object 'System.Collections.Generic.List[System.IO.FileInfo]'
    $pastas   = New-Object 'System.Collections.Generic.List[System.IO.DirectoryInfo]'
    $pilha    = New-Object 'System.Collections.Generic.Stack[System.IO.DirectoryInfo]'
    $pilha.Push((New-Object System.IO.DirectoryInfo $root))
    while ($pilha.Count -gt 0) {
        $d = $pilha.Pop()
        $filhos = @()
        try { $filhos = $d.GetFileSystemInfos() } catch { continue }
        foreach ($item in $filhos) {
            if ($item -is [System.IO.DirectoryInfo]) {
                if ($ExcludeDir -contains $item.Name) { continue }
                if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { continue }
                $pastas.Add($item)
                $pilha.Push($item)
            } else {
                $arquivos.Add([System.IO.FileInfo]$item)
            }
        }
    }
    return [pscustomobject]@{ Arquivos = $arquivos; Pastas = $pastas }
}

$arvore = Get-Arvore

# ----------------------------------------------------------------- conteudo ---
Write-Output "--- CONTEUDO ---"

$utf8Estrito = New-Object System.Text.UTF8Encoding($false, $true)
$utf8SemBom  = New-Object System.Text.UTF8Encoding($false)
$utf8ComBom  = New-Object System.Text.UTF8Encoding($true)
$latin1 = [System.Text.Encoding]::GetEncoding(28591)
$bom = [byte[]]@(0xEF, 0xBB, 0xBF)

$alterados = 0
$pulados = 0
foreach ($f in $arvore.Arquivos) {
    $incluir = ($Include -contains $f.Extension.ToLowerInvariant()) -or
               ($IncludeName -contains $f.Name) -or
               ($f.Name -like '.env*')
    if (-not $incluir) { continue }
    $excluir = $false
    foreach ($p in $ExcludeFile) { if ($f.Name -like $p) { $excluir = $true; break } }
    if ($excluir) { continue }

    # ReadAllText/WriteAllText NAO servem aqui: o StreamReader detecta BOM e ignora a codificacao
    # passada. ReadAllBytes + Encoding.GetString nao faz deteccao nenhuma - round-trip exato.
    $bytesAntes = [System.IO.File]::ReadAllBytes($f.FullName)
    $ehUtf8 = $true
    $temBom = ($bytesAntes.Length -ge 3 -and $bytesAntes[0] -eq $bom[0] -and $bytesAntes[1] -eq $bom[1] -and $bytesAntes[2] -eq $bom[2])
    try { $antes = $utf8Estrito.GetString($bytesAntes) } catch { $ehUtf8 = $false; $antes = $latin1.GetString($bytesAntes) }
    if ($ehUtf8 -and $temBom) { $antes = $antes.Substring(1) }

    $depois = Convert-Texto $antes
    if ($depois -ceq $antes) { continue }

    $rel = Get-Rel $f.FullName
    if (-not $ehUtf8 -and $depois -match '[^\x00-\x7F]' -and $naoAscii.Count -gt 0) {
        # O texto novo trouxe caractere nao-ASCII para um arquivo que nao e UTF-8: gravar
        # perderia informacao ou trocaria o byte. Deixa para o ajuste manual.
        Write-Output ("  [PULADO ] $rel  (nao e UTF-8 e o texto novo tem caractere nao-ASCII)")
        $pulados++
        continue
    }

    $alterados++
    Write-Output ("  [conteudo] $rel")
    if ($DryRun) { continue }
    if ($ehUtf8) {
        $enc = if ($temBom) { $utf8ComBom } else { $utf8SemBom }
        $saida = @($enc.GetPreamble()) + @($utf8SemBom.GetBytes($depois))
        [System.IO.File]::WriteAllBytes($f.FullName, [byte[]]$saida)
    } else {
        [System.IO.File]::WriteAllBytes($f.FullName, $latin1.GetBytes($depois))
    }
}
Write-Output ("Arquivos com conteudo alterado: $alterados")
if ($pulados -gt 0) { Write-Output ("Arquivos pulados (ajuste manual): $pulados") }

# ------------------------------------------------------- nomes de caminhos ---
if ($RenamePaths) {
    Write-Output ""
    Write-Output "--- NOMES DE ARQUIVOS E PASTAS ---"

    $renomeados = 0
    $alvosArquivo = @($arvore.Arquivos | Where-Object { (Convert-Texto $_.Name) -cne $_.Name })
    foreach ($f in $alvosArquivo) {
        $novo = Convert-Texto $f.Name
        $destino = Join-Path $f.DirectoryName $novo
        # Comparacao sem caixa: no Windows o filesystem e case-insensitive, e um rename que muda
        # apenas a caixa (MeuSistema -> Meusistema) acharia "o destino ja existe" olhando para o
        # proprio arquivo. Num filesystem case-sensitive o Test-Path ja daria falso.
        if ((Test-Path -LiteralPath $destino) -and -not $destino.Equals($f.FullName, [StringComparison]::OrdinalIgnoreCase)) {
            Write-Output ("  [CONFLITO] " + (Get-Rel $f.FullName) + "  ->  $novo  (o destino ja existe; renomeie a mao)")
            continue
        }
        Write-Output ("  [arquivo] " + (Get-Rel $f.FullName) + "  ->  $novo")
        if (-not $DryRun) { Rename-Item -LiteralPath $f.FullName -NewName $novo }
        $renomeados++
    }

    # Do mais profundo para o mais raso: renomear a pasta pai antes invalidaria o caminho da filha.
    $alvosPasta = @($arvore.Pastas |
        Where-Object { (Convert-Texto $_.Name) -cne $_.Name } |
        Sort-Object { ($_.FullName -split '[\\/]').Count } -Descending)
    foreach ($d in $alvosPasta) {
        $novo = Convert-Texto $d.Name
        $destino = Join-Path $d.Parent.FullName $novo
        if ((Test-Path -LiteralPath $destino) -and -not $destino.Equals($d.FullName, [StringComparison]::OrdinalIgnoreCase)) {
            Write-Output ("  [CONFLITO] " + (Get-Rel $d.FullName) + "  ->  $novo  (o destino ja existe; mescle a mao)")
            continue
        }
        Write-Output ("  [pasta]   " + (Get-Rel $d.FullName) + "  ->  $novo")
        if (-not $DryRun) { Rename-Item -LiteralPath $d.FullName -NewName $novo }
        $renomeados++
    }

    Write-Output ("Caminhos renomeados: $renomeados")
    Write-Output "Lembre: a pasta RAIZ do repositorio nao e renomeada aqui (esta em uso). Passo manual."
}

Write-Output ""
if ($DryRun) {
    Write-Output "Dry-run concluido. Confira a lista e reexecute sem -DryRun para aplicar."
} else {
    Write-Output "Concluido. Rode a varredura de residuos, o build e os testes para conferir."
}
