# Exigências das lojas + gotchas (Play e Apple)

> Legenda: 🔴 bloqueia submissão · 🟡 rejeição comum.
> Valores entre `<>` vêm da configuração — ver `references/configuracao.md`.

## Pré-requisitos do projeto (as duas lojas)
- 🔴 App ID livre nas 2 lojas (padrão `<org.app_id.prefixo>.<app>`).
- 🔴 Política de privacidade pública **com seção de exclusão de conta** (`<app.politica.url>`).
- 🔴 Keystore de upload Android + backup (fora do git + cofre).
- 🔴🟡 Exclusão de conta in-app funcionando (backend live) + grupo demo ATIVO com dados realistas
  (`<app.seed_revisor>`).
  ⚠️ O demo aprova mas **não prova escala** — ensaie a 1ª tela contra o maior tenant real antes de
  enviar (`references/ensaio-producao.md`).
- 🔴 Consentimento de IA in-app se o app manda dado a IA de terceiro (Apple 5.1.1(i)/5.1.2(i)).
- 🔴 Alerta de **5xx/latência na API** de pé **antes** de lançar (crash reporting não vê 500).
- Usage strings no `Info.plist`; `ITSAppUsesNonExemptEncryption=false`; guard try/catch no
  `Firebase.initializeApp` **+ `FirebaseAppDelegateProxyEnabled=NO`** (o guard não segura o swizzler
  nativo); deployment target `<default.ios_deployment_target>`.

## Especificação de assets (feed do -Spec do Validate-StoreAssets.ps1)
| Asset | Spec | -Spec | Alpha |
|---|---|---|---|
| Ícone Play | 512x512 PNG | `play-icon` | **permitido** |
| Ícone Apple | 1024x1024 PNG | `apple-icon` | **proibido** (rejeita) |
| Feature graphic (Play) | 1024x500 | `play-feature` | proibido (24-bit) |
| Screenshot telefone Play | 9:16, lado maior ≤ 2x o menor, lado 320..3840 | `play-phone` | proibido |
| Screenshot iPhone 6.9" | 1290x2796 (ou 1320x2868) | `apple-6.9` | proibido |
| Screenshot iPhone 6.5" | 1284x2778 / 1242x2688 | `apple-6.5` | proibido |
| Screenshot iPad 13" | 2064x2752 / 2048x2732 | `apple-ipad` | proibido |

Gotchas: telas modernas ~2.16:1 estouram o teto 2:1 do Play → **padding por edge-extend** (sem crop,
sem upscale). Só o ícone da Play leva alpha; todo o resto é 24-bit. **Sempre validar antes de subir.**

## Textos da ficha (limites; escreva uma vez, reuse nas 2)
Nome 30 · descrição curta 80 (Play) · descrição completa 4000 (ambas) · subtítulo 30 (Apple) ·
keywords 100 sem espaço após vírgula (Apple) · promo 170 (Apple) · novidades 500 (Play).
Estrutura: gancho → PARA O USUÁRIO → PARA GESTÃO → DIFERENCIAIS → SEGURANÇA → FUNCIONALIDADES → CTA.

---

## 🤖 GOOGLE PLAY (fazer primeiro)
**Portal:** `<org.play.portal>` · **login:** `<org.play.login>`.

1. Criar app; **travar package**; idioma `<default.idioma>`; build **AAB** (recusa APK).
2. Track **Interno** → instalar da loja real → depois promover.
3. Declarações do painel (todas **manuais**; radios do IARC e uploads de imagem exigem **clique humano**):
   - **Política de privacidade** (URL de `<app.politica.url>`).
   - **Classificação (IARC):** responda pelo perfil do app; um utilitário/produtividade sem conteúdo
     sensível cai em `<decl.classificacao>`.
   - **Data Safety:** declare `<decl.data_safety.coleta>`. Criptografado em trânsito
     `<decl.data_safety.transito>`; exclusão de dados `<decl.data_safety.exclusao>`.
     **Não** declarar `<decl.data_safety.nao_declarar>`.
   - **Público-alvo:** `<default.publico_alvo>` (18+ pula as etapas infantis/COPPA).
   - **Anúncios:** `<decl.anuncios>`. **Recursos financeiros:** `<decl.recursos_financeiros>`.
   - **IA generativa:** `<decl.ia_generativa>`; informe um contato de report.
   - **Acesso ao app:** credenciais do revisor (grupo demo).
   - **AAID:** `<decl.aaid>`. 🔴 Bloqueia Android 13+ até responder.
4. Assets: ícone 512, feature 1024x500 (sem alpha), 2-8 screenshots de telefone (tablets opcionais).
5. Promover: Produção → "Criar nova versão" → **"Adicionar da biblioteca"** (o AAB do teste) →
   países de `<default.pais>` → notas → revisão (1-3 dias).
6. **Publicação gerenciada:** ligar **antes** se quiser controlar o "ir ao ar" (OFF = publica ao aprovar).

Avisos benignos (não bloqueiam): "sem desofuscação" (sem R8) e "páginas de 16 KB".

---

## 🍎 APPLE APP STORE
**Portais:** `<org.apple.portal_dev>` · `<org.apple.portal_asc>`.
Sem Mac → build de nuvem (`references/codemagic-ios.md`).

**Config iOS:** `buildNumber` crescente; usage strings; `ITSAppUsesNonExemptEncryption=false`;
🟡 sem push v1 → remover `UIBackgroundModes=remote-notification` (risco 2.5.4) **mas manter
`FirebaseAppDelegateProxyEnabled=NO`** se `firebase_messaging` está no projeto (ver 2.1(a) abaixo —
**remover essa chave já crashou app em produção**); iPhone-only →
`TARGETED_DEVICE_FAMILY="<default.targeted_device_family>"` nas 3 configs do `project.pbxproj` —
**mas a Apple revisa o app num iPad mesmo assim** (modo compatibilidade; iPhone-only só dispensa os
*screenshots* de iPad).

**Assets:** iPhone 6.9" 1290x2796 (ou 6.5" 1284x2778 — o slot do ASC pode pedir esse; ter os dois).
iPad só se `supportsTablet=true` (desligar na v1). **Ícone da App Store vem do build** (sem upload
separado).

**Metadados / submissão:**
- Nome/subtítulo/keywords/descrição/novidades + 2 categorias (`<default.categoria_apple>`).
- **Classificação etária:** responda pelo perfil do app → `<decl.classificacao>`. Chat de IA privado
  = "Mensagens/UGC" **Não**.
- **App Privacy (nutrition label):** declare `<decl.data_safety.coleta>`; finalidade "Funcionalidade
  do app"; rastreamento `<decl.rastreamento>`; **Publicar**. ⚠️ **Reconcilie com o Data Safety da
  Play** — se lá o push foi declarado só no Android, aqui o device-ID não entra na v1. As duas
  declarações precisam contar a mesma história.
- Preço `<default.preco>`; disponibilidade `<default.pais>`; desligar Mac/Vision Pro.
- 🔴 Só aparecem ao clicar **"Adicionar para revisão"**: (1) **contato do revisor** —
  `<org.contato.revisor_nome>`, `<org.contato.revisor_telefone>`, `<org.contato.suporte_dpo>` e a
  **senha demo**, que quem digita é `<org.papel.digita_senha>`; (2) **Direitos de conteúdo** =
  "Não contém conteúdo de terceiros".
- Build → Novidades → **"Adicionar para revisão"** (submete direto; há "Cancelar envio").
  **Phased Release não existe na 1ª versão** → Automático.

### 🟡 Prevenção de rejeição (destilado de apps que somaram meia dúzia de rejeições)
| Guideline | O que pega | Como evitar |
|---|---|---|
| 5.1.1(v) | Exclusão de conta / campos pessoais obrigatórios | Exclusão real + campos opcionais em todos os fluxos |
| **5.1.1(i) / 5.1.2(i)** | 🔴 **App manda dado do usuário a IA de terceiro sem consentimento in-app** | Consentimento **dentro do app, ANTES do 1º envio** — ver abaixo |
| 4.8 | Login social sem Sign in with Apple | Se há Google/FB login, add Sign in with Apple (botão incondicional). Só e-mail/senha → N/A |
| 2.1(a) | Login sem conta demo / tenant demo inativo | Conta + grupo demo **ativo** (seed) |
| **2.1(a)** | 🔴 **Crash no launch pelo swizzler do Firebase** | `FirebaseAppDelegateProxyEnabled=NO` no `Info.plist` — ver abaixo |
| ITMS-90713 | Falta usage string | Todas as `NS...UsageDescription` |
| Export compliance | Trava o build | `ITSAppUsesNonExemptEncryption=false` |

#### 5.1.1(i)/5.1.2(i) — consentimento de IA
**Já reprovou app por isto.** Atinge todo app que tenha chat ou transcrição por IA. Se o app envia
dado do usuário (texto, áudio, dados do negócio) a um provedor de IA de terceiro — **mesmo que via
o seu próprio servidor** — a Apple exige, **dentro do app** e **antes do envio**:

1. **quais dados** são enviados;
2. **quem** é o destinatário — **nomear o provedor**: `<decl.ia.provedores>`;
3. **permissão explícita** do usuário **antes** de qualquer envio (recusou → não envia nada);
4. a política de privacidade cobrindo o que coleta / como / todos os usos + "proteção equivalente"
   pelo terceiro.

⚠️ **Política de privacidade sozinha NÃO basta** — a Apple é explícita: o consentimento tem que ser
in-app. A única saída alternativa é o app **não** mandar nada à IA. A implementação de referência do
seu projeto está em `<app.consentimento_ia>` — diálogo no 1º uso do chat, nomeando os provedores,
com aviso fixo na tela, flag persistida e gate no envio de texto e de áudio.

#### 2.1(a) — swizzler do Firebase derruba o app no launch
**Já reprovou app por isto.** Com `firebase_messaging` no projeto **mas sem `Firebase.initializeApp`
no iOS** (ex.: guard try/catch no `main.dart`, ou v1 sem push), o pod instala o
**`GULAppDelegateSwizzler`**, que roda no `didFinishLaunchingWithOptions` e **crasha o app no
launch** — o guard do Dart não impede o código nativo. **Fix:** `FirebaseAppDelegateProxyEnabled` =
**`NO`** (boolean) no `Info.plist`. Sem push, não se perde nada.
