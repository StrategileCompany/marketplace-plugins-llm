# marketplace-plugins-llm — skills de desenvolvimento para o Claude Code

Dez skills que levam uma necessidade do **requisito ao commit**. Elas interpretam um pedido vago e
o transformam numa issue dimensionada e priorizada no board, implementam seguindo os critérios de
aceitação, revisam a segurança do diff antes do commit, escrevem a mensagem, versionam e geram as
notas da release. Uma delas conduz a publicação de apps mobile nas duas lojas.

Tudo distribuído como **um único plugin**, via um **marketplace** do Claude Code. Livre para usar,
adaptar e forkar — licença [MIT](LICENSE).

```
/plugin marketplace add StrategileCompany/marketplace-plugins-llm
/plugin install dev-skills@dev-tools
```

- **Marketplace:** `dev-tools` · **Plugin:** `dev-skills` — agrupa as dez skills
- **Invocação:** com namespace (`/dev-skills:commit`) ou automática, quando o seu pedido
  combina com a `description` da skill
- Instalado no seu perfil, vale em **qualquer repositório**

> **Antes de instalar, leia o [Disclaimer](#disclaimer)** — idioma, plataforma, stack, acoplamento
> ao GitHub e o que as skills fazem sozinhas. Nada ali impede o uso, e tudo é forkável; mas são
> escolhas opinativas que você herda junto com a instalação.

---

## Disclaimer

O que você adota junto com o plugin. Quase tudo é descoberto em runtime e **degrada com aviso**
quando o recurso não existe — nenhum item abaixo impede o uso, e todos são forkáveis. Ainda assim,
são decisões nossas que passam a valer no seu ambiente, e é melhor conhecê-las antes.

### 1. Plataforma: duas skills exigem Windows

Oito das dez são agnósticas de sistema operacional. As duas que executam script, não:

| Skill | Script | Exigência |
|---|---|---|
| `lancamento-nas-lojas` | `Validate-StoreAssets.ps1` | **Windows** — usa `System.Drawing`, indisponível no PowerShell 7 de macOS/Linux |
| `versionador` | `Update-Version.ps1` | Windows PowerShell 5.1 (já incluso) ou `pwsh` 7 |

A do `lancamento-nas-lojas` é a mais incômoda, porque quem publica app iOS costuma estar no macOS.
Só a **validação de assets** fica de fora: checklist, ficha, declarações, ensaio de escala e gestão
das lojas por API funcionam em qualquer sistema.

### 2. Stack: o `versionador` é .NET, e o relógio é de São Paulo

Deliberadamente opinativo: projetos **C#/.NET** (lê `<AssemblyVersion>` dos `.csproj`), versão no
formato **`yyyy.MM.dd.HHmm`** e fuso padrão **`America/Sao_Paulo`** — sem `-TimeZone`, o carimbo sai
no horário de Brasília. Se o seu projeto não é .NET, ou a sua convenção é SemVer, é a skill a
trocar. As outras nove não presumem stack: build, testes e base remota são descobertos no repo.

### 3. Idioma: pt-BR, inclusive no gatilho

As skills são escritas em pt-BR e **produzem saída em pt-BR** — mensagem de commit, corpo de issue,
CHANGELOG, release notes. O detalhe menos óbvio: as `description` que disparam as skills
automaticamente também estão em português, então um pedido escrito em inglês aciona com menos
precisão. Num time que escreve em outro idioma, traduzir as `description` é o primeiro ajuste do
fork — não só a saída.

### 4. Ferramenta: GitHub, pelo `gh` CLI

Metade do plugin conversa com o GitHub e assume um arranjo específico:

- **Projects v2** como board, com campos `Status`, `Estimate`, `Size` e `Priority`
- **issue types nativos** da organização (Bug/Feature/Task)
- **Conventional Commits** nas mensagens e tags `v*` marcando as versões

Nada disso é hardcoded — board, campos e labels são descobertos em runtime, e cada skill avisa e
segue quando falta o recurso ou o scope `project`. Mas num time que vive em Jira, Azure DevOps ou
GitLab, as skills de backlog (`registra-issue`, `estima-esforco`, `prioriza-backlog`) entregam bem
menos. As de requisito, implementação, segurança, commit e release notes continuam valendo.

### 5. Política: o commit não credita IA como coautora

A skill `commit` **proíbe** o trailer `Co-Authored-By:` apontando para modelo, assistente ou
fornecedor de IA. É uma decisão nossa sobre autoria, não um padrão da indústria — e conflita com
empresas que **exigem** a atribuição de IA nos commits. Sendo o seu caso, é uma linha a remover
no fork.

### 6. Autonomia: o que as skills fazem sem perguntar

| Skill | Faz por padrão | Pede o seu "ok" |
|---|---|---|
| `versionador` | carimba a versão, gera as notas, commita, cria a tag e faz **push** | antes do push |
| `commit` | estagia e **commita** | só devolve a mensagem se você pedir isso explicitamente |
| `desenvolvedor` | rebase na base remota, move o board, implementa, commita | push, `--force-with-lease`, fechar a issue |
| `lancamento-nas-lojas` | monta checklist, valida assets, consulta status por API | enviar para revisão, promover para produção |

Os portões existem: `revisar-seguranca` barra o commit em achado Crítico/Alto, critério de aceitação
não atendido também barra, e toda ação irreversível pede confirmação. Ainda assim, o modo padrão do
`versionador` é `update + commit + push + tag` — um "versiona" solto chega ao remoto.

As skills também **gravam memórias de projeto** no seu perfil do Claude (`projeto-board`,
`projeto-core-business`, `projeto-novidades-local`), para não reperguntar a cada rodada qual é o
board, a promessa central do produto e onde vivem as novidades.

---

## 1. Abordagem escolhida

**Um único plugin agrupando todas as skills.** Elas compartilham o mesmo domínio e a mesma
cadência de release, então agrupá-las dá **uma instalação, uma versão e um `git push`** para
propagar tudo. As skills permanecem independentes (cada uma em `skills/<nome>/`), então o
agrupamento não as acopla — adicionar ou remover uma skill é só adicionar/remover a pasta.
Só faria sentido separar em plugins distintos se alguma skill tivesse público ou cadência
de release muito diferentes.

### Skills incluídas

| Skill | O que faz |
|---|---|
| `analista-de-requisitos` | Transforma uma necessidade vaga num requisito estruturado (user story + critérios de aceitação) e conduz o pipeline de requisito: "requisito" → "com esforço" → "com backlog" → "completo". |
| `commit` | Gera mensagens de commit no padrão Conventional Commits em pt-BR, com parágrafo de negócio, bullets técnicos e `Refs: #<número>` — e faz o commit, passando antes pelo gate de segurança. Nunca credita IA como co-autora. |
| `desenvolvedor` | Orquestra o fluxo completo do backlog ao commit: issue → sincroniza a branch com a base remota (rebase) → In Progress → implementação → build+testes → conferência dos critérios de aceitação (marca os checkboxes da issue numa única atualização) → gate de segurança → commit/push → Done. |
| `estima-esforco` | Estima o tamanho em escala T-shirt/Fibonacci ancorada em rubrica: enriquece o JSON do requisito (pré-issue) ou grava em issues vivas (título, corpo e Projects v2). |
| `prioriza-backlog` | Prioriza por score valor÷esforço (Customer Value, Business Value, Risco, Efeito destravador): enriquece o JSON (pré-issue) ou grava no board, ordena o backlog e reabastece o To Do. |
| `registra-issue` | Registra a issue no GitHub a partir do JSON enriquecido, aplicando tudo de uma vez (issue type, labels, tamanho no título, estimativa/prioridade) e sempre adicionando ao board da org. |
| `release-notes` | Gera as notas da versão a partir dos commits do intervalo em dois documentos: CHANGELOG técnico (raiz) + Novidades/"What's new" para o usuário final (local configurável). Acionada pelo `versionador`. |
| `revisar-seguranca` | Revisa a segurança do diff ancorada em OWASP (SQLi, segredos/tokens hardcoded, armazenamento de senha por hash, controle de acesso/multi-tenant/IDOR, prompt injection, XSS, cripto, dependências…), classifica por severidade e **barra o commit** em Crítico/Alto. Genérica; roda sob demanda ou como gate no `desenvolvedor`. |
| `versionador` | Carimba versão `yyyy.MM.dd.HHmm` (data/hora) em projetos .NET/`.csproj` + `.js`/`.html`/`.webmanifest` e, por padrão, faz commit, push, cria a tag `v<versão>` e gera as notas (via `release-notes`) — escopo restringível. |
| `lancamento-nas-lojas` | Conduz o lançamento (ou atualização) de um app na Google Play e Apple App Store. **Lê as constantes da sua organização** (contas, App ID, política, assinatura) de um arquivo de configuração externo e, não o encontrando, **entrevista você e o gera**. Separa pré-requisitos × exigências de cada loja, **valida assets** (dimensão + alpha) via script PowerShell, exige o **ensaio contra o maior tenant real** e alarme de 5xx antes do envio (_aprovado ≠ funcionando_), gerencia as lojas **por API** em vez de navegador, e guia ficha, Data Safety/App Privacy e o build iOS de nuvem. |

## 2. Estrutura do repositório

```
marketplace-plugins-llm/                ← raiz deste repo git
├── README.md
├── LICENSE                             ← MIT
├── .gitignore
├── docs/
│   └── Skills-no-Copilot-Guia-Pratico.md       ← usar estas skills no GitHub Copilot
├── .claude-plugin/
│   └── marketplace.json                ← catálogo do marketplace "dev-tools"
└── plugins/
    └── dev-skills/                     ← o plugin (bundle) com todas as skills
        ├── .claude-plugin/
        │   └── plugin.json             ← manifesto do plugin (nome, versão, autor)
        └── skills/
            ├── analista-de-requisitos/
            │   ├── SKILL.md
            │   ├── evals/
            │   └── references/
            ├── commit/
            │   └── SKILL.md
            ├── desenvolvedor/
            │   ├── SKILL.md
            │   └── references/
            ├── estima-esforco/
            │   ├── SKILL.md
            │   └── references/
            ├── lancamento-nas-lojas/
            │   ├── SKILL.md
            │   ├── assets/
            │   ├── references/
            │   └── scripts/
            ├── prioriza-backlog/
            │   ├── SKILL.md
            │   └── references/
            ├── registra-issue/
            │   ├── SKILL.md
            │   └── references/
            ├── release-notes/
            │   ├── SKILL.md
            │   └── references/
            ├── revisar-seguranca/
            │   ├── SKILL.md
            │   └── references/
            └── versionador/
                ├── SKILL.md
                └── scripts/
```

### `.claude-plugin/marketplace.json` (raiz)
```json
{
  "name": "dev-tools",
  "description": "Skills de desenvolvimento em português para o Claude Code: …",
  "owner": { "name": "StrategileCompany" },
  "plugins": [
    {
      "name": "dev-skills",
      "source": "./plugins/dev-skills",
      "description": "Skills de desenvolvimento, do requisito ao commit",
      "version": "3.1.0"
    }
  ]
}
```

### `plugins/dev-skills/.claude-plugin/plugin.json`
```json
{
  "name": "dev-skills",
  "description": "Dez skills de desenvolvimento para o Claude Code, do requisito ao commit",
  "version": "3.1.0",
  "author": { "name": "StrategileCompany" }
}
```

> **Versão:** use SemVer em `version`. A versão efetiva do plugin é resolvida nesta ordem:
> `version` do `plugin.json` → `version` da entrada no `marketplace.json` → SHA do commit
> (se você omitir `version`, cada commit vira uma "versão"). Como este repo define `version`
> nos **dois** arquivos, mantenha-os sempre **idênticos** e incremente os dois juntos: o
> valor do `plugin.json` prevalece sem aviso, então um valor defasado mascara o outro e os
> clientes não enxergam a atualização.

---

## 3. Manutenção (editar skills e publicar atualizações)

O repo é a fonte da verdade — as skills são editadas **diretamente aqui**:

1. Edite a skill em `plugins/dev-skills/skills/<nome>/` (o `SKILL.md` e, se houver,
   `references/`, `scripts/`, `assets/`). Para criar uma skill nova, adicione a pasta em
   `skills/` — ela entra no bundle automaticamente, sem mexer nos manifestos.
2. **Incremente a versão** em `plugins/dev-skills/.claude-plugin/plugin.json` **e** na entrada
   correspondente do `marketplace.json` (ex.: `1.1.0` → `1.2.0`). Se esquecer um dos dois,
   os clientes não enxergam a atualização (ver nota de versão na seção 2).
3. Commit + push:
   ```bash
   git add .
   git commit -m "feat(dev-skills): adiciona/atualiza skill <nome>"
   git push
   ```
4. Receba a atualização como qualquer instalação: `/plugin marketplace update dev-tools`
   (ver seção 5). Quem mantém usa o **mesmo plugin instalado** que todo mundo — não há
   caminho privilegiado.

> **Dica (testar antes de publicar):** dá para adicionar o clone local como um marketplace
> de teste — `/plugin marketplace add D:\caminho\do\repo` — e experimentar a mudança antes
> do push. Remova o marketplace de teste depois, para não manter duas cópias das skills.

> **Não mantenha cópias soltas.** Se você também guardar uma destas skills em
> `~/.claude/skills/`, ela aparece duas vezes na lista do Claude — o disparo fica ambíguo e as
> duas cópias divergem de versão com o tempo. Instale pelo plugin e edite aqui (ou no seu fork);
> não as duplique no perfil.

---

## 4. Instalação — uma vez

No Claude Code:
```
/plugin marketplace add StrategileCompany/marketplace-plugins-llm
/plugin install dev-skills@dev-tools
```
- Aceita também URL completa: `/plugin marketplace add https://github.com/StrategileCompany/marketplace-plugins-llm.git`
- Para conferir: `/plugin list`
- A skill fica disponível em **qualquer repositório** (é instalada no perfil do usuário,
  não no projeto), como `/dev-skills:commit`. Além da invocação explícita, as
  skills também disparam automaticamente pela `description` quando o pedido combina.
- O repositório é **público** — não é preciso acesso especial. Basta ter `git` na máquina
  (e `gh` autenticado para as skills que falam com o GitHub: issues, labels e board).

## 5. Manter atualizado

- **Manual:** `/plugin marketplace update dev-tools` (busca a versão nova do repo).
- **Automático:** ligue o auto-update do marketplace em `/plugin` → aba **Marketplaces**.
  Com auto-update ligado, o Claude Code verifica e atualiza periodicamente sozinho.

---

## 6. (Opcional) Propagação automática para todos

Para não depender de cada um rodar os comandos:

- **Por projeto** — commite em `.claude/settings.json` do(s) repo(s) do time:
  ```json
  {
    "extraKnownMarketplaces": {
      "dev-tools": {
        "source": { "source": "github", "repo": "StrategileCompany/marketplace-plugins-llm" }
      }
    },
    "enabledPlugins": {
      "dev-skills@dev-tools": true
    }
  }
  ```
  Quem clonar o repo (e confiar na pasta ao abrir) é convidado a instalar o marketplace
  automaticamente, já com o plugin habilitado.

- **Organização inteira (Teams/Enterprise)** — um admin aplica os mesmos campos via
  **managed settings**: no console admin (`claude.ai/admin-settings/claude-code`) ou num
  arquivo `managed-settings.json` distribuído por MDM/GPO:
  - Windows: `C:\Program Files\ClaudeCode\managed-settings.json`
    (o caminho legado `C:\ProgramData\ClaudeCode\` não é mais suportado desde a v2.1.75)
  - macOS: `/Library/Application Support/ClaudeCode/managed-settings.json`
  - Linux/WSL: `/etc/claude-code/managed-settings.json`

  Com `enabledPlugins` em managed settings a instalação é forçada para todos e os updates
  chegam automaticamente. Para restringir fontes de plugins, as chaves (managed only)
  `strictKnownMarketplaces` (allowlist; `[]` bloqueia qualquer adição) e
  `blockedMarketplaces` (blocklist) complementam o controle.

---

## 7. Referências (docs oficiais)

- Skills: https://code.claude.com/docs/en/skills.md
- Plugins: https://code.claude.com/docs/en/plugins.md
- Marketplaces de plugins: https://code.claude.com/docs/en/plugin-marketplaces.md
- Descobrir/instalar plugins: https://code.claude.com/docs/en/discover-plugins.md
- Managed settings: https://code.claude.com/docs/en/server-managed-settings.md
- Referência de settings: https://code.claude.com/docs/en/settings.md
