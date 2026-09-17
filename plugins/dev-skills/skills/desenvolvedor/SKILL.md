---
name: desenvolvedor
description: >-
  Skill de desenvolvedor que leva uma solicitação de implementação do backlog
  ao commit, orquestrando as demais skills. Dispara SEMPRE que o usuário
  disser "implemente", "altere", "corrija", "construa", "faz a feature/o bug
  X", e nas palavras de fechamento "commit", "push", "versiona", "fecha a
  issue". Verifica se há uma issue: se não houver, procura no backlog e — se
  for nova — cria via o pipeline de requisito (analista-de-requisitos →
  estima-esforco → registra-issue), nascendo já dimensionada e no board;
  sincroniza a branch com a base remota por rebase antes de escrever código,
  move a issue para "In Progress" no board, implementa seguindo os critérios
  de aceitação, valida build+testes (bloqueia se falhar), confere os critérios
  um a um e marca os checkboxes da issue numa única atualização e, no
  fechamento, faz commit/push conforme pedido e, com confirmação, marca Done e
  fecha a issue. Global — funciona em qualquer repositório.
---

# Desenvolvedor: da solicitação ao commit

## Missão
Levar uma solicitação de implementação do **backlog ao commit**, com rastreabilidade na issue.
Você **orquestra** as outras skills — não reimplementa o que elas fazem:
- `analista-de-requisitos` — entende e estrutura uma necessidade nova.
- `estima-esforco` — dimensiona o requisito (**modo JSON**, antes do registro).
- `registra-issue` — registra a issue já dimensionada e a adiciona ao board.
- `revisar-seguranca` — **portão de segurança do diff**, acionado **antes do commit** (barra em Crítico/Alto).
- `versionador` — quando o pedido inclui **versiona** (versão + commit + push).

## Passo 0 — Tem issue?
A primeira verificação: o usuário informou uma **issue** (número/URL)?
- **Sim** → **Fluxo COM issue**.
- **Não** → **Fluxo SEM issue**.

## Fluxo SEM issue
1. **Procure no backlog.** Interprete a tarefa e busque:
   `gh issue list --state open --search "<palavras-chave>"` (e `gh search issues` se útil). Leia os
   candidatos mais próximos e **julgue** o melhor match. (O `gh` não faz busca vetorial — é
   palavra-chave + leitura/julgamento.)
2. **Achou um candidato plausível?** Mostre a issue (nº, título, corpo) e pergunte:
   *"Isso se refere à #X?"*.
   - **Confirmou** → Fluxo COM issue (#X).
   - **Não é** → trate como "não achou".
3. **Não achou** → acione **`analista-de-requisitos`** (estrutura; pode perguntar) e, com o "ok"
   do requisito, siga o pipeline **sem novas paradas**: **`estima-esforco`** (modo JSON, enriquece
   o requisito) → **`registra-issue`** (cria a issue já dimensionada e a adiciona ao board).
4. **Apresente o requisito** da issue e peça autorização: *"Posso começar a implementar?"*.
   - **Aprovou** → Fluxo COM issue.

## Fluxo COM issue (issue #N)
1. **Eco do requisito:** assim que a issue a implementar estiver identificada, escreva no chat o
   **título** e as **duas primeiras seções do corpo** — `## Problema` e `## Requisito` —
   transcritas na íntegra (`gh issue view N --json title,body`). Isso dá ao usuário a chance de
   ver o que será implementado — e de barrar uma issue errada — **antes** de qualquer mudança de
   estado (branch, board). Se o corpo não seguir o template canônico do analista-de-requisitos,
   mostre o equivalente mais próximo (os primeiros parágrafos).
2. **Branch (condicional ao tamanho):** leia o **tamanho** da issue — prefixo T-shirt no título,
   linha de estimativa no corpo ou campo `Size` do board (gravados pela `estima-esforco`) — e
   decida:
   - **PP ou P** → **não pergunte**; siga na **branch atual**. São mudanças pequenas e pontuais, e
     abrir branch para elas só adiciona cerimônia.
   - **M ou maior** (M/G/GG/XG/XXG) → **pergunte** antes de mover para In Progress:
     *"Quer uma branch específica pra #N (ex.: `feat/N-slug`) ou implemento na branch atual?"*.
     Crie a branch se ele pedir; senão siga na branch atual.
   - **Sem estimativa** (issue não dimensionada) → na dúvida, **pergunte** (trate como M+).
3. **Sincronize com a origin — ANTES de escrever qualquer código.** Codar sobre uma base
   desatualizada gera conflito lá na frente e, pior, faz você "consertar" o que já foi consertado
   na base. Descubra a base remota (`main` ou `master` — **nunca assuma**), rode `git fetch origin`
   e traga os commits para o ponto onde vai trabalhar, **por rebase**:
   - **Está na própria base** (`main`/`master`) → `git pull --rebase origin <base>`.
   - **Está numa branch de trabalho** → `git rebase origin/<base>`, para que a branch passe a
     conter os últimos commits da base remota.
   - **Vai criar branch nova** (passo 2) → crie-a a partir de `origin/<base>` recém-buscada: já
     nasce sincronizada.
   Se a árvore estiver suja, faça **stash automático** e reaplique depois, avisando. Se o rebase
   **conflitar**, **pare e chame o usuário** — não aborte nem force nada por conta própria. Se o
   rebase reescrever commits **já publicados**, o push adiante exigirá `--force-with-lease`: só com
   o "ok" explícito. Sem `origin` (repo local), **avise e siga**. Mecânica em
   `references/sincronizacao-git.md`.
4. **Status → `In Progress` — mova ANTES de escrever qualquer código.** Este é o passo que torna
   o trabalho visível: o board é a fonte da verdade do que está em andamento. Se você pular direto
   para a implementação, a issue fica parada em "Todo" enquanto já está sendo feita — a
   rastreabilidade quebra e um colega pode pegar a mesma tarefa achando que está livre. Por isso,
   **não comece a implementar sem antes fazer essa transição** (adicione a issue ao board se
   preciso). Mecânica em `references/board-e-gh.md`.
   **Única exceção:** quando a transição é *impossível* — o repo não tem board ou falta o scope
   `project` —, **avise explicitamente** que não deu para mover e só então siga. A degradação
   graciosa cobre a **ausência de board**, nunca "pular a etapa por pressa".
5. **Implemente** usando os **Critérios de aceitação** da issue como especificação. Respeite as
   convenções do projeto (CLAUDE.md/AGENTS.md, arquitetura, estilo, testes) — não reinvente.
6. **Valide:** rode o **build** e os **testes relevantes** do projeto. Descubra os comandos em
   runtime — CLAUDE.md/AGENTS.md, scripts do `package.json`, `Makefile`, CI, ou o manifesto da
   stack (`dotnet build`, `npm test`, `pytest`, `go test ./...`, `mvn verify`…); **nunca assuma**
   uma stack. **Bloqueie o commit se falhar** — conserte ou reporte; nunca feche com build/teste
   quebrado.
7. **Confira os critérios de aceitação e marque a issue.** Com build/testes verdes, releia a seção
   `## Critérios de aceitação` da issue e **julgue cada critério um a um**, em três baldes:
   **satisfeito** (com evidência — arquivo:linha, teste que cobre), **não verificável** (com o
   motivo: exige device físico, ambiente de homologação, dado de produção…) e **não atendido**.
   Depois escreva o resultado na issue em **uma única passada**: **um** `gh issue edit` marcando de
   uma vez **todos** os checkboxes satisfeitos, e **um** `gh issue comment` com a conferência
   completa (evidências, motivos dos não verificáveis e o que falta nos não atendidos). **Nunca**
   edite a issue a cada critério.
   **Critério não atendido barra o commit** — igual ao gate de segurança: reporte o que falta e só
   siga com a **correção** ou com **override explícito** do usuário. Se for corrigir, **não escreva
   na issue ainda**: a escrita é a conferência definitiva, feita uma vez só, imediatamente antes do
   commit que vai de fato acontecer. Mecânica e formato em `references/criterios-de-aceitacao.md`.
8. **Fechamento** (quando o usuário pedir): abaixo.

## Fechamento (commit / push / versiona / fecha)
**Gate de segurança — antes de qualquer commit.** Acione a skill **`revisar-seguranca`** sobre o
diff a ser commitado (modo gate). Se ela **barrar** (achado **Crítico** ou **Alto**), **não
prossiga** com o commit: reporte, ofereça corrigir/abrir issue, e só siga com a **correção** ou com
**override explícito** do usuário ("segue mesmo assim"). Achado **Médio/Baixo** apenas informa, não
bloqueia. É o portão que impede código com risco conhecido de entrar no histórico.

Depois de passar nos **dois gates** (critérios de aceitação e segurança), faça **exatamente o que
foi pedido**:
- **commit** → mensagem no estilo do repo (veja `git log`), referenciando a issue: `… (#N)`.
- **push** → `git push` (branch atual, salvo se criaram branch da issue). Se o rebase do passo 3
  reescreveu commits já publicados, `--force-with-lease` **com o "ok" do usuário**.
- **versiona** → acione a skill **`versionador`** (versão + commit + push).

Depois, **confirme o fechamento da tarefa**: *"Fechar a tarefa? (Status → Done e issue fechada)"*.
- Com o "ok": Status do board → **`Done`** **e** `gh issue close N`. (Aqui **Done ≡ issue fechada**.)

## Guard-rails
- Nunca commite/feche com **build ou testes quebrados**.
- **Sincronizar antes de codar não é opcional:** a branch de trabalho tem de conter os últimos
  commits da base remota (`origin/main` ou `origin/master`) **antes** da primeira linha de código,
  por **rebase**. Conflito de rebase **para o fluxo** e chama o usuário; `--force-with-lease` só
  com o "ok" explícito. Sem `origin`, avise e siga.
- **Critérios de aceitação são gate de commit:** confira cada um após build/testes; **critério não
  atendido barra** até corrigir ou o usuário liberar explicitamente. **Não verificável não barra** —
  mas exige o motivo registrado na issue.
- **A issue é atualizada uma única vez por fechamento:** um `gh issue edit` com todos os checkboxes
  e um `gh issue comment` com a conferência. Nunca uma escrita por critério.
- **Segurança é gate de commit:** `revisar-seguranca` roda **antes do commit**; **Crítico/Alto
  barra** até corrigir ou o usuário liberar explicitamente. Não pule o gate por pressa.
- **Branch é condicional ao tamanho:** PP/P seguem na branch atual **sem perguntar**; **M ou maior**
  (ou issue sem estimativa) pergunta antes de mover para In Progress. Nunca force branch nova sem o "ok".
- No fechamento, faça só o que foi pedido (commit e/ou push e/ou versiona); **Done + close** exigem
  confirmação explícita.
- **Mover para `In Progress` antes de codar não é opcional quando existe board** — é o gate que
  mantém o board fiel ao que está em andamento. A etapa só é dispensada quando não há board/scope
  `project` (transição impossível) e, mesmo aí, **avise**. O que degrada graciosamente é a
  mecânica, não a intenção.
- Respeite as convenções do repositório; a implementação segue os **critérios de aceitação** da
  issue.

## Telemetria "Actual" (fica para depois)
Gancho planejado: ao fechar, registrar o **custo real de agente** (modelo, tokens, duração) como
"Actual", para calibrar contra o `Estimate` da `estima-esforco`. Atribuição limpa exige isolar a
implementação (subagente/SDK) — **não implementado agora**.

## Referências
- `references/sincronizacao-git.md` — descobrir a base remota, rebase, stash, conflito e
  `--force-with-lease`; degradação graciosa.
- `references/criterios-de-aceitacao.md` — ler, julgar e marcar os critérios; a escrita única na
  issue e o formato do comentário de conferência.
- `references/board-e-gh.md` — mover Status no board, fechar issue, buscar no backlog; comandos e
  degradação graciosa.
