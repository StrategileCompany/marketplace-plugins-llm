# Severidade, gate e relatório

Como classificar um achado, o que **barra** e o que **avisa**, e o formato exato do relatório.

## 1. Rubrica de severidade
Severidade = **quão explorável** × **qual o impacto**. Use as âncoras; ajuste pelo contexto (auth
necessária, alcance do dado, mitigação existente).

| Severidade | Âncora (explorabilidade × impacto) | Exemplos típicos |
|---|---|---|
| **Crítico** | Explorável de forma remota/fácil, muitas vezes sem auth, com impacto grave: vazamento de dados, RCE, comprometimento de contas, acesso cross-tenant. | SQLi alcançável por entrada do usuário · segredo de produção vivo no repo · filtro de tenant ausente (dado de outro cliente) · senha em texto puro · saída de LLM aciona ação sensível sem validação. |
| **Alto** | Explorável sob alguma condição, ou impacto sério porém contido. | Hash de senha fraco/reversível · bypass de autorização de alcance limitado · stored XSS · SSRF · JWT sem verificação de assinatura · deserialização insegura. |
| **Médio** | Exige condição incomum, ou impacto limitado; defesa em profundidade que falta. | Reflected XSS com mitigação · CORS liberal sem credenciais · stack trace vazando · sem rate limit no login · PII em log. |
| **Baixo** | Endurecimento; risco pequeno ou muito indireto. | Constante de segurança mágica · header de segurança ausente · vazamento mínimo de informação. |

**Confiança** acompanha (não substitui) a severidade: reporte **alta confiança** como achado;
**incerto** vai marcado **"a confirmar"** (você viu o cheiro mas não confirmou o fluxo). Nunca
transforme suspeita em certeza — falso-positivo é o que faz o time desligar o portão.

## 2. Mapa do gate (o que barra, o que avisa)
| Severidade | Ação do portão |
|---|---|
| **Crítico** | **BARRA.** Commit/fechamento não prossegue. |
| **Alto** | **BARRA.** Commit/fechamento não prossegue. |
| **Médio** | **AVISA.** Registra; não bloqueia. |
| **Baixo** | **AVISA.** Registra; não bloqueia. |

- **Override:** o usuário pode liberar um bloqueio de forma **explícita** ("segue mesmo assim",
  "ignora e commita", "aceito o risco"). Ao liberar, **registre no relatório**: "liberado com
  ressalva pelo usuário" + o achado. Sem override explícito, um Crítico/Alto **para o fluxo**.
- **Acoplada ao `desenvolvedor`:** barrar aqui **impede o passo de commit** do Fechamento. É o que
  dá dente ao portão.
- **"A confirmar" não barra sozinho:** um item incerto não bloqueia — mas **peça a confirmação**
  antes de seguir, ou trate-o (ler o contexto) para promover a achado ou descartar.

## 3. Template do relatório
Comece pelo **veredito** e pela **contagem** — o leitor decide em 2 segundos. Sem emojis; texto
limpo. Formato:

```
## Revisão de segurança — <escopo>

Veredito: BARRADO (2 Crítico · 1 Alto)      [ou] Veredito: PASSOU (0 Crítico/Alto · 2 Médio)
Escopo: working tree (staged + unstaged) · 7 arquivos · stack: <detectada>
Checado: injeção, segredos, senha, acesso/multi-tenant, prompt injection, XSS, cripto, deps, logging

### Achados

1. [CRÍTICO] Injeção — SQL (OWASP A03) — `src/Repo/UsuarioRepository.cs:42`
   - O que: a query concatena `email` direto na string SQL.
   - Por que importa: entrada do usuário vira SQL — permite ler/alterar dados de qualquer conta.
   - Correção: parametrize (`WHERE Email = @email`, valor à parte). Nunca interpole entrada em SQL.
   - Confiança: alta.

2. [ALTO] Controle de acesso — IDOR/multi-tenant (OWASP A01) — `src/Api/PedidoFunction.cs:88`
   - O que: busca o pedido por `id` da rota sem filtrar pelo tenant do usuário autenticado.
   - Por que importa: trocar o `id` na URL retorna pedido de outro cliente (vazamento cross-tenant).
   - Correção: adicione `AND TenantId = @tenant` derivado do contexto autenticado (não do request).
   - Confiança: alta.

### A confirmar (incerto — não barra sozinho)
- [Médio?] `src/.../Foo.cs:120` — possível XSS ao renderizar `descricao` como MarkupString; confirmar
  se o valor passa por sanitização antes. (Ler o fluxo antes de cravar.)

### Avisos (Médio/Baixo — não barram)
- [MÉDIO] Sem rate limit no login (`AuthController:31`) — expõe a brute force. (item 12)
- [BAIXO] TTL de token como número mágico repetido (`Config.cs:7`, `Jwt.cs:19`) — centralize. (item 5)

### Como seguir
- Corrijo algum agora? (aplico com seu ok)
- Abro issue para os adiados? (via registra-issue, uma por achado)
- Ou você libera explicitamente e segue com a ressalva?
```

Regras do relatório:
- **Ranqueie** por severidade (Crítico → Baixo). Numere os achados que barram.
- Cada achado: **severidade · categoria (OWASP) · `arquivo:linha` · o que · por que importa ·
  correção · confiança.** A correção é **acionável** (o que fazer, não "revise a segurança").
- Separe **"a confirmar"** (incerto) e **"avisos"** (Médio/Baixo) dos bloqueios.
- Liste em **"Checado"** as classes que você varreu — dá ao leitor a superfície coberta e evita a
  falsa impressão de "tudo certo" quando na verdade algo não foi olhado.
- **Nunca prometa "seguro"/"impecável".** O veredito é sobre *o que foi checado neste diff*.

## 4. Degradação graciosa
- **Não é repo git / sem diff:** avise e ofereça revisar um arquivo/pasta apontado ou o último
  commit (`git show`). Não invente escopo.
- **Stack não reconhecida:** aplique os checks **conceituais** (o cheiro é o mesmo) e diga que a
  heurística específica da linguagem foi limitada.
- **`/security-review` nativo indisponível:** siga só com a régua curada e **avise** que a varredura
  de amplitude não rodou.
- **Sem `gh` / sem acesso ao PR:** revise o escopo local (working tree/branch) e avise a limitação.

Em todos os casos: **degrade com aviso explícito** — o usuário precisa saber o que **não** foi
coberto para não confundir "passou" com "não olhei".
