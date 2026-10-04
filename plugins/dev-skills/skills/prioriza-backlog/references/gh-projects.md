# Gravar prioridade no Projects, memória do core business e degradação graciosa

As gravações deste arquivo valem para o **modo issue viva**. No modo JSON (pipeline de requisito),
nada é gravado no GitHub — a `registra-issue` aplica a linha do corpo e o campo Priority na
criação. A **memória do core business** vale nos dois modos.

## Memória do core business (âncora do Customer Value)
Customer Value se mede contra a **promessa central do produto**. Estabeleça-a **uma vez por projeto**:

1. **Descubra** lendo o que o repo declara (nesta ordem de preferência):
   `CLAUDE.md` → `AGENTS.md` → `README` → descrição do repo (`gh repo view --json description`).
2. **Confirme em uma frase** com o usuário:
   *"Entendi que o core deste produto é: `<frase>`. Confere?"*.
3. **Grave numa memória de projeto** (não pergunte de novo). Arquivo em
   `.../memory/projeto_core_business.md`:
   ```markdown
   ---
   name: projeto-core-business
   description: Promessa central (core business) do produto <REPO> — âncora do Customer Value na priorização.
   metadata:
     type: project
   ---

   O core business de <OWNER/REPO> é: <frase>.
   Régua para pontuar Customer Value na skill [[prioriza-backlog]]: o quanto uma issue serve a esta promessa.
   ```
   E adicione o ponteiro em `MEMORY.md`.
4. **Nas próximas rodadas:** leia a memória; só reconfirme se o usuário pedir ou se o produto mudou de
   rumo. Se houver mais de um repo, use uma memória por repo (inclua `OWNER/REPO` na frase).

## Descobrir o campo Priority (número) no board
Pré-requisitos: scope `project` e um board. Nunca hardcode IDs — descubra em runtime.

**Qual board? (memória `projeto-board`)** Mesmo padrão da memória do core business acima: leia a
memória de projeto `projeto-board` e use o board dela (owner + número). Sem memória:
`gh project list --owner` — **um** board → use e **grave** a memória (arquivo `projeto_board.md`,
`type: project`, com owner/número/título + ponteiro no `MEMORY.md`); **vários** → pergunte uma
vez e grave. Board memorizado que sumiu → redescubra e atualize.

```bash
OWNER=$(gh repo view --json owner --jq .owner.login)
REPO=$(gh repo view --json name --jq .name)
gh project list --owner "$OWNER" --format json --jq '.projects[] | {number,title,id}'   # só sem memória
PROJ_NUM=<n>
PROJ_ID=$(gh project view "$PROJ_NUM" --owner "$OWNER" --format json --jq '.id')
# procure um campo numérico de prioridade (nomes comuns: "Priority", "Score", "Prioridade"):
gh project field-list "$PROJ_NUM" --owner "$OWNER" --format json \
  --jq '.fields[] | {name, id, dataType}'
PRIORITY_FIELD=<id do campo numérico>
```
Se **não existir** um campo numérico de prioridade, ofereça criar um:
```bash
gh project field-create "$PROJ_NUM" --owner "$OWNER" --name "Priority" --data-type NUMBER
```
> Nota: um campo **single-select "Priority"** padrão do GitHub (P0/P1/P2) **não** serve para o score
> contínuo — use um campo **NUMBER**. Se o usuário quiser, mapeie faixas do score para P0/P1/P2 à
> parte, mas o ranking vive no campo numérico.

## Gravar o score e ordenar
**Achar o item (o board pode ser da org, com vários repos):** o `item-list` **trunca em 100** por
padrão e filtrar só por `.content.number` casa com a issue de **outro repositório**. Sempre
`--limit 1000` + filtro por **repo + número**:
```bash
ITEM=$(gh project item-list "$PROJ_NUM" --owner "$OWNER" --limit 1000 --format json \
  --jq ".items[] | select((.content.repository // \"\") == \"$OWNER/$REPO\" and .content.number == <N>) | .id")
# vazio? então a issue ainda não está no board: aí sim use item-add
[ -z "$ITEM" ] && ITEM=$(gh project item-add "$PROJ_NUM" --owner "$OWNER" \
  --url "https://github.com/$OWNER/$REPO/issues/<N>" --format json --jq '.id')
```
> **Confira antes de gravar:** um `item-edit` em item errado altera a issue de **outro produto**,
> em silêncio e sem erro. O item encontrado tem de bater em **repo e número**.

Priority é número → `--number` (não `--single-select-option-id`).
```bash
gh project item-edit --id "$ITEM" --field-id "$PRIORITY_FIELD" --project-id "$PROJ_ID" \
  --number <score>
```
Para **ordenar o backlog**, ordene a view do board por `Priority` desc na UI, ou apresente ao
usuário a tabela já ordenada por score.

## Abastecer o To Do (promover o topo do ranking)
Enche a coluna **To Do** com as issues de maior score que ainda estão em **No Status** — incremental,
sem tocar em In Progress/Done.

Descubra o campo **Status** e as opções (single-select):
```bash
gh project field-list "$PROJ_NUM" --owner "$OWNER" --format json \
  --jq '.fields[] | select(.name=="Status") | {id, options}'
STATUS_FIELD=<id>; OPT_TODO=<id de "Todo"/"To Do">; OPT_NOSTATUS=<id de "No Status" (se existir)>
```
Descubra **quantas vagas** o To Do tem livres (quantos itens já estão em "Todo") — sempre com
`--limit 1000` e trazendo o **repo** de cada item, que é o que desambigua o número:
```bash
# lista itens do board com repo + número da issue e Status atual:
gh project item-list "$PROJ_NUM" --owner "$OWNER" --limit 1000 --format json \
  --jq '.items[] | {repo: .content.repository, number: .content.number, status: .status}'
```
`N_TODO = 5` (calibrável). `vagas = N_TODO − (itens já em Todo)`. Pegue as `vagas` primeiras do
ranking que estejam em **No Status** (ignore In Progress/Done/Todo) e mova cada uma — usando o
`ITEM` achado por **repo + número** (seção anterior), nunca só pelo número:
```bash
gh project item-edit --id "$ITEM" --field-id "$STATUS_FIELD" --project-id "$PROJ_ID" \
  --single-select-option-id "$OPT_TODO"
```
Regras:
- **Só promova** quem está em **No Status**. Nunca rebaixe/remova quem já está em Todo/In Progress/Done.
- Se `vagas ≤ 0`, o To Do já está cheio → **não** promova nada (só reporte o ranking).
- **Board compartilhado por vários repositórios:** a coluna `To Do` é da **org**, então as vagas e
  os itens já lá são de **todos** os produtos. Encher as `N` vagas com o topo do ranking de um só
  repo mistura backlogs. Nesse caso, **pule o reabastecimento e avise**, ou conte as vagas só
  entre os itens do **repo atual** — combine com o usuário qual dos dois.
- Nomes de coluna variam por repo ("Todo" vs "To Do" vs "A fazer"); case os equivalentes ou pule
  avisando.

## Linha de transparência no corpo (valor atual, sobrescrevível)
Diferente da estimativa (histórica/imutável), a prioridade **muda com o tempo** → mantenha **uma**
linha com o valor atual e **sobrescreva** ao re-priorizar:
```
> **Prioridade:** 3.4 — CV 5×1.2 · BV 3 · Risco 2 · Destrava 4 · conf. média ÷ 3 pts. <porquê curto>.
```
Se já existir uma linha `> **Prioridade:**`, substitua-a; não empilhe.

## Degradação graciosa
- Sem scope `project` → `gh project …` falha. Avise (`gh auth refresh -s project`) e siga: apresente o
  ranking na conversa e grave só a linha do corpo (a ordenação persistente do board fica pendente).
- Sem board/campo → ofereça criar o campo; se recusado, entregue o ranking na conversa + linha no
  corpo.
- Issue sem estimativa (sem pontos) → score fica **provisório** (só numerador); avise que o ranking
  final depende de rodar a `estima-esforco`.
