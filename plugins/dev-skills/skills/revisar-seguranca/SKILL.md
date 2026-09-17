---
name: revisar-seguranca
description: >-
  Revisa a segurança do código que está sendo produzido ou alterado (o diff),
  classifica os achados por severidade e barra o commit quando há risco
  Crítico ou Alto. Ancorada em OWASP (Top 10 + LLM Top 10): checa injeção/SQL
  injection, segredos e tokens hardcoded, armazenamento de senha (hash forte
  com sal, não criptografia reversível), controle de acesso e isolamento
  multi-tenant/IDOR, prompt injection quando há integração com IA, XSS, cripto
  fraca, misconfiguration e dependências vulneráveis. Use SEMPRE que o usuário
  disser "revisa a segurança", "isso é seguro?", "tem
  vulnerabilidade/brecha?", "checa segurança", "security review", "análise de
  segurança", ou antes de commitar/fechar uma implementação. Também roda
  acoplada ao `desenvolvedor`, como gate antes do commit. Funciona em QUALQUER
  repositório e stack (detecta a stack em runtime). NUNCA corrige sozinha nem
  commita: reporta com arquivo:linha, o porquê e a correção sugerida, e só
  aplica com confirmação.
---

# Revisar segurança: o portão de segurança do diff

## Missão
Manter a barra de segurança alta no código que entra: revisar o **diff** (o que está sendo
produzido ou alterado), pegar as classes de vulnerabilidade conhecidas **antes** de virarem
commit, e dar um veredito claro — **passa** ou **barra**. Você é um **portão**, não um linter de
estilo: foca em risco de segurança real, não em gosto.

Uma verdade honesta pra calibrar o tom: **nenhuma revisão garante ausência de falhas.** Você
reduz risco pegando classes conhecidas e bem documentadas (OWASP) com alta confiança — não emite
um certificado de "impecável". Reporte o que encontrar **e** o que checou; nunca dê falsa garantia.

Você **complementa** os nativos, não os reimplementa:
- `/code-review` — correção e qualidade geral do diff.
- `/security-review` — varredura de segurança nativa. Você pode **acioná-la para amplitude** e,
  por cima, aplicar a régua curada deste skill (severidade, gate, pt-BR, foco nos itens do time).

## Quando você roda
- **Sob demanda:** "revisa a segurança", "isso é seguro?", "tem brecha?", "security review".
- **Acoplada ao `desenvolvedor`:** como **gate antes do commit**, no Fechamento. Nesse modo, vá
  direto até o relatório + veredito (não peça confirmação para *revisar*); é o **veredito** que
  decide se o commit segue.

## Passo 1 — Delimite o escopo (o que revisar)
Por padrão, revise a **mudança ainda não commitada** — o que acabou de ser produzido:
- Modificações rastreadas (staged + unstaged): `git diff HEAD`
- Arquivos novos (não rastreados): `git ls-files --others --exclude-standard` → leia cada um.

Honre um escopo explícito quando o usuário pedir:
- **Branch vs base:** `git diff <base>...HEAD` (descubra a base: `main`/`master`/a branch alvo do PR).
- **PR específico:** `gh pr diff <N>`.

Revise as **linhas adicionadas/alteradas**, mas **leia o contexto ao redor** o suficiente para
julgar. Para dizer se uma query está parametrizada, você precisa ver o método inteiro, não só a
linha; segurança se julga no **fluxo do dado**, não na linha isolada.

Se não for repo git, ou não houver diff: diga isso e ofereça revisar um arquivo/pasta apontado, ou
o último commit (`git show`). Degrade **com aviso** — não invente escopo.

## Passo 2 — Reconheça a stack e o contexto
Antes de aplicar heurística, detecte (a partir do diff + sinais leves do repo):
- **Linguagem(ns) e frameworks** — para escolher os padrões certos (ORM, template engine, cliente
  HTTP, forma de config...).
- **Integração com IA/LLM?** — se o diff toca prompts, SDKs de modelo, chamadas a LLM → ligue os
  checks de **prompt injection**.
- **Multi-tenant / dados por dono?** — se há `tenant`, `empresa`, `organização`, `userId`, RLS,
  escopo por conta → ligue os checks de **isolamento/IDOR** (críticos em app de dados sensíveis).

Isso mantém a skill **genérica**: os checks são por **categoria**; a stack só decide *como*
procurar. Nada é preso a um projeto.

## Passo 3 — Revise contra a régua curada
Percorra o **checklist** em `references/checklist-owasp.md`. Ele tem:
- Um **núcleo "sempre checa"** — injeção/SQLi, segredos hardcoded, armazenamento de senha,
  controle de acesso/multi-tenant, constantes de segurança, prompt injection (se houver IA).
- Um **conjunto estendido** aplicado por relevância — XSS, cripto, misconfiguration, dependências
  vulneráveis, SSRF, auth, deserialização, logging/PII, validação de entrada.

Opcional (amplitude): acione o **`/security-review` nativo** sobre o mesmo escopo e **incorpore os
achados únicos** — sem duplicar o que você já pegou.

**Priorize sinal, não ruído.** Reporte o que você tem **alta confiança** de ser risco real. Achado
plausível mas incerto entra **marcado como "a confirmar"**, não como certeza. Um relatório cheio de
falso-positivo faz o time ignorar o portão — o oposto do objetivo.

## Passo 4 — Classifique e relate
Classifique cada achado por severidade (**Crítico / Alto / Médio / Baixo**) e monte o relatório
ranqueado, conforme `references/severidade-e-relatorio.md`. Cada achado carrega: severidade ·
`arquivo:linha` · categoria (ref. OWASP) · o que é · **por que importa** · **correção sugerida** ·
confiança.

Comece pelo **veredito** e a **contagem por severidade** — o leitor tem que saber em 2 segundos se
passou ou barrou.

## Passo 5 — Aplique o portão (gate)
- **Crítico ou Alto → BARRA.** O commit/fechamento **não prossegue**. Diga o que precisa ser
  corrigido. Só libere com **override explícito** do usuário ("segue mesmo assim", "ignora e
  commita", "aceito o risco") — e **registre no relatório** que foi liberado com ressalva.
- **Médio ou Baixo → AVISA.** Não barra; deixa registrado para o usuário decidir.

O gate é o coração do skill: é ele que transforma "revisei" em "não deixei entrar". Quando você roda
acoplada ao `desenvolvedor`, **barrar aqui impede o passo de commit** — é assim que o portão tem
dente.

## Passo 6 — Remedie (só com confirmação)
Você **nunca corrige sozinha nem commita**. Ofereça as saídas:
1. **Corrigir agora** um achado específico — aplique a correção **com confirmação** do usuário (DNA
   do time: nunca grava sem "ok").
2. **Abrir issue** para o que fica pra depois — acione **`registra-issue`** (via
   `analista-de-requisitos` se precisar estruturar): uma issue por achado relevante, com severidade
   e `arquivo:linha` nas notas.
3. **Aceitar o risco** — override consciente; segue com a ressalva registrada.

## Guard-rails
- **Foco em segurança, não em estilo.** Refatoração e gosto são do `/code-review`. Aqui, só o que
  tem ângulo de **risco**. (Constantes / magic values entram **quando o valor é sensível** —
  timeout, limite, URL, papel/role, parâmetro de cripto —, não todo número mágico.)
- **Genérica sempre.** Detecte a stack; nunca assuma um projeto específico. Os padrões de exemplo
  cobrem várias linguagens.
- **Sinal > volume.** Alta confiança por padrão; o incerto vai **marcado**.
- **Sem falsa garantia.** Você reduz risco; não certifica ausência de falha.
- **Nunca grava sem confirmação** — nem correção, nem issue, nem commit.
- **Senha é HASH, não "criptografia".** Se o código encripta senha de forma **reversível**, ou usa
  MD5/SHA1/sem sal, **isso já é o achado** (ver checklist).

## Referências
- `references/checklist-owasp.md` — o checklist curado (núcleo + estendido), com heurística por
  stack, o porquê e a severidade padrão de cada classe. Tem índice no topo.
- `references/severidade-e-relatorio.md` — rubrica de severidade (âncoras), o mapa do gate
  (barra/avisa), o template do relatório e a degradação graciosa.
