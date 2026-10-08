---
name: deriva-projeto
description: >-
  Deriva um projeto novo do clone de um repositório existente: remove o domínio
  antigo, preserva a infra reaproveitável (bootstrap/DI, autenticação,
  middlewares, layout, componentes genéricos, CI/CD, IaC), renomeia pastas,
  projetos, namespaces, identificadores, chaves de configuração e recursos de
  nuvem, e REGENERA segredos e identidades em vez de herdá-los — com build e
  testes verdes. Use SEMPRE que o usuário disser "vou começar um projeto novo
  aproveitando esse repo", "usa o projeto X como template/base", "clonei o Y
  para começar o Z", "limpa tudo que é do projeto antigo", "tira o que é
  específico e renomeia para...", "quero reaproveitar a infra desse
  repositório", "criar o esqueleto do novo sistema a partir deste" — mesmo sem
  a palavra "template" e sem citar os nomes. Agnóstica de stack: descobre tipo
  de projeto, build, testes, CI/CD e IaC em runtime. NUNCA faz commit.
model: opus
effort: high
---

# Derivar um projeto novo a partir de um repositório existente

O usuário clonou um repositório que já tem infraestrutura pronta (autenticação, DI, CI/CD,
observabilidade, layout) e quer usá-lo como ponto de partida para um sistema diferente. Seu
trabalho é remover o domínio antigo, renomear o que é identificador, **regenerar o que é
identidade** e entregar um repositório que **compila, passa nos testes e sobe** — sem vestígio
do projeto anterior.

Três coisas dão errado quando isso é feito à mão, e o processo abaixo existe para evitar as três:

1. **Sobra código morto** do domínio antigo, que confunde quem entra depois.
2. **Some algo que era infraestrutura**, e o build quebra de um jeito difícil de diagnosticar.
3. **O projeto novo herda a identidade do antigo** — mesma chave de assinatura de token, mesmo
   client OAuth, mesmo webhook, mesmo domínio. Este é o mais grave, porque não aparece no build:
   aparece em produção, quando os dois sistemas passam a aceitar o token um do outro.

Esta skill é agnóstica de stack e de plataforma. Nada de tipo de projeto, comando de build,
ferramenta de CI, provedor de nuvem ou convenção de nome de recurso está fixado aqui — tudo é
**descoberto no repositório** e o que não der para descobrir **se pergunta**.

## Regra inegociável: nada de commit

Não rode `git commit`, `git push`, nem crie repositório remoto. O fluxo é: limpar → o usuário
cria o repositório → só então o primeiro commit, com autorização explícita. Você para no
`git init`. **Diga isso logo no começo**, para o usuário não ficar esperando.

## Passo 1 — Perguntar o que não se deduz (antes de qualquer análise)

Faça uma listagem rápida dos projetos/manifestos antes de perguntar — a pergunta fica muito
melhor com os nomes reais na mão. Use `AskUserQuestion` com o padrão detectado como primeira
opção, marcada como recomendada. São cinco itens e o `AskUserQuestion` aceita quatro por chamada:
agrupe nome e namespace numa pergunta só, ou faça duas rodadas seguidas — não espalhe ao longo do
trabalho.

1. **Nome do projeto novo** — se a solution/monorepo tem várias camadas, pergunte como nomear o
   conjunto. Ofereça o padrão que o repositório já usa: se hoje é `Foo.Api` / `Foo.Core`, o
   natural é `Novo.Api` / `Novo.Core`. Confirme, não presuma.
2. **Namespace ou pacote raiz** — normalmente igual ao prefixo dos projetos, mas nem sempre.
3. **Histórico Git** — apagar o `.git` e começar do zero, ou preservar o histórico do antigo?
   (Apagar é o default: o histórico do projeto antigo raramente ajuda e carrega segredo que já
   foi commitado algum dia.)
4. **Nomes de recurso na nuvem e IaC** — derivar pela convenção que o repositório já demonstra,
   deixar placeholder, ou remover os diretórios de infra?
5. **Banco de dados**, se o inventário achou esquema versionado — o projeto novo começa com um
   script de criação único já limpo (baseline novo, o default recomendado) ou preserva o histórico
   de migrations do antigo? Detalhes em `references/banco-de-dados.md`.

Os itens 1 a 3 vêm antes de qualquer análise, porque determinam tudo o que segue. Os itens 4 e 5
dependem de saber o que existe: se a listagem rápida não responder, pergunte-os logo depois do
inventário — mas **antes** de apresentar o plano, que deve chegar fechado.

## Passo 2 — Inventário e linha de base (só leitura)

Rode o inventário. Ele reúne, de uma vez, tudo que você precisa antes de decidir qualquer coisa:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}/scripts/Get-Inventario.ps1" -Path "<raiz>" -Token <TokenAntigo>
```

> **Fora do Claude Code** (GitHub Copilot, por exemplo) a variável `${CLAUDE_SKILL_DIR}` **não** é
> substituída e o comando quebra sem erro claro. Troque-a pelo caminho da pasta desta skill — o
> `scripts/` fica ao lado do `SKILL.md`. Sem PowerShell na máquina, levante os mesmos fatos com
> as ferramentas que tiver; o roteiro não muda, só a forma de coletar.

O script reporta: projetos e tipo de cada um, **variantes de caixa do token** e onde aparecem,
arquivos fora de UTF-8, pontos de entrada e rota de saúde, pacotes duplicados, configuração,
CI/CD, IaC e containers, **chaves de segredo e identidade** (só o nome — nunca o valor),
**domínios com o token**, artefatos de banco, instruções de agente, carimbos de versão, assets
de marca e o estado do Git. Ele também sugere o `-Map` do rename, já ordenado.

Se ele não conseguir derivar o token, informe `-Token` explicitamente — e confira o resultado:
um token derivado errado contamina todo o resto.

**Rode a linha de base agora, antes de tocar em nada.** Descubra os comandos no próprio
repositório (README, CI, manifestos) e execute build e testes. Isso separa "eu quebrei" de "já
estava quebrado". Se algo falhar por ambiente (feed de pacotes privado, credencial, ferramenta
ausente), **não trave**: registre como pendência, siga, e diga ao usuário no relatório final.

## Passo 3 — Classificar

Leia o guia da stack correspondente antes de classificar — cada um diz o que é estrutural ali e
onde ficam as armadilhas. Se a solution mistura tipos (comum: uma API + um front), leia os dois;
são curtos e se complementam.

| Se o inventário apontou | Leia |
|---|---|
| Azure Function | `references/azure-functions.md` |
| Blazor Server / Web App / API | `references/blazor-server.md` |
| Blazor WebAssembly | `references/blazor-wasm.md` |
| Banco de dados (scripts, migrations) | `references/banco-de-dados.md` |
| CI/CD e IaC | `references/ci-cd-e-iac.md` |
| Sempre (segredos e identidades) | `references/segredos-e-identidades.md` |

Stack sem guia aqui (Node, Python, Go, Flutter…)? O critério de classificação abaixo vale igual.
Descubra o equivalente ao bootstrap, ao ponto de entrada e à configuração, e aplique o mesmo
raciocínio.

### Como decidir se um arquivo fica ou sai

O critério é **teste da segunda aplicação**: se você fosse escrever outro sistema qualquer
amanhã, esse arquivo sairia praticamente igual? Então é infraestrutura, fica.

**Fica** (infraestrutura): bootstrap e registro de DI, autenticação e autorização, provedores de
token, middlewares transversais, tratamento de erro, logging e telemetria, clientes HTTP
genéricos, layout/menu/topbar, sistema de notificação de UI, componentes parametrizados por tipo
genérico, tipos utilitários (resultado paginado, envelope de erro), design system, CI/CD, IaC,
`.gitignore`, `.editorconfig`.

**Sai** (domínio): tudo que nomeia entidades do negócio antigo — páginas, componentes de tela,
DTOs, enums de status, filtros, mocks, JS de uma tela, CSS de página específica, e os pontos de
entrada (endpoints, jobs, consumidores de fila) que servem um processo do domínio antigo.

**Fronteira** (pergunte): não decida sozinha nesses casos — o custo de perguntar é baixo e o de
errar é alto nos dois sentidos.

- Componente genérico na forma que consome um endpoint específico do backend antigo.
- Código morto que sobreviveu (registrado no DI, nunca chamado).
- **Capacidades de plataforma que se disfarçam de domínio.** Este é o caso mais comum e o mais
  custoso de errar: identidade e multi-tenancy, cobrança e assinatura, notificação (e-mail, push),
  auditoria, exportação, feature flags, rateio de custo. Elas costumam estar organizadas como se
  fossem módulos de negócio — com nome de contexto, pasta própria e tabelas — mas na maioria das
  derivações **ficam**, porque o sistema novo vai precisar delas no primeiro dia. Liste-as
  explicitamente e deixe o usuário decidir uma por uma.

**Testes seguem o que testam.** Teste de página do domínio sai junto com a página. Teste de
componente genérico fica. Helpers e fixtures de teste ficam mesmo que fiquem temporariamente sem
uso — são infraestrutura de teste.

### Feche o grafo de dependências antes de apresentar o plano

Depois de montar as listas, faça o passo que evita build quebrado: procure, **nos arquivos que
vão ficar**, referências a qualquer coisa que vai sair. Para cada pendência encontrada, uma de
duas coisas está errada — ou o tipo referenciado é infraestrutura e deve ser promovido a mantido,
ou quem referencia é domínio disfarçado e deve sair.

Vale também o caminho inverso, que é o mais fácil de esquecer: um `import`/`@using` de namespace
que deixa de existir, um registro de DI apontando para um serviço apagado, um `Content Remove` ou
entrada de manifesto para arquivo removido, uma rota que some, um teste que importa o que saiu.

**O registro de DI é o ponto de pendência número um.** Onde o bootstrap agrupa registros por
módulo (`services.UseXContext()`, `AddFooModule()`, uma lista de providers), cada exclusão de
módulo precisa remover a linha correspondente. Confira o bootstrap linha por linha contra a lista
de exclusão — é mecânico e é o que mais quebra build.

## Passo 4 — Apresentar o plano em bloco

Uma aprovação só, não item a item. Mostre:

- **Excluir**: agrupado por projeto e por pasta, com contagem (não liste 80 caminhos soltos —
  "13 arquivos em `Pages/Financeiro/**`" comunica melhor).
- **Renomear**: pastas, solution/manifestos, projetos, tokens de conteúdo, prefixos de CSS.
- **Regenerar**: os segredos e identidades, um por um, com o que gera cada um
  (`references/segredos-e-identidades.md`). Nunca colapse isso em "ajustar configuração".
- **Alterar**: os pontos que exigem edição manual, um por um, com o *porquê*.
- **Criar**: o que precisa nascer para o build, a rota ou o smoke test continuarem de pé.
- **Pontos de atenção**: o que você derivou por convenção e o usuário precisa validar depois
  (nomes de recurso na nuvem, chaves de configuração, integrações externas, domínios).

Se algum caso de fronteira ficou aberto, resolva com `AskUserQuestion` **antes** de apresentar o
plano — o plano deve chegar fechado.

## Passo 5 — Executar, nesta ordem

A ordem importa: excluir antes de renomear reduz o volume do rename; renomear caminhos antes de
reescrever conteúdo evita reescrever arquivos que vão sumir.

1. **Limpe o que não pode entrar no rename, antes de tudo**: saída de build (`bin/`, `obj/`,
   `dist/`, `target/`, `node_modules/`) e, principalmente, **worktrees ou cópias do repositório
   dentro dele** (o inventário avisa). Uma worktree esquecida é um repositório inteiro que o
   rename reescreveria por dentro.
2. **Excluir** os arquivos e pastas aprovados.
3. **Confirmar encoding**: reveja a lista de arquivos não-UTF-8 do inventário. Se algum
   sobreviveu, o rename precisa ser byte-safe — o script é; ferramentas que reescrevem o arquivo
   inteiro não são.
4. **Renomear** com o script, **sempre com `-DryRun` primeiro**:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}/scripts/Rename-Token.ps1" -Path "<raiz>" -Map "MeuSistema=NovoSistema;meusistema=novosistema" -RenamePaths -DryRun
   ```

   - Tokens **mais longos primeiro**: são aplicados em ordem, e um curto aplicado antes come o
     longo. O script recusa um `-Map` cuja ordem se autossabotaria, mas confira você também.
   - Inclua **todas as variantes de caixa que o inventário encontrou** — PascalCase, minúscula
     (URLs, domínios, recursos de nuvem), MAIÚSCULA, kebab, snake e o nome de exibição com espaço.
   - **Token curto** (2–4 letras) pede `-WholeWord`, senão ele casa dentro de outras palavras. O
     inventário avisa quando encontra o token colado a outras letras.
   - **Destino sem acento** nos identificadores. O script recusa renomear caminhos com caractere
     não-ASCII: use a forma sem acento em namespace, pasta e chave, e ajuste o nome de exibição
     à mão depois.
5. **Prefixo de CSS**: se o design system usa um prefixo derivado do projeto antigo (`.ms-table`,
   `--ms-primary`), ele é um identificador e entra no rename. Antes, confirme que o prefixo nunca
   aparece colado a outra palavra.
6. **Regenerar segredos e identidades** conforme `references/segredos-e-identidades.md`. Você
   **gera valores novos onde souber gerar** e **aponta o que é ação do usuário** — nunca copia o
   valor antigo, e nunca escreve segredo no repositório.
7. **Ajustes manuais** guiados pelo guia da stack. Depois de podar CSS ou qualquer arquivo por
   intervalo de linhas, **valide a integridade** (chaves `{` e `}` batendo) — recortar por
   intervalo é o jeito mais fácil de deixar uma chave órfã, ainda mais quando o arquivo não
   termina com quebra de linha.
8. **Zerar versão e histórico de release**: carimbos de versão voltam ao inicial, CHANGELOG e
   notas de versão do projeto antigo saem.
9. **Criar** o que faltou.

## Passo 6 — Verificar

Não declare pronto sem estes quatro sinais:

1. **Build** — zero erros, com o comando que o repositório usa.
2. **Testes** — todos verdes.
3. **Varredura de resíduos** — vazia, salvo menções intencionais (crédito no README, por exemplo).
   Rode com todas as variantes de caixa e o prefixo de CSS, ignorando saída de build e `.git`.
4. **A aplicação sobe.** Build verde não prova que a app sobe.

### Sobre o smoke test

**Antes de subir, descubra o que a inicialização exige.** Bootstrap que lê configuração de banco,
cofre de segredos, serviço de descoberta ou fila **falha antes de chegar às rotas** — e variável
de ambiente fictícia não resolve, porque a dependência é uma conexão, não um valor. Leia o
bootstrap e decida:

- Dá para subir a dependência local (container, script de criação de banco do próprio repo)?
  Suba — é o smoke test de verdade.
- Não dá? **Declare a pendência explicitamente** no relatório: o que faltou, por quê, e o que o
  usuário precisa para fechar. Não invente que testou.

Quando subir, bata numa rota que **não exija autenticação** — e confirme que ela é anônima em
**todas** as camadas. Um endpoint marcado como anônimo no framework ainda pode ser barrado por
middleware próprio do repositório, que decide por atributo ou convenção. Se a autenticação
impedir o teste e a configuração estiver vazia, isso é esperado, não é defeito da limpeza: diga
isso com essas palavras.

## Passo 7 — Fechar

- Se o usuário optou por descartar o histórico: apague o `.git` e `git init -b <branch-default>`.
  **Pare aqui.** Nada de `git add`, nada de commit.
- Acrescente ao `.gitignore` o que não deve ir para o repositório novo: arquivos de usuário da
  IDE, configuração de desenvolvimento local, arquivos de segredo local (`local.settings.json`,
  `.env`, `appsettings.Development.json`), settings locais de agente. Se o inventário apontou
  algum desses **já versionado**, é a hora de corrigir.
- **Reescreva os arquivos de instrução de agente** (`CLAUDE.md`, `AGENTS.md`, equivalentes) e o
  `README.md` para o projeto novo: stack, estrutura, como rodar, o que precisa ser preenchido.
  Eles descrevem o domínio antigo inteiro; renomear o token não os torna verdadeiros.
- Apague documentação de produto, backlog e registros de sessão do projeto antigo, e settings
  locais de agente (`.claude/settings.local.json` e afins).
- **Substitua os assets de marca** — logo, favicon, ícones, splash, imagens de compartilhamento.
  São binários: o rename não os toca, e eles continuam mostrando a marca antiga.

### Relatório final

Entregue nesta forma — é o que o usuário precisa para decidir os próximos passos:

- **Resultado**: build, testes, varredura de resíduos e smoke test, com os números.
- **Desvios do plano**: se mudou de ideia durante a execução, diga o quê e por quê. Nunca deixe
  um desvio implícito.
- **Segredos e identidades**: o que foi regenerado e o que ainda depende do usuário.
- **Integrações a reconfigurar fora do repositório**: DNS, provedor OAuth, webhook no provedor de
  pagamento, domínio de e-mail, CORS, secrets do CI, chaves no cofre. O rename trocou o texto; o
  outro lado não existe ainda.
- **Pendências do usuário**: validação de nomes de recurso, credenciais, renomear a pasta local,
  e o lembrete de que **nenhum commit foi feito**.

## Armadilhas recorrentes

Estas custam tempo toda vez que aparecem. Vale conferir mesmo quando parecem improváveis.

- **Valor default com a marca antiga dentro do código.** `?? "MeuSistema"`, um `baseUrl` default
  apontando para o domínio antigo. O rename gera um default que aponta para um recurso que não
  existe. Procure por defaults, não só por chaves.
- **Duplicata de dependência**: ao remover a duplicata você fixa uma versão, e uma dependência
  transitiva pode exigir versão maior (em .NET, `NU1605` — downgrade tratado como erro). Ao
  deduplicar, resolva também o piso das transitivas.
- **Biblioteca que mudou de licença.** Pacote de asserção, de mock ou de UI que passou a exigir
  licença comercial numa major nova. Ao mexer em versão, confira a licença e diga ao usuário o
  que escolheu e por quê. (Caso conhecido: FluentAssertions ≥ 8 exige licença comercial; a série
  6.x é Apache 2.0.)
- **Porta de debug local herdada** colide com o projeto original rodando na mesma máquina. Troque
  nos arquivos de perfil de execução.
- **Limite de tamanho e alfabeto em nome de recurso de nuvem.** Vários estouram em silêncio no
  build e só falham no deploy (em Azure, Storage Account tem 24 caracteres e aceita só minúsculas
  e dígitos). Confira os limites do provedor antes de propor o nome; se estourar, proponha uma
  abreviação e deixe isso explícito — é decisão do usuário.
- **Chave de configuração com a sigla** (`BaseAddressApiXX`, nome de cookie, escopo OIDC, nome de
  fila, prefixo de métrica) é identificador tanto quanto namespace.
- **Expressão de agendamento herdada.** Um job que roda 03:00 porque o processo antigo precisava
  disso é ruído no sistema novo. Confirme a janela.
- **A pasta local continua com o nome antigo.** Renomeá-la exige encerrar a sessão; deixe como
  passo manual e avise.
