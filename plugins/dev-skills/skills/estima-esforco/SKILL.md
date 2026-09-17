---
name: estima-esforco
description: >-
  Estima o esforço/tamanho numa escala relativa ancorada em rubrica — T-shirt
  (PP/P/M/G/GG/XG/XXG) mapeada para Fibonacci (1/2/3/5/8/13/21) — em DOIS
  modos: (1) modo JSON (pré-issue), enriquecendo o requisito da
  analista-de-requisitos com o bloco "estimativa" antes do registro, sem tocar
  o GitHub e sem pedir confirmação — segunda etapa do pipeline "requisito com
  esforço/backlog/completo"; (2) modo issue viva, estimando uma issue
  existente do GitHub (ou várias, em lote) e gravando nela: prefixo no título,
  linha no corpo (estimativa original + confiança) e os campos do Projects v2
  (Estimate numérico + Size mapeado). Funciona em QUALQUER repositório
  (descobre board/campo em runtime; degrada com aviso). Use quando o usuário
  disser "estima", "dimensiona", "classifica o esforço/tamanho", "quantos
  pontos", "estima o backlog", "que tamanho é essa issue", ou dentro do
  pipeline de requisito. No modo issue viva, NUNCA grava sem confirmação.
---

# Estima esforço → dimensionar o requisito ou a issue

## Missão
Dizer **quanto** custa um requisito, numa escala relativa e consistente. Você opera em dois modos:
- **Modo JSON (pré-issue):** dentro do pipeline de requisito, enriquecendo o JSON da
  `analista-de-requisitos` **antes** de a issue existir. Nada é gravado no GitHub — quem aplica
  tudo na criação é a `registra-issue`.
- **Modo issue viva:** sobre uma issue existente (número/URL) — uma, ou o backlog em lote —
  gravando a estimativa na própria issue.

Estimar não é adivinhar: o número sai de **drivers** explícitos (escopo, reuso, complexidade,
incerteza, integração, testes, risco), ancorado em issues que você já estimou. Os drivers são o
seu **método interno** — o chat recebe só o resultado.

## Escala (T-shirt ↔ Fibonacci)
`PP=1 · P=2 · M=3 · G=5 · GG=8 · XG=13 · XXG=21`. Rubrica completa (âncoras + drivers + confiança)
em `references/rubrica.md` — **leia antes de estimar**. `XXG (21)` = épico → **recomende quebrar**
em issues menores em vez de agendar.

## Como estimar (igual nos dois modos)
1. **Leia o requisito:** no modo JSON, o próprio arquivo (as **Notas técnicas** do analista —
   arquivos, reuso — são seu melhor input); no modo vivo,
   `gh issue view <n> --json title,body,labels`.
2. Se faltar contexto (issue crua, sem notas), faça um **grep leve** pra avaliar escopo/reuso —
   sem caçar causa raiz.
3. Avalie os **drivers** (rubrica) e derive **T-shirt + pontos**, a **confiança**
   (alta/média/baixa) e a **incerteza principal**. Ancore: *"é um M como a #59"*. A incerteza e a
   confiança ficam no registro (JSON/corpo) — não viram parágrafo no chat.

## Modo JSON (pré-issue, dentro do pipeline)
1. **Entrada:** o caminho do arquivo `requisito-*.json` (vindo da `analista-de-requisitos`).
2. **Estime** e acrescente o bloco ao **mesmo arquivo** (schema no `formato-requisito.md` da
   analista):
   ```json
   "estimativa": { "tshirt": "M", "pontos": 3, "confianca": "média", "incerteza": "<driver>" }
   ```
3. **Nada de GitHub e nada de confirmação** — você só enriqueceu um arquivo local; a
   `registra-issue` aplica título/corpo/campos na criação.
4. **Saída no chat: uma linha.** `Estimativa: M (3) · confiança média.`
5. Continue a cadeia se o pedido incluir mais etapas (`prioriza-backlog` → `registra-issue`).

## Modo issue viva
### Onde gravar (as três formas)
Depois de **confirmar com o usuário**, grave as três (comandos em `references/gh-projects.md`):
1. **Título** — prefixe `[<T>] - ` (ex.: `[M] - <título>`). Ao re-estimar, **troque** um prefixo
   `[..] - ` já existente.
2. **Corpo** — acrescente **uma vez** a linha da estimativa **original** (é histórico; não
   sobrescreva em re-estimativas):
   `> **Estimativa (original):** M (3) — confiança média. Incerteza: <driver>.`
3. **GitHub Projects** — dois campos: **Estimate** (número) = pontos e **Size** (single-select) =
   T-shirt mapeado (**PP→XS · P→S · M→M · G→L · GG/XG/XXG→XL**). O board vem da memória do
   projeto (`projeto-board`; a primeira escolha é gravada — ver referência), os campos em
   runtime; sem scope/board/campo, **pule e avise** (degradação graciosa).

> **Re-estimativa:** atualize o **prefixo do título** e os campos **Estimate + Size** do Projects
> (o "atual"); a **linha do corpo permanece a original** (base histórica para comparar com o
> esforço real depois).

### Fluxo
1. **Alvo:** descubra a(s) issue(s) — número/URL, ou "backlog" (`gh issue list --state open`;
   filtre as **sem** estimativa: título sem prefixo `[..] - ` e/ou sem `Estimate` no board).
2. **Estime** cada uma.
3. **Confirme:** apresente o resultado — issue, T-shirt, pontos, confiança. Em **lote**, uma tabela
   (nº · título · T-shirt · pontos · confiança), sem coluna de justificativa. Confirme antes de
   gravar.
4. Com o **"ok"**, grave as três formas.
5. **Reporte** numa linha o que gravou (avise se pulou o Projects).

## Saída no chat (menos é mais)
Entregue o **resultado**, não o raciocínio: sem lista de drivers, sem explicar como chegou no
número. Duas exceções, de **uma frase** cada: `XXG` (recomende quebrar) e **confiança baixa**
(sinalize a faixa, ex.: "M–G", e a necessidade de spike).

## Guard-rails
- **Modo issue viva:** nunca grave (título/corpo/Projects) sem confirmação explícita do usuário.
- **Modo JSON:** não grava nada no GitHub — por isso não pede confirmação; é só enriquecimento
  local do requisito.
- Escala fixa `PP..XXG` / `1..21` — não invente valores.
- Projects é **opcional**: descubra IDs em runtime, nunca hardcode; sem scope/board/campo, pule e
  avise (com o comando `gh auth refresh -s project` quando for scope).
- A linha do corpo é a estimativa **original** e imutável; re-estimar mexe só no título e no
  Projects.
- Estimar **não** altera o issue type nem o conteúdo do requisito.

## Referências
- `references/rubrica.md` — escala, drivers, confiança, âncoras, regra do XXG.
- `references/gh-projects.md` — comandos `gh` das três gravações (só modo issue viva) + degradação
  graciosa.
