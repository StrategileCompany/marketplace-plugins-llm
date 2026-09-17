---
name: registra-issue
description: >-
  Registra (cria) uma issue no repositório GitHub atual a partir do JSON de
  requisito da analista-de-requisitos — em qualquer estado de enriquecimento:
  só o requisito, com estimativa (estima-esforco) e/ou com prioridade
  (prioriza-backlog) — ou de um título/corpo já prontos, usando o `gh` CLI.
  Aplica TUDO de uma vez na criação: issue type nativo (Bug/Feature/Task),
  labels existentes, prefixo de tamanho no título, linhas de
  estimativa/prioridade no corpo e SEMPRE adiciona a issue ao board da org,
  preenchendo Estimate/Size/Priority quando presentes. Funciona em QUALQUER
  repositório: detecta o repo pelo remote do Git e usa o board memorizado
  (memória projeto-board; degrada com aviso). Pode ser acionada em QUALQUER
  ponto do pipeline e é o fecho do "requisito completo" (aí cria direto, sem
  nova confirmação). Use quando o usuário disser "registra", "cria a issue",
  "abre no GitHub", "manda pro backlog", "pode criar". Sem pedido explícito de
  registro, confirma antes de criar.
---

# Registrar issue no GitHub (o fecho do pipeline)

## O que esta skill faz
Pega o requisito estruturado — no estado de enriquecimento em que estiver — e o publica como issue
no repositório GitHub **atual**, via `gh`, **de uma vez só**: cria a issue já com o título final
(prefixo de tamanho, se houver estimativa), o corpo final (requisito + linhas de
estimativa/prioridade, se houver), o **issue type nativo**, as labels **opcionais**, e **sempre**
adiciona a issue ao **projeto (board) da org** — com os campos Estimate/Size/Priority preenchidos
quando o JSON os tiver. Nada de criar e ficar editando depois.

Ela é mecânica: não reescreve o conteúdo do requisito — posta o `body` como veio.

## Entrada (uma das duas)
- **Requisito estruturado (preferido):** o JSON da `analista-de-requisitos` (caminho do arquivo
  `requisito-*.json`, ou inline), possivelmente enriquecido pelos blocos `estimativa`
  (`estima-esforco`) e `prioridade` (`prioriza-backlog`). Blocos ausentes não são erro — a issue
  nasce sem essas marcações e elas podem ser aplicadas depois, em modo issue viva. Schema e
  montagem em `references/gh-e-labels.md`.
- **Título + corpo prontos:** se o usuário já te deu o texto, use direto (peça/infira o `type`).

Se só houver uma **frase solta** e nenhum requisito estruturado, esta não é a skill certa — peça
para a `analista-de-requisitos` estruturar primeiro.

## Conceito: issue type ≠ label
O GitHub tem **issue types nativos** (Bug / Feature / Task / "No type"), definidos no nível da
**organização** — é a classificação principal e aparece como um "pill" na issue. **Labels** são
outra coisa (área, prioridade, módulo) e são **opcionais/complementares**. Priorize acertar o
**tipo**; não crie uma label só para espelhar o tipo.

## Repositório e diretório atuais
Aja no repositório do **diretório atual** — o `gh` infere pelo remote do Git. **Não** use `--repo`.
Descubra e mostre qual é: `gh repo view --json nameWithOwner -q .nameWithOwner`.

## Autorização (quando confirmar)
- **Pedido explícito na conversa** — "registra", "pode criar", "cria a issue", "manda pro
  backlog", ou o pipeline "requisito completo" — **já é a autorização**: crie direto e reporte.
- **Sem pedido explícito** (ex.: você foi acionada por engano, ou o usuário só pediu o requisito):
  mostre o resumo — repositório, título final, tipo, labels, estimativa/prioridade — e peça **um**
  "ok".

## Fluxo
1. **Ambiente:** repo (`gh repo view --json nameWithOwner -q .nameWithOwner`) e auth
   (`gh auth status`). Se não for repo Git com remote no GitHub, ou o `gh` não estiver autenticado,
   **avise e pare**. Confira `status: "ready"` no JSON.
2. **Monte título e corpo finais** a partir do JSON (regras em `references/gh-e-labels.md`):
   - **Título:** com `estimativa` → `[<T>] - <title>`; sem → `<title>`.
   - **Corpo:** o `body` verbatim; se houver `estimativa`/`prioridade`, acrescente ao fim o bloco
     de marcações (separador `---` + linha da estimativa original + linha da prioridade).
3. **Issue types disponíveis:** `gh api "orgs/<owner>/issue-types" --jq '.[].name'`.
   - Mapeie o `type` do requisito para um tipo **existente** (case-insensitive):
     `bug`→**Bug**, `feature`→**Feature**, `task`→**Task**.
   - Se o endpoint falhar (repo de usuário, sem org, recurso indisponível) ou não houver match,
     **siga sem tipo nativo** — e, se o usuário quiser, ofereça uma label como substituta. Nunca
     invente um tipo.
4. **Labels (opcional):** `gh label list`. Aplique só as labels da entrada que **existem**;
   descarte as demais e avise. Não crie label sem o usuário pedir.
5. **Crie** (corpo por arquivo, para não sofrer com escaping):
   - Salve o corpo final em `issue-body.md` (ferramenta Write).
   - `URL=$(gh issue create --title "<título final>" --body-file "<caminho>/issue-body.md" [--label "<l>"])`
   - `gh issue create` devolve a URL; o número é o final dela.
6. **Defina o tipo nativo** (se houve match no passo 3):
   - `gh api --method PATCH "repos/<owner>/<repo>/issues/<n>" -f type="<Bug|Feature|Task>"`
   - (`gh` 2.92 não tem `--type` no create/edit; o tipo se aplica pela API REST.)
7. **Board (SEMPRE):** adicione a issue ao projeto da org — **mesmo sem estimativa/prioridade** —
   e preencha os campos que o JSON tiver: `estimativa` → **Estimate** (pontos) + **Size** (T-shirt
   mapeado); `prioridade` → **Priority** (score). Não mexa no Status. O board vem da **memória do
   projeto** (`projeto-board` — na primeira vez, descubra, pergunte se houver mais de um, e
   **grave**); os campos, em runtime. Sem scope/board/campo, **pule e avise** (degradação
   graciosa). Comandos e o padrão da memória em `references/gh-e-labels.md`.
8. **Feche o ciclo:** acrescente ao JSON o bloco
   `"registro": { "numero": <n>, "url": "<url>" }` e **reporte numa linha**: nº, URL, tipo, board
   (ok/pulado) e campos gravados.

> Se a issue nasceu sem estimativa/prioridade e o usuário quiser depois, `estima-esforco` e
> `prioriza-backlog` atuam sobre a **issue viva** normalmente.

## Guard-rails
- **Nunca** rode `gh issue create` sem autorização do usuário na conversa (pedido explícito ou um
  "ok" à sua confirmação — uma vez só; não re-confirme o que o pipeline já autorizou).
- Só use **issue types e labels que existem** no repo/org. Não invente tipo nem `--repo`.
- Corpo **sempre** por `--body-file`, nunca `--body "..."` inline (PowerShell quebra com acentos).
- Não edite o conteúdo do requisito — se algo estiver errado, aponte e devolva para a análise.
- O board é **sempre tentado**; quando impossível (sem scope/board), **avise** — nunca omita em
  silêncio.

## Referência
- `references/gh-e-labels.md` — schema do JSON de entrada (com os blocos de enriquecimento),
  montagem do título/corpo finais, **issue types** (comandos e mapeamento), labels, board
  (item-add + campos) e troubleshooting do `gh`.
