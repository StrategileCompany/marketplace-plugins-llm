---
name: planeja-implementacao
description: >-
  Desenha o plano de implementação de um requisito ou de uma issue, usando o
  Plan Mode nativo do Claude Code (EnterPlanMode/ExitPlanMode) para pensar
  antes de alterar qualquer código — em DOIS modos: (1) modo JSON (pré-issue),
  dentro do pipeline de requisito, gravando o plano no campo
  plano_implementacao do arquivo requisito-*.json da analista-de-requisitos
  (e a seção "## Plano de implementação" no body), sem tocar o GitHub e sem
  pedir confirmação adicional — quarta etapa opcional do pipeline, acionada
  quando o pedido inclui "planejar"/"plano de implementação"; (2) modo issue
  viva, planejando uma issue já existente (número/URL) fora do pipeline de
  requisito — por exemplo uma issue já em andamento — e publicando o plano
  como um comentário novo na issue (histórico: cada replanejamento soma um
  comentário; a seção "## Plano de implementação" no corpo só é adicionada
  uma vez). Funciona em QUALQUER repositório. Use quando o usuário disser
  "planeja", "planejar", "cria um plano de implementação", "plano de
  implementação dessa issue", "desenha o plano antes de implementar", ou
  dentro do pipeline de requisito junto de "requisito"/"requisito com
  esforço"/"requisito com backlog"/"requisito completo". No modo issue viva,
  NUNCA grava sem confirmação explícita.
model: opus
effort: high
---

# Planeja implementação → desenhar o plano antes de codar

## Missão
Pensar **antes de alterar qualquer código**: desenhar a abordagem de implementação, as decisões
de arquitetura e os riscos de um requisito ou de uma issue, usando o **Plan Mode** nativo do
Claude Code. Diferente de `estima-esforco`/`prioriza-backlog` — que só enriquecem o JSON sem
tocar ferramentas —, planejar muda o que você **faz**: aciona `EnterPlanMode`, escreve o plano no
arquivo de plano que o sistema indicar ao entrar, e só publica o conteúdo depois que o usuário
**aprovar o plano** (via `ExitPlanMode`). Você opera em dois modos:
- **Modo JSON (pré-issue):** dentro do pipeline de requisito, enriquecendo o JSON da
  `analista-de-requisitos` com o campo `plano_implementacao` — quarta etapa opcional do pipeline.
- **Modo issue viva:** sobre uma issue já existente (número/URL), fora do pipeline de requisito —
  tipicamente uma issue que já está em andamento e cujo plano ainda não foi desenhado.

## Modo JSON (pré-issue, dentro do pipeline)
1. **Entrada:** o caminho do arquivo `requisito-*.json` (vindo da `analista-de-requisitos`), **já
   salvo** — nunca recomece o requisito.
2. **Entre em Plan Mode** (`EnterPlanMode`) e desenhe a implementação: abordagem, arquivos
   provavelmente tocados (ancore nas *Notas técnicas* do requisito), decisões de design, riscos e
   passos. Chame `ExitPlanMode` para pedir a aprovação do plano em si.
3. **Aprovado**, grave no **mesmo arquivo** (schema no `formato-requisito.md` da
   `analista-de-requisitos` — **não muda**):
   - o campo `plano_implementacao` com o conteúdo do plano;
   - a seção `## Plano de implementação` no `body`, com o ponteiro fixo do template canônico —
     **não** duplique o conteúdo do plano no `body`.
4. **Nada de GitHub e nada de confirmação adicional** — a aprovação do plano (passo 2) já é a
   autorização; você só enriqueceu um arquivo local. Quem publica o plano como comentário, na
   criação da issue, é a `registra-issue`.
5. **Saída no chat: uma linha.** `Plano de implementação gravado no requisito.`
6. Continue a cadeia se o pedido incluir mais etapas (`estima-esforco` → `prioriza-backlog` →
   `registra-issue`).

## Modo issue viva
Planejar uma issue que já existe — tipicamente já em andamento — é uma capacidade **fora** do
pipeline de requisito: não há arquivo JSON, o destino é a própria issue.
1. **Alvo:** número ou URL da issue. Leia-a: `gh issue view <n> --json number,title,body`.
2. **A issue já tem um plano?** Se o `body` já tiver a seção `## Plano de implementação`, isto é
   um **replanejamento** — não é erro, apenas avise que vai acrescentar um novo registro (ver
   "Replanejamento" abaixo).
3. **Entre em Plan Mode** (`EnterPlanMode`) e desenhe a implementação com base no título, no
   corpo (Problema/Requisito/Critérios de aceitação) e num **grep leve** no repositório atual.
   Chame `ExitPlanMode` para a aprovação do plano.
4. **Aprovado, confirme com o usuário antes de gravar na issue** — mostre um resumo curto do
   plano (os passos principais) e peça **um "ok"** para publicar. (A aprovação do `ExitPlanMode`
   valida o **conteúdo** do plano; esta segunda confirmação autoriza **escrever na issue**, no
   mesmo padrão de "nunca grave sem confirmação explícita" das demais skills de issue viva.)
5. Com o "ok", grave (comandos e degradação graciosa em `references/gh-comentario.md`):
   - **Seção no corpo** — só se ainda **não** existir `## Plano de implementação`: acrescente-a
     (template canônico da `analista-de-requisitos`, mesmo ponteiro fixo). Já existindo, **não
     toque no corpo**.
   - **Comentário novo** — publique o conteúdo do plano via `gh issue comment` **sempre**, mesmo
     em replanejamento (é um log histórico — ver abaixo).
6. **Reporte numa linha**: issue, se era replanejamento, e que o comentário foi publicado.

### Replanejamento (histórico, não substituição)
Cada vez que a skill planeja uma issue que **já tem plano**, ela soma um **comentário novo** —
nunca edita ou apaga um comentário anterior. É um log: dá para ver como o plano evoluiu conforme
o entendimento mudou. Já a seção `## Plano de implementação` no **corpo** é gravada **uma única
vez**; o ponteiro fixo ("...resgate-o no comentário desta issue") continua valendo — quem lê a
issue vai aos comentários e usa o **mais recente** como o plano vigente.

## Guard-rails
- **Modo issue viva:** nunca publique comentário ou altere o corpo sem a confirmação explícita do
  usuário (depois da aprovação do próprio plano via `ExitPlanMode`).
- **Modo JSON:** não grava nada no GitHub — por isso não pede confirmação adicional; é só
  enriquecimento local do requisito. A aprovação do plano em si (`ExitPlanMode`) é a única
  autorização necessária.
- **Nunca** altere código antes de o plano ser aprovado — é o propósito do Plan Mode.
- A seção `## Plano de implementação` no corpo é gravada **uma vez só**; não duplique nem a
  reescreva em replanejamentos — só o comentário se repete.
- Planejar **não** altera o issue type, as labels, a estimativa ou a prioridade, nem o Status do
  board.
- Em modo issue viva, o plano é sempre publicado como **comentário**, nunca dentro do `body` — o
  corpo só aponta para ele (mesma regra do modo JSON / `registra-issue`).

## Referências
- schema do campo `plano_implementacao` e o template canônico da seção `## Plano de
  implementação` no `body`: `formato-requisito.md` da `analista-de-requisitos` (contrato do
  pipeline — não redefina aqui).
- `references/gh-comentario.md` — modo issue viva: achar a issue, checar a seção existente,
  comandos `gh` para corpo/comentário, degradação graciosa.
