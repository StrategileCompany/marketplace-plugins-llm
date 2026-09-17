# Formato do requisito (contrato do pipeline)

Este é o contrato entre as skills do pipeline de requisito. O JSON nasce na **análise** (esta
skill), é **enriquecido no mesmo arquivo** pelas etapas seguintes e é consumido no **registro**
(`registra-issue`), que aplica tudo de uma vez na criação da issue.

| Etapa | Skill | O que preenche |
|---|---|---|
| 1. Análise | `analista-de-requisitos` | `title`, `type`, `labels`, `fields`, `body`, `status` |
| 2. Esforço | `estima-esforco` (modo JSON) | bloco `estimativa` |
| 3. Prioridade | `prioriza-backlog` (modo JSON) | bloco `prioridade` |
| 4. Registro | `registra-issue` | bloco `registro` (nº/URL após criar) |

O arquivo vive no scratchpad da sessão (ex.: `requisito-<slug>.json`). Cada skill **acrescenta o
seu bloco sem tocar no resto**. O registro pode acontecer em qualquer etapa — blocos ausentes só
significam que a issue nasce sem aquelas marcações.

## Schema (JSON)
```json
{
  "schema_version": 2,
  "title": "Problema atual e/ou comportamento desejado (sem ponto final)",
  "type": "bug | feature | task",
  "labels": [],
  "fields": {
    "problema": "Comportamento atual + impacto. 1–3 frases.",
    "requisito": "Como <persona>, quero <capacidade>, para <benefício>.",
    "criterios_de_aceitacao": ["condição testável 1", "condição testável 2"],
    "notas_tecnicas": "Área e 1–3 arquivos prováveis (do grep leve); dependências (#NN). Ou null.",
    "fora_de_escopo_e_suposicoes": "O que NÃO faz parte; suposições assumidas. Ou null.",
    "relacionadas": ["#12"]
  },
  "body": "markdown do corpo, já renderizado no template canônico abaixo",
  "status": "ready | needs_clarification",
  "clarifying_questions": [],
  "estimativa": {
    "tshirt": "PP | P | M | G | GG | XG | XXG",
    "pontos": 3,
    "confianca": "alta | média | baixa",
    "incerteza": "o driver principal de incerteza"
  },
  "prioridade": {
    "score": 3.4,
    "drivers": { "customer_value": 5, "business_value": 3, "risco_criticidade": 2, "efeito_destravador": 4 },
    "confianca": "alta | média | baixa",
    "justificativa": "uma linha: os drivers que pesaram"
  },
  "registro": { "numero": 61, "url": "https://github.com/<owner>/<repo>/issues/61" }
}
```
- `type`: **issue type nativo do GitHub** — `bug`, `feature` ou `task` (ver tabela). É a
  classificação **principal**; a skill de registro a aplica como tipo nativo da issue.
- `labels`: **opcional** — labels extras (área, prioridade, módulo do repo, etc.). **Não** use
  label para espelhar o tipo (o tipo já é nativo). Deixe `[]` a menos que haja uma label útil e
  óbvia, ou o usuário peça. Só nomes que existem em `gh label list`.
- `status: "needs_clarification"`: preencha `clarifying_questions`, deixe `body` vazio, e **não**
  siga o pipeline — pergunte ao usuário primeiro; a cadeia continua depois das respostas.
- `fields` são a informação mapeada (rastreio/reuso); `body` é o que vai para a issue. Gere os
  dois juntos, coerentes.
- `estimativa` / `prioridade` / `registro`: **omitidos** até a skill correspondente rodar (não crie
  vazios). A analista não os preenche.
- O `body` permanece **só o requisito**: as linhas de estimativa/prioridade da issue são compostas
  pela `registra-issue` na criação (a partir dos blocos), sem alterar o `body` do JSON.

## Template canônico do corpo (renderize `body` exatamente assim)
```
## Problema
<Comportamento atual + o incômodo/impacto. 1–3 frases. Situe o leitor.>

## Requisito
Como <persona>, quero <capacidade/comportamento>, para <benefício>.

## Critérios de aceitação
- [ ] <condição objetiva e testável>
- [ ] <cobre casos de borda: mobile, ESC, erro, vazio...>

## Notas técnicas (opcional)
<Módulo e 1–3 arquivos prováveis (do grep leve), dependências (#NN), links.>

## Fora de escopo / Suposições (opcional)
<O que NÃO faz parte; e qualquer suposição que você assumiu ao inferir.>
```
**Regras de renderização:**
- **Problema, Requisito, Critérios de aceitação** são obrigatórias.
- O "(opcional)" nos cabeçalhos é nota deste template, **não** vai para a issue: com conteúdo,
  use o cabeçalho limpo (`## Notas técnicas`); vazia, **omita a seção inteira** (sem cabeçalho
  órfão).
- Critérios de aceitação cravam o comportamento e cobrem bordas (ESC, toque, telas, vazio). Toda
  suposição inferida aparece explícita.
- `relacionadas` pode ser citada em Notas técnicas (ex.: "Relacionada: #12").

## Título
Descreva o **problema atual** e/ou o **comportamento desejado**, em linguagem natural — o efeito
que o usuário sente, **não** a solução técnica. Três formatos (escolha conforme o caso):

1. **Problema atual** (verbos no passado/presente):
   `Os popups estão fechando sem ação intencional`
2. **Comportamento desejado** (verbos no futuro/condicional):
   `Os popups não deveriam fechar automaticamente ao clicar/tocar fora`
3. **Problema + desejado** (mesclado — geralmente o melhor):
   `Os popups estão fechando sem ação intencional, mas não deveriam fechar ao clicar/tocar fora`

**Por tipo:**
- **Bug:** prefira o formato **mesclado** (o que está errado hoje + o que se espera) — é onde o
  contraste problema↔desejado mais ajuda.
- **Feature:** foque na **capacidade desejada** (formato 2), opcionalmente citando a lacuna atual.
  Ex.: `Não dá para exportar os lançamentos; poder exportar para CSV (Excel)`.
- **Task:** descreva o **trabalho** de forma direta. Ex.: `Cobrir o ConviteEmailSender com testes unitários`.

**Regras:** sem `T-NNN`, sem ponto final, sem prefixo de tipo (o tipo é nativo), **sem prefixo de
tamanho** — o `[<T>] - ` é aplicado pela `registra-issue` na criação, quando houver `estimativa`.
Evite o título como solução ("só fechar por botão"); descreva o problema/efeito.

## Tipo (issue type nativo do GitHub)
O GitHub tem **issue types** nativos (separados de labels): tipicamente **Bug**, **Feature**,
**Task** (e "No type"). Classifique o requisito num destes:

| `type` | Issue type | Quando |
|--------|-----------|--------|
| `bug` | **Bug** | Um problema ou comportamento inesperado (algo quebrado/errado). |
| `feature` | **Feature** | Pedido, ideia ou nova funcionalidade. |
| `task` | **Task** | Um trabalho específico (refactor, teste, doc, infra, chore). |

A skill `registra-issue` mapeia isso para o tipo nativo **que existe** no repo/org e o aplica.
Se o repo não tiver issue types habilitados, o tipo é omitido (e, se o usuário quiser, pode virar
uma label opcional). Nunca invente um tipo fora dos que existem.

## Labels (opcional)
Labels são um **recurso opcional e complementar** ao tipo — para área/módulo/prioridade. Aplique
uma só quando o encaixe for óbvio **e** a label existir (`gh label list`); na dúvida, deixe de
fora e ofereça ao usuário na confirmação. **Não espelhe o tipo como label** (nada de `type: bug` +
label `bug`).
