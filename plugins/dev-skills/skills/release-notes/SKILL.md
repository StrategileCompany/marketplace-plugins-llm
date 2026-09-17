---
name: release-notes
description: >-
  Gera as notas de uma nova versão a partir dos commits do intervalo, em DOIS documentos para DOIS
  públicos: um CHANGELOG técnico (raiz do repo, toda versão, agrupado por tipo) e um documento de
  "Novidades"/"What's new" para o usuário final (linguagem simples, só o que ele percebe, acumulativo).
  Lê o intervalo entre as duas últimas versões (tags `v*`, com fallback para os commits de deploy),
  filtra por tipo de Conventional Commit, agrupa por issue e usa o parágrafo de negócio do commit como
  texto para o usuário. Funciona em QUALQUER repositório: o local das Novidades é descoberto em runtime
  e guardado na memória do projeto (nada é hardcoded). Use quando o usuário disser "gera release notes",
  "notas da versão", "novidades", "what's new", "changelog", "o que mudou nesta versão", ou logo após
  versionar (a skill `versionador` a aciona antes do commit do bump). NUNCA escreve sem confirmação.
---

# Release notes → CHANGELOG técnico + Novidades para o usuário

## Missão
Transformar os **commits de uma versão** em comunicação. São **dois públicos, dois documentos**:

| Documento | Público | Conteúdo | Onde vive |
|-----------|---------|----------|-----------|
| **CHANGELOG** | dev/você | **tudo** que mudou, por tipo, com `#N` | `CHANGELOG.md` na raiz do repo |
| **Novidades** ("What's new") | usuário final | **só o que ele percebe** (feat/fix visível), em linguagem simples | local configurável (memória do projeto) |

A matéria-prima já existe nos commits: o **parágrafo de negócio** vira a Novidade; o **subject + tipo**
viram a linha do CHANGELOG.

## Agnóstica de projeto (regra dura)
Nada de caminho/repo/org fixo. O **local das Novidades** é descoberto em runtime e guardado na
**memória do projeto** (slug `projeto-novidades-local`), igual ao *core business* da `prioriza-backlog`.
Detalhes e comandos em `references/formato-e-git.md`.

## Modos
- **Integrado (chamado pelo `versionador`):** roda **antes do commit do bump**, gera/atualiza os dois
  arquivos para a nova versão e **não commita** — o `versionador` commita tudo junto (bump + notas) e a
  confirmação de push dele cobre. Apresente o rascunho, sem pedir "ok" próprio.
- **Avulso:** o usuário pede as notas de uma versão já existente. Detecta o intervalo pelos dois últimos
  marcos, **confirma**, escreve os arquivos e pergunta se commita.

## Como gerar
1. **Descubra o intervalo** (comandos em `references/formato-e-git.md`):
   - Integrado: `<última tag v*>..HEAD` (fallback: último commit `deploy:` → `..HEAD`).
   - Avulso: entre as **duas últimas tags** `v*` (ou dois últimos commits de deploy).
   - Pegue também a **versão nova** (o `versionador` te passa; ou derive da tag/`.csproj`).
2. **Colete os commits** do intervalo (`--no-merges`), com subject **e** corpo.
3. **Classifique cada commit** pelo tipo de Conventional Commit e roteie (rubrica abaixo).
4. **Agrupe por issue** (`#N` / `Refs: #N`): colapsa vários commits da mesma issue. Opcional: enriqueça
   com `gh issue view N --json title,type` pra dar título melhor (degrade se não houver `gh`/repo).
5. **Redija:**
   - **CHANGELOG:** subject enxuto por item, com `(#N)`, agrupado por seção.
   - **Novidades:** o **parágrafo de negócio** do commit em linguagem de usuário, na **voz do produto**
     (leia `CLAUDE.md`/`AGENTS.md`/README pra tom; sem jargão técnico, sem "refatorou/cache/endpoint").

## A régua (tipo → onde entra)
| Tipo do commit | CHANGELOG | Novidades (usuário) |
|---|---|---|
| `feat` | **Adicionado** | ✅ sim |
| `fix` | **Corrigido** | ✅ só se o usuário percebe (senão, não) |
| `perf` | **Desempenho** | ✅ se perceptível |
| `refactor` `chore` `test` `docs` `ci` `build` `style` | **Interno** (seção recolhida) | ❌ nunca |
| `revert` | **Revertido** | ❌ (a menos que reverta algo que o usuário via) |
| commit `deploy:` do bump, merges | ❌ ignora | ❌ ignora |

Na dúvida se um `fix` é visível ao usuário, **inclua no CHANGELOG e deixe fora das Novidades**, e
**sinalize** pra revisão. Não invente novidade que o usuário não sente.

## Onde e como escrever
1. **CHANGELOG.md** (raiz do repo) — estilo *Keep a Changelog*, **mais recente no topo**; um bloco por
   versão. Se não existir, crie com cabeçalho. Idempotente: se o bloco da versão já existe, substitua-o.
2. **Novidades** (local da memória do projeto) — **acumulativo**, mais recente no topo. **Só escreve um
   bloco novo se houver item de usuário** — versão só com `chore`/interno **não** gera bloco de Novidades
   (não spamar o usuário). Se o local não estiver na memória, **descubra/pergunte uma vez e grave** (ver
   `references/formato-e-git.md`).

Modelos exatos dos dois arquivos em `references/formato-e-git.md`.

## Fluxo de trabalho
1. Detecte modo (integrado × avulso), intervalo e versão nova.
2. Colete e classifique os commits; agrupe por issue.
3. Monte os **dois rascunhos** (CHANGELOG + Novidades) e **apresente**.
4. **Avulso:** confirme → escreva → pergunte se commita. **Integrado:** entregue os arquivos escritos ao
   `versionador` (ele commita); não peça confirmação própria.
5. **Reporte** o que gerou (versão, nº de itens por seção, se pulou Novidades por não haver item de usuário).

## Guard-rails
- **Nunca** escreva/commite sem confirmação — **exceto** no *modo integrado*, em que o `versionador` já
  detém a confirmação (você só escreve os arquivos pra entrarem no commit dele).
- **Agnóstica:** zero caminho/repo/org hardcoded; local das Novidades sempre via memória/descoberta.
- Exclua sempre o commit `deploy:` do próprio bump e os merges.
- `deploy:`/interno sem nada de usuário → **CHANGELOG sim, Novidades não** (bloco vazio nunca).
- Voz do usuário nas Novidades: simples, sem jargão, no tom do produto. CHANGELOG pode ser técnico.
- Degrade com aviso: sem `gh` (não enriquece issue), sem tags (usa commits `deploy:`), sem local de
  Novidades configurável (pergunta/propõe e grava na memória).

## Referências
- `references/formato-e-git.md` — detecção de intervalo (tags/deploy) e comandos git, parsing de
  Conventional Commits, modelos do CHANGELOG e das Novidades, memória do local, degradação graciosa.
