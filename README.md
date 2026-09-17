# ia-plugins — skills de desenvolvimento para o Claude Code

Dez skills que levam uma necessidade do **requisito ao commit**. Elas interpretam um pedido vago e
o transformam numa issue dimensionada e priorizada no board, implementam seguindo os critérios de
aceitação, revisam a segurança do diff antes do commit, escrevem a mensagem, versionam e geram as
notas da release. Uma delas conduz a publicação de apps mobile nas duas lojas.

Tudo distribuído como **um único plugin**, via um **marketplace** do Claude Code. Livre para usar,
adaptar e forkar — licença [MIT](LICENSE).

```
/plugin marketplace add StrategileCompany/ia-plugins
/plugin install dev-skills@dev-tools
```

- **Marketplace:** `dev-tools` · **Plugin:** `dev-skills` — agrupa as dez skills
- **Invocação:** com namespace (`/dev-skills:commit-message`) ou automática, quando o seu pedido
  combina com a `description` da skill
- Instalado no seu perfil, vale em **qualquer repositório**

> **Duas escolhas opinativas, para você decidir antes de instalar:**
> - **As skills são escritas em pt-BR e produzem saída em pt-BR** — mensagem de commit, corpo de
>   issue, release notes. Se o seu time escreve em outro idioma, é o primeiro ajuste do fork.
> - Quase tudo é **agnóstico de stack e de repositório**: board, labels, base remota e comandos de
>   build são descobertos em runtime, e a skill degrada com aviso quando o recurso não existe. A
>   exceção é o **`versionador`**, deliberadamente opinativo — projetos .NET/`.csproj`, versão no
>   formato `yyyy.MM.dd.HHmm` e mensagem de bump fixa. Se a sua convenção é outra, é a skill a
>   trocar.

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
      "description": "Skills de desenvolvimento, do requisito ao commit",
      "version": "2.5.2"
    }
  ]
}
```

### `plugins/dev-skills/.claude-plugin/plugin.json`
```json
{
  "name": "dev-skills",
  "description": "Dez skills de desenvolvimento para o Claude Code, do requisito ao commit",
  "version": "2.5.2",
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
