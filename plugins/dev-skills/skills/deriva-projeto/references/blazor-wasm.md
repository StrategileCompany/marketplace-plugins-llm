# Blazor WebAssembly

Vale tudo do `blazor-server.md` sobre classificação, `_Imports.razor`, rota `/`, CSS isolado e poda
de CSS. O que muda são a topologia, a configuração e o fato de o front ser **público**.

## Topologia

Identifique qual antes de classificar:

- **Standalone**: um projeto `Microsoft.NET.Sdk.BlazorWebAssembly`, publicado como site estático ou
  atrás de um backend separado.
- **Hosted**: `Client` (WASM) + `Server` (ASP.NET Core que hospeda e serve a API) + `Shared`
  (contratos usados pelos dois). O `Shared` é onde mais se confunde infraestrutura com domínio —
  trate-o com o mesmo critério de uma camada de domínio.
- **Client + API separada** (Functions ou Web API): leia também o guia da API.

O `Server` de uma solution *hosted* é um projeto Web comum: classifique por `blazor-server.md`.

## O que é estrutural no Client

- `Program.cs`: `WebAssemblyHostBuilder`, `HttpClient` com `BaseAddress`, autenticação
  (`AddMsalAuthentication` / `AddOidcAuthentication` / `AddApiAuthorization` / esquema próprio),
  `DelegatingHandler` de token.
- `wwwroot/index.html`: a host page — `<base href="/">`, links de CSS, `blazor.webassembly.js`,
  `<div id="app">`, tela de carregamento.
- `App.razor`, `_Imports.razor`, layouts, `RedirectToLogin`, a página que trata o retorno da
  autenticação.
- `wwwroot/appsettings.json`: **atenção** — no WASM a configuração é servida como arquivo estático
  e vai inteira para o navegador. Nunca coloque segredo aqui, e **confira se o repositório antigo
  deixou algum**; se deixou, é um segredo que já está público e precisa ser rotacionado no projeto
  antigo também — avise o usuário.

## Armadilhas específicas

**`<base href>` no `index.html`.** Se a aplicação nova for publicada num caminho diferente
(subpasta em vez de raiz), isso muda — e o pipeline pode reescrever esse valor no deploy. Confira
antes de assumir que fica igual.

**O nome do assembly aparece no runtime.** Além do `<NomeDoAssembly>.styles.css`, o WASM carrega os
assemblies pelo nome no manifesto gerado no build, e o `.csproj` pode ter carregamento tardio
(`BlazorWebAssemblyLazyLoad`) listando DLLs por nome. Renomeando o projeto, essas entradas
precisam acompanhar.

**Service worker e PWA.** Existindo `service-worker.js` e manifesto (`manifest.json` ou
`manifest.webmanifest`), eles carregam nome, descrição, cor e ícones do app antigo — e o service
worker versiona o cache. Atualize nome e descrição, **substitua os ícones** (são binários; o rename
não os toca) e mantenha a configuração de `ServiceWorkerAssetsManifest` no `.csproj`.

**Autenticação é diferente do Server.** Não há cookie nem `HttpContext`: o token vive no cliente e
é anexado por um `DelegatingHandler`. Os arquivos são outros, mas a classificação é a mesma — tudo
isso é infraestrutura e fica.

**Chave pública embutida no front.** Client id de OAuth, chave pública de push e chave pública de
gateway de pagamento ficam no código ou na configuração do WASM e **precisam bater exatamente com
o valor do lado servidor**. Divergência produz falha genérica ("token inválido") que não aponta a
causa. Regenerando esses pares (ver `segredos-e-identidades.md`), troque os dois lados na mesma
passada.

**URLs de API são absolutas** no WASM — o navegador chama direto. Procure chaves com a sigla antiga
na configuração e nos escopos solicitados, e não esqueça que cada ambiente tem a sua cópia.

**CORS é do outro lado.** O domínio novo do front precisa entrar na lista de origens permitidas da
API e nas origens autorizadas do provedor de identidade. Isso é configuração fora deste
repositório: vai para os pontos de atenção.

## Verificação

`dotnet build` cobre a compilação, mas o WASM só falha de verdade no navegador. Suba e confira que
a host page e o manifesto de boot respondem 200:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:<porta>/
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:<porta>/_framework/blazor.boot.json
```

Havendo ferramenta de navegador disponível, abrir a raiz e checar o console é melhor ainda — erro de
assembly faltando só aparece lá.
