# Conferir os critérios de aceitação e marcar a issue

Roda **depois** do build/testes verdes e **antes** do commit. Duas escritas no GitHub, no máximo:
**um** `gh issue edit` (todos os checkboxes de uma vez) + **um** `gh issue comment` (a conferência
inteira). Nunca uma escrita por critério.

## 1. Ler os critérios (sempre da issue, nunca de memória)
```bash
gh issue view <N> --json body --jq .body > /tmp/issue-<N>.md
```
A seção canônica (escrita pela `analista-de-requisitos`) é:
```
## Critérios de aceitação
- [ ] <condição objetiva e testável>
- [ ] <cobre casos de borda: mobile, ESC, erro, vazio...>
```
Se a issue não seguir esse template, trabalhe com a lista equivalente mais próxima (bullets de
"Aceite"/"Definition of Done"). Sem nenhuma lista de critérios, **diga isso** e conferira contra o
`## Requisito` — sem inventar checkbox que não existe na issue.

## 2. Julgar cada critério — três baldes
| Balde | Quando | Efeito |
|---|---|---|
| **Satisfeito** | Você consegue **apontar a evidência**: `arquivo:linha` do comportamento implementado, teste que cobre (e passou), saída de execução. | Marca `- [x]` |
| **Não verificável** | O critério é real, mas a verificação **está fora do seu alcance agora**: device físico, loja/ambiente de homologação, dado de produção, aprovação de terceiro, comportamento visual que exige olho humano. | Fica `- [ ]` + **motivo** |
| **Não atendido** | Está no escopo, dava para fazer, e **não foi feito** (ou foi feito parcialmente). | Fica `- [ ]` + **barra o commit** |

Regras de julgamento:
- "O código parece fazer isso" **não é evidência** — ou você aponta onde, ou é não verificável.
- Um critério com várias condições (`e`/`ou`) só é satisfeito quando **todas** as partes estão
  cobertas; caso contrário, não atendido, dizendo qual parte falta.
- Na dúvida entre *não verificável* e *não atendido*, escolha **não atendido** (o balde que barra):
  é o erro seguro — o usuário pode liberar; o contrário passa despercebido.

## 3. Escrever na issue — passada única
Releia o corpo **imediatamente antes** de escrever (alguém pode ter editado a issue enquanto você
implementava), altere **apenas** `- [ ]` → `- [x]` nos satisfeitos e não toque em mais nenhum
caractere do corpo:
```bash
gh issue view <N> --json body --jq .body > /tmp/body-<N>.md
# edite /tmp/body-<N>.md: só os checkboxes satisfeitos viram [x]
gh issue edit <N> --body-file /tmp/body-<N>.md
```
Depois, **um** comentário com a conferência completa:
```bash
gh issue comment <N> --body-file /tmp/conferencia-<N>.md
```

Se **nenhum** critério foi satisfeito, pule o `edit` (não há checkbox a mudar) e poste só o
comentário.

## 4. Formato do comentário de conferência
```markdown
### Conferência dos critérios de aceitação

**Verificados e marcados (3/5)**
- Nenhum diálogo fecha ao clicar no backdrop — `src/ui/DialogProvider.tsx:42` (`disableBackdropClick`)
- ESC não descarta o diálogo — `src/ui/DialogProvider.tsx:51` + teste `DialogProvider.test.tsx:88`
- Vale para todos os diálogos do app — provider único, aplicado em `src/App.tsx:17`

**Não verificáveis (2)**
- Comportamento no toque em mobile — **motivo:** exige device físico/emulador; a suíte só roda
  eventos de mouse. Sugestão: validar no próximo build de homologação.
- Não perde o conteúdo digitado após 30 min de sessão — **motivo:** depende do timeout real do
  ambiente de produção.

**Não atendidos (0)**
—

Build e testes: build do projeto ok, 128 testes passaram.
```
Regras do comentário:
- Omita os blocos vazios (ou marque com `—`), mas **sempre** mostre a contagem `x/y`.
- Um critério por linha, começando pelo texto do critério (para casar visualmente com o corpo).
- Evidência é `arquivo:linha` ou nome do teste — não é prosa.
- Motivo de "não verificável" diz **o que impede** e, quando der, **como/quando verificar**.

## 5. Interação com o commit
- **Algum não atendido** → **barra o commit**. Reporte no chat e ofereça: (a) implementar o que
  falta, (b) override explícito ("segue mesmo assim"). **Se for corrigir, não escreva na issue
  agora** — a escrita é a conferência definitiva, feita uma vez só, imediatamente antes do commit
  que vai realmente acontecer.
- **Só não verificáveis** → não barra. Escreva a conferência e siga para o gate de segurança.
- **Override do usuário** → escreva mesmo assim: checkboxes dos satisfeitos marcados, os não
  atendidos desmarcados e listados no comentário como pendências conhecidas.

## 6. Degradação graciosa
- **Sem permissão de escrita na issue** (`gh issue edit` falha) → apresente a conferência completa
  no chat e avise que não deu para gravar.
- **Issue de outro repositório** → use `--repo <owner>/<name>` nos dois comandos.
- **Issue sem seção de critérios** → não crie a seção; relate a conferência contra o requisito no
  comentário.
