---
name: lancamento-nas-lojas
description: >-
  Conduz o lançamento (ou a atualização) de um app mobile na Google Play e na
  Apple App Store, do zero à submissão. Use SEMPRE que o usuário falar em
  "lançar o app", "publicar na Play Store", "publicar na App Store", "subir o
  app na loja", "submeter para revisão", "TestFlight", "ficha da loja"/"store
  listing", "Data Safety", "App Privacy", "classificação etária", "assinar o
  app"/"keystore", "build iOS sem Mac"/"Codemagic", "checklist de lançamento",
  "atualizar o app na loja", "status da revisão" ou "reenviar após rejeição".
  Funciona em qualquer organização: lê contas, App ID, política e assinatura
  de um arquivo de configuração externo e, não o encontrando, entrevista o
  usuário e o gera. Valida os assets antes do upload, exige ENSAIO contra o
  maior tenant real e alarme de 5xx antes do envio (aprovado ≠ funcionando) e
  gerencia as lojas por API. NÃO manuseia segredos: aponta onde estão, nunca
  cola o valor.
---

# Lançamento de app nas lojas (Google Play + Apple App Store)

Leva um app novo (ou uma atualização) ao ar nas duas lojas. Destila lançamentos reais de apps
Flutter B2B multi-tenant, mas o roteiro serve a qualquer app nativo.

**As constantes da sua organização não estão aqui.** Contas, prefixo de App ID, host da política,
nome da chave de publicação, caminho do keystore — tudo vem de um arquivo de configuração externo.
O passo 0 cuida disso; o contrato está em `references/configuracao.md`.

As exigências detalhadas de cada loja e os gotchas estão em `references/lojas-requisitos.md`; a
receita do build iOS de nuvem em `references/codemagic-ios.md`; o ensaio de escala antes do envio
em `references/ensaio-producao.md`; a gestão das lojas por API em `references/gestao-por-api.md`.
Leia a referência antes de agir na etapa correspondente — não decore.

## O básico (contexto)

Lançar = **5 coisas**: (1) contas de dev nas 2 lojas, (2) binário assinado `.aab` + `.ipa`,
(3) ficha (textos + imagens), (4) declarações legais (privacidade, data safety, classificação),
(5) passar na revisão.

**Regras de ouro (agilidade):**
- **Google primeiro** — barato, rápido (1-3 dias na 1ª vez), tolerante. Valida cedo.
- **Apple é o polo longo** — conta cara/lenta de abrir e revisão com rejeições; comece cedo e espere iterar.
- **Flutter não tem OTA** — toda correção vira build nativo + revisão. **Qualidade ANTES de submeter.**
- **Aprovado na loja ≠ funcionando para o cliente.** O revisor testa a conta demo, que não tem
  volume real. Ensaie contra o **maior tenant de produção** antes de enviar (seção 5) — e só
  considere lançado depois de abrir o app com dados de cliente real.
- **Reaproveite** contas, infra de build, textos e assets entre apps.

## Regra de ouro sobre segredos (inegociável)

NUNCA escreva no repositório nem cole em campo: **senha de conta, `.p8` da Apple, chave privada RSA
do certificado iOS, senha/arquivo do keystore, credencial de produção**. Esses valores ficam no
cofre de senhas da organização e em arquivos fora do git.

O arquivo de configuração **também não** guarda segredo: ele guarda identificadores e **aponta**
onde cada segredo está. Se um campo pedir senha (ex.: senha do revisor no formulário da Apple ou do
Google), **peça a quem está definido em `org.papel.digita_senha`** — você não digita senha em campo.

## Passo 0 — Carregue a configuração (antes de tudo)

Nenhuma etapa começa sem isto. Leia `references/configuracao.md` e execute:

1. **Procure** `lancamento-nas-lojas.config.json` na ordem: memória `lojas-config-path` →
   `./.scratch/` → `./.docs/` → raiz do repo atual → `~/.claude/`.
2. **Achou e está completo** (toda variável `required` com valor) → siga para o passo 1, dizendo
   numa linha de onde leu.
3. **Não achou** → **pergunte onde o arquivo está** antes de qualquer outra coisa; ele pode viver
   fora da ordem de busca. Só se não existir, ofereça a entrevista.
4. **Achou incompleto** → liste o que falta e entreviste **apenas** essas variáveis.
5. **Entreviste** com as perguntas do próprio arquivo (campo `description`), agrupadas por assunto,
   **grave o JSON** e **informe o caminho absoluto** em que gravou — conferindo antes que o destino
   esteja gitignored.
6. **Grave o caminho na memória** `lojas-config-path` para não perguntar de novo.

**Nunca invente um valor.** Variável obrigatória ausente **bloqueia** a etapa que depende dela:
diga qual falta e onde costuma estar. A entrevista **nunca pergunta um segredo** — para esses,
pergunta apenas onde estão.

## Passo a passo

### 1. Enquadre o pedido
Descubra e confirme com o usuário:
- **Qual app / projeto** e a **raiz do repo** (padrão: repo atual).
- **App novo** (1ª submissão) ou **atualização** de um já publicado.
- **Quais lojas** agora (recomende Google primeiro; Apple em paralelo/fast-follow).
- **Plataforma iOS:** tem Mac? Se não, o caminho é o **build de nuvem** — ver `references/codemagic-ios.md`.

Gere um **checklist enxuto adaptado ao app** a partir das seções 3-6 abaixo, usando os valores da
configuração (App IDs, nome, Apple ID numérico, política). Marque `[ ]`/`[x]` e mostre.

### 2. Pré-requisitos do projeto (valem para as duas lojas)
- **App ID** no padrão `<org.app_id.prefixo>.<app>`, seguindo `org.app_id.convencao` — **livre nas
  2 lojas** e imutável. Confirme com o dono antes de gravar.
- **Política de privacidade** pública no ar (`app.politica.url`, default `org.politica.url_padrao`)
  **com seção de exclusão de conta**.
- **Assinatura Android:** keystore de upload (`app.keystore.arquivo`) + propriedades
  (`app.keystore.properties`), ambos fora do git, com **backup** no cofre. 🔴 Perder = nunca mais
  publica update.
- **Exclusão de conta in-app funcionando** (backend live) e **grupo demo ATIVO** — rode
  `app.seed_revisor` em produção.
- **Config nativa:** usage strings no `Info.plist`, `ITSAppUsesNonExemptEncryption=false`, guard
  try/catch no `Firebase.initializeApp`, deployment target `default.ios_deployment_target`, e — se
  há `firebase_messaging` sem push no iOS — **`FirebaseAppDelegateProxyEnabled=NO`** (o guard do
  Dart **não** impede o swizzler nativo de crashar no launch; ver `references/lojas-requisitos.md`).
- **Consentimento de IA in-app** se o app manda dado do usuário a IA de terceiro: política de
  privacidade **não basta** (Apple 5.1.1(i)/5.1.2(i)) — ver `references/lojas-requisitos.md`.

### 3. Textos da ficha
Escreva **uma vez** e reaproveite nas 2 lojas (limites e estrutura em
`references/lojas-requisitos.md`). Se já existe um `STORE-LISTING.md` no projeto, reuse. Gere:
nome (30), descrição curta (80, Play), descrição completa (4000), subtítulo/keywords/promo (Apple),
novidades (500, Play).

### 4. Valide os assets ANTES de subir (barato; evita bloqueio no upload)
Rode o script para conferir **dimensão + canal alpha** contra a especificação da loja.
Use `powershell` (5.1, já no Windows) ou `pwsh` (7):

```powershell
# Reporta W x H, alpha e ratio de cada imagem (sem julgar):
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}/scripts/Validate-StoreAssets.ps1" -Path "<pasta_ou_arquivo>"

# Valida contra uma especificação (PASS/FAIL por arquivo):
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}/scripts/Validate-StoreAssets.ps1" -Path "<pasta>" -Spec play-phone
```

> **Fora do Claude Code** (GitHub Copilot, por exemplo) a variável `${CLAUDE_SKILL_DIR}` **não** é
> substituída e o comando quebra sem erro claro. Troque-a pelo caminho da pasta desta skill — o
> `scripts/` fica ao lado do `SKILL.md`.

`-Spec` aceita: `play-icon`, `apple-icon`, `play-feature`, `play-phone`, `apple-6.9`, `apple-6.5`,
`apple-ipad`. Saída por linha (TAB):
`IMG\t<arquivo>\t<w>x<h>\talpha=<bool>\tratio=<r>\t<PASS|FAIL: motivo>`.
Exit 0 = tudo ok · 2 = houve FAIL · 3 = nenhuma imagem encontrada.
Regras-chave (detalhe na referência): só o **ícone da Play** pode ter alpha; **ícone Apple 1024 SEM
alpha**; screenshots/feature **sem alpha (24-bit)**; screenshot de telefone Play com **lado maior
≤ 2x o menor**.

Se algum FAIL: aponte a correção (achatar p/ 24-bit; para o teto 2:1 do Play, usar **padding por
edge-extend** — sem crop, sem upscale). Não suba nada reprovado.

### 5. Ensaio com o maior tenant real — antes de enviar (BLOQUEIA o lançamento)
**Aprovado ≠ funcionando.** A conta demo do revisor (seção 2) é uma **armadilha dupla**: (a) o
revisor aprova o app exercitando um volume ridículo de dados, então bug de escala só aparece em
produção, com cliente real; (b) ela pode **causar** o incidente — martelada pelos revisores,
envenena o cache de plano do banco e derruba a primeira tela para **todos os clientes com volume
real**, horas depois de o app ir ao ar, sem ninguém saber. História completa e roteiro em
`references/ensaio-producao.md`.

Custa minutos:
- Liste os endpoints da **primeira tela** (a que abre depois do login).
- Exercite cada um **contra o MAIOR tenant/conta de PRODUÇÃO**, medindo o tempo. Não contra o demo.
- **Portão:** qualquer resposta **> 5s** ou **erro** → **não envie**; corrija antes.
- **"Passou em staging" não cobre performance.** Staging montado por script nasce com estatísticas
  e planos frescos → nunca reproduz bug de plano em cache.
- **Alarme ANTES de lançar, não monitoramento depois:** exija **alerta de 5xx e de latência (p95)
  na API** configurado antes do envio. Crash reporting (Play Vitals/Sentry) **não pega** isso — o
  app não crasha, a API é que devolve 500.

### 6. Gestão das lojas por API, não por navegador
O navegador é o gargalo do dia do lançamento: trava, a sessão do App Store Connect expira, o
co-piloto entra em loop. **Cheque status e reenvie por API**; reserve o navegador para o que só
existe no console (radios do IARC, upload de imagem, Resolution Center). Receita, credenciais e
gotchas de API em `references/gestao-por-api.md`.

Os scripts do seu projeto vêm da configuração: `app.script.store_status` (read-only) e
`app.script.asc_resubmit` (**dry-run por padrão**, submete só com confirmação explícita). Não
existindo ainda, `references/gestao-por-api.md` descreve o padrão para implementá-los.

### 7. Trilha Google Play (fazer primeiro)
Portal e login vêm da configuração (`org.play.portal`, `org.play.login`). Sequência e todas as
declarações (Data Safety, IARC, público-alvo, AAID, IA) em `references/lojas-requisitos.md` seção
Play. Resumo: AAB → track Interno → declarações do painel (todas manuais) → promover para Produção
(países de `default.pais`) → revisão. Os radios do IARC e uploads de imagem exigem **clique humano**.

### 8. Trilha Apple App Store
Sem Mac → **build de nuvem** (`references/codemagic-ios.md`: setup 1x, `codemagic.yaml`, e a receita
de assinatura com certificado próprio estável). Depois: build → TestFlight → metadados + App Privacy
+ classificação etária + **contato do revisor** → "Adicionar para revisão". Detalhes e a tabela de
prevenção de rejeição (5.1.1(v), 5.1.1(i)/5.1.2(i) consentimento de IA, 4.8, 2.1(a) crash do
swizzler, ITMS-90713, export compliance) em `references/lojas-requisitos.md` seção Apple.
Rejeitou? Corrija, rebuilde e **reenvie por API** (seção 6).

### 9. Ações irreversíveis — confirme antes
São externas/irreversíveis; mostre o resumo e **peça o "ok"** do usuário antes:
- **Enviar para revisão** (Play "Enviar para revisão" / Apple "Adicionar para revisão").
- **Promover para Produção** / publicar.
- **push** de commits de assinatura/CI.

Campos de **senha** (revisor) → quem digita é `org.papel.digita_senha`.

### 10. Pós-lançamento
- **No ar ≠ funcionando.** Assim que a loja publicar, **abra o app com uma conta de cliente real**
  (não a demo) e confira a primeira tela. É assim que um app quebrado costuma ser descoberto.
- Vigie o **alarme de 5xx/latência** que já deve estar de pé desde a seção 5 — é ele, não o crash
  reporting, que enxerga a API caindo.
- **versionCode (Android) / buildNumber (iOS) sempre crescentes** e independentes por binário.
- Sincronizar **registro de versão no backend** após cada release (Android no `completed`, iOS só no
  `READY_FOR_SALE`).
- Monitorar crashes/ANRs 24h (Play Vitals + Sentry); responder 1ªs avaliações.
- Flutter: hotfix = build nativo + revisão (sem OTA).

## Regras importantes
- **Sem configuração, não comece.** O passo 0 é pré-requisito de todas as etapas; valor obrigatório
  ausente **bloqueia** a etapa que depende dele. Nunca invente login, App ID, host ou nome de chave.
- **Google antes de Apple.** Valida rápido e barato; Apple em paralelo/fast-follow.
- **Aprovado na loja ≠ funcionando para o cliente.** Ensaie a 1ª tela contra o **maior tenant real**
  antes de enviar e exija **alarme de 5xx** antes de lançar (seção 5). A conta demo do revisor não
  prova escala — e pode ser ela a quebrar a produção.
- **Segredos nunca no repo nem na configuração** — aponte o cofre; não cole valor; senha de campo
  quem digita é o papel da configuração.
- **Sempre valide dimensão + alpha dos assets antes do upload** (seção 4).
- **Status e reenvio por API, navegador só no que não tem API** (seção 6).
- **Confirme antes de qualquer ação irreversível** (seção 9).
- Bundle ID é imutável: **confirme com o dono antes de gravar** e cheque livre nas 2 lojas.
- Leia a referência da etapa antes de agir; não decore os limites/gotchas.

## Referências
- `references/configuracao.md` — **o passo 0**: nome canônico do arquivo, ordem de busca, schema da
  variável, regra de completude, roteiro da entrevista, camadas org/app e onde gravar.
- `assets/lancamento-nas-lojas.config.example.json` — o molde com todas as variáveis e suas
  perguntas. Variável nova entra aqui primeiro.
- `references/lojas-requisitos.md` — exigências e gotchas de cada loja, specs de asset, limites de
  texto e a tabela de prevenção de rejeição.
- `references/codemagic-ios.md` — build iOS de nuvem: setup, `codemagic.yaml` e assinatura.
- `references/ensaio-producao.md` — o ensaio de escala antes do envio e o alarme de 5xx.
- `references/gestao-por-api.md` — status e reenvio por API, com os gotchas que custam caro.
