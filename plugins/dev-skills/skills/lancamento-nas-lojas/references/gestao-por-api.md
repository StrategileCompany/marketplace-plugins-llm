# Gestão das lojas por API (sem navegador)

> Por que: no dia do lançamento o navegador vira o gargalo — console travando, sessão do App Store
> Connect expirando, co-piloto entrando em loop. Status e reenvio saem por API em segundos.
> O navegador fica só para o que **não tem API**: radios do IARC, upload de imagem, Resolution Center.

## O padrão (implemente uma vez, reuse em todo app)

Node puro (`https` + `crypto`), **sem dependências**, credenciais em pasta **fora do git** e passadas
por **env var** — nunca no repo. Dois scripts, cujos caminhos vêm da configuração:

| Script | O que faz |
|---|---|
| `<app.script.store_status>` | **Read-only.** 🍎 ASC API (JWT **ES256**) → `appStoreState`, build linkado, `reviewSubmissions` · 🤖 Play Developer API (service account, OAuth2 **RS256**) → abre um *edit* efêmero, lê a track e **abandona** o edit (nada persistido) |
| `<app.script.asc_resubmit>` | **iOS:** linka o build novo na versão + atualiza as notas do revisor e, **só com `CONFIRM_SUBMIT=1`**, reenvia a revisão (**dry-run por padrão**) |

Ainda não existem no seu projeto? Implemente-os com esse contrato. As variáveis
`app.script.store_status` e `app.script.asc_resubmit` ficam vazias até lá, e a skill cai no
navegador avisando.

**O portão de confirmação é regra, não enfeite:** enviar a revisão é ação irreversível (SKILL.md
seção 9) — o dry-run existe para que o "ok" humano aconteça antes. Não contorne.

## Credenciais (identificadores por env var; o segredo fica fora)

- 🍎 `ASC_API_KEY_ID` / `ASC_API_ISSUER_ID` / `ASC_API_PRIVATE_KEY_PATH` — use
  `<org.asc.key_id>` e `<org.asc.issuer_id>`, e **reaproveite o `.p8` da chave já cadastrada no
  serviço de build** (role Admin); não gere chave nova. O `.p8` baixa **uma vez** só.
- 🤖 `PLAY_SERVICE_ACCOUNT_JSON` — service account do projeto GCP (o mesmo do Firebase), com a
  *Google Play Android Developer API* habilitada. O JSON é **segredo**: caminho por env var, arquivo
  fora do git.

## Gotchas de API (custaram caro)

### 🍎 App Store Connect
- **Submission rejeitada trava o reenvio.** Ela fica em `UNRESOLVED_ISSUES` e **não aceita item
  novo** (responde **409**) → **cancele** (`PATCH canceled=true`) e **crie uma nova submission**.
- **Linkar um build numa versão `REJECTED`** a move para `PREPARE_FOR_SUBMISSION` (é o caminho normal
  do reenvio).
- **401 esporádico** mesmo com credencial correta → **retry com token novo**.
- **O motivo da rejeição NÃO está na API.** O texto do revisor (Resolution Center) só aparece no
  **e-mail** ou no painel — a API entrega o estado, não a razão. Não tente adivinhar pelo status.

### 🤖 Google Play
- **`completed` na track ≠ aprovado.** Num 1º lançamento a release aparece como `completed` **com a
  revisão do Google ainda pendente** — é só o alvo de rollout de 100%, não veredito. O sinal real de
  "está público" é a **listagem pública da loja respondendo HTTP 200 vs 404**. Cruze os dois.
- **A página "Acesso via API" do console foi REMOVIDA.** A service account se concede em
  *Usuários e permissões* → **⋮** → **"Convidar novos usuários"**.
- **Permissão "somente leitura" já basta** para o script de status: ela permite abrir o edit
  efêmero de leitura da track. Não dê Admin a uma service account de status.
