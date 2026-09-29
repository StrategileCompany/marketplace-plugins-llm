# Azure Functions (.NET)

## Primeiro: confirme o modelo de hospedagem

O inventário já classifica, mas confirme — isso muda o que é infraestrutura e pode inviabilizar a
derivação:

- **Isolated worker** (`Microsoft.Azure.Functions.Worker`, `OutputType` = `Exe`): existe um
  `Program.cs` com `HostBuilder`/`FunctionsApplication` e DI própria. É o coração da
  infraestrutura, equivalente ao `Program.cs` de um Web App.
- **In-process** (`Microsoft.NET.Sdk.Functions`, sem `Program.cs`): a DI vem de uma classe
  `Startup` com `[assembly: FunctionsStartup(...)]`.

**In-process sai de suporte em 10 de novembro de 2026.** Encontrando in-process, **pare e avise
antes de derivar**: um projeto novo nascer num modelo sem suporte é um débito que já vem vencido,
e a migração para isolated mexe exatamente nos arquivos que esta skill vai reescrever (bootstrap,
DI, assinatura de cada function, tipos de request/response). Ofereça as opções ao usuário:

1. Migrar o repositório base para isolated **antes** de derivar (recomendado).
2. Derivar em isolated direto, tratando a migração como parte do trabalho — maior, mas evita fazer
   duas vezes.
3. Derivar em in-process ciente do prazo, se houver razão de curto prazo.

`host.json` e `local.settings.json` existem nos dois. `local.settings.json` **não deve ir para o
repositório** (contém segredo) — se estiver versionado, é oportunidade de corrigir.

## O que é estrutural (fica)

- `Program.cs` / `Startup.cs`: DI, `HttpClient` nomeados, autenticação de saída, fontes de
  configuração, serialização, telemetria.
- Middlewares de worker (isolated), filtros, tratamento de exceção, correlação, acesso ao contexto.
- Controller/classe base das functions, extensões de `HttpRequestData`, envelope de resposta.
- Clientes HTTP genéricos, provedores de token, extensões utilitárias.
- Helpers de teste (fakes de handler, fixtures).

### `host.json` não é "fica e pronto"

Logging, sampling e `extensions` são escolhas de plataforma e ficam. Mas duas coisas dependem do
plano de hospedagem do projeto **novo**:

- **`functionTimeout`**: um valor sem limite (`-1`) só é válido em Premium, Dedicated ou Flex. No
  plano Consumption a aplicação falha. Herdar isso de um projeto que rodava em Premium é uma
  quebra que não aparece até o deploy.
- **`retry`** e limites de concorrência dos bindings foram calibrados para o volume do processo
  antigo.

Confirme o plano de hospedagem do projeto novo antes de manter esses valores.

## O que sai (domínio)

Cada classe de function cujo gatilho serve um processo do negócio antigo — HTTP de endpoint de
negócio, timer de rotina do domínio, fila/tópico de evento do domínio — mais os DTOs, validadores
e serviços que elas usam, e os testes correspondentes.

**Não esqueça o registro de DI.** Bootstrap que agrupa registros por módulo
(`services.UseXContext()`, `AddFooModule()`) precisa perder a linha de cada módulo excluído. É o
que mais quebra build nesta stack.

## Ponto de entrada mínimo

Se **todas** as functions saírem, o projeto fica sem ponto de entrada. Isso compila, mas o
`func start` sobe sem rota nenhuma e parece quebrado. Crie uma function de saúde:
`HttpTrigger` anônimo em `GET /api/health` retornando 200. Serve de esqueleto e de smoke test.

**Anônimo tem que valer em todas as camadas.** `AuthorizationLevel.Anonymous` só desliga a chave
de função do runtime. Se o repositório tem middleware próprio de autenticação — e projetos com
`Program.cs` customizado quase sempre têm — é ele que decide, tipicamente por atributo na function
ou por convenção de nome. Leia o registro dos middlewares e o predicado que cada um usa, e garanta
que a rota de saúde não cai na condição que exige token. O sintoma é 401 numa rota que o código
"diz" ser anônima.

Se já existe uma rota de saúde ou de versão, reaproveite-a em vez de criar outra — mas confirme
que ela é anônima pelo mesmo raciocínio.

## Nomes que são identificadores e passam despercebidos

- **Nome da function** no atributo (`[Function("Nome")]` / `[FunctionName(...)]`) — define a rota e
  aparece no portal.
- **`Route =`** no `HttpTrigger`.
- **Nome de fila, tópico, subscription, container e tabela** nos atributos de binding, inclusive na
  forma `%AppSetting%`.
- **Chave de app setting** referenciada por `%NOME%` nos bindings e lida na configuração.
- **String de conexão e nome de recurso** em `local.settings.json`.
- **Expressão CRON** de timer: geralmente fica, mas confirme que a janela faz sentido para o
  processo novo.

Essas chaves precisam existir no cofre ou na configuração do ambiente antes do deploy. Liste-as
nos pontos de atenção — você está derivando por convenção, não verificando.

## Configuração que vem de fora do repositório

Muitos projetos adicionam uma fonte de configuração externa no bootstrap: cofre de segredos,
serviço de configuração de aplicação, ou **uma tabela do próprio banco**. Duas consequências:

1. **A precedência importa.** A fonte adicionada por último vence. Se a configuração vem de tabela
   adicionada depois do ambiente, definir a chave como app setting **não** tem efeito enquanto a
   tabela tiver outro valor — e o sintoma (valor antigo em uso) parece bug de código.
2. **A aplicação não sobe sem a fonte.** Ver o smoke test abaixo.

Para tratar as chaves, veja `segredos-e-identidades.md`; para as que moram em tabela, veja também
`banco-de-dados.md`.

## Verificação

Além de build e testes:

```bash
func start --port <porta>
```

O `func` lista as functions carregadas na saída — lista vazia depois da limpeza é o sinal de que
faltou o ponto de entrada mínimo. Depois, bata na rota de saúde:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:<porta>/api/health
```

**Se o bootstrap depende de fonte externa de configuração, o `func start` morre antes de servir
qualquer rota** — e variável de ambiente fictícia não resolve, porque o que falta é uma conexão.
Dá para subir a dependência local (container do banco, script de criação do próprio repositório)?
Suba, e o smoke test vale. Não dá? Declare a pendência: qual dependência faltou, por quê, e o que
o usuário precisa rodar. Não declare smoke test feito.

Se o Core Tools não estiver instalado, não invente: diga que o smoke test ficou pendente e por quê.

## IaC

Function App geralmente traz conta de armazenamento, plano de execução e recurso de
observabilidade, todos com o nome do sistema antigo. Veja `ci-cd-e-iac.md`, incluindo a seção de
limites de nome — em Azure, a conta de armazenamento é a mais apertada (24 caracteres, só
minúsculas e dígitos).
