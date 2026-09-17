---
name: prioriza-backlog
description: >-
  Prioriza por um score de valor÷esforço ancorado em rubrica, para responder
  "o que fazer primeiro?", em DOIS modos: (1) modo JSON (pré-issue),
  enriquecendo o requisito da analista-de-requisitos com o bloco "prioridade"
  antes do registro, sem tocar o GitHub e sem pedir confirmação — terceira
  etapa do pipeline "requisito com backlog/completo"; (2) modo issue viva,
  priorizando uma issue existente (ou o backlog em lote), gravando o score no
  Projects v2, ordenando o backlog e reabastecendo o To Do. O valor sai de
  quatro drivers — Customer Value (o que o usuário PERCEBE que ganha, com peso
  maior), Business Value, Risco/Criticidade e Efeito destravador — combinados
  com a Confiança e divididos pelos pontos da estima-esforco. Funciona em
  QUALQUER repositório. Use quando o usuário disser "prioriza", "o que fazer
  primeiro/a seguir", "ordena o backlog", "qual a prioridade dessa issue",
  "vale a pena agora?", ou dentro do pipeline de requisito. No modo issue
  viva, NUNCA grava sem confirmação.
---

# Prioriza backlog → o que fazer primeiro

## Missão
Dizer **o quanto vale** cada requisito e, com isso, **em que ordem** atacá-los. Você complementa a
`estima-esforco` (que diz *quanto custa*): prioridade é sempre **valor ÷ esforço**. O denominador
(esforço) você já tem — os **pontos Fibonacci** da `estima-esforco`. Seu trabalho é medir o
**numerador (o valor)** com método, e ranquear. Dois modos:
- **Modo JSON (pré-issue):** dentro do pipeline de requisito, enriquecendo o JSON **antes** de a
  issue existir. Nada é gravado no GitHub — quem aplica é a `registra-issue`.
- **Modo issue viva:** sobre issues existentes (uma, ou o backlog em lote), gravando score no
  board e reabastecendo o To Do.

Priorizar não é opinião: o número sai de **quatro drivers** explícitos, ancorados em rubrica, e o
mais forte deles — **Customer Value** — é julgado contra a **promessa central do produto**, não
contra o gosto de quem prioriza. Os drivers são **método interno** — o chat recebe só o score.

## Princípio-guia
> Priorize pelo **valor que o usuário percebe que ganha**; use o **Business Value** como filtro pra
> garantir que o que encanta o cliente também sustenta a empresa.

Quem paga as contas é o cliente. Por isso o Customer Value pesa mais (constante `PESO_CUSTOMER_VALUE
= 1.2`, calibrável). Business Value é consequência de Customer Value sustentado — importante, mas
não soberano.

## A fórmula
```
Prioridade = ( CustomerValue × 1.2  +  BusinessValue  +  RiscoCriticidade  +  EfeitoDestravador )
             × Confiança
             ÷ Pontos
```
- Cada driver: **1–5** (rubrica em `references/rubrica-valor.md` — **leia antes de priorizar**).
- **Confiança:** alta = 1.0 · média = 0.85 · baixa = 0.7.
- **Pontos:** Fibonacci da `estima-esforco` (1/2/3/5/8/13/21).
- Os valores absolutos não importam — só a **ordem relativa**. Ancore em issues já priorizadas.

## O core business (âncora do Customer Value)
Customer Value se mede contra a **promessa central do produto**. A skill roda em qualquer repo,
então precisa saber qual é essa promessa (vale nos dois modos):
1. **Descubra** lendo o que o repo declara — `CLAUDE.md` / `AGENTS.md` / `README` / descrição do repo.
2. **Confirme em uma frase:** *"Entendi que o core deste produto é: `<frase>`. Confere?"* — usuário
   corrige/aprova.
3. **Guarde** numa **memória de projeto** (`type: project`, slug `projeto-core-business`) pra não
   perguntar de novo e manter a pontuação coerente entre issues/sessões. Nas próximas rodadas, leia
   a memória; só reconfirme se o usuário pedir ou se o produto mudou de rumo.

Sem uma âncora estável, cada issue seria julgada contra um "core" diferente e o ranking ficaria
incoerente. Detalhes em `references/gh-projects.md`.

## Como pontuar (igual nos dois modos)
1. **Leia o requisito:** no modo JSON, o próprio arquivo (com o bloco `estimativa` → pontos); no
   modo vivo, `gh issue view <n> --json title,body,labels` + pontos do prefixo `[T] - ` no título /
   campo `Estimate` no board. Sem estimativa → veja Guard-rails.
2. **Customer Value** — pontue 1–5 pelas **três lentes** (rubrica):
   - **Relevância ao core:** quão perto da promessa central do produto?
   - **Consequência da ausência:** o que dói/quebra pro usuário sem isto?
   - **Ganho percebido:** o que ele sente que ganhou tendo isto?
3. **Business Value** (1–5): alinhamento estratégico, receita, diferenciação.
4. **Risco/Criticidade** (1–5): bug, segurança, dado financeiro/legal errado, bloqueio.
5. **Efeito destravador** (1–5): quantas outras entregas isto habilita.
6. Aplique a **Confiança** e divida pelos **Pontos** → o **score**. A justificativa de **uma
   linha** vai no registro (JSON/corpo) — não no chat.

## Modo JSON (pré-issue, dentro do pipeline)
1. **Entrada:** o arquivo `requisito-*.json` já com o bloco `estimativa` (se faltar, acione antes a
   `estima-esforco` em modo JSON — na cadeia normal ela já rodou).
2. **Garanta a âncora** do core business (memória, ou confirme uma vez).
3. **Pontue** e acrescente o bloco ao **mesmo arquivo**:
   ```json
   "prioridade": {
     "score": 3.4,
     "drivers": { "customer_value": 5, "business_value": 3, "risco_criticidade": 2, "efeito_destravador": 4 },
     "confianca": "média",
     "justificativa": "<uma linha: os drivers que pesaram>"
   }
   ```
4. **Nada de GitHub e nada de confirmação** — a `registra-issue` grava a linha no corpo e o campo
   Priority na criação.
5. **Saída no chat: uma linha.** `Prioridade: 3.4.`
6. Continue a cadeia se o pedido incluir o registro (`registra-issue`).

## Modo issue viva
### Onde gravar
Depois de **confirmar com o usuário** (comandos em `references/gh-projects.md`):
1. **GitHub Projects** — campo numérico **Priority** (ou `Score`) = o score calculado. É o que
   **ordena** o board. O board vem da memória do projeto (`projeto-board`, mesmo padrão do core
   business); o campo, em runtime. Sem scope/board/campo, **pule e avise**.
2. **Corpo** — atualize (ou acrescente) **uma** linha de transparência com o detalhamento:
   `> **Prioridade:** 3.4 — CV 5×1.2 · BV 3 · Risco 2 · Destrava 4 · conf. média ÷ 3 pts. <porquê>.`
   Diferente da estimativa, **prioridade muda com o tempo** → esta linha é o valor **atual**
   (sobrescreva ao re-priorizar; não é histórico imutável).
3. **Título:** **não** prefixe. Prioridade muda demais; poluir o título gera ruído. A ordenação vive
   no board.

### Abastecer o To Do (reabastecedor incremental)
Priorizar não serve de nada se o topo do ranking não vira **trabalho pronto pra pegar**. Por isso, em
**lote**, depois de gravar os scores, a skill **enche a coluna "To Do"** do board com as issues de
maior prioridade — de forma **incremental**:
- **Fonte:** só as issues em **`No Status`** (o backlog não iniciado). **Nunca** mexe em quem já está
  em `In Progress` ou `Done`.
- **Meta (topo):** encha o To Do **até `N` vagas** (`N_TODO = 5`, calibrável — casa com o limite `0/5`
  da coluna). Se o To Do já tiver itens, só complete as **vagas restantes** (`N − já_no_todo`) com o
  topo do ranking; **não remova** o que já está lá.
- **Efeito incremental:** conforme você move issues do To Do pra In Progress/Done, as vagas abrem; a
  próxima rodada repõe com o próximo do ranking. Rodar a skill = "mantém meu To Do cheio com o que
  mais vale agora".
- Mecânica do Status (single-select → `--single-select-option-id`) em `references/gh-projects.md`.
  Sem board/scope/coluna, **avise e siga** (entrega só o ranking).

### Fluxo
1. **Alvo:** uma issue (número/URL) ou "o backlog" (`gh issue list --state open`).
2. **Core business:** garanta a âncora (memória ou confirme uma vez).
3. **Pontue** cada issue. Em **lote**, monte a tabela ordenada.
4. **Confirme:** apresente o **ranking** — tabela ordenada por score desc (nº · título · pontos ·
   score), sem coluna de justificativa — e, em lote, **quais entram no To Do** (as `N` do topo que
   estão em `No Status`). Confirme antes de gravar.
5. Com o **"ok"**: grave os scores (Projects + linha do corpo) **e** promova o topo pra `To Do`
   (respeitando as vagas).
6. **Reporte** numa linha o que gravou e o que foi pro To Do (avise se pulou o Projects).

## Saída no chat (menos é mais)
Entregue o **score e a ordem**, não o raciocínio: sem detalhar drivers, sem justificar nota por
nota. Exceção de **uma frase**: quando o score for **provisório** (sem estimativa) ou a confiança
**baixa**, sinalize.

## Guard-rails
- **Modo issue viva:** nunca grave sem confirmação explícita do usuário.
- **Modo JSON:** não grava nada no GitHub — por isso não pede confirmação; é só enriquecimento
  local do requisito.
- **Precisa de esforço:** o score divide pelos pontos. Sem estimativa → no modo JSON, rode antes a
  `estima-esforco`; no modo vivo, ofereça rodá-la, ou pontue só o **numerador (valor)** e marque
  **provisório**, avisando que o ranking final depende do esforço.
- `PESO_CUSTOMER_VALUE = 1.2` é constante nomeada e visível — calibra-se com o tempo (junto da
  futura `calibrar-estimativas`), não se enterra na conta.
- Customer Value só pontua alto se serve à **promessa do produto** — nunca por "eu acho legal".
- Escala fixa dos drivers **1–5**; não invente valores nem dimensões novas sem combinar.
- Projects é **opcional**: descubra IDs em runtime, nunca hardcode; sem scope/board/campo, pule e
  avise (`gh auth refresh -s project` quando for scope).
- Priorizar **não** altera o issue type, o requisito nem a estimativa.

## Referências
- `references/rubrica-valor.md` — os 4 drivers, as 3 lentes do Customer Value, confiança, âncoras,
  a constante de peso.
- `references/gh-projects.md` — descobrir/gravar o campo Priority, ordenar o board, memória do core
  business, degradação graciosa (só modo issue viva).
