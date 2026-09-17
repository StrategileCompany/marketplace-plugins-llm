# gh: JSON de entrada, montagem, issue types, labels e board

## JSON de entrada (o requisito enriquecido do pipeline)
Campos que esta skill usa (schema completo no `formato-requisito.md` da `analista-de-requisitos`):
- `title` — título-base da issue (sem prefixos).
- `body` — corpo em markdown, **postado verbatim** (não re-renderize).
- `type` — issue type nativo pretendido: `bug` | `feature` | `task`.
- `labels` — array **opcional** de labels complementares; aplique só as que existem.
- `estimativa` — **opcional** (gravado pela `estima-esforco`): `{tshirt, pontos, confianca, incerteza}`.
- `prioridade` — **opcional** (gravado pela `prioriza-backlog`): `{score, drivers, confianca, justificativa}`.

Ignore o resto (`fields`, `relacionadas`, `schema_version`). Confira `status`: se **não** for
`ready`, **não crie** — devolva para a `analista-de-requisitos`. Após criar, acrescente ao JSON o
bloco `"registro": { "numero": <n>, "url": "<url>" }`.

## Montagem do título e do corpo finais
- **Título:** com `estimativa` → `[<tshirt>] - <title>` (ex.: `[M] - Os popups estão fechando…`);
  sem `estimativa` → `<title>` puro. Nunca empilhe prefixos.
- **Corpo:** o `body` verbatim e, se houver `estimativa` e/ou `prioridade`, acrescente ao fim:
  ```
  ---
  > **Estimativa (original):** <tshirt> (<pontos>) — confiança <confianca>. Incerteza: <incerteza>.
  > **Prioridade:** <score> — CV <cv>×1.2 · BV <bv> · Risco <risco> · Destrava <destrava> · conf. <confianca> ÷ <pontos> pts. <justificativa>.
  ```
  Inclua só as linhas cujo bloco existe. São as mesmas linhas que `estima-esforco`/
  `prioriza-backlog` gravam em modo issue viva — a issue nasce igual a uma que foi marcada depois.

## Issue types (nativos do GitHub)
Issue types são definidos no nível da **organização** e são a classificação principal
(Bug/Feature/Task/"No type"). São **separados de labels**.

**Mapeamento** (`type` do requisito → nome do issue type, case-insensitive):
`bug` → `Bug` · `feature` → `Feature` · `task` → `Task`.

**Comandos:**
```bash
# Dono do repo (para o endpoint da org)
gh repo view --json owner -q .owner.login

# Tipos existentes na org (nomes)
gh api "orgs/<owner>/issue-types" --jq '.[].name'

# Ver o tipo atual de uma issue
gh api "repos/<owner>/<repo>/issues/<n>" --jq '.type.name'

# DEFINIR o tipo de uma issue (é assim que se aplica — o gh 2.92 não tem --type)
gh api --method PATCH "repos/<owner>/<repo>/issues/<n>" -f type="Bug"

# LIMPAR o tipo (voltar a "No type")
gh api --method PATCH "repos/<owner>/<repo>/issues/<n>" -f type=""
```

**Quando não há issue types:** se `gh api orgs/<owner>/issue-types` falhar (repo de usuário, sem
org, ou recurso indisponível) ou nenhum nome casar com bug/feature/task, **omita o tipo**. Avise o
usuário e, se ele quiser, aplique uma label equivalente como substituta (ex.: `bug`) — só se ela
existir. Nunca invente tipo.

## Labels (opcionais e complementares)
Labels padrão que existem na maioria dos repos: `bug`, `documentation`, `duplicate`,
`enhancement`, `good first issue`, `help wanted`, `invalid`, `question`, `wontfix`.

Com issue types nativos, **não use label para espelhar o tipo** (nada de tipo `Bug` + label
`bug`). Labels servem para área/módulo/prioridade — são um extra opcional. Confirme sempre com
`gh label list`; aplique só o que existe; se uma label sugerida não existir, descarte e avise.

```bash
gh label list                                   # labels existentes
gh issue list --search "<palavras-chave>" --state all   # duplicatas/relacionadas
```

## Criar a issue (só com autorização — ver SKILL.md)
Fluxo em dois passos: criar (corpo por arquivo) e depois aplicar o tipo.
```bash
# 1) cria (sem --repo: usa o repo atual). Guarde a URL; o número é o final dela.
URL=$(gh issue create \
  --title "<título final>" \
  --body-file "<caminho>/issue-body.md" \
  --label "<label-opcional>")     # omita --label se não houver
echo "$URL"                        # ex.: https://github.com/<owner>/<repo>/issues/59
N="${URL##*/}"

# 2) aplica o issue type nativo (se houve match)
gh api --method PATCH "repos/<owner>/<repo>/issues/$N" -f type="Bug"
```

## Board (SEMPRE): adicionar ao projeto da org + campos
Toda issue registrada entra no **projeto (board) da org**, mesmo sem estimativa/prioridade.
Pré-requisitos: token com scope `project` e um board. Sem isso, **pule e avise** (degradação
graciosa abaixo). O **board** vem da memória do projeto (abaixo); os **IDs** de board, campos e
opções são descobertos em runtime — nunca hardcode.

### Qual board? (memória do projeto — slug `projeto-board`)
A escolha do board é **persistida por repositório**, no mesmo padrão do core business da
`prioriza-backlog`:
1. **Leia a memória `projeto-board`** do projeto atual. Existindo, use o board dela
   (owner + número) — sem listar, sem perguntar.
2. **Sem memória**, descubra: `gh project list --owner "$OWNER"`.
   - **Um** board → use-o e **grave a memória** (sem perguntar; mencione no report).
   - **Vários** → pergunte **uma vez** ao usuário qual usar e grave a escolha.
3. Board memorizado que **não existe mais** (comando falha) → redescubra (passo 2) e
   **atualize** a memória.

Formato (arquivo `projeto_board.md` na memória do projeto + ponteiro no `MEMORY.md`):
```markdown
---
name: projeto-board
description: Board (Projects v2) das issues de <OWNER/REPO> — "<TÍTULO>" (#<número>).
metadata:
  type: project
---

As issues de <OWNER/REPO> vão para o projeto (board) **"<TÍTULO>"** (número <n>, owner
<OWNER>). Usado por registra-issue, estima-esforco e prioriza-backlog para item-add e campos,
sem redescobrir nem perguntar de novo.
```

### Comandos
```bash
OWNER=$(gh repo view --json owner --jq .owner.login)
REPO=$(gh repo view --json name --jq .name)
# PROJ_NUM: da memória projeto-board; sem memória (1ª vez), descubra e grave:
gh project list --owner "$OWNER" --format json --jq '.projects[] | {number,title,id}'
PROJ_NUM=<número>
PROJ_ID=$(gh project view "$PROJ_NUM" --owner "$OWNER" --format json --jq '.id')

# 1) adiciona a issue ao board (SEMPRE; repetir é inócuo — o item já existe)
ITEM=$(gh project item-add "$PROJ_NUM" --owner "$OWNER" \
  --url "https://github.com/$OWNER/$REPO/issues/$N" --format json --jq '.id')
```

**Com `estimativa`** — campos **Estimate** (número) e **Size** (single-select; mapa
`PP→XS · P→S · M→M · G→L · GG/XG/XXG→XL`):
```bash
gh project field-list "$PROJ_NUM" --owner "$OWNER" --format json \
  --jq '.fields[] | select(.name=="Estimate") | {id,type}'
EST_FIELD=<id>
gh project field-list "$PROJ_NUM" --owner "$OWNER" --format json \
  --jq '.fields[] | select(.name=="Size") | {id, options}'
SIZE_FIELD=<id>; OPT=<id da opção mapeada>

gh project item-edit --id "$ITEM" --field-id "$EST_FIELD" --project-id "$PROJ_ID" --number <pontos>
gh project item-edit --id "$ITEM" --field-id "$SIZE_FIELD" --project-id "$PROJ_ID" \
  --single-select-option-id "$OPT"
```

**Com `prioridade`** — campo numérico **Priority** (ou `Score`):
```bash
gh project field-list "$PROJ_NUM" --owner "$OWNER" --format json \
  --jq '.fields[] | {name, id, dataType}'
PRIORITY_FIELD=<id do campo numérico>
gh project item-edit --id "$ITEM" --field-id "$PRIORITY_FIELD" --project-id "$PROJ_ID" \
  --number <score>
```

**Não mexa no Status** — a issue entra em `No Status`; quem promove para To Do é a
`prioriza-backlog` (lote), e para In Progress/Done é a `desenvolvedor`.

### Degradação graciosa (board)
- **Sem scope** → `gh project ...` falha pedindo `read:project`/`project`. Crie a issue, pule o
  board e avise: rode `gh auth refresh -s project`.
- **Sem board** ou **sem campo** → adicione o que der (item sem campo faltante), avise o que
  pulou; ofereça criar o campo
  (`gh project field-create <num> --owner "$OWNER" --name Estimate --data-type NUMBER`).
- Nunca invente IDs; descubra sempre.

## Troubleshooting
- **"could not determine base repo"** → diretório sem remote GitHub. Avise o usuário; não force
  `--repo`.
- **`gh` não autenticado** → `gh auth status` falha; peça `gh auth login`.
- **`orgs/<owner>/issue-types` retorna 404/Not Found** → o dono não é org ou não tem issue types.
  Omita o tipo (e ofereça label opcional).
- **PATCH de tipo falha (422)** → o nome do tipo não existe na org; use exatamente um dos nomes de
  `gh api orgs/<owner>/issue-types`.
- **Label inexistente** → `gh issue create` falha; remova a label (e avise) ou crie só se o usuário
  pedir: `gh label create "<nome>" --color <hex>`.
- **Acentos/markdown embaralhados** no corpo → use `--body-file`, nunca `--body` inline.
