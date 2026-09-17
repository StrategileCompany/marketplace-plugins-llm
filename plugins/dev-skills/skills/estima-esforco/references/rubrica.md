# Rubrica de estimativa (T-shirt ↔ Fibonacci)

## Escala
| T-shirt | Fib | Quando |
|---|---|---|
| **PP** | 1 | Trivial, isolado, **reuso total**, zero incerteza. |
| **P** | 2 | Mudança localizada num ponto; pouco teste. |
| **M** | 3 | Vários pontos **ou** 1 decisão de design **ou** migração simples. |
| **G** | 5 | Várias camadas (UI+API+DB), integração conhecida, teste relevante. |
| **GG** | 8 | Capacidade nova multi-camada; incerteza real ou integração externa. |
| **XG** | 13 | Grande, várias frentes, incerteza alta — provavelmente já quebrar. |
| **XXG** | 21 | Épico → **recomende quebrar** em issues menores antes de agendar. |

## Drivers (o "porquê" do número)
Avalie cada um; o de maior peso puxa o tamanho:
- **Escopo/abrangência** — 1 lugar × vários × transversal.
- **Reuso** — já existe pronto? (a maior alavanca **pra baixo**).
- **Complexidade/novidade técnica** — padrão conhecido × algo novo.
- **Incerteza / unknowns** — sei como fazer? quantas perguntas em aberto?
- **Superfície de integração** — só UI × API × migração de banco × serviço externo.
- **Testes** — trivial × suíte relevante.
- **Risco** — reversível × destrutivo/dados/segurança.

## Confiança
- **Alta** — reuso claro, escopo fechado, sem unknowns.
- **Média** — 1–2 incertezas que podem mexer no número.
- **Baixa** — muitos unknowns; considere dar uma **faixa** (ex.: "M–G") e sinalizar que precisa de
  spike/investigação antes de cravar.

## Âncoras vivas (calibre pela própria base)
Prefira comparar com issues **já estimadas neste repositório** — é o que mantém consistência entre
rodadas. Monte as âncoras conforme for estimando ("é um M como a #NN, porque…"); o padrão do que
ancora cada tamanho:
- **PP (1)** — reuso total: a capacidade já existia ponta a ponta, só faltava ligar o gatilho.
- **M (3)** — vários call sites + uma decisão de design + uma incerteza de borda.

Revisite depois de entregar: *o M levou mesmo um M?* Ajuste as âncoras. (No futuro, dá pra
calibrar contra o custo real de agente/tokens que a implementação consumiu.)

## XXG = quebrar, não agendar
21 (XXG) é sinal de épico. Em vez de estimar e mandar pra fila, **recomende quebrar** em issues
menores (e ofereça fazê-lo via `analista-de-requisitos`). Uma issue que não cabe num tamanho
estimável com confiança é uma issue mal fatiada.
