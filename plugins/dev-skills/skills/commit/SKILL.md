---
name: commit
description: >-
  Escreve mensagens de commit no padrão Conventional Commits em português (pt-BR), com um
  parágrafo de negócio explicativo seguido de bullets técnicos sucintos e o footer "Refs:
  #<numero>". Use SEMPRE que o usuário pedir para gerar, escrever, montar, revisar ou
  padronizar uma mensagem de commit — inclusive quando disser apenas "mensagem de commit",
  "commit message", "gera o commit", "descreve essas alterações para commit" ou variações — em
  qualquer repositório. Vale mesmo quando o usuário não citar "Conventional Commits"
  explicitamente. Nunca inclui a LLM como coautora da mensagem.
---

# Mensagem de commit (Conventional Commits, pt-BR)

Objetivo: produzir uma mensagem de commit clara, em português, que explique primeiro o **negócio** (por que a mudança existe e o que ela resolve) e depois os **detalhes técnicos** de forma enxuta. O leitor futuro entende a intenção antes do mecanismo.

## Formato

```
tipo(escopo): resumo no imperativo

<parágrafo de negócio: o problema anterior, o que muda e o porquê>

- <bullet técnico sucinto>
- <bullet técnico sucinto>
- ...

Refs: #<numero>
```

### Header (primeira linha)
- Estrutura `tipo(escopo): resumo`. O escopo é opcional, mas prefira incluí-lo quando houver um módulo/feature claro (ex.: `exportacao`, `auth`, `relatorios`).
- Resumo no **imperativo**, em pt-BR, começando com letra minúscula, sem ponto final. Mire ~50 caracteres e não passe de ~72.
- Tipos: `feat` (nova funcionalidade), `fix` (correção), `refactor`, `perf`, `docs`, `test`, `build`, `ci`, `chore`, `style`.

### Corpo
- Comece com **um parágrafo de negócio** (não bullets): descreva como era antes, o que passa a acontecer e o porquê/benefício. É a parte mais descritiva — mas escreva de forma sucinta para quem não acompanhou a implementação.
- Depois, **bullets técnicos curtos** com as principais mudanças (o que foi tocado, não linha a linha). Cada bullet é uma frase enxuta.
- Quebre as linhas em ~72-80 colunas para boa leitura em `git log`.

### Footer
- Termine com `Refs: #<numero>` sempre que houver número de work item/issue — informado pelo usuário ou inferido do contexto da conversa (issue em andamento, nome da branch, issue citada no pedido). **Sem número, omita o footer**: nunca escreva `Refs: #WI` nem qualquer outro placeholder — a mensagem termina nos bullets técnicos.
- **NUNCA credite IA como co-autor.** Não inclua `Co-Authored-By:` — nem trailer equivalente — apontando para modelo de linguagem, assistente ou fornecedor de IA (Claude, Anthropic, Copilot, GPT, Gemini e afins). A autoria do commit é de quem assina o commit; nada vem depois do corpo da mensagem.

## Regras de operação
- **Sempre faça o commit**, usando a mensagem gerada — a menos que o usuário peça explicitamente para NÃO commitar ou peça APENAS a mensagem: nesse caso apenas devolva a mensagem no chat, dentro de um bloco de código, pronta para copiar. Conta como APENAS a mensagem pedir para **revisar, padronizar ou reescrever** uma mensagem já existente.
- Baseie o conteúdo nas alterações reais: inspecione o diff com `git status`/`git diff` para descrever fielmente o que mudou — sem inventar mudanças.
- **Antes de commitar, mostre o que vai entrar** (`git status --short`) e estague só o que a mensagem descreve. Se aparecer algo fora do escopo da mensagem, avise antes de prosseguir.
- **Gate de segurança:** acione a skill `revisar-seguranca` sobre o diff estagiado. Achado **Crítico** ou **Alto** barra o commit até corrigir ou o usuário liberar explicitamente.
- Ajuste tipo/escopo/tamanho do corpo conforme o pedido do usuário (ex.: "encurte o corpo", "use escopo X").

## Exemplo

Contexto: a listagem não tinha como levar os dados para fora do sistema.

```
feat(exportacao): permite exportar a listagem para CSV

Até agora o usuário só conseguia tirar os dados da tela copiando e colando, o
que se perdia em listagens grandes e ignorava os filtros aplicados. A listagem
passa a oferecer uma ação "Exportar", que gera um CSV respeitando os filtros
ativos — o arquivo abre direto na planilha, com a acentuação correta.

- Listagem: nova ação "Exportar" na barra de ferramentas, desabilitada quando
  não há resultado.
- Serviço de exportação reaproveita a consulta da listagem, sem duplicar a
  lógica de filtro.
- CSV em UTF-8 com BOM e separador pt-BR, para abrir na planilha sem ajuste.
- Testes cobrem o caso "lista vazia" e o escape de aspas no conteúdo.

Refs: #482
```
