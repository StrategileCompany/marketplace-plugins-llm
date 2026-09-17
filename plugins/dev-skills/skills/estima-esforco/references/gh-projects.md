# Gravar a estimativa via gh (as três formas — modo issue viva)

Estas gravações valem para o **modo issue viva**. No modo JSON (pipeline de requisito), nada é
gravado no GitHub — a `registra-issue` aplica título/corpo/campos na criação.

Todos os comandos são **após confirmação** do usuário. Descubra IDs em runtime — nunca hardcode.

## 1) Título — prefixo T-shirt
```bash
# título atual (para não duplicar prefixo)
TITULO=$(gh issue view <n> --json title --jq .title)
# aplica: [<T>] - <título sem prefixo anterior>
gh issue edit <n> --title "[<T>] - <título limpo>"
```
Se o título já começar com `[..] - ` (re-estimativa), **substitua** esse prefixo — não empilhe.

## 2) Corpo — linha da estimativa original (uma vez)
Acrescente ao **fim** do corpo, só se ainda não existir uma linha "Estimativa (original)":
```
---
> **Estimativa (original):** <T> (<pontos>) — confiança <alta|média|baixa>. Incerteza: <driver>.
```
Aplique pegando o corpo atual, acrescentando a linha e regravando por arquivo (evita escaping):
```bash
gh issue view <n> --json body --jq .body > /tmp/body.md   # ou um arquivo de scratch
# (acrescente a linha ao arquivo com a ferramenta Write/Edit)
gh issue edit <n> --body-file /tmp/body.md
```
Em **re-estimativa**, **não** troque esta linha — ela é o registro histórico "original".

## 3) GitHub Projects v2 — dois campos: "Estimate" (número) e "Size" (single-select)
Pré-requisitos: token com scope `project` e um board com esses campos. Se faltar, **pule e avise**.

**Mapa T-shirt → Size** (o single-select do GitHub tem 5 níveis; a escala tem 7 → fusão):
| T-shirt | Size |
|---|---|
| PP | XS |
| P | S |
| M | M |
| G | L |
| GG / XG / XXG | XL |

**Qual board? (memória `projeto-board`)** Antes de listar, leia a memória de projeto
`projeto-board`: existindo, use o board dela (owner + número) direto. Sem memória:
`gh project list --owner` — **um** board → use e **grave** a memória (arquivo
`projeto_board.md`, `type: project`, com owner/número/título + ponteiro no `MEMORY.md`);
**vários** → pergunte uma vez e grave. Board memorizado que sumiu → redescubra e atualize.

Descoberta (genérica — board, campo numérico, e o single-select **com IDs das opções**):
```bash
OWNER=$(gh repo view --json owner --jq .owner.login)
REPO=$(gh repo view --json name --jq .name)
gh project list --owner "$OWNER" --format json --jq '.projects[] | {number,title,id}'   # só sem memória
PROJ_NUM=<número>
PROJ_ID=$(gh project view "$PROJ_NUM" --owner "$OWNER" --format json --jq '.id')
# Estimate (numérico)
gh project field-list "$PROJ_NUM" --owner "$OWNER" --format json \
  --jq '.fields[] | select(.name=="Estimate") | {id,type}'
EST_FIELD=<id do Estimate>
# Size (single-select) + IDs das opções — precisa do id da opção (XS/S/M/L/XL), não do nome
gh project field-list "$PROJ_NUM" --owner "$OWNER" --format json \
  --jq '.fields[] | select(.name=="Size") | {id, options}'
SIZE_FIELD=<id do Size>; OPT=<id da opção mapeada>
```
Aplicar na issue:
```bash
ITEM=$(gh project item-add "$PROJ_NUM" --owner "$OWNER" \
  --url "https://github.com/$OWNER/$REPO/issues/<n>" --format json --jq '.id')
# Estimate = pontos (número)
gh project item-edit --id "$ITEM" --field-id "$EST_FIELD" --project-id "$PROJ_ID" --number <pontos>
# Size = opção mapeada (single-select usa --single-select-option-id, NÃO --number)
gh project item-edit --id "$ITEM" --field-id "$SIZE_FIELD" --project-id "$PROJ_ID" \
  --single-select-option-id "$OPT"
```
Verificar:
```bash
gh project item-list "$PROJ_NUM" --owner "$OWNER" --format json \
  --jq '.items[] | select(.content.number? == <n>) | {estimate, size}'
```
Em **re-estimativa**, o item já existe (`item-add` de novo é inócuo); atualize `--number` e o
`--single-select-option-id`.

## Degradação graciosa (Projects opcional)
- **Sem scope** → `gh project ...` falha pedindo `read:project`/`project`. Grave título+corpo, pule
  o Projects e avise: rode `gh auth refresh -s project`.
- **Sem board** ou **sem campo numérico** → pule o Projects e avise; ofereça criar o campo:
  `gh project field-create <num> --owner "$OWNER" --name Estimate --data-type NUMBER`.
- Nunca invente IDs; descubra sempre.

## Notas
- `gh issue view --json` **não** expõe o issue type. Para checar o tipo use a API:
  `gh api repos/$OWNER/$REPO/issues/<n> --jq .type.name`. (Estimar não mexe no tipo.)
- O single-select "Size" (XS–XL, 5 níveis) recebe o T-shirt **mapeado** (fusão GG/XG/XXG→XL). O
  T-shirt **exato** (7 níveis) fica no **título**; os pontos no **Estimate**; o Size aproximado no
  campo **Size**.
