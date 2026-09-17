# Dev Skills — Marketplace de Skills do Claude Code

Um conjunto de **skills de desenvolvimento** — do requisito ao commit — distribuído como **um
único plugin**, via um **marketplace** do Claude Code. Público e livre para usar, adaptar e
forkar (licença MIT).

**Este repositório é a fonte da verdade das skills.** Elas são editadas aqui, versionadas
aqui e distribuídas pelo plugin — ninguém (nem o mantenedor) usa cópias pessoais em
`~/.claude/skills`, garantindo que todos rodem exatamente a mesma versão.

- **Repositório:** [`StrategileCompany/ia-plugins`](https://github.com/StrategileCompany/ia-plugins)
- **Marketplace:** `dev-tools`
- **Plugin (bundle):** `dev-skills` — agrupa todas as skills
- **Invocação:** dentro do plugin, cada skill é chamada com namespace, ex.:
  `/dev-skills:commit-message`
- **Licença:** [MIT](LICENSE)

> **Antes de instalar, duas escolhas opinativas deste conjunto:**
> - **As skills são escritas em português (pt-BR)** e produzem saída em pt-BR — mensagens de
>   commit, corpo de issue, release notes. Adapte no fork se o seu time escreve em outro idioma.
> - Quase tudo é **agnóstico de stack e de repositório** (descobre board, labels, base remota e
>   comandos de build em runtime). A exceção é o **`versionador`**, que é deliberadamente
>   opinativo: projetos .NET/`.csproj`, versão no formato `yyyy.MM.dd.HHmm` e mensagem de bump
>   fixa. Se a sua convenção de versão é outra, essa é a skill a trocar.

---

## 1. Abordagem escolhida

**Um único plugin agrupando todas as skills.** Todas as skills são de desenvolvimento e
mantidas pelo mesmo time; agrupá-las dá **uma instalação, uma versão e um `git push`** para
propagar tudo. As skills permanecem independentes (cada uma em `skills/<nome>/`), então o
agrupamento não as acopla — adicionar ou remover uma skill é só adicionar/remover a pasta.
Só faria sentido separar em plugins distintos se alguma skill tivesse público ou cadência
de release muito diferentes.

### Skills incluídas

| Skill | O que faz |
|---|---|
| `analista-de-requisitos` | Transforma uma necessidade vaga num requisito estruturado (user story + critérios de aceitação) e conduz o pipeline de requisito: "requisito" → "com esforço" → "com backlog" → "completo". |
| `commit-message` | Gera mensagens de commit no padrão Conventional Commits em pt-BR, com parágrafo de negócio, bullets técnicos e `Refs: #<número>` — e faz o commit, passando antes pelo gate de segurança. Nunca credita IA como co-autora. |
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
ia-plugins/                             ← raiz deste repo git
├── README.md
├── LICENSE                             ← MIT
├── .gitignore
├── docs/
│   └── Skills-no-Copilot-Guia-para-Alunos.md   ← usar estas skills no GitHub Copilot
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
            ├── commit-message/
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
  "owner": { "name": "StrategileCompany" },
  "plugins": [
    {
      "name": "dev-skills",
      "source": "./plugins/dev-skills",
      "description": "Skills de desenvolvimento do time",
      "version": "2.5.1"
    }
  ]
}
```

### `plugins/dev-skills/.claude-plugin/plugin.json`
```json
{
  "name": "dev-skills",
  "description": "Coleção de skills de desenvolvimento do time",
  "version": "2.5.1",
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
4. Receba a atualização como todo mundo: `/plugin marketplace update dev-tools`
   (ver seção 5). O mantenedor usa o **mesmo plugin instalado** que os colegas.

> **Dica (testar antes de publicar):** dá para adicionar o clone local como um marketplace
> de teste — `/plugin marketplace add D:\caminho\do\repo` — e experimentar a mudança antes
> do push. Remova o marketplace de teste depois, para não manter duas cópias das skills.

> **Histórico (bootstrap):** este repo nasceu do empacotamento das skills pessoais que
> ficavam em `~/.claude/skills/`. Após a migração para o plugin, as cópias pessoais foram
> **removidas** — mantê-las junto com o plugin duplicaria cada skill na lista do Claude
> (disparo ambíguo) e permitiria divergência de versão. Não recrie skills em
> `~/.claude/skills`; edite aqui.

---

## 4. Instalação — uma vez

No Claude Code de cada pessoa:
```
/plugin marketplace add StrategileCompany/ia-plugins
/plugin install dev-skills@dev-tools
```
- Aceita também URL completa: `/plugin marketplace add https://github.com/StrategileCompany/ia-plugins.git`
- Para conferir: `/plugin list`
- A skill fica disponível em **qualquer repositório** (é instalada no perfil do usuário,
  não no projeto), como `/dev-skills:commit-message`. Além da invocação explícita, as
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
        "source": { "source": "github", "repo": "StrategileCompany/ia-plugins" }
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
