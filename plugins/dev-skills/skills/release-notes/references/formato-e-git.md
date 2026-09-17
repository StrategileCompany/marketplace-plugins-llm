# Intervalo, commits, modelos e local das Novidades

Tudo aqui é **genérico** (qualquer repo). Nada de caminho/nome de projeto fixo.

## 1. Detectar o intervalo da versão
A versão é ancorada em **tags** `v*` (o `versionador` cria `v<versão>` a cada release). Fallback: os
commits de bump (`deploy: atualiza versão para ...`).

```bash
# tags de versão, mais recente primeiro:
git tag --list 'v*' --sort=-creatordate | head -5
```

- **Modo integrado** (chamado pelo `versionador`, **antes** do novo commit/tag):
  ```bash
  PREV=$(git tag --list 'v*' --sort=-creatordate | head -1)   # última tag existente
  RANGE="${PREV:+$PREV..}HEAD"                                  # PREV..HEAD, ou HEAD se não houver tag
  ```
  Sem nenhuma tag → fallback pelo último commit de deploy:
  ```bash
  PREV=$(git log --grep '^deploy: atualiza versão' -n 1 --format=%H)
  RANGE="${PREV:+$PREV..}HEAD"
  ```
- **Modo avulso** (versão já tagueada): use as **duas últimas** tags.
  ```bash
  PREV=$(git tag --list 'v*' --sort=-creatordate | sed -n '2p')
  LAST=$(git tag --list 'v*' --sort=-creatordate | sed -n '1p')
  RANGE="$PREV..$LAST"
  ```

A **versão nova**: no integrado, o `versionador` te passa `VERSAO_NOVA`; no avulso, derive da última tag
(`v2026.06.14.0048` → `2026.06.14.0048`) ou do `<Version>` no `.csproj`. A **data** de exibição pode sair
da própria versão quando ela é `yyyy.MM.dd.*`; senão, use a data do último commit do intervalo
(`git log -1 --format=%ad --date=short <ref>`).

## 2. Coletar e parsear os commits
```bash
# hash \t subject \t body(1ª linha) — sem merges:
git log "$RANGE" --no-merges --format='%H%x09%s%x09%b%x1e'
```
Cada commit: **subject** = `tipo(escopo): descrição`; **body** = parágrafo de negócio (1º parágrafo) +
bullets. Extraia:
- `tipo` (feat/fix/perf/refactor/chore/test/docs/ci/build/style/revert) e `escopo` do subject.
- issue: `#N` do subject `(#N)` ou do body `Refs: #N`.
- **texto de usuário** (Novidades): o **1º parágrafo do body** (parágrafo de negócio). Se vazio/fraco,
  caia pro título da issue (`gh issue view N --json title`) ou pro subject.

Enriquecer por issue (opcional, degrade se não houver `gh`):
```bash
gh issue view <N> --json title,type --jq '{title:.title, type:.type.name}'
```

## 3. Roteamento por tipo (a régua)
- `feat` → CHANGELOG **Adicionado** + **Novidades**.
- `fix` → CHANGELOG **Corrigido**; Novidades **só se o usuário percebe**.
- `perf` → CHANGELOG **Desempenho**; Novidades se perceptível.
- `refactor|chore|test|docs|ci|build|style` → CHANGELOG **Interno**; **nunca** Novidades.
- `revert` → CHANGELOG **Revertido**.
- `deploy:` (bump) e merges → **ignorar** nos dois.

Agrupe por issue: vários commits do mesmo `#N` viram **um** item (use o melhor texto).

## 4. Modelo — CHANGELOG.md (raiz do repo)
*Keep a Changelog*, mais recente no topo. Crie o arquivo se não existir (com o cabeçalho). Um bloco por
versão; se o bloco da versão já existe, **substitua-o** (idempotente).

```markdown
# Changelog

Todas as mudanças notáveis deste projeto são documentadas aqui.
Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/).

## [<versão>] - <data>
### Adicionado
- <descrição curta> (#<N>)
### Corrigido
- <descrição curta> (#<N>)
### Desempenho
- <descrição curta> (#<N>)
### Interno
- <descrição curta> (#<N>)
```
Omita seções vazias. `<data>` no formato `AAAA-MM-DD`.

## 5. Modelo — Novidades (local da memória do projeto)
Acumulativo, mais recente no topo, **linguagem de usuário** e na **voz do produto**. Só acrescente um
bloco se houver ao menos um item de usuário (feat/fix visível). Nunca um bloco vazio.

```markdown
# Novidades

## <data amigável> — v<versão>
- <benefício em linguagem simples: o que o usuário agora consegue/ganhou>
- <outro benefício>
```
Sem jargão técnico (nada de "cache", "endpoint", "refatoração"). Curto e direto. Respeite o tom do
produto (leia `CLAUDE.md`/`AGENTS.md`/README — ex.: minimalista, sem emoji).

## 6. Local das Novidades (memória do projeto — genérico)
1. **Leia** a memória do projeto de slug `projeto-novidades-local`. Se houver, use o caminho de lá.
2. **Senão, descubra**: procure uma pasta de site/landing/docs publicável no repo, por exemplo:
   ```bash
   find . -maxdepth 3 -type d \( -iname '*landing*' -o -iname 'site' -o -iname 'www' -o -iname 'docs' \) \
     -not -path '*/node_modules/*' -not -path '*/.git/*'
   ```
   Proponha um caminho (ex.: `<pasta-do-site>/novidades/novidades.md`) e **confirme com o usuário**.
   Sem candidato, sugira `docs/novidades/novidades.md`.
3. **Grave** a escolha na memória (para não perguntar de novo):
   ```markdown
   ---
   name: projeto-novidades-local
   description: Caminho do arquivo de Novidades (What's new) do usuário final neste projeto.
   metadata:
     node_type: memory
     type: project
   ---

   As Novidades (What's new) deste repositório são escritas em `<caminho relativo>` (acumulativo, mais
   recente no topo), renderizadas pela página de novidades do site. Usado pela skill [[release-notes]].
   ```
   E adicione o ponteiro no `MEMORY.md`.

## 7. Degradação graciosa
- **Sem tags** → use os commits `deploy:` como marcos; se nem isso, gere desde o início do histórico
  (ou pergunte o ponto de corte).
- **Sem `gh`/repo** → não enriquece por issue; usa subject/parágrafo de negócio do commit.
- **Sem local de Novidades** e usuário não quer definir → gere só o CHANGELOG e avise.
- **Nada de usuário no intervalo** → CHANGELOG sim, Novidades não (informe que não houve item visível).
