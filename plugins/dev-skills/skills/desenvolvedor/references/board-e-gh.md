# Board (Status), fechar issue e busca no backlog

## Mover o Status no board (GitHub Projects v2)
Pré-requisitos: scope `project` e um board com campo **Status** (single-select). Sem isso, **avise
e siga** — a implementação não depende do board.

Descoberta (genérica, em runtime — nunca hardcode IDs):
```bash
OWNER=$(gh repo view --json owner --jq .owner.login)
REPO=$(gh repo view --json name --jq .name)
gh project list --owner "$OWNER" --format json --jq '.projects[] | {number,title,id}'
PROJ_NUM=<n>; PROJ_ID=<id do board>
gh project field-list "$PROJ_NUM" --owner "$OWNER" --format json \
  --jq '.fields[] | select(.name=="Status") | {id, options}'
STATUS_FIELD=<id>; OPT_INPROGRESS=<id de "In Progress">; OPT_DONE=<id de "Done">
```
Aplicar (Status é single-select → `--single-select-option-id`, não `--number`):
```bash
ITEM=$(gh project item-add "$PROJ_NUM" --owner "$OWNER" \
  --url "https://github.com/$OWNER/$REPO/issues/<N>" --format json --jq '.id')
# início da implementação:
gh project item-edit --id "$ITEM" --field-id "$STATUS_FIELD" --project-id "$PROJ_ID" \
  --single-select-option-id "$OPT_INPROGRESS"
# fechamento:
gh project item-edit --id "$ITEM" --field-id "$STATUS_FIELD" --project-id "$PROJ_ID" \
  --single-select-option-id "$OPT_DONE"
```
Os nomes podem variar por repo; se não houver "Status"/"In Progress"/"Done", use os equivalentes
existentes ou pule (avisando). `item-add` repetido é inócuo (item já existe).

## Fechar a issue
```bash
gh issue close <N>      # só após a confirmação do usuário; aqui Status Done ≡ issue fechada
# reabrir se preciso:  gh issue reopen <N>
```

## Buscar no backlog (fluxo SEM issue)
```bash
gh issue list --state open --search "<palavras-chave>" --limit 20 --json number,title,labels
# leia os candidatos e julgue o melhor match:
gh issue view <n> --json title,body --jq '{title:.title, body:.body}'
```
Não é busca vetorial — é palavra-chave + leitura/julgamento do agente.

## Commit / branch / versão
- **Commit:** siga o estilo do repo (veja `git log --oneline -10`; ex.: conventional commits
  `feat(escopo): … (#N)`); **referencie a issue** com `(#N)`.
- **Branch:** pergunte antes de mover para In Progress; sem pedido explícito, use a **branch atual**.
- **versiona:** use a skill `versionador` (faz versão + commit + push).

## Degradação graciosa
- Sem scope `project` → `gh project …` falha (`gh auth refresh -s project`). Avise e siga a
  implementação; o Status simplesmente não é atualizado.
- Sem board/campo Status → pule a atualização de Status (a issue ainda é fechada no final).
