# Banco de dados

O banco é uma camada com o mesmo problema do código — parte é infraestrutura, parte é domínio —
mas com duas diferenças que mudam o tratamento: **o esquema não quebra o build** (um objeto do
domínio antigo sobrevive calado por meses) e **o histórico de migration é acumulativo** (o
projeto novo não precisa reviver a evolução do antigo).

Se o inventário não achou artefato de banco, pule este guia. Confirme antes que o esquema não vem
de outro repositório ou de criação por ORM em tempo de execução.

## Passo 1 — Descubra como o esquema nasce

Isso define tudo o que vem depois:

- **Scripts SQL versionados** (criação + pasta de migrations por data ou número): você controla o
  conteúdo diretamente.
- **Migrations de ORM ou ferramenta** (EF Core, Alembic, Prisma, Flyway, Liquibase, Knex): há um
  estado consolidado (snapshot, tabela de controle) que precisa ser coerente com os arquivos.
- **Criação automática pelo ORM** a partir do modelo: o esquema segue as classes, então
  classificar o código já classifica o banco. Só cuide dos dados de seed.

## Passo 2 — Classifique os objetos

Mesmo critério do código — **teste da segunda aplicação** — aplicado a tabela, view, procedure e
função:

**Fica** (infraestrutura): tabela de configuração da aplicação, usuário/conta, tenant ou
organização, papel e permissão, convite, redefinição de senha, sessão ou refresh token,
auditoria/log, fila de notificação, assinatura e plano (se o produto novo também cobra),
preferência do usuário, controle de migration.

**Sai** (domínio): as tabelas das entidades do negócio antigo e tudo que depende só delas —
índices, views, procedures, triggers, constraints e tabelas de ligação.

**Fronteira**: tabela genérica na forma mas alimentada por domínio (catálogo, parâmetro,
categoria), e as capacidades de plataforma da lista do `SKILL.md` — cobrança, notificação,
exportação. Pergunte.

**A ordem de remoção segue a dependência**, não o alfabeto: chave estrangeira apontando para
tabela removida impede a criação. Se o script de criação é um arquivo único e longo, remover blocos
no meio quebra a ordem — confira que o resultado roda do zero num banco vazio, que é o único teste
que vale aqui.

## Passo 3 — Decida sobre o histórico de migrations

Pergunte ao usuário; o default recomendado é o primeiro:

1. **Baseline novo** (recomendado): um único script de criação com o esquema final já limpo, e a
   pasta de migrations zerada. O projeto novo nasce sem a arqueologia do antigo, e a próxima
   migration é a primeira. Em ferramenta com estado consolidado, isso significa apagar as
   migrations e gerar a inicial de novo — não editar as antigas à mão.
2. **Preservar o histórico**: mantém rastreabilidade, ao custo de carregar migrations que criam e
   alteram tabelas que não existem mais. Se escolherem isso, **não edite migrations já aplicadas**;
   acrescente uma nova que remove o que saiu.

Escolhido o baseline, confira o que fica pendurado: script de seed que insere em tabela removida,
migration que referencia objeto que não existe mais, e a tabela de controle de migration, que
precisa ser coerente com os arquivos.

## Passo 4 — Trate os dados semeados

Seed é onde valor de produção se esconde. Separe:

- **Seed estrutural** (papéis, status, unidades, catálogo de preferências): fica, já limpo do que
  era domínio.
- **Seed de demonstração** com dados fictícios do negócio antigo: sai.
- **Seed de configuração**: as chaves ficam, **os valores não** — quando a configuração mora em
  tabela, o script de seed contém segredo e identidade em claro. Trate por
  `segredos-e-identidades.md`: gere valor novo ou deixe o campo vazio com a pendência anotada.
  Chave de identidade semeada em script é o caso mais comum de identidade herdada sem ninguém
  perceber.
- **Usuário de teste com senha** (mesmo em hash): sai, ou nasce com credencial nova. Um usuário
  conhecido com senha conhecida no banco novo é porta aberta.

## Passo 5 — Nomes que são identificadores

Entram no rename como qualquer outro:

- **Nome do banco** e o nome no endereço do servidor.
- **Schema** próprio da aplicação, se houver.
- **Login/usuário da aplicação** no banco (a senha, por outro lado, é nova).
- **Prefixo de tabela**, quando o projeto usa um.
- **Nome de recurso** do servidor de banco no IaC — sujeito aos limites do provedor.

O que **não** muda: nome de tabela e coluna de infraestrutura. Renomear `Usuario` para
`NovoSistemaUsuario` só cria trabalho.

## Verificação

O banco tem um teste próprio, e build verde não o substitui:

1. Rodar a criação **num banco vazio**, do zero, sem erro.
2. Aplicar os seeds que ficaram, sem erro.
3. Subir a aplicação apontada para esse banco. Este é o passo que prova que o esquema e o código
   continuam de acordo — e é também o que viabiliza o smoke test quando o bootstrap lê
   configuração do banco (ver `SKILL.md`, Passo 6).

Não sendo possível criar o banco no ambiente, **declare a pendência** em vez de assumir: diga que
a criação não foi exercitada e o que o usuário precisa rodar.
