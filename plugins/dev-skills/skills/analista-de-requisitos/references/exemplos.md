# Exemplos (frase → análise → JSON)

Os exemplos são agnósticos de linguagem/stack. Adapte as buscas e os arquivos ao repositório
atual. O `type` é o **issue type nativo** (bug/feature/task); labels são **opcionais**.

## Exemplo 1 — informação suficiente (`status: ready`)
**Usuário:** "os popups estão fechando quando a gente clica ou toca fora dele"

**Análise (sinais):**
- popup → diálogo do frontend. "popups" no plural → **todos** os diálogos → transversal.
- "clica ou toca" → desktop e mobile. "fora dele" → clique no backdrop.
- Implícito: fechar sem confirmar **perde o que foi digitado** → retrabalho.
- Persona: usuário preenchendo um formulário. Suposição a declarar: ESC deve deixar de descartar.

**Grep leve:** localize onde os diálogos são configurados (ex.: um provider central de modais, ou
os pontos que abrem os diálogos) e cite 1–2 arquivos. Sem enumerar todos os call sites.

**Tipo:** `bug` (comportamento indesejado). **Labels:** nenhuma necessária (transversal, sem
módulo óbvio) — o tipo Bug já classifica.

```json
{
  "schema_version": 2,
  "title": "Os diálogos estão fechando sem ação intencional, mas não deveriam fechar ao clicar/tocar fora",
  "type": "bug",
  "labels": [],
  "fields": {
    "problema": "Hoje qualquer diálogo fecha ao clicar/tocar fora dele (no backdrop). Se o usuário já digitou algo, o conteúdo é perdido sem aviso, forçando a refazer tudo — atrito e frustração, sobretudo no mobile.",
    "requisito": "Como usuário preenchendo um formulário em um diálogo, quero que ele só feche quando eu clicar num botão de forma intencional (confirmar/salvar ou cancelar), para não perder o que digitei por um toque acidental fora dele.",
    "criterios_de_aceitacao": [
      "Nenhum diálogo fecha ao clicar/tocar no backdrop (fora do diálogo).",
      "Diálogos fecham apenas por botão explícito (Confirmar/Salvar ou Cancelar).",
      "A tecla ESC não descarta o diálogo (ou é tratada como Cancelar).",
      "Vale para todos os diálogos do app, desktop e mobile (toque)."
    ],
    "notas_tecnicas": "Comportamento transversal — provável ponto central: a configuração/provider de diálogos do front. Cite os 1–2 arquivos achados no grep leve.",
    "fora_de_escopo_e_suposicoes": "Assumido que ESC entra no escopo (desativado ou tratado como cancelar). A confirmar: aviso \"descartar alterações?\" ao cancelar com dados preenchidos (pode virar outra issue).",
    "relacionadas": []
  },
  "body": "## Problema\nHoje qualquer diálogo fecha ao clicar/tocar fora dele (no backdrop). Se o usuário já digitou algo, o conteúdo é perdido sem aviso, forçando a refazer tudo — atrito e frustração, sobretudo no mobile.\n\n## Requisito\nComo usuário preenchendo um formulário em um diálogo, quero que ele só feche quando eu clicar num botão de forma intencional (confirmar/salvar ou cancelar), para não perder o que digitei por um toque acidental fora dele.\n\n## Critérios de aceitação\n- [ ] Nenhum diálogo fecha ao clicar/tocar no backdrop (fora do diálogo).\n- [ ] Diálogos fecham apenas por botão explícito (Confirmar/Salvar ou Cancelar).\n- [ ] A tecla ESC não descarta o diálogo (ou é tratada como Cancelar).\n- [ ] Vale para todos os diálogos do app, desktop e mobile (toque).\n\n## Notas técnicas\nComportamento transversal — provável ponto central: a configuração/provider de diálogos do front (ver arquivos citados no grep leve).\n\n## Fora de escopo / Suposições\nAssumido que ESC entra no escopo (desativado ou tratado como cancelar). A confirmar: aviso \"descartar alterações?\" ao cancelar com dados preenchidos (pode virar outra issue).",
  "status": "ready",
  "clarifying_questions": []
}
```
Prévia legível ao usuário: **título + tipo (Bug) + labels (nenhuma) + corpo**, com a suposição do
ESC declarada — sem narrar a análise. Daí, siga o pedido: só "requisito" → encerre oferecendo
"estima", "prioriza" ou "registra"; "com esforço"/"com backlog" → siga a cadeia (modo JSON);
"requisito completo" ou "cria a issue" → cadeia até a `registra-issue`, que cria direto.

## Exemplo 2 — informação insuficiente (`status: needs_clarification`)
**Usuário:** "o dashboard tá meio confuso, queria melhorar"

"dashboard" e "confuso" são vagos — não dá para escrever critério testável. Não invente escopo.

```json
{
  "schema_version": 2,
  "title": "",
  "type": "feature",
  "labels": [],
  "fields": {},
  "body": "",
  "status": "needs_clarification",
  "clarifying_questions": [
    "O que especificamente confunde? (ex.: excesso de informação, rótulos, ordem, um gráfico difícil de ler, não saber por onde começar)",
    "Quem e quando sente isso? (usuário novo no 1º acesso, ou no uso diário? desktop, mobile, os dois?)",
    "Você já tem em mente como ficaria melhor, ou quer que eu proponha? (ex.: destacar o principal no topo, esconder o secundário)"
  ]
}
```
Faça as perguntas ao usuário (agrupadas) e **pare**. Só depois das respostas monte o requisito
`ready` (aí sim o `type` definitivo — provável `feature` ou `task`).

## Exemplo 3 — feature com área clara (resumo)
**Usuário:** "queria que desse pra exportar meus dados pra usar no excel"

- Infere: exportar para **CSV** (abre no Excel/Sheets) a partir da tela de listagem, respeitando
  os filtros. Declare essas suposições.
- Grep leve: ache a tela de listagem e o endpoint/consulta; cite-os.
- **Título (capacidade desejada + lacuna atual):** `Não dá para exportar os lançamentos; poder exportar para CSV (Excel)`.
- **Tipo:** `feature` (nova funcionalidade). **Labels:** opcional — só se houver uma de área óbvia
  no repo; senão nenhuma.
- Critérios fortes: ação "Exportar" visível; CSV com cabeçalho; respeita filtros; formato pt-BR
  (separador decimal/data) e acentos (UTF-8 com BOM); caso "lista vazia" tratado; isolamento por
  usuário/tenant se aplicável.
- Ofereça 1–2 perguntas de confirmação junto do rascunho (CSV vs xlsx; filtro vs tudo) — mas já
  entregue o requisito `ready`, sem travar.
