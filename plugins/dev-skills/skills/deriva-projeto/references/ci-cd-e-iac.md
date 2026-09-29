# CI/CD e infraestrutura como código

Pipeline e IaC são a parte mais reaproveitável do repositório: a mecânica de build, teste e deploy
serve a qualquer sistema. O que muda são **os nomes** (do projeto e dos recursos), **os segredos**
e os **valores herdados de catálogo** que ninguém revisa.

Nada aqui presume ferramenta ou provedor. Descubra os dois no inventário e aplique o raciocínio.

## Passo 1 — Descubra de onde vêm os nomes de recurso

Esta é a pergunta que organiza o resto, e há dois arranjos:

**A. O IaC está neste repositório.** Os nomes de recurso estão em arquivos que você edita
diretamente. É o caso de `.tf`/`.tf.json`, Bicep, ARM, Pulumi, CDK, charts.

**B. O IaC é externo e o pipeline o chama por parâmetro.** O repositório só tem o workflow, que
referencia um template de outro repositório e passa entradas (`Project`, ambiente, caminho). Os
nomes de recurso são **derivados dentro do template** a partir dessas entradas. Aqui você troca
**as entradas**, não nomes de recurso — e, importante, **você não vê a convenção**: o nome final
é montado fora do seu alcance.

No arranjo B, diga isso ao usuário com clareza: o rename da entrada `Project` renomeia toda a
infraestrutura na próxima execução do pipeline, e você não tem como verificar antes se algum nome
derivado estoura limite do provedor. Isso vai para os pontos de atenção, não para a lista de
verificações concluídas.

Reconhecer o arranjo B é fácil: o workflow tem uma referência a template de outro repositório e
quase nenhum comando concreto. O inventário lista esses templates externos.

## Passo 2 — O que fica, muda e se revisa no pipeline

**Fica**: a mecânica toda — gatilhos, matriz de ambientes, etapas de build/teste/publicação,
portões de aprovação, referência aos templates, versão de runtime, ordem de dependência entre
jobs.

**Muda**: nome do projeto publicado (aparece mais de uma vez — procure todas), caminhos que
contêm o nome antigo, nomes de recurso ou grupo de recurso, domínio customizado, URLs que uma
parte usa para falar com a outra (front → API), nome do artefato.

**Revise com o usuário** — são valores herdados de catálogo interno que ninguém confere e que
seguem errados por anos: time/squad responsável, centro de custo, departamento, sistema no CMDB,
tags de cobrança, canal de notificação, lista de aprovadores, `CODEOWNERS`.

**Segredos do CI**: todo `secrets.*` referenciado é um segredo que **não existe** no repositório
novo. O pipeline falha no primeiro deploy com erro que não explica isso. Liste todos como
pendência e trate-os por `segredos-e-identidades.md` — credencial de deploy é credencial de
terceiro e precisa ser nova, nunca a mesma do projeto antigo.

**Gatilho por convenção**: pipeline que dispara por padrão de mensagem de commit, nome de branch
ou tag precisa continuar coerente com o que o projeto novo vai usar.

## Passo 3 — IaC no repositório

Quando o IaC está aqui (arranjo A), a mecânica é a mesma em qualquer ferramenta:

- **Renomeie a declaração e a referência juntas.** Trocar o nome de um módulo/recurso e esquecer a
  interpolação que o referencia (`module.x.id`, `resource.y.name`, saída usada por outro módulo) é
  o erro mais comum, e a validação da ferramenta pega — rode-a.
- **Renomeie o que a convenção manda**: nome de cada recurso, grupo/namespace, sub-rede, registro
  de DNS, certificado, conta de armazenamento, plano de execução, recurso de observabilidade.
  Derive pela convenção que os arquivos já demonstram, não por uma que você prefira.
- **Não mexa** no que é compartilhado ou de plataforma: identificador de assinatura/projeto na
  nuvem, região, versões de provider, rede e recursos de rede compartilhados, backend de estado.
- **Estado.** IaC com estado remoto guarda o estado do projeto antigo. O projeto novo precisa de
  **estado próprio** (chave/container/workspace novo), senão o primeiro `apply` propõe destruir a
  infraestrutura do antigo e criar a nova no lugar. Isto é destrutivo e é o pior acidente possível
  aqui: confira a configuração de backend antes de qualquer execução e **nunca** rode `apply`
  nesta skill.
- **Parâmetros por ambiente** existem em várias cópias (dev/hmg/prd). Renomeie em todas; esquecer
  uma só aparece no deploy daquele ambiente.

## Passo 4 — Limites de nome do provedor

Vários serviços têm limite de tamanho e alfabeto restrito, e o nome derivado (prefixo +
token + sufixo + ambiente) estoura em silêncio no build e só falha no deploy. Antes de propor o
nome, **consulte os limites do provedor** para os tipos de recurso que o IaC cria, e some o
tamanho real. Em Azure, o mais apertado costuma ser Storage Account: 24 caracteres, só minúsculas
e dígitos.

Estourando, proponha uma abreviação do token e **deixe isso explícito no relatório** — é decisão
do usuário, e quem cuida da infraestrutura precisa saber que o nome do recurso não é igual ao nome
do projeto.

## Passo 5 — Containers, se houver

`Dockerfile` e composição ficam; o que muda é nome de imagem, nome de serviço, nome de volume e
rede, e o caminho do artefato publicado. Portas expostas localmente podem colidir com o projeto
antigo rodando na mesma máquina.

## Verificação

- Rode a **validação** da ferramenta de IaC (`validate`, `lint`, `what-if`, `plan` sem aplicar).
  Interpolação órfã aparece aqui.
- Valide a **sintaxe do pipeline** com o linter da ferramenta, se houver.
- **Nunca execute deploy nem `apply`.** Esta skill para antes do commit; deploy vem muito depois.
- No relatório, separe o que você **verificou** do que **derivou por convenção**. Nome de recurso
  derivado, entrada de template externo e segredo do CI são derivação — o usuário precisa validar.
