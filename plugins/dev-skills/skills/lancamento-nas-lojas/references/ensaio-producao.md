# Ensaio com o maior tenant real (portão antes do envio)

> Por que esta etapa existe: um app B2B multi-tenant foi **aprovado nas duas lojas e foi ao ar
> quebrado**. A cicatriz está abaixo. O ensaio que teria evitado custa minutos.

## A cicatriz

O app entrou nas duas lojas pela manhã. Horas depois, o **painel — a primeira tela, logo após o
login** — devolvia **erro 500 ao estourar o timeout** para **todos os clientes com volume real**.
Funcionava só nos tenants pequenos. **Ninguém foi avisado: a descoberta veio de alguém abrindo o
app no celular**, não de um alarme.

**Causa: parameter sniffing.** O banco guarda **um plano de execução por texto de query**,
compilado com o **primeiro** valor de parâmetro que aparecer. Quando os tenants são
desproporcionais — um grupo de demonstração com **dezenas** de registros contra um cliente real com
**centenas de milhares**, e milhões de linhas de detalhe —, um plano compilado para o pequeno
inviabiliza os grandes: a query não termina e estoura o timeout.

**O agravante que muda o processo:** o suspeito de ter envenenado o plano é a **conta demo do
revisor** — a conta que esta própria skill manda criar e que os revisores das lojas martelam
durante a análise. Ou seja: **o ato de ser revisado ajudou a quebrar a produção.**

- **Cura imediata:** forçar a recompilação do plano daquele objeto — em SQL Server,
  `EXEC sp_recompile 'dbo.<Tabela>'`. O tempo de resposta caiu de timeout para poucos segundos na
  hora.
- **Fix definitivo:** `Option (Recompile)` na query agregada por tenant. O custo de compilar é de
  milissegundos; medido depois, o maior cliente respondia em poucos segundos e o grupo demo em
  milissegundos — cada tenant com o seu plano ótimo.

> O mecanismo é de SQL Server, mas a classe do bug existe em **qualquer engine que cacheie plano
> por texto de query**. Se o seu banco cacheia, você tem esse risco.

## O roteiro (antes de enviar às lojas)

1. **Liste os endpoints da primeira tela** — a que abre depois do login. É a que o cliente vê, e a
   que derruba a percepção do produto inteiro.
2. **Exercite cada um contra o MAIOR tenant/conta de PRODUÇÃO**, medindo o tempo de resposta.
   Não o demo, não um tenant médio.
3. **Portão:** qualquer chamada **> 5s** ou **com erro** → **não envie**. Não há OTA: o que sair
   quebrado só se conserta com build novo + nova revisão.
4. Se o app tem tela pesada além da primeira (relatório, listagem grande), repita nela.

## Armadilhas ao interpretar o resultado

- **"Passou em staging" não cobre performance.** Staging montado por **script** (schema + carga)
  nasce com **estatísticas e planos frescos** → **nunca** reproduz bug de plano em cache. Já medido:
  mesma query, mesmos dados, **segundos em homologação contra timeout em produção**. Staging valida
  funcionalidade, não escala.
- **"Rápido no cliente de SQL, lento pelo app" = plano diferente**, não "problema do app". Texto de
  query e SET options diferentes são **entradas de cache diferentes**.
- **Reformatar o SQL para testar mascara o bug** — o texto novo compila um plano bom e o teste
  "passa". Não conclua nada a partir disso.

## Alarme ANTES de lançar (não monitoramento depois)

Crash reporting (Play Vitals, Sentry) **não teria pego** este incidente: o app **não crashou** — a
API devolvia 500 e o app mostrava o erro genérico. Antes do envio, exija:

- **alerta de taxa de 5xx** e **de latência (p95)** na API, com notificação que chega em alguém;
- se a infra é IaC (Terraform no pipeline de produção, por exemplo), configure por lá, não no clique.

Sem alarme, o canal de detecção é um humano abrindo o app — foi exatamente o que aconteceu.
