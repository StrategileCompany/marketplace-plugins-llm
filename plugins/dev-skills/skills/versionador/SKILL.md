---
name: versionador
description: >-
  Atualiza o numero de versao (formato yyyy.MM.dd.HHmm, baseado em data/hora)
  de assemblies .NET (.csproj) e de arquivos HTML/JavaScript/webmanifest num
  projeto C#/.NET e, por padrao, tambem faz commit e push na branch ativa. Use
  SEMPRE que o usuario pedir para "atualizar versao", "atualiza versao", "subir/bump a versao",
  "carimbar versao", "versionar", "versionador", "atualizar versao + commit",
  "atualizar versao + commit + push" ou variacoes, mesmo sem citar o nome da
  skill. Reconheca tambem o formato curto por palavras-chave separadas por
  virgula: "versao", "versao, commit", "versao, commit, push". O modo padrao e
  update + commit + push, e inclui criar e enviar a tag `v<versao>` e gerar as
  notas da versao (CHANGELOG + Novidades) acionando a skill release-notes
  antes do commit. O usuario pode restringir o escopo ("sem commit", "sem
  push", "so atualiza") ou pular partes ("sem tag", "sem novidades"/"sem
  changelog").
---

# Atualizacao de versao .NET (yyyy.MM.dd.HHmm)

Esta skill carimba uma nova versao baseada em data/hora em projetos C#/.NET e,
conforme o pedido, registra no git.

## Formato da versao

`yyyy.MM.dd.HHmm` no fuso **America/Sao_Paulo** (ex.: `2026.06.14.0048`).
O ultimo bloco e `HHmm` (hora+minuto, 24h, com zero a esquerda). A versao e
sempre gerada a partir do momento atual — nao invente nem reaproveite valores.

## Modo padrao e restricoes (detecte pela frase do usuario)

**O modo padrao e `update + commit + push`.** Um pedido generico — "versionar",
"versiona", "atualiza a versao", "carimba a versao", "versao", "versao, commit,
push" — dispara os **tres** passos: troca a versao nos arquivos, commita e faz
push na branch ativa. Na duvida sobre o escopo, siga o padrao (os tres passos).

So faca **menos** que isso quando o usuario **restringir explicitamente** o
escopo. A restricao corta do fim para o comeco (push, depois commit):

| O usuario pediu...                                          | Modo                       | Acoes                              |
|-------------------------------------------------------------|----------------------------|------------------------------------|
| pedido generico / "versao, commit, push" (**padrao**)       | **update + commit + push** | troca + commit + push branch ativa |
| "sem push" / "so versao e commit" / "versao, commit"        | **update + commit**        | troca + `git commit`               |
| "sem commit" / "so atualiza a versao" / "nao commite"       | **update**                 | troca a versao nos arquivos        |

Mesmo no padrao, o push e irreversivel: mostre branch + commit e **confirme antes
de enviar** (passo 5).

Alem dos tres passos, o **padrao** tambem **gera as notas da versao** (passo 3,
via skill `release-notes`, antes do commit — pra entrarem no mesmo commit) e
**cria/envia a tag** `v<versao>` (passo 6). Pule com **"sem novidades"/"sem
changelog"** (nao gera notas) e **"sem tag"** (nao cria tag). Restringir a
**update**/**sem push** tambem nao cria a tag (nada e enviado).

## Passo a passo

### 1. Localize a raiz do projeto
Use o diretorio que o usuario indicou; se nao indicou, use o repositorio/pasta
atual. Confirme rapidamente qual e a raiz se houver ambiguidade.

### 2. Rode o script de substituicao (PowerShell)
O script gera a versao nova, detecta a atual no `<AssemblyVersion>` dos `.csproj` e
substitui nos arquivos que carregam versao por definicao (`.csproj`, `.props`,
`.targets`, `.js`, `.ts`, `.html`, `.webmanifest`, `.json`, `.config`, `.xml`) —
cada um sai como `CHANGED`. Arquivos de prosa e de codigo (`.md`, `.txt`, `.yml`,
`.cs`, `.razor`, `.css`) nao sao alterados.

Ignora `bin/`, `obj/`, `.git/`, `.claude/`, `node_modules/` etc. A troca e feita a
nivel de bytes, preservando encoding/BOM. Funciona no Windows PowerShell 5.1 (ja
incluso no Windows) e no PowerShell 7.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}/scripts/Update-Version.ps1" -Root "<raiz_do_projeto>"
```

> **Fora do Claude Code** (GitHub Copilot, por exemplo) a variavel `${CLAUDE_SKILL_DIR}` **nao** e
> substituida e o comando quebra sem erro claro. Troque-a pelo caminho da pasta desta skill — o
> `scripts/` fica ao lado do `SKILL.md`.

Observacoes:
- Use `powershell` (5.1) ou `pwsh` (7) — ambos funcionam.
- `-NoProfile -ExecutionPolicy Bypass` evita bloqueio por politica de execucao.
- Parametros uteis: `-Version <yyyy.MM.dd.HHmm>` (forca a nova), `-Current
  <versao>` (forca a antiga, util quando ha `.csproj` divergentes), `-TimeZone`
  (default `America/Sao_Paulo`).

Saida relevante (separada por TAB):
- `VERSAO_ANTIGA` / `VERSAO_NOVA` — mostre ao usuario.
- `CHANGED\t<caminho>\t<n>` — uma linha por arquivo alterado. Use para mostrar
  ao usuario exatamente o que mudou.
- `NADA_A_FAZER` (exit 3) — antiga == nova (mesma minuto) ou versao nao
  encontrada. Informe o usuario e pare; nao commite nada.
- Saida de erro (exit 2) — versao ambigua (varios `.csproj` com versoes
  diferentes) ou formato invalido. Mostre o aviso e peca para o usuario decidir;
  voce pode reexecutar passando `-Current <versao_antiga>` para escolher qual
  substituir, ou `-Version <yyyy.MM.dd.HHmm>` para forcar a nova.

Apresente ao usuario um resumo curto: versao antiga → nova e a lista de arquivos
tocados.

### 3. Acione a skill de Release notes — CHANGELOG + Novidades (faz parte do padrao)
Antes de commitar, acione a skill **release-notes** em **modo integrado** para
gerar/atualizar o `CHANGELOG.md` (raiz) e as **Novidades** do usuario a partir dos
commits desde a ultima versao (intervalo por tag `v*`, com fallback nos commits de
deploy). Como roda **antes** do commit, esses arquivos entram no **mesmo commit**
do bump (o `git add -A` do passo 4 os inclui).

Pule este passo se o usuario restringiu a **update** apenas, ou disse **"sem
novidades"/"sem changelog"**. A release-notes e agnostica e degrada sozinha: sem
item de usuario no intervalo, gera so o CHANGELOG; sem local de Novidades
configurado, pergunta uma vez e guarda na memoria do projeto. Ela apresenta o
rascunho, mas **nao commita** — quem commita e este passo 4.

### 4. Commit (faz parte do padrao)
Faca sempre, exceto se o usuario restringiu a **update** ("sem commit" / "so
atualiza"). Use `git add -A` (adiciona tudo). Como isso pode incluir alteracoes
nao relacionadas, **sempre rode `git status` antes e mostre ao usuario o que sera
commitado** — se aparecer algo inesperado, avise antes de prosseguir.

```bash
git -C <raiz> status --short        # mostre ao usuario o que sera commitado
git -C <raiz> add -A
git -C <raiz> commit -m "deploy: atualiza versão para <VERSAO_NOVA>"
```

A mensagem do commit e sempre, literalmente:
`deploy: atualiza versão para <VERSAO_NOVA>` (com o numero real, ex.:
`deploy: atualiza versão para 2026.06.14.0048`).

### 5. Push para a branch ativa (faz parte do padrao)
Faca sempre, exceto se o usuario restringiu a **update** ou **update + commit**
("sem push"). Antes, **mostre um resumo e confirme** — push e irreversivel:

```bash
git -C <raiz> rev-parse --abbrev-ref HEAD     # descobre a branch ativa
```

Mostre ao usuario: branch ativa, versao nova e o commit que sera enviado. Apos o
"ok":

```bash
git -C <raiz> push                # se ja existe upstream
# se nao houver upstream configurado para a branch:
git -C <raiz> push -u origin <branch_ativa>
```

Se o push falhar (sem upstream, rejeitado, credenciais), explique o erro ao
usuario em vez de tentar contornar.

### 6. Tag da versao (faz parte do padrao)
Depois do push do commit, crie e envie a tag `v<VERSAO_NOVA>` — ela aponta para o
commit do bump e **ancora o intervalo** da proxima `release-notes`. Faca sempre no
padrao; pule se o usuario restringiu a **update**/**update + commit** (sem push) ou
disse **"sem tag"**.

```bash
git -C <raiz> tag "v<VERSAO_NOVA>"
git -C <raiz> push origin "v<VERSAO_NOVA>"
```

Se a tag ja existir (reexecucao no mesmo minuto), avise e nao recrie. Se o repo tem
uma tag de versao criada por outra automacao (ex.: pipeline), alinhe com o usuario
para nao duplicar.

## Regras importantes

- O **padrao** e `update + commit + push`. So reduza o escopo quando o usuario
  restringir explicitamente ("sem commit", "sem push", "so atualiza a versao").
- A restricao corta do fim para o comeco: "sem push" = update + commit; "sem
  commit" (ou "so atualiza") = update apenas.
- Push e irreversivel: mesmo no padrao, mostre branch + commit e confirme antes
  de enviar.
- As **notas** (passo 3, via `release-notes`) e a **tag** `v<versao>` (passo 6)
  fazem parte do padrao. Pule com "sem novidades"/"sem changelog" e "sem tag";
  restringir a update/sem push tambem nao cria a tag. As notas rodam **antes** do
  commit pra entrarem no mesmo commit do bump.
- A tag `v<versao>` ancora o intervalo da proxima `release-notes`; nao a recrie se
  ja existir (reexecucao no mesmo minuto ou tag criada por pipeline).
- Sempre mostre versao antiga → nova e os arquivos afetados antes de seguir.
- Se a deteccao for ambigua, pergunte; nao adivinhe qual versao substituir.
- A versao e sempre o timestamp atual; nao reutilize um valor de execucao anterior.
- **Nao carimbe fora do escopo.** O script ja ignora `.claude/` (worktrees de
  outras branches), `bin/`, `obj/`, `node_modules/`. Se `CHANGED` listar caminho
  fora do projeto que o usuario pediu, pare e avise.

## Exemplos

**Exemplo 1 — padrao (update + commit + push)**
Pedido: "versiona o projeto" (ou "atualiza a versão", "versão, commit, push")
Acao: roda o script, mostra antiga→nova e arquivos, faz `git add -A` e commita com
`deploy: atualiza versão para 2026.06.14.0048`, mostra branch + commit, confirma e
faz push na branch ativa.

**Exemplo 2 — restringido a update + commit (sem push)**
Pedido: "atualiza a versão e commita, mas não pusha"
Acao: roda o script, mostra `git status`, commita. Sem push.

**Exemplo 3 — restringido a update (só o número)**
Pedido: "só atualiza o número da versão, não commite"
Acao: roda o script, mostra antiga→nova e arquivos. Sem git.
