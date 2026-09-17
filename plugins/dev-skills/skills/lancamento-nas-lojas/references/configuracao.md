# Configuração da skill (passo 0 — antes de qualquer outra coisa)

Esta skill não guarda nenhuma constante da sua organização. Login das lojas, prefixo de App ID,
nome da chave de publicação, host da política, caminho do keystore — tudo isso vem de um
**arquivo de configuração externo**, que a skill procura, valida e, se não existir, ajuda você a
criar por entrevista.

> **Por que assim:** a skill é pública e serve a qualquer empresa. Se as constantes vivessem no
> corpo dela, cada time receberia as de outro — e o repositório publicaria o mapa da infra de
> publicação de quem a escreveu.

## Nome canônico

```
lancamento-nas-lojas.config.json
```

O nome é derivável do `name` do frontmatter (`<skill>.config.json`) — não precisa ser memorizado.

## Ordem de busca

Pare no primeiro que existir:

1. **Caminho gravado na memória** de projeto `lojas-config-path`, se houver.
2. `./.scratch/lancamento-nas-lojas.config.json`
3. `./.docs/lancamento-nas-lojas.config.json`
4. `./lancamento-nas-lojas.config.json` (raiz do repositório atual)
5. `~/.claude/lancamento-nas-lojas.config.json` (perfil do usuário — vale para todos os repos)

```bash
for p in ./.scratch ./.docs . "$HOME/.claude"; do
  [ -f "$p/lancamento-nas-lojas.config.json" ] && echo "ACHOU: $p/lancamento-nas-lojas.config.json" && break
done
```

## As duas camadas

Mesmo nome, mesmo schema, dois arquivos:

| Camada | Onde vive | O que carrega |
|---|---|---|
| **Organização** | perfil do usuário ou diretório gitignored | as variáveis de `scope: "org"` — contas, portais, identificadores de build, defaults de ficha, perfil de declarações |
| **App** | repositório privado de cada app | as de `scope: "app"` — App IDs, nome, keystore, seed do revisor, caminhos |

Carregue as duas e **sobreponha: o arquivo do app vence**. Só a camada de organização existindo,
a skill funciona até precisar de um valor de app — e aí pergunta.

## O schema

Uma variável por entrada. A pergunta da entrevista mora na própria definição:

```json
{
  "name": "org.play.login",
  "value": null,
  "required": true,
  "scope": "org",
  "description": "Qual o e-mail de login do Google Play Console?"
}
```

| Campo | Significado |
|---|---|
| `name` | Identificador da variável, em notação pontuada. É como a skill a referencia. |
| `value` | O valor. `null` = ainda não respondida. |
| `required` | Booleano. `true` bloqueia a etapa que depende dela. |
| `scope` | `"org"` ou `"app"` — decide em qual camada a variável vive. |
| `requiredIf` | Opcional. Nome de outra variável: só é obrigatória se aquela tiver valor. |
| `description` | **A pergunta da entrevista.** Escreva sempre como pergunta. |

O molde com todas as variáveis está em `assets/lancamento-nas-lojas.config.example.json` — é a
documentação viva do contrato. Variável nova entra lá primeiro.

## Regra de completude

Não basta o arquivo existir. Ele está **completo** quando toda variável com `required: true` tem
`value` não-nulo — descontadas as que têm `requiredIf` apontando para uma variável sem valor.

```bash
node -e '
const c=require("./lancamento-nas-lojas.config.json");
const tem=n=>{const v=c.variables.find(x=>x.name===n);return v&&v.value!==null};
const faltam=c.variables.filter(v=>
  v.value===null && v.required && (!v.requiredIf || tem(v.requiredIf))
);
console.log(faltam.length?faltam.map(v=>v.name).join("\n"):"COMPLETO");
'
```

Incompleto **não** é erro: é o gatilho para perguntar só o que falta.

## O fluxo do passo 0

1. **Procure** na ordem acima.
2. **Achou e está completo** → siga para a etapa 1 da skill. Nada a relatar além de uma linha
   dizendo de onde leu.
3. **Não achou** → **pergunte primeiro onde o arquivo está.** Ele pode existir fora da ordem de
   busca — noutro diretório, noutro repositório, no cofre do time. Só ofereça a entrevista depois
   de o usuário dizer que não existe.
4. **Achou mas está incompleto** → mostre **quais** variáveis faltam e entreviste **apenas** essas.
   Nunca reperguntar o que já está respondido.
5. **Entreviste** (regras abaixo), **grave o JSON** e **informe o caminho absoluto** em que gravou.
6. **Grave o caminho na memória** `lojas-config-path` para não perguntar de novo.

## Regras da entrevista

- **Agrupe as perguntas** — 3 a 5 por vez, por assunto (contas, build, ficha, declarações). Não
  uma de cada vez: ninguém responde 31 perguntas enfileiradas.
- **Use o `description` como pergunta**, literal. Se precisar reformular, atualize o molde também
  — senão os dois divergem.
- **Só o que falta.** Variável já respondida não volta.
- **Ofereça o default quando houver.** Muitas são públicas (URL de portal, canal do Flutter,
  máquina de build); proponha e peça só a confirmação.
- **Nunca pergunte um segredo** (ver abaixo).
- **Nunca invente um valor.** Sem resposta, a variável fica `null` e a etapa que depende dela
  **bloqueia**, dizendo qual valor falta e onde costuma estar.
- **Opcional pode ficar em branco.** Não insista: `required: false` existe para isso.

## Onde gravar (e a checagem que não pode faltar)

Ordem de preferência: um diretório **gitignored** do repositório atual (`.scratch/`, `.docs/`) ou
o perfil do usuário (`~/.claude/`).

**Antes de gravar, confirme que o destino está ignorado:**

```bash
git check-ignore -q "<caminho>" && echo "ignorado (ok)" || echo "ATENCAO: nao ignorado"
```

Não estando ignorado, **avise** e ofereça acrescentar a linha ao `.gitignore`. Um arquivo de
configuração versionado por engano recria exatamente o problema que esta separação existe para
resolver. Se o usuário insistir em gravar num diretório versionado, registre o aviso e siga — a
decisão é dele.

Ao terminar, diga **o caminho absoluto** e quantas variáveis ficaram pendentes.

## Configuração não guarda segredo

A configuração guarda **identificadores**: login, Team ID, Key ID, Issuer ID, nomes de recurso,
caminhos, URLs. Isso **nunca** entra nela:

| Nunca na configuração | Onde vive |
|---|---|
| Senha de conta de loja | cofre de senhas |
| `.p8` da App Store Connect API | arquivo fora do git + cofre |
| Chave privada do certificado iOS | secret no serviço de build + cofre |
| Keystore de upload e sua senha | arquivo gitignored no repo do app + cofre |
| Credencial de produção, senha do revisor | seed do projeto + cofre |

Para esses, a entrevista pergunta **onde estão**, nunca o valor. E a skill nunca digita senha em
formulário: quem digita é o papel definido em `org.papel.digita_senha`.

## Degradação graciosa

- **Sem `node` disponível** → valide a completude lendo o JSON com a ferramenta de leitura e
  conferindo `required`/`value` à mão. A checagem é a mesma.
- **Arquivo corrompido** (JSON inválido) → **não sobrescreva.** Mostre o erro de parse, diga o
  caminho e pergunte se recria do zero ou se o usuário prefere corrigir.
- **Duas camadas em conflito** → o arquivo do app vence; mencione numa linha qual valor foi
  sobreposto.
- **Usuário recusa a entrevista** → siga só até onde a configuração permitir; cada etapa que
  precisar de um valor ausente para e diz o que falta.
