#Requires -Version 5.1
<#
.SYNOPSIS
    Levanta o inventario de um repositorio que sera a base de um projeto novo.

.DESCRIPTION
    Somente leitura: nao altera nada. Reune os fatos que a skill deriva-projeto precisa antes
    de classificar o que fica, o que sai, o que se renomeia e o que se regenera:

      - projetos, solutions (.sln/.slnx) e manifestos de qualquer stack (.NET em detalhe);
      - tokens do projeto antigo em todas as variantes de caixa, e onde aparecem;
      - arquivos fora de UTF-8;
      - pontos de entrada (rotas Blazor, triggers de Azure Functions, rota de saude);
      - PackageReference duplicados;
      - configuracao, CI/CD, IaC e containers;
      - chaves de segredo e identidade (SO O NOME da chave; valores nunca sao exibidos);
      - dominios que carregam o token (integracoes a reconfigurar fora do repositorio);
      - banco de dados (scripts, migrations);
      - artefatos de agente, documentacao, changelog, versao, assets de marca e estado do Git.

    Funciona no Windows PowerShell 5.1 e no PowerShell 7 (Windows, macOS e Linux).

.PARAMETER Path
    Raiz do repositorio. Default: diretorio atual.

.PARAMETER Token
    Token(s) do projeto antigo, de preferencia em PascalCase (ex.: MeuSistema). As variantes
    minuscula, MAIUSCULA, kebab-case, snake_case e nome de exibicao com espaco sao geradas
    automaticamente. Se omitido, deriva do prefixo comum dos projetos .NET ou do "name" do
    package.json da raiz.

.PARAMETER ExcludeDir
    Pastas que nao sao percorridas (saida de build, dependencias, IDE, agente).

.EXAMPLE
    ./Get-Inventario.ps1 -Path D:\Prj\NovoRepo
    ./Get-Inventario.ps1 -Token MeuSistema,MS
#>
[CmdletBinding()]
param(
    [string]$Path = ".",
    [string[]]$Token,
    [string[]]$ExcludeDir = @('.git', 'bin', 'obj', '.vs', '.idea', 'node_modules', '.claude', 'dist',
                              'target', '.next', '.nuxt', '__pycache__', '.venv', 'venv', 'TestResults')
)

$ErrorActionPreference = "Stop"
# Get-Item expande caminhos curtos 8.3 do Windows (C:\Users\FULANO~1); Resolve-Path nao.
# Precisa bater com o FullName da varredura, senao o caminho relativo sai torto.
$root = (Get-Item -LiteralPath $Path).FullName.TrimEnd('\', '/')
$temGitRepo = Test-Path -LiteralPath (Join-Path $root '.git')
$temGit = [bool](Get-Command git -ErrorAction SilentlyContinue)

# ------------------------------------------------------------------- apoio ---
function Write-Secao([string]$titulo) {
    Write-Output ""
    Write-Output ("=" * 76)
    Write-Output "  $titulo"
    Write-Output ("=" * 76)
}

function Get-Rel([string]$full) {
    if ($full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
        return $full.Substring($root.Length).TrimStart('\', '/')
    }
    return $full
}

function Write-Lista($itens, [int]$max = 30, [string]$recuo = '  ') {
    $itens = @($itens)
    foreach ($i in ($itens | Select-Object -First $max)) { Write-Output ($recuo + $i) }
    if ($itens.Count -gt $max) { Write-Output ($recuo + "... e mais " + ($itens.Count - $max)) }
}

function Invoke-Git([string[]]$argumentos) {
    if (-not ($temGitRepo -and $temGit)) { return @() }
    # No PowerShell 5.1, stderr de comando nativo com ErrorActionPreference=Stop vira excecao.
    $anterior = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $saida = & git -C $root @argumentos 2>$null
        if ($LASTEXITCODE -ne 0) { return @() }
        return @($saida)
    } finally {
        $ErrorActionPreference = $anterior
    }
}

# Extensoes e nomes tratados como texto. Mantenha em sincronia com Rename-Token.ps1.
$extTexto = @(
    '.cs', '.razor', '.cshtml', '.vb', '.fs', '.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs', '.vue',
    '.svelte', '.py', '.go', '.java', '.kt', '.kts', '.swift', '.dart', '.rb', '.php', '.rs', '.scala',
    '.sql', '.kql', '.ps1', '.psm1', '.psd1', '.sh', '.bat', '.cmd',
    '.csproj', '.fsproj', '.vbproj', '.sln', '.slnx', '.props', '.targets', '.json', '.jsonc', '.yml',
    '.yaml', '.toml', '.ini', '.config', '.xml', '.resx', '.plist', '.gradle', '.properties',
    '.editorconfig', '.gitignore', '.gitattributes', '.dockerignore', '.tf', '.tfvars', '.bicep',
    '.bicepparam', '.http', '.html', '.htm', '.css', '.scss', '.sass', '.less', '.webmanifest', '.svg',
    '.md', '.txt', '.rst', '.adoc'
)
$nomesTexto = @('Dockerfile', 'Makefile', 'Procfile', 'Jenkinsfile', 'CODEOWNERS')
$padraoExcluido = @('*.min.js', '*.min.css', '*.map')

function Test-Texto([System.IO.FileInfo]$f) {
    foreach ($p in $padraoExcluido) { if ($f.Name -like $p) { return $false } }
    if ($f.Name -like '.env*') { return $true }
    return ($extTexto -contains $f.Extension.ToLowerInvariant()) -or ($nomesTexto -contains $f.Name)
}

function Get-Variantes([string]$t) {
    # "MeuSistemaWeb" -> MeuSistemaWeb, meusistemaweb, MEUSISTEMAWEB, meu-sistema-web,
    # meu_sistema_web, MEU_SISTEMA_WEB, "Meu Sistema Web".
    $vistas = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $lista = New-Object 'System.Collections.Generic.List[string]'
    $add = { param($v) if ($v -and $vistas.Add($v)) { $lista.Add($v) } }
    & $add $t
    $palavras = @([regex]::Matches($t, '[A-Z]+(?=[A-Z][a-z]|[^A-Za-z]|$)|[A-Z]?[a-z]+|[0-9]+') | ForEach-Object { $_.Value })
    if ($palavras.Count -gt 0) {
        $junto = $palavras -join ''
        & $add $junto.ToLowerInvariant()
        & $add $junto.ToUpperInvariant()
        if ($palavras.Count -gt 1) {
            $min = @($palavras | ForEach-Object { $_.ToLowerInvariant() })
            & $add ($min -join '-')
            & $add ($min -join '_')
            & $add (($min -join '_').ToUpperInvariant())
            & $add ((@($palavras | ForEach-Object { $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1) })) -join ' ')
        }
    }
    return $lista.ToArray()
}

# --------------------------------------------------------------- varredura ---
# Percorre a arvore uma vez, podando as pastas ignoradas (nao desce em node_modules etc.)
# e os pontos de reparse (junctions/symlinks), que podem criar ciclos.
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

# Le cada arquivo de texto uma vez. UTF-8 estrito primeiro; o que falhar e registrado como
# nao-UTF-8 e lido como Latin-1 (round-trip de todos os bytes).
$utf8Estrito = New-Object System.Text.UTF8Encoding($false, $true)
$latin1 = [System.Text.Encoding]::GetEncoding(28591)
$textos = @{}
$naoUtf8 = New-Object 'System.Collections.Generic.List[string]'
foreach ($f in $arquivos) {
    if (-not (Test-Texto $f)) { continue }
    if ($f.Length -gt 5MB) { continue }
    $rel = Get-Rel $f.FullName
    $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
    try { $textos[$rel] = $utf8Estrito.GetString($bytes) }
    catch { $textos[$rel] = $latin1.GetString($bytes); $naoUtf8.Add($rel) }
}
$chaves = @($textos.Keys | Sort-Object)

function Get-Textos([string[]]$extensoes) {
    return @($chaves | Where-Object { $extensoes -contains [System.IO.Path]::GetExtension($_).ToLowerInvariant() })
}

# ---------------------------------------------------------------- projetos ---
Write-Secao "PROJETOS, SOLUTIONS E MANIFESTOS"

$solucoes = @($arquivos | Where-Object { $_.Extension -eq '.sln' -or $_.Extension -eq '.slnx' })
if ($solucoes.Count -eq 0) { Write-Output "Solution : (nenhuma .sln/.slnx)" }
foreach ($s in $solucoes) { Write-Output ("Solution : " + (Get-Rel $s.FullName)) }

$projetosDotnet = @($arquivos | Where-Object { @('.csproj', '.fsproj', '.vbproj') -contains $_.Extension })
$conteudoProjeto = @{}
foreach ($c in $projetosDotnet) {
    $conteudo = [System.IO.File]::ReadAllText($c.FullName)
    $conteudoProjeto[$c.FullName] = $conteudo
    $xml = $null
    try { $xml = [xml]$conteudo } catch { }

    $sdk = ''; $tfm = ''; $out = ''
    if ($xml -and $xml.Project) {
        $sdk = [string]$xml.Project.Sdk
        foreach ($g in @($xml.Project.PropertyGroup)) {
            if ($g.TargetFramework)  { $tfm = [string]$g.TargetFramework }
            if ($g.TargetFrameworks) { $tfm = [string]$g.TargetFrameworks }
            if ($g.OutputType)       { $out = [string]$g.OutputType }
        }
    }

    # Classificacao do tipo de projeto por evidencias no disco.
    $dir = $c.DirectoryName
    $prefixoDir = $dir + [System.IO.Path]::DirectorySeparatorChar
    $temHostJson  = Test-Path -LiteralPath (Join-Path $dir 'host.json')
    $temIndexHtml = Test-Path -LiteralPath (Join-Path (Join-Path $dir 'wwwroot') 'index.html')
    $temRazorRaiz = @($arquivos | Where-Object {
        @('App.razor', 'Index.razor', 'Routes.razor') -contains $_.Name -and
        $_.FullName.StartsWith($prefixoDir, [StringComparison]::OrdinalIgnoreCase)
    }).Count -gt 0
    $ehTeste = $conteudo -match 'Microsoft\.NET\.Test\.Sdk|<IsTestProject>\s*true'

    $tipo = 'Biblioteca / classe'
    if ($temHostJson) {
        $tipo = 'Azure Function'
        if ($conteudo -match 'Microsoft\.NET\.Sdk\.Functions') {
            $tipo += ' - IN-PROCESS [!!] fim de suporte em 10/11/2026: migrar para isolated'
        } elseif ($conteudo -match 'Microsoft\.Azure\.Functions\.Worker') {
            $tipo += ' - isolated worker'
        }
    }
    elseif ($sdk -match 'BlazorWebAssembly' -or $temIndexHtml) { $tipo = 'Blazor WebAssembly (client)' }
    elseif ($sdk -match 'Sdk\.Web') { if ($temRazorRaiz) { $tipo = 'Blazor Server / Web App' } else { $tipo = 'ASP.NET Core Web / API' } }
    elseif ($ehTeste) { $tipo = 'Testes' }

    Write-Output ""
    Write-Output ("Projeto  : " + (Get-Rel $c.FullName))
    Write-Output ("  Tipo   : $tipo")
    if ($sdk) { Write-Output ("  Sdk    : $sdk") }
    if ($tfm) { Write-Output ("  TFM    : $tfm") }
    if ($out) { Write-Output ("  Output : $out") }
    $refs = @([regex]::Matches($conteudo, 'ProjectReference\s+Include="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
    if ($refs.Count -gt 0) { Write-Output ("  Refs   : " + ($refs -join ", ")) }
}

$nomesManifesto = @('package.json', 'pyproject.toml', 'requirements.txt', 'setup.py', 'go.mod', 'pom.xml',
                    'build.gradle', 'build.gradle.kts', 'Cargo.toml', 'composer.json', 'Gemfile',
                    'pubspec.yaml', 'deno.json')
$manifestos = @($arquivos | Where-Object { $nomesManifesto -contains $_.Name })
if ($manifestos.Count -gt 0) {
    Write-Output ""
    Write-Output "Outros manifestos:"
    foreach ($m in $manifestos) {
        $rel = Get-Rel $m.FullName
        $linha = "  $rel"
        if ($m.Name -eq 'package.json' -and $textos[$rel] -and $textos[$rel] -match '"name"\s*:\s*"([^"]+)"') {
            $linha += "  (name: " + $Matches[1] + ")"
        }
        Write-Output $linha
    }
}
if ($projetosDotnet.Count -eq 0 -and $manifestos.Count -eq 0) {
    Write-Output "Nenhum manifesto de projeto reconhecido. Descubra build e testes pelo README/CI."
}

# ------------------------------------------------------------------ tokens ---
Write-Secao "TOKENS DO PROJETO ANTIGO"

if (-not $Token -or $Token.Count -eq 0) {
    $nomes = @($projetosDotnet | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) })
    if ($nomes.Count -gt 0) {
        # Maior prefixo comum por segmento: Foo.Bar.Api + Foo.Bar.Domain -> Foo.Bar.
        $comum = @($nomes[0] -split '\.')
        foreach ($n in $nomes) {
            $seg = @($n -split '\.')
            $i = 0
            while ($i -lt $comum.Count -and $i -lt $seg.Count -and $comum[$i] -ceq $seg[$i]) { $i++ }
            $comum = @($comum | Select-Object -First $i)
        }
        if ($nomes.Count -eq 1 -and $comum.Count -gt 1) { $comum = @($comum | Select-Object -First ($comum.Count - 1)) }
        if ($comum.Count -gt 0) {
            $Token = @($comum -join '.')
            Write-Output ("Token derivado do nome dos projetos: " + $Token[0])
        } else {
            Write-Output "Sem prefixo comum nos projetos .NET. Informe -Token explicitamente."
            Write-Output ("Projetos: " + ($nomes -join ", "))
        }
    }
    if ((-not $Token -or $Token.Count -eq 0)) {
        $pkgRaiz = 'package.json'
        if ($textos[$pkgRaiz] -and $textos[$pkgRaiz] -match '"name"\s*:\s*"([^"]+)"') {
            $Token = @($Matches[1] -replace '^@[^/]+/', '')
            Write-Output ("Token derivado do package.json da raiz: " + $Token[0])
        }
    }
}

$variantes = New-Object 'System.Collections.Generic.List[string]'
if ($Token -and $Token.Count -gt 0) {
    Write-Output "(Se o token derivado nao for o nome do sistema, reexecute com -Token.)"
    foreach ($t in $Token) {
        foreach ($v in (Get-Variantes $t)) { if (-not $variantes.Contains($v)) { $variantes.Add($v) } }
    }

    $ocorrem = New-Object 'System.Collections.Generic.List[string]'
    foreach ($v in $variantes) {
        $com = @($chaves | Where-Object { $textos[$_].Contains($v) })
        if ($com.Count -gt 0) { $ocorrem.Add($v) }
        Write-Output ""
        Write-Output ("Variante '" + $v + "' (caixa exata) aparece em " + $com.Count + " arquivo(s):")
        Write-Lista $com 25 '    '

        # Token curto colado a outras letras vira substituicao indevida (ex.: "rv" em "server").
        if ($v.Length -le 4 -and $com.Count -gt 0) {
            $re = '(?<=[A-Za-z0-9])' + [regex]::Escape($v) + '|' + [regex]::Escape($v) + '(?=[a-z])'
            $colados = @($com | Where-Object { [regex]::IsMatch($textos[$_], $re) })
            if ($colados.Count -gt 0) {
                Write-Output ("    [!!] '" + $v + "' aparece colado a outras letras em " + $colados.Count + " arquivo(s) - restrinja o padrao antes do rename:")
                Write-Lista $colados 10 '      '
            }
        }
    }

    $comTokenNoNome = @(@($arquivos) + @($pastas) | Where-Object {
        $n = $_.Name
        @($variantes | Where-Object { $n.IndexOf($_, [StringComparison]::OrdinalIgnoreCase) -ge 0 }).Count -gt 0
    } | ForEach-Object { Get-Rel $_.FullName } | Sort-Object -Unique)
    Write-Output ""
    Write-Output ("Pastas/arquivos cujo NOME contem o token (serao renomeados): " + $comTokenNoNome.Count)
    Write-Lista $comTokenNoNome 40 '    '

    Write-Output ""
    Write-Output "Sugestao de -Map para o Rename-Token.ps1 (preencha o lado direito; mais longos primeiro):"
    foreach ($v in $variantes) {
        if (-not $ocorrem.Contains($v) -and
            @($comTokenNoNome | Where-Object { $_.IndexOf($v, [StringComparison]::Ordinal) -ge 0 }).Count -gt 0) { $ocorrem.Add($v) }
    }
    $ordenadas = @($ocorrem | Sort-Object -Property Length -Descending)
    Write-Output ("    " + (($ordenadas | ForEach-Object { $_ + '=?' }) -join ';'))
}

# ---------------------------------------------------------------- encoding ---
Write-Secao "ENCODING (arquivos de texto que NAO sao UTF-8 valido)"

if ($naoUtf8.Count -eq 0) {
    Write-Output "Nenhum."
} else {
    Write-Output "Provavelmente Windows-1252/Latin-1. O Rename-Token.ps1 os trata byte a byte; nao use"
    Write-Output "ferramentas que reescrevem o arquivo inteiro como UTF-8:"
    Write-Lista $naoUtf8 40
}

# ------------------------------------------------------- pontos de entrada ---
Write-Secao "PONTOS DE ENTRADA"

$reSaude = '(?i)(^|/)(health|healthz|healthcheck|ping|status|version|liveness|readiness)(/|$)'

$rotas = New-Object 'System.Collections.Generic.List[object]'
foreach ($k in (Get-Textos @('.razor'))) {
    foreach ($m in [regex]::Matches($textos[$k], '(?m)^\s*@page\s+"([^"]*)"')) {
        $rotas.Add([pscustomobject]@{ Rota = $m.Groups[1].Value; Arquivo = $k })
    }
}
if ($rotas.Count -gt 0) {
    Write-Output ("Rotas Blazor (@page): " + $rotas.Count)
    Write-Lista (@($rotas | Sort-Object Rota | ForEach-Object { "{0,-40} {1}" -f $_.Rota, $_.Arquivo })) 60 '    '
    $raiz = @($rotas | Where-Object { $_.Rota -eq '/' })
    if ($raiz.Count -eq 0) {
        Write-Output "    [!!] Nenhuma pagina responde pela rota '/'."
    } else {
        Write-Output ("    Rota '/' pertence a: " + (($raiz | ForEach-Object { $_.Arquivo }) -join ", ") + " - se sair, crie uma pagina inicial.")
    }
}

$triggers = @{}
$qtdFuncoes = 0
$rotasFn = New-Object 'System.Collections.Generic.List[string]'
$temMapHealth = $false
foreach ($k in (Get-Textos @('.cs', '.fs', '.vb'))) {
    $t = $textos[$k]
    foreach ($m in [regex]::Matches($t, '\[\s*(\w+)Trigger\s*[\(\]]')) {
        $n = $m.Groups[1].Value
        $triggers[$n] = 1 + [int]$triggers[$n]
    }
    $qtdFuncoes += [regex]::Matches($t, '\[\s*Function(?:Name)?\s*\(\s*"').Count
    foreach ($m in [regex]::Matches($t, 'Route\s*=\s*"([^"]*)"')) { $rotasFn.Add($m.Groups[1].Value) }
    if ($t -match 'MapHealthChecks') { $temMapHealth = $true }
}
if ($qtdFuncoes -gt 0) {
    Write-Output ""
    Write-Output ("Azure Functions: $qtdFuncoes function(s). Triggers: " +
        ((@($triggers.Keys | Sort-Object) | ForEach-Object { $_ + '=' + $triggers[$_] }) -join ', '))
}
$saude = @(@($rotasFn) + @($rotas | ForEach-Object { $_.Rota }) | Where-Object { $_ -match $reSaude } | Sort-Object -Unique)
if ($temMapHealth) { $saude += 'MapHealthChecks' }
if ($qtdFuncoes -gt 0 -or $rotas.Count -gt 0 -or $temMapHealth) {
    Write-Output ""
    if ($saude.Count -gt 0) {
        Write-Output ("Rota de saude/versao encontrada: " + ($saude -join ', '))
        Write-Output "    Confira se ela e anonima em TODAS as camadas de autenticacao (inclusive middleware proprio)."
    } else {
        Write-Output "[!!] Nenhuma rota de saude. Se todos os pontos de entrada sairem, crie uma (GET /health anonima)."
    }
}
if ($qtdFuncoes -eq 0 -and $rotas.Count -eq 0 -and -not $temMapHealth) {
    Write-Output "Nenhum ponto de entrada .NET reconhecido. Identifique-os pelo guia da stack."
}

# ----------------------------------------------------------------- pacotes ---
Write-Secao "PACOTES DUPLICADOS NOS PROJETOS .NET"

$achouDup = $false
foreach ($c in $projetosDotnet) {
    $pkgs = [regex]::Matches($conteudoProjeto[$c.FullName], 'PackageReference\s+Include="([^"]+)"\s+Version="([^"]+)"')
    foreach ($g in ($pkgs | Group-Object { $_.Groups[1].Value } | Where-Object { $_.Count -gt 1 })) {
        $achouDup = $true
        $versoes = $g.Group | ForEach-Object { $_.Groups[2].Value }
        Write-Output ("  " + (Get-Rel $c.FullName) + " -> " + $g.Name + " : " + ($versoes -join ", "))
    }
}
if (-not $achouDup) { Write-Output "Nenhuma duplicata." }

# ------------------------------------------------ configuracao, CI e IaC ---
Write-Secao "CONFIGURACAO, CI/CD, IaC E CONTAINERS"

$cfg = @(); $ci = @(); $iac = @(); $cont = @()
foreach ($f in $arquivos) {
    $rel = Get-Rel $f.FullName
    $n = $f.Name
    # CI primeiro: um workflow chamado "application-prd.yml" nao e configuracao da aplicacao.
    if ($rel -match '^\.github[\\/]workflows[\\/]' -or
        $n -match '^(azure-pipelines.*\.ya?ml|\.gitlab-ci\.ya?ml|bitbucket-pipelines\.yml|Jenkinsfile)$' -or
        ($rel -match '(^|[\\/])(esteiras|pipelines|\.pipelines|\.azuredevops|\.circleci)[\\/]' -and $n -match '\.ya?ml$')) { $ci += $rel }
    elseif ($n -match '^(appsettings.*\.json|local\.settings\.json|host\.json|launchSettings\.json|serviceDependencies.*\.json|web\.config|application(-\w+)?\.(ya?ml|properties)|\.env.*)$') { $cfg += $rel }
    elseif ($n -match '\.(tf|tfvars|bicep|bicepparam)$' -or $n -match '\.tf\.json$' -or $n -match '^(Pulumi.*\.ya?ml|cdk\.json|azuredeploy.*\.json)$') { $iac += $rel }
    elseif ($n -match '^(Dockerfile.*|.*\.dockerfile|docker-compose.*\.ya?ml|compose\.ya?ml|Chart\.yaml)$') { $cont += $rel }
}
Write-Output "Configuracao:";  if ($cfg.Count)  { Write-Lista $cfg 40 '    ' }  else { Write-Output "    (nenhuma)" }
Write-Output "CI/CD:";         if ($ci.Count)   { Write-Lista $ci 40 '    ' }   else { Write-Output "    (nenhum)" }
Write-Output "IaC:";           if ($iac.Count)  { Write-Lista $iac 40 '    ' }  else { Write-Output "    (nenhuma no repositorio)" }
Write-Output "Containers:";    if ($cont.Count) { Write-Lista $cont 20 '    ' } else { Write-Output "    (nenhum)" }

$externos = New-Object 'System.Collections.Generic.List[string]'
foreach ($k in $ci) {
    if (-not $textos[$k]) { continue }
    foreach ($m in [regex]::Matches($textos[$k], '(?m)uses:\s*([^\s@#]+/\.github/workflows/[^\s@#]+)@')) { $externos.Add($m.Groups[1].Value) }
    foreach ($m in [regex]::Matches($textos[$k], '(?m)template:\s*([^\s#]+@[^\s#]+)')) { $externos.Add($m.Groups[1].Value) }
}
if ($externos.Count -gt 0) {
    Write-Output ""
    Write-Output "Templates de pipeline EXTERNOS (IaC/deploy fora deste repo; nomes de recurso saem dos inputs):"
    Write-Lista (@($externos | Sort-Object -Unique)) 20 '    '
}

$rastreados = @(Invoke-Git @('ls-files'))
if ($rastreados.Count -gt 0) {
    $indevidos = @($rastreados | Where-Object {
        $_ -match '(^|/)(local\.settings\.json|appsettings\.Development\.json|settings\.local\.json|\.env(\.[^/]*)?|[^/]+\.user)$' -and
        $_ -notmatch '\.env\.(example|sample|template)$'
    })
    if ($indevidos.Count -gt 0) {
        Write-Output ""
        Write-Output "[!!] Versionados, mas nao deveriam (segredo ou estado local) - tirar do controle e do .gitignore:"
        Write-Lista $indevidos 20 '    '
    }
}

# -------------------------------------------------- segredos e identidades ---
Write-Secao "SEGREDOS E IDENTIDADES (so nomes de chave - valores nunca sao exibidos)"

# Sensibilidade por PALAVRA do nome da chave (quebrada em PascalCase, _, -, :, .), nao por
# substring: "PctSalTit" nao contem "salt", mas "Jwt_SigningKey" e "Acs_ConnectionString" contam.
$palavrasSensiveis = @('secret', 'secrets', 'senha', 'password', 'passwd', 'pwd', 'passphrase', 'apikey',
                       'salt', 'pepper', 'jwt', 'vapid', 'webhook', 'token', 'dsn', 'thumbprint',
                       'certificate', 'cert', 'pfx', 'connectionstring', 'connectionstrings', 'appguid',
                       'privatekey', 'publickey', 'clientid', 'credential', 'credentials')
$paresSensiveis = @('api key', 'access key', 'private key', 'public key', 'client id', 'client secret',
                    'signing key', 'connection string', 'connection strings', 'instrumentation key',
                    'app guid', 'app id', 'crypto key', 'encryption key', 'account key', 'sas token')
function Test-Sensivel([string]$chave) {
    $w = @([regex]::Matches($chave, '[A-Z]+(?=[A-Z][a-z]|[^A-Za-z]|$)|[A-Z]?[a-z]+|[0-9]+') | ForEach-Object { $_.Value.ToLowerInvariant() })
    foreach ($x in $w) { if ($palavrasSensiveis -contains $x) { return $true } }
    for ($i = 0; $i -lt $w.Count - 1; $i++) { if ($paresSensiveis -contains ($w[$i] + ' ' + $w[$i + 1])) { return $true } }
    return $false
}
$sensiveis = @{}
function Add-Sensivel([string]$chave, [string]$arquivo) {
    if (-not $sensiveis.ContainsKey($chave)) { $sensiveis[$chave] = New-Object 'System.Collections.Generic.List[string]' }
    if (-not $sensiveis[$chave].Contains($arquivo)) { $sensiveis[$chave].Add($arquivo) }
}

# 1. Chaves lidas pelo codigo (config em arquivo, variavel de ambiente ou tabela no banco).
$reLeitura = @(
    '(?:GetValue<[^>]+>|GetSection|GetRequiredSection)\s*\(\s*"([^"]+)"',
    'Configuration\s*\[\s*"([^"]+)"\s*\]',
    'Environment\.GetEnvironmentVariable\s*\(\s*"([^"]+)"',
    '(?:process\.env|import\.meta\.env)\.([A-Za-z_][A-Za-z0-9_]*)',
    'os\.(?:environ(?:\.get)?|getenv)\s*[\[\(]\s*["'']([^"'']+)'
)
$chavesCodigo = @{}
foreach ($k in (Get-Textos @('.cs', '.fs', '.vb', '.razor', '.ts', '.tsx', '.js', '.jsx', '.mjs', '.py', '.go', '.java', '.kt'))) {
    $t = $textos[$k]
    foreach ($re in $reLeitura) {
        foreach ($m in [regex]::Matches($t, $re)) {
            $chave = $m.Groups[1].Value
            $chavesCodigo[$chave] = $true
            if (Test-Sensivel $chave) { Add-Sensivel $chave $k }
        }
    }
    foreach ($m in [regex]::Matches($t, 'GetConnectionString\s*\(\s*"([^"]+)"')) {
        $chave = 'ConnectionStrings:' + $m.Groups[1].Value
        $chavesCodigo[$chave] = $true
        Add-Sensivel $chave $k
    }
}

# 2. Chaves declaradas em arquivos de configuracao.
foreach ($k in $cfg) {
    if (-not $textos[$k]) { continue }
    $re = '"([A-Za-z0-9_.:\-]+)"\s*:'
    if ([System.IO.Path]::GetFileName($k) -like '.env*') { $re = '(?m)^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=' }
    foreach ($m in [regex]::Matches($textos[$k], $re)) {
        if (Test-Sensivel $m.Groups[1].Value) { Add-Sensivel $m.Groups[1].Value $k }
    }
}

# 3. Segredos referenciados pelo CI (precisam ser cadastrados no repositorio novo).
foreach ($k in $ci) {
    if (-not $textos[$k]) { continue }
    foreach ($m in [regex]::Matches($textos[$k], 'secrets\.([A-Za-z0-9_]+)')) { Add-Sensivel ('secrets.' + $m.Groups[1].Value) $k }
}

# 4. Onde os scripts SQL semeiam essas chaves (config guardada em tabela) ou declaram variaveis sensiveis.
$sensiveisCodigo = @($chavesCodigo.Keys | Where-Object { (Test-Sensivel $_) -and $_ -notlike 'ConnectionStrings:*' })
foreach ($k in (Get-Textos @('.sql'))) {
    $t = $textos[$k]
    foreach ($chave in $sensiveisCodigo) { if ($t.Contains($chave)) { Add-Sensivel $chave $k } }
    foreach ($m in [regex]::Matches($t, '(?i)DECLARE\s+@([A-Za-z_][A-Za-z0-9_]*)')) {
        if (Test-Sensivel $m.Groups[1].Value) { Add-Sensivel ('@' + $m.Groups[1].Value) $k }
    }
}

# 5. IaC.
foreach ($k in $iac) {
    if (-not $textos[$k]) { continue }
    foreach ($m in [regex]::Matches($textos[$k], '(?m)^\s*"?([A-Za-z0-9_\-]+)"?\s*[=:]')) {
        if (Test-Sensivel $m.Groups[1].Value) { Add-Sensivel $m.Groups[1].Value $k }
    }
}

if ($sensiveis.Count -eq 0) {
    Write-Output "Nenhuma chave sensivel reconhecida. Revise a configuracao a mao mesmo assim."
} else {
    Write-Output "Candidatos a REGENERAR (nao renomear) - chave <- onde aparece:"
    $linhas = @($sensiveis.Keys | Sort-Object | ForEach-Object {
        $locais = $sensiveis[$_]
        $txt = (@($locais | Select-Object -First 3) -join ', ')
        if ($locais.Count -gt 3) { $txt += " (+" + ($locais.Count - 3) + ")" }
        "{0,-40} <- {1}" -f $_, $txt
    })
    Write-Lista $linhas 80 '    '
}
if ($chavesCodigo.Count -gt 0) {
    Write-Output ""
    Write-Output ("Chaves de configuracao lidas pelo codigo: " + $chavesCodigo.Count + " (a lista completa vai para o relatorio de pendencias).")
    if ($variantes.Count -gt 0) {
        $comSigla = @($chavesCodigo.Keys | Where-Object { $ch = $_; @($variantes | Where-Object { $ch.IndexOf($_, [StringComparison]::OrdinalIgnoreCase) -ge 0 }).Count -gt 0 } | Sort-Object)
        if ($comSigla.Count -gt 0) {
            Write-Output "Chaves com a sigla antiga no nome (sao identificadores, entram no rename):"
            Write-Lista $comSigla 40 '    '
        }
    }
}

# ---------------------------------------------------- dominios e integracoes ---
Write-Secao "DOMINIOS COM O TOKEN (integracoes a reconfigurar fora do repositorio)"

$hosts = @{}
$tlds = 'com|net|org|io|app|dev|br|cloud|ai|co|me|info|biz|us|eu|pt|tech|site|online|store|xyz'
$varHost = @($variantes | Where-Object { $_ -ceq $_.ToLowerInvariant() -and $_ -notmatch '[_ ]' })
foreach ($v in $varHost) {
    $re = '(?<![A-Za-z0-9.-])((?:[a-z0-9-]+\.)*[a-z0-9-]*' + [regex]::Escape($v) + '[a-z0-9-]*(?:\.[a-z0-9-]+)*\.(?:' + $tlds + '))(?![A-Za-z0-9-])'
    foreach ($k in $chaves) {
        foreach ($m in [regex]::Matches($textos[$k], $re)) {
            $h = $m.Groups[1].Value
            if (-not $hosts.ContainsKey($h)) { $hosts[$h] = New-Object 'System.Collections.Generic.List[string]' }
            if (-not $hosts[$h].Contains($k)) { $hosts[$h].Add($k) }
        }
    }
}
if ($hosts.Count -eq 0) {
    Write-Output "Nenhum dominio com o token."
} else {
    Write-Output "O rename troca o texto, mas o outro lado (DNS, provedor OAuth, webhook, e-mail, CORS) nao existe:"
    Write-Lista (@($hosts.Keys | Sort-Object | ForEach-Object { "{0,-45} {1} arquivo(s)" -f $_, $hosts[$_].Count })) 40 '    '
}

# ------------------------------------------------------------------- banco ---
Write-Secao "BANCO DE DADOS"

$sql = @($arquivos | Where-Object { $_.Extension -eq '.sql' })
if ($sql.Count -gt 0) {
    Write-Output ("Scripts .sql: " + $sql.Count)
    foreach ($g in ($sql | Group-Object { Get-Rel $_.DirectoryName } | Sort-Object Name)) {
        $nomeDir = $g.Name; if (-not $nomeDir) { $nomeDir = '.' }
        Write-Output ("    {0,-50} {1}" -f $nomeDir, $g.Count)
    }
}
$snapshots = @($arquivos | Where-Object { $_.Name -like '*ModelSnapshot.cs' } | ForEach-Object { Get-Rel $_.DirectoryName })
if ($snapshots.Count -gt 0) { Write-Output "Migrations do EF Core:"; Write-Lista $snapshots 10 '    ' }
$pastasMig = @($pastas | Where-Object { $_.Name -match '^(?i)(migrations?|migrate)$' } | ForEach-Object { Get-Rel $_.FullName })
if ($pastasMig.Count -gt 0) { Write-Output "Pastas de migration:"; Write-Lista $pastasMig 10 '    ' }
$ferramentasMig = @($arquivos | Where-Object { @('alembic.ini', 'schema.prisma', 'flyway.conf', 'liquibase.properties', 'knexfile.js', 'knexfile.ts') -contains $_.Name } | ForEach-Object { Get-Rel $_.FullName })
if ($ferramentasMig.Count -gt 0) { Write-Output "Ferramentas de migration:"; Write-Lista $ferramentasMig 10 '    ' }
if ($sql.Count -eq 0 -and $snapshots.Count -eq 0 -and $pastasMig.Count -eq 0 -and $ferramentasMig.Count -eq 0) {
    Write-Output "Nenhum artefato de banco no repositorio."
}

# ------------------------------------------------------ artefatos e versao ---
Write-Secao "ARTEFATOS DE AGENTE, DOCUMENTACAO, VERSAO, MARCA E GIT"

$instrucoes = @($arquivos | Where-Object {
    @('CLAUDE.md', 'CLAUDE.local.md', 'AGENTS.md', 'GEMINI.md', '.cursorrules', '.windsurfrules', 'copilot-instructions.md') -contains $_.Name
} | ForEach-Object { Get-Rel $_.FullName })
Write-Output "Instrucoes de agente (descrevem o projeto antigo - reescrever):"
if ($instrucoes.Count) { Write-Lista $instrucoes 20 '    ' } else { Write-Output "    (nenhuma)" }

$ocultasRaiz = @((New-Object System.IO.DirectoryInfo $root).GetDirectories() | Where-Object {
    $_.Name.StartsWith('.') -and @('.git', '.github', '.vs', '.vscode', '.idea') -notcontains $_.Name
} | ForEach-Object { $_.Name })
if ($ocultasRaiz.Count -gt 0) {
    Write-Output "Pastas ocultas na raiz (agentes/ferramentas - revisar; nao entram no rename):"
    Write-Lista $ocultasRaiz 20 '    '
}
$pastaClaude = Join-Path $root '.claude'
if (Test-Path -LiteralPath $pastaClaude) {
    $filhosClaude = @(Get-ChildItem -LiteralPath $pastaClaude -Force | ForEach-Object { $_.Name })
    Write-Output ("    .claude contem: " + ($filhosClaude -join ', '))
    $wt = Join-Path $pastaClaude 'worktrees'
    if (Test-Path -LiteralPath $wt) {
        $qtdWt = @(Get-ChildItem -LiteralPath $wt -Directory -Force).Count
        if ($qtdWt -gt 0) { Write-Output "    [!!] .claude/worktrees tem $qtdWt copia(s) do repositorio antigo - apague antes do rename." }
    }
}

$docs = @($arquivos | Where-Object { $_.Name -match '^(?i)(CHANGELOG|HISTORY|RELEASE[-_]?NOTES|NOVIDADES|LICENSE|CODEOWNERS)(\..*)?$' } | ForEach-Object { Get-Rel $_.FullName })
if ($docs.Count -gt 0) { Write-Output "Changelog, licenca e donos:"; Write-Lista $docs 20 '    ' }

$versoes = New-Object 'System.Collections.Generic.List[string]'
foreach ($c in $projetosDotnet) {
    foreach ($m in [regex]::Matches($conteudoProjeto[$c.FullName], '<(AssemblyVersion|FileVersion|Version|VersionPrefix|InformationalVersion)>([^<]+)<')) {
        $versoes.Add(("{0,-22} {1,-20} {2}" -f $m.Groups[1].Value, $m.Groups[2].Value, (Get-Rel $c.FullName)))
    }
}
foreach ($m in $manifestos) {
    $rel = Get-Rel $m.FullName
    if ($m.Name -eq 'package.json' -and $textos[$rel] -and $textos[$rel] -match '"version"\s*:\s*"([^"]+)"') {
        $versoes.Add(("{0,-22} {1,-20} {2}" -f 'version', $Matches[1], $rel))
    }
}
if ($versoes.Count -gt 0) { Write-Output "Carimbos de versao (zerar no projeto novo):"; Write-Lista $versoes 30 '    ' }

$marca = @($arquivos | Where-Object {
    @('.png', '.jpg', '.jpeg', '.ico', '.svg', '.webp', '.gif') -contains $_.Extension.ToLowerInvariant() -and
    $_.Name -match '(?i)logo|icon|favicon|brand|marca|splash|og[-_]|apple-touch'
} | ForEach-Object { Get-Rel $_.FullName })
if ($marca.Count -gt 0) {
    Write-Output ("Assets de marca (binarios - o rename nao os toca; substituir): " + $marca.Count)
    Write-Lista $marca 20 '    '
}

if ($temGitRepo -and $temGit) {
    $branch  = @(Invoke-Git @('rev-parse', '--abbrev-ref', 'HEAD')) | Select-Object -First 1
    $commits = @(Invoke-Git @('rev-list', '--count', 'HEAD')) | Select-Object -First 1
    $tags    = @(Invoke-Git @('tag', '--list')).Count
    $wts     = @(Invoke-Git @('worktree', 'list')).Count
    # Tira credencial embutida na URL do remote (https://usuario:token@host).
    $remotes = @(Invoke-Git @('remote', '-v') | ForEach-Object { $_ -replace '://[^@/\s]+@', '://' } | Sort-Object -Unique)
    Write-Output "Git:"
    Write-Output ("    branch: $branch | commits: $commits | tags: $tags | worktrees: $wts")
    Write-Lista $remotes 6 '    remote: '
} elseif ($temGitRepo) {
    Write-Output "Git: repositorio presente, mas o executavel git nao esta no PATH."
} else {
    Write-Output "Git: sem .git na raiz."
}

# ------------------------------------------------------------------- fecho ---
Write-Secao "RESUMO"
Write-Output ("Raiz                 : $root")
Write-Output ("Arquivos percorridos : " + $arquivos.Count + " (ignoradas: " + ($ExcludeDir -join ', ') + ")")
Write-Output ("Arquivos de texto    : " + $textos.Count)
Write-Output ("Projetos .NET        : " + $projetosDotnet.Count + " | outros manifestos: " + $manifestos.Count)
Write-Output ("Nao-UTF-8            : " + $naoUtf8.Count)
Write-Output ("Chaves sensiveis     : " + $sensiveis.Count + " | dominios com token: " + $hosts.Count)
Write-Output ""
Write-Output "Proximo passo: classificar fica / sai / fronteira / regenerar e apresentar o plano."
