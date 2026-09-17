# Skills no GitHub Copilot — Guia Prático

> Como transformar uma pasta com um `SKILL.md` em uma capacidade que o Copilot
> aciona sozinho — com foco no **Visual Studio 2026** e no **VS Code**, e
> comparando com a Copilot CLI e o Copilot no GitHub (nuvem).

---

## 1. O conceito: uma *skill* não é um *slash command*

Uma **skill** (Agent Skill) é um conjunto de instruções reutilizáveis, gravado
num arquivo `SKILL.md`, que **ensina o agente a executar uma tarefa** (gerar uma
mensagem de commit, versionar o projeto, revisar segurança etc.).

A diferença mais importante — e a que mais confunde quem vem de "comandos" — é
**quem dispara**:

| | Como é acionado | Exemplo |
|---|---|---|
| **Skill** | **O agente decide** (model-invoked). Você descreve a tarefa em linguagem natural e o Copilot escolhe a skill pela `description`. | "gera a mensagem de commit dessas alterações" → dispara a skill `commit` |
| **Prompt / slash command** | **Você chama** (user-invoked), digitando `/nome`. | `/explain`, `/nome-do-prompt` |
| **Custom instructions** | **Sempre ativas**, como pano de fundo. | `copilot-instructions.md` |

> **Regra de ouro:** skill é para o agente *escolher quando* usar. Se você quer
> algo que **você** invoca explicitamente e sempre roda igual, isso é um
> **prompt file** ou um **custom agent**, não uma skill.

Esse mesmo formato `SKILL.md` segue a especificação aberta
[agentskills.io](https://agentskills.io/specification), então **a mesma skill
funciona no Claude Code e no Copilot** (com algumas diferenças que veremos na
seção 8).

---

## 2. Anatomia de uma skill

Cada skill é **uma pasta** com um `SKILL.md` dentro. Recursos extras (scripts,
exemplos, documentação) ficam em subpastas opcionais.

```text
minha-skill/
├── SKILL.md          # obrigatório: frontmatter (metadados) + instruções
├── scripts/          # opcional: código executável
├── references/       # opcional: documentação de apoio
└── assets/           # opcional: templates, modelos
```

### O `SKILL.md`

```markdown
---
name: github-issues
description: Cria e gerencia issues no GitHub seguindo o padrão do time. Use ao
  trabalhar com rastreamento de issues, relatórios de bug ou pedidos de feature.
---

Ao criar issues no GitHub:

- Use o título no formato: [Componente] Descrição curta
- Aplique labels conforme o tipo da issue
- Inclua passos de reprodução em bugs
- Vincule issues e PRs relacionados
```

### Campos do frontmatter

| Campo | Obrigatório | Regras |
|---|---|---|
| `name` | **Sim** | Só **letras minúsculas, números e hífen**. **Máx. 64 caracteres.** Precisa ser **igual ao nome da pasta**. |
| `description` | **Sim** | O que a skill faz **e quando usá-la**. **Máx. 1.024 caracteres.** |
| `license` | Não | Nome da licença ou referência a um arquivo. |
| `compatibility` | Não | Requisitos de ambiente (produto, pacotes de sistema). |
| `metadata` | Não | Pares chave-valor livres. |
| `allowed-tools` | Não | Lista de ferramentas pré-aprovadas (separadas por espaço). |

> ⚠️ **Duas regras que causam "falha silenciosa"** (a skill simplesmente não
> aparece, sem erro):
> 1. **`name` com caractere inválido** ou **diferente do nome da pasta**.
> 2. **`description` acima de 1.024 caracteres** (o Visual Studio é rígido nisso).

**Dica:** mantenha o `SKILL.md` com menos de ~500 linhas; jogue material extenso
para arquivos em `references/`.

---

## 3. Onde colocar as skills (os diretórios que o Copilot varre)

Existem **dois escopos**:

| Escopo | Locais aceitos | Vale para... |
|---|---|---|
| **Workspace / projeto** (versionado no repo, compartilhado com o time) | `.github/skills/`, `.claude/skills/`, `.agents/skills/` | **apenas aquele repositório** quando aberto |
| **Pessoal** (no seu perfil de usuário, não vai para o git) | `~/.copilot/skills/`, `~/.claude/skills/`, `~/.agents/skills/` | **todos os seus projetos** |

No Windows, `~` é a sua pasta de usuário, ex.: `C:\Users\SeuUsuario`. Então
"pessoal" fica em `C:\Users\SeuUsuario\.copilot\skills\`.

> ⚠️ **Armadilha nº 1 — `.copilot/skills` dentro do projeto NÃO é lido.**
> O escopo pessoal é na sua **HOME** (`~/.copilot/skills`). Uma pasta
> `.copilot/skills` na raiz do projeto **não** é varrida. No projeto, os nomes
> válidos são `.github/skills`, `.claude/skills` ou `.agents/skills`.

> ⚠️ **Armadilha nº 2 — "criei em outro projeto".** Skill de **workspace** só
> aparece com **aquele repo aberto**. Se você quer que ela vale em qualquer
> projeto, use o escopo **pessoal** (`~/.copilot/skills`), ou copie a pasta para
> o `.github/skills` do projeto atual.

### Como instalar = copiar a pasta

Importar uma skill é **copiar a pasta dela** (com o `SKILL.md` e as subpastas)
para um dos locais acima. A estrutura final tem que ser:

```text
~/.copilot/skills/
├── commit/
│   └── SKILL.md
├── versionador/
│   ├── SKILL.md
│   └── scripts/
└── github-issues/
    └── SKILL.md
```

> ⚠️ **Armadilha nº 3 — nível de aninhamento.** O `SKILL.md` precisa estar
> **direto** dentro da pasta da skill. Se você copiar a pasta-mãe inteira
> (ex.: `skills/` ou `dev-skills/`) por engano, vira
> `~/.copilot/skills/skills/commit/SKILL.md` (fundo demais) e o Copilot
> não encontra.

---

## 4. A grande diferença: cada superfície aciona de um jeito

Este é o ponto que gera mais confusão. **"Skill" é o mesmo formato em toda
parte, mas COMO ela é acionada e recarregada muda conforme onde você usa o
Copilot:**

| Superfície | Aparece no menu `/`? | Como aciona | Como recarrega |
|---|:--:|---|---|
| **Visual Studio 2026** | **Não** | **Automático** em *agent mode*: o agente decide pela `description`. | Reiniciar / novo chat de agente (não há `/reload`) |
| **VS Code** | **Sim** | No menu `/` (junto dos prompt files) **e** automático em agente. | *Developer: Reload Window* |
| **Copilot CLI** | **Sim** | `/nome-da-skill …` **e** automático. | `/skills reload` |
| **Copilot no GitHub** (cloud agent, code review) | **Não** | **100% automático**. Não existe `/` para skill. | Automático (lê do repo) |

> 🔴 **Consequência prática:** se você digitar `/` no **Visual Studio** ou no
> **Copilot da web** esperando ver suas skills, **não vai aparecer nada** — não
> porque a skill está errada, mas porque **nessas superfícies skill não é
> slash**. Você **descreve a tarefa** e o agente aciona.

---

## 5. Passo a passo — Visual Studio 2026 (foco)

### 5.1. Pré-requisitos
- **Visual Studio 2026 versão 18.5 ou superior** para *usar* skills.
- O **painel de Skills** (para ver/gerenciar pela interface) só existe no
  **18.6+ Insiders**.
- Confira em **Help → About Microsoft Visual Studio**.
- Uma assinatura ativa do **GitHub Copilot**.

### 5.2. Instale a skill
- **Para todos os seus projetos (pessoal):** copie a pasta para
  `~/.copilot/skills/` → ex.: `C:\Users\SeuUsuario\.copilot\skills\minha-skill\SKILL.md`.
- **Só para este projeto (workspace):** copie para `.github/skills/` na raiz do
  repositório.

> 💡 **Dica de criação:** no VS 2026 dá para criar skill pelo **painel de Skills**
> (botão **+**), mas só no **18.6+ Insiders**. Se você também usa **VS Code**, o
> comando **`/create-skill`** (seção 6) é o jeito mais rápido — ele grava a skill
> já na pasta certa e ela **aparece automaticamente no VS 2026** (pasta
> compartilhada).

### 5.3. Use em *agent mode*
Skill **só roda em agente**. No Copilot Chat, troque o modo de **Ask** para
**Agent**.

### 5.4. Verifique (painel de Skills)
Clique no ícone de **Tools no canto inferior direito do Copilot Chat** → abre o
**painel de Skills**, com **todas as skills descobertas** e, importante, os
**diagnósticos de erro** (é aqui que uma `description > 1.024` ou um `name`
inválido aparece marcado). No painel você pode **editar**, **abrir o local do
arquivo** e **filtrar** por nome.

> Se você **não** estiver no 18.6+ Insiders, não terá o painel. Nesse caso,
> verifique **testando**: em agent mode, peça algo que combine com a
> `description` e observe a skill **ativar no chat**.

### 5.5. Recarregue (re-scan)
Adicionou a skill com o VS aberto? Abra um **novo chat de agente** ou
**reinicie o Visual Studio**. **Não existe `/reload`** aqui.

### 5.6. Acione
Não digite `/`. **Descreva a tarefa** — o agente escolhe a skill e avisa no chat
quando a aplica.

---

## 6. Passo a passo — VS Code

O VS Code (versão recente) tem o **melhor fluxo para *criar* skills** — e é o
caminho que recomendo para quem está começando, porque ele **grava a skill já na
pasta certa**, eliminando de vez as armadilhas de local e aninhamento da
seção 3.

### 6.1. Criar uma skill do zero (assistido) — o jeito fácil

**Opção A — pelo chat (`/create-skill`):**
1. No Copilot Chat, digite **`/create-skill`** e descreva a skill que você quer
   (ex.: *"uma skill para rodar e depurar testes de integração"*).
2. O agente faz **perguntas de esclarecimento** e gera o `SKILL.md` já com a
   estrutura de pastas pronta.

**Opção B — pela interface (Agent Customizations):**
1. Clique na engrenagem **Configure Chat** (ou rode **Chat: Open Customizations**
   na Command Palette — `Ctrl+Shift+P`).
2. Abra a aba **Skills**.
3. Escolha **New Skill (Workspace)** ou **New Skill (User)** e informe o destino.

Nos dois casos você escolhe o **escopo** e o VS Code coloca a skill no local
correto:
- **Workspace:** `.github/skills/`, `.claude/skills/` ou `.agents/skills/`
- **User (pessoal):** `~/.copilot/skills/`, `~/.claude/skills/` ou `~/.agents/skills/`

### 6.2. Instalar uma skill que você já tem
Copie a pasta para `.github/skills/` (projeto) ou `~/.copilot/skills/` (pessoal).

### 6.3. Usar e acionar
- As skills aparecem no menu **`/`**, ao lado dos prompt files, **e** disparam
  automaticamente pela `description` em *agent mode*.
- Não apareceu? Rode **Developer: Reload Window**.

> 🟢 **Bônus — a skill criada no VS Code também vale no Visual Studio 2026.**
> Como os dois IDEs leem **as mesmas pastas** (`~/.copilot/skills` para pessoal,
> `.github/skills` para projeto), uma skill criada no VS Code é **descoberta
> automaticamente pelo VS 2026** também — sem recopiar nada. No VS Code o
> carregamento é imediato; no Visual Studio ela aparece no **próximo scan**
> (novo chat de agente ou reinício). É por isso que **"criar no VS Code" resolve
> os dois de uma vez** — e sem cair nas armadilhas de pasta.

---

## 7. Passo a passo — Copilot CLI (resumo)

1. Copie a pasta para `~/.copilot/skills/`.
2. Se a sessão estava aberta: `/skills reload`.
3. Liste: `/skills list` (ou pergunte "que skills você tem?").
4. Confirme: `/skills info nome-da-skill`.
5. Ligue/desligue: `/skills` (setas ↑↓ + barra de espaço).
6. Acione: automático **ou** manual com `/nome-da-skill …`.

---

## 8. Portabilidade Claude Code ↔ Copilot

O `SKILL.md` é o mesmo padrão, mas atenção a três diferenças ao trazer uma skill
do Claude para o Copilot:

| Item | Claude Code | Copilot |
|---|---|---|
| **Limite da `description`** | tolerante (descrições longas ajudam o disparo) | **máx. 1.024 caracteres** (o VS bloqueia) |
| **Variável `${CLAUDE_SKILL_DIR}`** | substituída pelo caminho da skill | **não** é substituída → caminho de script quebra |
| **Caminho de scripts** | pode usar a variável | use **caminho relativo** (ex.: `scripts/Meu.ps1`) |

**Recomendações para nascer portável:**
- Escreva a `description` **enxuta e ≤1.024**, começando por *o que faz* e
  *quando usar*, com palavras-gatilho.
- Nos scripts, use **caminho relativo à pasta da skill** em vez de
  `${CLAUDE_SKILL_DIR}/...`.
- Se você quer descrições **ricas no Claude** (mais gatilhos = melhor disparo)
  **e** compatíveis com o VS, mantenha uma **versão encurtada** só nas cópias do
  Copilot (por isso, aqui, **copiar é melhor que symlink** — o symlink forçaria
  conteúdo idêntico nos dois lados).

---

## 9. "Minha skill não aparece" — checklist de diagnóstico

Percorra na ordem:

1. **Superfície certa?** No **VS** e na **web** não há `/` para skill — é
   automático. Não fique procurando no menu `/`.
2. **Está em *agent mode*?** Skill não roda no modo *Ask*.
3. **Local válido?** Pessoal = `~/.copilot/skills` (na HOME). Projeto =
   `.github/skills` / `.claude/skills` / `.agents/skills`. Um `.copilot/skills`
   **dentro do projeto não conta**.
4. **Escopo certo?** Skill de **outro projeto** (workspace) não aparece aqui;
   torne-a **pessoal** ou copie para o projeto atual.
5. **Aninhamento certo?** `SKILL.md` **direto** dentro da pasta da skill.
6. **`name` válido?** Minúsculas/números/hífen, **≤64**, **igual ao nome da
   pasta**. Se não, falha **sem erro**.
7. **`description` ≤ 1.024?** Acima disso, o VS não carrega. Confira no **painel
   de Skills** (diagnósticos).
8. **Recarregou?** Novo chat de agente / **reiniciar** (VS), *Reload Window*
   (VS Code), `/skills reload` (CLI).
9. **Script quebrando?** Troque `${CLAUDE_SKILL_DIR}/...` por caminho relativo.

---

## 10. Boas práticas para o disparo automático

Como o agente escolhe a skill pela `description`, escreva-a pensando em
**recuperação**:

- Comece dizendo **o que a skill faz** e **quando** ela deve ser usada.
- Inclua **palavras-gatilho e sinônimos** que o usuário realmente digitaria
  ("mensagem de commit", "commit message", "descreve para commit"…).
- Seja específico o suficiente para **não** disparar em tarefas parecidas
  erradas.
- Respeite o teto de **1.024 caracteres** (corte redundância, não os gatilhos).
- Um `name` claro e autoexplicativo também ajuda.

---

## Cheat sheet

| Preciso... | Faça |
|---|---|
| **Criar uma skill do zero (mais fácil)** | **VS Code: `/create-skill`** — grava na pasta certa e vale no VS 2026 também |
| Instalar para todos os projetos | Copiar a pasta para `~/.copilot/skills/<nome>/SKILL.md` |
| Instalar só neste repo | Copiar para `.github/skills/<nome>/SKILL.md` |
| Ver as skills no **VS 2026** | Ícone **Tools** no canto inferior direito do Copilot Chat (18.6+ Insiders) |
| Ver as skills na **CLI** | `/skills list` |
| Acionar no **VS / web** | Descrever a tarefa em **agent mode** (sem `/`) |
| Acionar na **CLI / VS Code** | `/nome-da-skill` ou descrever a tarefa |
| Recarregar após adicionar | VS: reiniciar/novo chat · VS Code: *Reload Window* · CLI: `/skills reload` |
| Skill não aparece | Rodar o **checklist da seção 9** |

---

## Referências

- [Use Agent Skills with GitHub Copilot — Visual Studio (Microsoft Learn)](https://learn.microsoft.com/en-us/visualstudio/ide/copilot-agent-skills?view=visualstudio)
- [Use Agent Mode — Visual Studio (Microsoft Learn)](https://learn.microsoft.com/en-us/visualstudio/ide/copilot-agent-mode?view=visualstudio)
- [Adding agent skills for GitHub Copilot CLI — GitHub Docs](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills)
- [Adding agent skills for GitHub Copilot (cloud agent) — GitHub Docs](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills)
- [Use Agent Skills in VS Code](https://code.visualstudio.com/docs/agent-customization/agent-skills)
- [Especificação agentskills.io](https://agentskills.io/specification)
- [github/awesome-copilot — exemplos da comunidade](https://github.com/github/awesome-copilot)
