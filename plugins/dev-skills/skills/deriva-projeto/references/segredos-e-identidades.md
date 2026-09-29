# Segredos e identidades — regenerar, nunca renomear

Este é o guia mais importante da skill, porque é o único cujo erro **não aparece no build**.

Um rename bem-feito deixa o projeto novo com as mesmas chaves do antigo. Onde a chave é só um
nome (`BaseAddressApi`), isso é o que se quer. Onde a chave é uma **identidade** — algo que prova
quem o sistema é, ou autoriza alguém a agir em nome dele — herdar é um defeito de segurança que
fica dormente até produção.

## O que herdar uma identidade causa

Dois sistemas com a **mesma chave de assinatura de token** aceitam o token um do outro: quem faz
login no sistema antigo entra no novo, com os papéis que o token disser. Nenhum teste pega isso.

Dois sistemas com o **mesmo client OAuth** aparecem como o mesmo aplicativo para o provedor de
identidade, e um consentimento vale para os dois.

Duas instalações com o **mesmo par de chaves de push** disputam a mesma identidade de remetente
junto ao serviço de push; revogar por causa de um derruba o outro.

O **mesmo segredo de webhook** significa que o provedor externo não distingue os dois destinos, e
uma notificação do sistema antigo é aceita como legítima pelo novo.

A **mesma credencial de deploy** dá ao repositório novo acesso à infraestrutura do antigo.

## Como classificar cada chave

O inventário lista os candidatos. Para cada um, a pergunta é: **este valor prova identidade,
autoriza acesso, ou é apenas um endereço?**

| Categoria | Como tratar | Exemplos |
|---|---|---|
| **Identidade do sistema** | **Gerar novo.** Nunca copiar. | chave de assinatura/validação de token, GUID ou id de aplicação, par de chaves de push, chave de criptografia de dados, salt/pepper de senha |
| **Credencial de terceiro** | **Criar nova no provedor.** É ação do usuário. | client id/secret de OAuth, chave de API de gateway de pagamento, chave de serviço de e-mail/SMS, chave de provedor de IA, string de conexão de banco e de fila, credencial de deploy, token de registry |
| **Segredo compartilhado com terceiro** | **Gerar novo nos dois lados.** | usuário/senha de webhook, segredo de assinatura de webhook, chave de callback |
| **Endereço ou identificador público** | **Renomear** pela convenção. | URL base, nome de recurso, nome de fila, nome de cookie, escopo, nome de aplicação em telemetria |
| **Parâmetro de comportamento** | **Revisar** se o valor faz sentido no sistema novo. | dias de carência, limites, tamanhos de página, janelas de retentativa |

Quando ficar em dúvida entre "identidade" e "endereço", trate como identidade. O custo de gerar
um valor novo é zero; o de compartilhar identidade é um incidente.

## Onde a chave pode estar guardada — procure em todas

Uma mesma chave costuma aparecer em mais de um lugar, e esquecer um deles é o padrão. O inventário
varre estes; confirme:

- **Arquivo de configuração** versionado e não versionado (`appsettings*.json`, `.env`,
  `local.settings.json`, `application.yml`).
- **Variável de ambiente** declarada no CI, no manifesto de container ou no IaC.
- **Cofre de segredos** do provedor, referenciado por nome no código ou no IaC.
- **Segredos do CI** (`secrets.*` nos workflows) — o repositório novo nasce sem nenhum deles
  cadastrado; liste-os como pendência.
- **Banco de dados.** Quando a configuração é lida de tabela, os valores foram semeados por
  script — e o script está versionado, com o valor dentro. É a fonte mais fácil de esquecer e a
  mais perigosa, porque um provider de banco adicionado **por último** na cadeia de configuração
  tem precedência: definir a chave no ambiente **não** resolve se a tabela tiver outro valor.
  Procure nos scripts de criação, seed e migration.
- **Código.** Valor default embutido (`?? "chave-de-dev"`), constante de teste, comentário
  explicativo com o valor real.

## Como agir

**Você gera o que sabe gerar.** Chave simétrica, GUID, salt, par de chaves para push — o próprio
repositório costuma ter um script para isso (o inventário mostra os scripts); use-o. Não havendo,
gere com a ferramenta padrão da plataforma.

**Você não digita nem pede segredo em chat.** Para credencial de terceiro, a ação é do usuário no
provedor. Sua parte é dizer exatamente o que criar, onde, e qual chave preencher depois.

**Segredo não entra no repositório.** Valor gerado vai para configuração local não versionada, ou
para o cofre. Se o inventário apontou arquivo de segredo já versionado, corrija: tire do controle
de versão e ponha no `.gitignore` — é a oportunidade de consertar uma dívida do projeto antigo.

**Deixe o valor antigo fora do relatório.** Você viu nomes de chave; não repita valores, nem os
que estavam em claro no repositório antigo.

## Integrações a reconfigurar fora do repositório

Estas não são chaves, mas falham pelo mesmo motivo: o rename troca o texto e o outro lado não
existe. Liste todas nos pontos de atenção, com o que precisa ser feito em cada provedor:

- **DNS e certificado** para cada domínio novo que o rename criou.
- **Origens e URIs de redirecionamento autorizados** no provedor de identidade.
- **URL de webhook** cadastrada no provedor de pagamento, mensageria ou repositório.
- **Domínio verificado** no serviço de e-mail, e os registros de autenticação de e-mail.
- **CORS** e lista de origens permitidas na API.
- **Chave pública do cliente** que está embutida no front e precisa bater com a do servidor.
- **Consultas, painéis e alarmes de observabilidade** que filtram por nome de recurso.

O padrão de teste que cobre isso: subir o front novo e fazer um login real. É o primeiro fluxo que
atravessa identidade, domínio e CORS ao mesmo tempo.
