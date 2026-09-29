# Blazor Server, ASP.NET Core Web App e Web API

## O que é estrutural (fica)

| Área | Arquivos típicos |
|---|---|
| Bootstrap | `Program.cs` — DI, esquemas de autenticação, políticas, `HttpClient` nomeados, render mode |
| Host page | `App.razor` ou `Components/Index.razor`, `Routes.razor`, `_Imports.razor` |
| Layout | `MainLayout.razor` (+ `.razor.css`), layouts vazio/erro, página `/Error` |
| Autenticação | controller de conta (login/logout/acesso negado), `RedirectToLogin.razor`, provedores de token, serviço de contexto do usuário |
| HTTP | `DelegatingHandler` que injeta o token, serviço genérico de chamada à API |
| Transversal | middlewares de validação de acesso e sessão, filtros, `CircuitHandler` de logging |
| UI genérica | notificações/toasts, grid genérico, inputs parametrizados, máscaras |
| Estilo | CSS do design system, framework de UI, fontes, favicon |

Numa Web API sem Razor, o equivalente da host page e do layout não existe; o resto é igual, e o
controller base, os filtros e o envelope de resposta são infraestrutura.

## O que sai (domínio)

Páginas e controllers de negócio, componentes de tela (barras de filtro, modais), DTOs e enums do
domínio, mocks de API, JS de uma tela específica, e as seções de CSS presas a páginas específicas.

**Não esqueça o registro de DI**: cada serviço de domínio registrado no bootstrap sai junto.

## Armadilhas específicas desta stack

**A rota `/` some junto com a página inicial.** Em geral a home é uma página de negócio. Confira no
inventário quem responde por `@page "/"`; se ela sair, **crie uma página inicial nova** usando as
classes do design system que sobraram. Sem isso a raiz cai no `NotFound` e parece bug de
roteamento.

**`_Imports.razor` com `@using` órfão quebra TODOS os componentes.** Um `@using` para namespace que
deixou de existir é erro de compilação, e o erro aparece espalhado por vários arquivos, não no
`_Imports`. Depois de excluir, confira cada linha — em especial namespaces que só existiam por
causa de um único componente.

**`_Imports.razor` só vale para a própria pasta e subpastas.** Se ele está em `Components/` e as
páginas ficam em `Pages/` (pasta irmã), as páginas **não herdam** aqueles `@using` — cada uma
declara os seus. Ao criar a página inicial, inclua os `@using` que ela precisa
(`Microsoft.AspNetCore.Components.Web` para `<PageTitle>`, por exemplo) ou mova o `_Imports.razor`
para a raiz do projeto.

**O CSS isolado é referenciado pelo nome do assembly.** A host page traz
`<link href="<NomeDoAssembly>.styles.css">`. Renomeie junto com o projeto, senão todo o CSS isolado
(`*.razor.css`) para de carregar — sem erro nenhum no console.

**`Content Remove` / `Content Include` no `.csproj`** pode apontar para arquivo excluído. Remova
essas linhas.

**Menu do layout.** O layout costuma ter os links do sistema antigo e os métodos de navegação
correspondentes. Esvazie deixando só a entrada de início — preserve a mecânica do menu (abrir,
fechar ao navegar, dropdown de usuário), que é infraestrutura. Troque o título exibido.

**Poda de CSS.** As seções de design system (tokens, tabelas, botões, paginação, modal, topbar,
notificações, shell do layout) ficam; as seções nomeadas por tela do domínio antigo saem. Depois de
recortar, confira o balanceamento de chaves:

```bash
awk '{o+=gsub(/{/,"{"); c+=gsub(/}/,"}")} END{print "abre="o, "fecha="c, "saldo="o-c}' app.css
```

Se o arquivo não terminava com quebra de linha, a última linha "invisível" pode sobrar órfã depois
de um recorte por intervalo.

**Configuração com sigla é identificador**: nome do cookie de autenticação, chave da URL da API,
escopo OIDC, nome da aplicação em telemetria. Ver `segredos-e-identidades.md` para separar o que é
identificador (renomeia) do que é identidade (regenera).

## Smoke test

A política padrão costuma exigir usuário autenticado, então `/` redireciona para o login e falha se
a configuração de identidade estiver vazia — isso é esperado. Para provar que a aplicação sobe e
renderiza, bata numa rota anônima (a página de erro normalmente é) e num arquivo estático do design
system:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:<porta>/Error
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:<porta>/app.css
```

Se o handler de identidade recusar até isso por falta de configuração, suba com variáveis de
ambiente fictícias só para o teste. Um erro de *host não encontrado* na raiz prova que o desafio de
autenticação está sendo disparado — ou seja, o pipeline está correto.

Se o bootstrap lê configuração de fonte externa (cofre, serviço de configuração, banco), a
aplicação pode não subir de jeito nenhum sem ela: ver a seção de smoke test do `SKILL.md`.
