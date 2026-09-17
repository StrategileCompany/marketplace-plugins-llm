# Checklist de segurança (ancorado em OWASP)

Régua curada para revisar o diff. Cada item traz **o que procurar**, **heurística por stack** (como
caçar — genérico, não preso a uma linguagem), **por que importa** e a **severidade padrão** (ajuste
pelo contexto: exploração remota sem auth sobe; mitigação forte desce).

Aplique o **núcleo** sempre. Aplique o **estendido** por relevância (a stack e o que o diff toca
decidem). Não force um item que não se aplica — ruído mata o portão.

## Índice
**Núcleo (sempre checa)**
1. [Injeção — SQL, comando, NoSQL, LDAP](#1-injecao)
2. [Segredos e tokens hardcoded](#2-segredos)
3. [Armazenamento de senha (hash forte, não criptografia)](#3-senha)
4. [Controle de acesso, multi-tenant e IDOR](#4-acesso)
5. [Constantes de segurança (magic values sensíveis)](#5-constantes)
6. [Prompt injection / LLM (quando há IA)](#6-prompt-injection)

**Estendido (por relevância)**
7. [XSS / output encoding](#7-xss)
8. [Falhas de criptografia (além de senha)](#8-cripto)
9. [Security misconfiguration](#9-misconfig)
10. [Dependências vulneráveis](#10-deps)
11. [SSRF](#11-ssrf)
12. [Falhas de autenticação / sessão](#12-auth)
13. [Integridade / deserialização insegura](#13-deserializacao)
14. [Logging e dados sensíveis (segredos/PII em log)](#14-logging)
15. [Validação de entrada, mass assignment, open redirect, CSRF, path traversal, XXE](#15-validacao)

---

# Núcleo (sempre checa)

## 1. Injeção — SQL, comando, NoSQL, LDAP {#1-injecao}
**O que procurar:** entrada do usuário concatenada/interpolada numa query, comando de SO, filtro
NoSQL/LDAP ou caminho — em vez de **parametrizada**.

**Heurística por stack (o mesmo cheiro em cada uma):**
- **SQL — inseguro:** interpolação/concatenação na query. `.NET/Dapper/ADO`: `$"... {var}"` ou
  `"... " + var` em `Query`/`Execute`/`SqlCommand`. `Node`: template string ou `+` em `db.query`,
  `knex.raw(`...${x}`)`. `Python`: f-string/`%`/`.format`/`+` em `cursor.execute`, `text("... "+x)`
  no SQLAlchemy. `Java`: concat em `Statement`. `PHP`: concat em `mysqli_query`.
  **Seguro:** parâmetros (`@p` / `?` / `$1` / `:p`) com o valor passado à parte.
- **Comando de SO:** entrada em `os.system`, `subprocess(..., shell=True)`, `exec`, `eval`,
  `Runtime.exec`, `child_process.exec`, crase/`sh -c`. Seguro: API sem shell + args em lista,
  allowlist.
- **NoSQL/LDAP:** objeto vindo do request usado direto como filtro (`{$where: userInput}`,
  `find(req.body)`), DN/filtro LDAP montado por concat.

**Por que importa:** é a classe nº 1 de comprometimento — vaza, altera ou apaga dados; em muitos
casos vira execução remota. Em SQLi, um único parâmetro não parametrizado basta.

**Severidade padrão:** **Crítico** quando entrada do usuário alcança a query/comando; **Alto** se
houver mitigação parcial (ex.: whitelist estrita a montante).

## 2. Segredos e tokens hardcoded {#2-segredos}
**O que procurar:** senha, token, API key, connection string, chave privada, secret de assinatura
**embutidos no código** (ou em arquivo versionado) em vez de virem da **configuração do ambiente /
secret store** do projeto.

**Heurística:** literais atribuídos a `password`/`senha`/`secret`/`apikey`/`token`/`connectionString`;
strings de alta entropia; prefixos conhecidos (`AKIA`/`ASIA` AWS, `AIza` Google, `ghp_`/`gho_`
GitHub, `xox` Slack, `sk-`/`sk_live_` chaves de API, JWT `eyJ...`, `-----BEGIN ... PRIVATE KEY-----`);
connection strings com `Password=`. Cuidado com **falso-positivo**: placeholders óbvios
(`your-key-here`, `xxxxx`), fixtures de teste e exemplos não são achado — mas um segredo **real**
é, mesmo "temporário".

**Onde deveria estar (genérico):** fora do código — em variável de ambiente, arquivo de config do
ambiente, ou secret store adotado pelo projeto. **Respeite a convenção do repositório** (leia
CLAUDE.md/AGENTS.md/README); não imponha uma solução (Key Vault, `.env`, tabela de config — o que o
projeto usar).

**Por que importa:** segredo em repositório = **assuma comprometido** (fica no histórico do git para
sempre, mesmo removido depois). Rotação vira incidente.

**Severidade padrão:** **Crítico** para segredo de produção/credencial viva; **Alto** para
não-produção ou de baixo alcance. Se estava commitado, recomende **rotacionar**, não só remover.

## 3. Armazenamento de senha — hash forte, não "criptografia" {#3-senha}
**O que procurar:** como a senha é guardada e comparada. O correto é **hash de senha lento e com
sal** — **argon2id** (preferido), **bcrypt**, **scrypt** ou **PBKDF2** com fator de trabalho
adequado. O hash é **via única**: senha não se "descriptografa".

**É achado quando:**
- A senha é **encriptada de forma reversível** (ex.: AES/DES sobre a senha) — reversível =
  recuperável = errado. **Isto já é o achado.**
- Usa hash **rápido/genérico**: MD5, SHA1, SHA-256/512 "cru", ou **sem sal**.
- Cripto caseira / rolada à mão, sal fixo/global, fator de trabalho baixo.
- Comparação **não constante no tempo**, ou senha **logada**/trafegada em claro indevidamente.

**Heurística:** procure `MD5`/`SHA1`/`SHA256` perto de `password`; `Encrypt(password)`;
ausência de `bcrypt`/`argon`/`scrypt`/`pbkdf2`/`Rfc2898`/`PasswordHasher`. Tokens de reset/sessão
também devem ser aleatórios (CSPRNG) e guardados como hash.

**Por que importa:** vazou o banco, hash forte com sal dá tempo; MD5/sem sal cai em minutos; senha
reversível ou em claro é vazamento imediato de todas as contas — e reúso de senha propaga o dano.

**Severidade padrão:** **Alto** (hash fraco/reversível); **Crítico** se senha em **texto puro**.

## 4. Controle de acesso, multi-tenant e IDOR {#4-acesso}
**O que procurar:** todo acesso a dado escopado ao **dono/tenant certo**, e todo endpoint com a
**autorização** exigida. Este é o risco nº 1 de vazamento em app multi-inquilino — trate com
carinho.

**É achado quando:**
- **Filtro de tenant/dono ausente** numa query de dado do usuário: `WHERE Id = @id` **sem**
  `AND TenantId = @tenant` / `AND OwnerId = @user`. Um `id` sequencial + filtro faltando = ler dado
  de outro cliente (**IDOR**).
- **Tenant/papel vindo do cliente** e confiado (header/campo/`role` do request) em vez de derivado
  do contexto autenticado.
- **Endpoint sem authZ** para a operação: rota de dados como anônima/pública indevidamente
  (`AuthorizationLevel.Anonymous`, `[AllowAnonymous]`, middleware de auth ausente), ou só
  *autenticado* onde precisa **autorizado** (dono/admin).
- **Referência direta a objeto** por id do request sem checar posse (download/edição por id).
- Escalada **vertical** (usuário comum atinge função de admin) ou **horizontal** (usuário A vê dados
  de B).

**Heurística:** para cada acesso a dado no diff, pergunte "isto está preso ao tenant/dono do
usuário autenticado?"; procure queries com `Id`/`Guid` do request sem cláusula de escopo; endpoints
novos sem atributo/checagem de autorização; uso de `tenantId`/`role` lido do request.

**Por que importa:** em app financeiro/de dados sensíveis, um filtro esquecido = **vazamento entre
clientes** — dano existencial e, no Brasil, exposição sob a **LGPD**.

**Severidade padrão:** **Crítico** (acesso cross-tenant / bypass de autorização); **Alto** se o
alcance for restrito.

## 5. Constantes de segurança (magic values sensíveis) {#5-constantes}
**O que procurar:** valores **sensíveis à segurança** embutidos soltos no código, espalhados e sem
nome: TTL/expiração de token, número máximo de tentativas de login, origens permitidas (CORS),
nomes de papéis/roles, tamanhos de chave, parâmetros de cripto (iterações, custo), limites de
upload.

**Por que importa (o ângulo de segurança):** valor mágico espalhado diverge entre pontos — um lugar
expira o token em 15 min, outro em 24 h; a regra de segurança fica inconsistente e difícil de
auditar. Nomeado/centralizado (constante ou config), a política é única e revisável.

**Limite do escopo:** aqui **não** é lint de todo número mágico — isso é do `/code-review`. Só entra
o valor com **ângulo de segurança**. Na dúvida se é "sensível", provavelmente não é.

**Severidade padrão:** **Baixo** (endurecimento/manutenibilidade de segurança). Sobe se o valor
mágico **é** a falha (ex.: `maxAttempts` inexistente = sem proteção a brute force → ver item 12).

## 6. Prompt injection / LLM (quando há integração com IA) {#6-prompt-injection}
**Só aplique se o diff toca IA/LLM** (prompts, SDK de modelo, agentes, tools). Ancorado no OWASP
Top 10 para LLM.

**O que procurar:**
- **Entrada não confiável concatenada no prompt** sem separação/rotulagem entre instrução do
  sistema e dado do usuário — deixando o usuário **sobrescrever** a instrução ("ignore as regras
  acima...").
- **Injeção indireta:** conteúdo de fonte externa (página, documento, e-mail, resultado de tool)
  tratado como instrução, não como dado.
- **Saída do modelo dirigindo ação privilegiada** sem validação — o texto do LLM aciona uma tool,
  SQL, shell, compra, e-mail, mudança de permissão direto.
- **Tools/functions expostas ao modelo sem authZ** própria (o modelo vira um usuário sem checagem).
- **Segredos/PII colocados no prompt**, ou **saída do modelo renderizada sem sanitizar** (vira XSS —
  ver item 7) ou usada para exfiltrar dado.

**Mitigações a exigir:** system vs. user separados; **tratar toda saída do modelo como não
confiável**; allowlist/confirmação para tools de efeito colateral; validar/limitar a saída;
defender injeção indireta; nunca colocar segredo no contexto.

**Por que importa:** prompt injection é a injeção da era de IA — sem contorno geral confiável; a
defesa é **arquitetural** (privilégio mínimo, validação na fronteira, humano no circuito para ações
sensíveis). Ver também as regras de fronteira de instrução (dado ≠ comando).

**Severidade padrão:** **Alto**; **Crítico** se a saída do modelo aciona ação sensível sem validação
(RCE, mover dinheiro, mudar acesso, exfiltrar dado).

---

# Estendido (por relevância)

## 7. XSS / output encoding {#7-xss}
**O que procurar:** dado do usuário renderizado **sem escape**. `Blazor`: `(MarkupString)` com
conteúdo do usuário. `React`: `dangerouslySetInnerHTML`. `Angular`: `bypassSecurityTrust*`. DOM:
`innerHTML`/`document.write`. Template com autoescape **desligado**. Markdown/HTML do usuário
renderizado **sem sanitizar** (allowlist).
**Por que importa:** executa script no navegador da vítima — sequestro de sessão, ações no nome dela.
Stored XSS atinge todo mundo que vê o conteúdo.
**Severidade padrão:** **Alto** (armazenado) / **Médio** (refletido). Corrija encodando por padrão,
sanitizando HTML por allowlist e considerando CSP.

## 8. Falhas de criptografia — além de senha {#8-cripto}
**O que procurar:** algoritmo fraco (DES, RC4, **ECB**), **chave/IV hardcoded** ou IV estático, MD5/
SHA1 para integridade, **aleatoriedade fraca** (`Math.random`, `rand()`) para token/segredo/ID,
TLS ausente (`http://` para dado sensível) ou **validação de certificado desabilitada**.
**Por que importa:** cripto malfeita dá falsa sensação de proteção; IV fixo/ECB vaza padrão; token
previsível é adivinhável.
**Severidade padrão:** **Médio**–**Alto** conforme o dado protegido. Use AEAD (ex.: AES-GCM), IV
aleatório, CSPRNG, TLS obrigatório.

## 9. Security misconfiguration {#9-misconfig}
**O que procurar:** **CORS** liberal (`*`, ainda pior com credenciais), **stack trace / erro
verboso** devolvido ao cliente, endpoint de debug/admin exposto, credencial padrão, listagem de
diretório, headers de segurança ausentes (HSTS, CSP, `X-Content-Type-Options`), permissões amplas
demais, `DEBUG=true` em produção.
**Por que importa:** entrega o mapa ao atacante (mensagem de erro detalhada) ou abre a porta (CORS/
debug). É configuração, some fácil no diff.
**Severidade padrão:** **Médio** (**Alto** se CORS com credenciais, ou stack trace em produção).

## 10. Dependências vulneráveis {#10-deps}
**O que procurar:** manifesto de dependência alterado no diff; pacote adicionado/fixado em versão
com CVE conhecido.
**Como checar (por ecossistema):** `dotnet list package --vulnerable --include-transitive` ·
`npm audit` / `pnpm audit` · `pip-audit` · `govulncheck` · `bundler-audit` · `cargo audit`.
**Por que importa:** a maioria dos apps é mais dependência do que código próprio; um pacote furado
compromete tudo.
**Severidade padrão:** a do CVE (padrão **Médio**–**Alto**). Aponte a versão corrigida.

## 11. SSRF — Server-Side Request Forgery {#11-ssrf}
**O que procurar:** servidor faz requisição a **URL vinda do usuário** (fetch/proxy/webhook/importar-
de-URL/preview) sem allowlist; sem bloqueio de faixas internas e do **metadata da nuvem**
(`169.254.169.254`).
**Por que importa:** o atacante usa seu servidor para alcançar a rede interna e roubar credenciais
de instância (metadata) — pivô clássico para nuvem.
**Severidade padrão:** **Alto**. Corrija com allowlist de destino e bloqueio de IP interno/metadata.

## 12. Falhas de autenticação / sessão {#12-auth}
**O que procurar:** **sem rate limit / lockout** no login (brute force), política de senha fraca,
token/sessão **previsível** ou curto, **JWT** com `alg:none`/assinatura não verificada/sem expiração,
session fixation, **token na URL**, refresh de vida longa sem rotação.
**Por que importa:** é a porta da frente; sem limite de tentativa, senha vira questão de tempo.
**Severidade padrão:** **Médio**–**Alto** (JWT não verificado = **Alto**/Crítico).

## 13. Integridade / deserialização insegura {#13-deserializacao}
**O que procurar:** desserializar dado **não confiável** com desserializador perigoso
(`BinaryFormatter`/.NET, `pickle`/Python, YAML inseguro, Java nativo), plugin/atualização
**baixado sem verificar assinatura**, build confiando em fonte não verificada.
**Por que importa:** desserialização insegura de dado controlado costuma virar **execução remota**.
**Severidade padrão:** **Alto**–**Crítico**. Prefira formatos de dados (JSON) com tipos restritos;
verifique assinatura/hash de artefatos.

## 14. Logging e dados sensíveis (segredos/PII em log) {#14-logging}
**O que procurar:** log de **segredo/token/senha**, corpo de request inteiro, número de cartão,
dado de saúde, **PII** sem necessidade; PII/segredo em **URL/query string** (vaza em log de acesso/
histórico); ausência de trilha para eventos de segurança.
**Por que importa:** o log vira um segundo banco de dados sensível, muitas vezes menos protegido;
sob **LGPD/GDPR**, logar PII à toa é exposição e passivo legal. Minimize e **mascare**.
**Severidade padrão:** **Médio** (**Alto** se segredo/PII em escala).

## 15. Validação de entrada — mass assignment, open redirect, CSRF, path traversal, XXE {#15-validacao}
**O que procurar (grupo):**
- **Mass assignment / over-posting:** request vinculado direto à entidade, expondo campos que o
  usuário não deveria setar (`isAdmin`, `role`, `ownerId`, `saldo`). Corrija com DTO/allowlist de
  campos.
- **Open redirect:** destino do redirect vindo do usuário sem allowlist (usado em phishing).
- **CSRF:** endpoint que muda estado, com auth por **cookie**, sem anti-CSRF token nem
  `SameSite`.
- **Path traversal:** caminho de arquivo montado com entrada do usuário (`../../etc/passwd`); upload
  sem validar tipo/tamanho/destino.
- **XXE:** parser de XML com **entidades externas** habilitadas sobre XML não confiável.
**Por que importa:** são as bordas onde "entrada vira comportamento" — cada uma tem exploração
conhecida e correção conhecida.
**Severidade padrão:** **Médio**–**Alto** conforme o alcance (mass assignment de `role`/`ownerId` =
**Alto**; conecta com o item 4).

---

## Como reportar cada achado
Para cada item confirmado, produza a linha no formato do relatório (ver
`severidade-e-relatorio.md`): **severidade · `arquivo:linha` · categoria (OWASP) · o que é · por que
importa · correção sugerida · confiança**. Achado incerto vai **marcado como "a confirmar"** — nunca
como certeza.
