# Rubrica de valor — os 4 drivers, a confiança e o peso

Cada driver pontua **1–5**. Combine na fórmula:
```
Prioridade = ( CustomerValue × PESO_CUSTOMER_VALUE  +  BusinessValue  +  RiscoCriticidade  +  EfeitoDestravador )
             × Confiança  ÷  Pontos
```
`PESO_CUSTOMER_VALUE = 1.2` (20% a mais). Constante calibrável — ajuste com o histórico ao longo do
tempo; não é achismo fixo.

---

## 1. Customer Value (o driver dominante) — peso 1.2
O valor que o **usuário percebe que ganha**. Não é o que você acha que entregou; é o que ele
**sente**. Julgue **contra a promessa central do produto** (o core business — veja `gh-projects.md`),
por **três lentes**:

- **Relevância ao core** — quão perto isto está da promessa central do produto?
- **Consequência da ausência** — o que dói/quebra pro usuário se não existir?
- **Ganho percebido** — o que ele sente que ganhou ao ter isto?

Chegue a **um** número 1–5 combinando as três lentes (a relevância ao core é a régua-mãe):

| Nota | Significado |
|------|-------------|
| **5** | É a promessa central. Sem isto o produto não cumpre o que se propõe. O usuário reclamaria alto e contaria pra alguém. |
| **4** | Muito relevante ao core; ausência dói pra maioria; ganho claramente percebido. |
| **3** | Relevante, mas periférico à promessa; parte dos usuários sente falta. |
| **2** | Infra/suporte necessário, pouco percebido (ex.: recuperar senha); um ou outro usuário precisa. |
| **1** | Não toca a promessa; ganho imperceptível pro usuário. |

> **Exemplo (app de gestão financeira):** *registrar compra parcelada* = **5** (é a promessa central).
> *Recuperar senha* = **2** (necessário, mas infra; não é o que o produto promete resolver). Note
> como o mesmo item pode valer notas diferentes em produtos diferentes — daí a âncora do core.

## 2. Business Value (o filtro estratégico) — peso 1
Benefícios tangíveis e intangíveis pra **organização**: receita, retenção, diferenciação, alinhamento
com objetivos estratégicos. É consequência de Customer Value sustentado — importante, mas **não
soberano**.

| Nota | Significado |
|------|-------------|
| **5** | Habilita receita direta ou é diferencial estratégico central (ex.: cobrança/assinatura, marca). |
| **3** | Contribui pra retenção/estratégia de forma relevante. |
| **1** | Impacto de negócio marginal. |

## 3. Risco / Criticidade — peso 1
Valor **negativo evitado**: o custo de *não* fazer por risco. Bug, falha de segurança, dado
financeiro/legal errado, bloqueio de compliance, perda de dados.

| Nota | Significado |
|------|-------------|
| **5** | Segurança/perda de dados/erro financeiro ou legal ativo; risco alto e presente. |
| **3** | Bug incômodo, contornável, sem risco grave. |
| **1** | Sem risco relevante. |

## 4. Efeito destravador — peso 1
Quanto isto **habilita outras entregas** (o "custo de atraso" do WSJF, enxuto). É onde uma feature de
baixo valor direto se salva por ser pré-requisito.

| Nota | Significado |
|------|-------------|
| **5** | Destrava várias issues/épicos; é fundação. |
| **3** | Facilita/prepara algumas entregas futuras. |
| **1** | Isolada; não habilita nada além de si. |

---

## Confiança (multiplicador)
Quão seguro está o julgamento de valor (clareza do requisito, conhecimento do usuário/mercado):

| Nível | Multiplicador |
|-------|---------------|
| Alta  | 1.0 |
| Média | 0.85 |
| Baixa | 0.7 |

## Pontos (denominador)
Os pontos Fibonacci da `estima-esforco` (`PP=1·P=2·M=3·G=5·GG=8·XG=13·XXG=21`). Sem estimativa,
veja Guard-rails no SKILL.md (estimar antes, ou marcar provisório).

## Como interpretar o score
Número em unidade arbitrária — vale só a **ordem**. Score alto = muito valor por ponto = **quick win**
(faça já). Score baixo com esforço alto = **money pit** (adie/quebre). Ancore em issues já
priorizadas ("é mais prioritário que a #X, menos que a #Y") para manter coerência entre rodadas.
