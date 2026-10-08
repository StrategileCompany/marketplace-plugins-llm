# gh: achar a issue, checar a seção, comentário e degradação graciosa (modo issue viva)

Estas gravações valem para o **modo issue viva**. No modo JSON (pipeline de requisito), nada é
gravado no GitHub — a `registra-issue` publica o plano como comentário na criação da issue.

Todos os comandos são **após a confirmação** do usuário (ver SKILL.md).

## 1) Achar a issue e ler o corpo atual
```bash
gh issue view <n> --json number,title,body
```
Repositório e autenticação: o `gh` infere pelo remote do diretório atual (não use `--repo`). Sem
remote GitHub ou `gh` não autenticado, **avise e pare** (mesmo tratamento das demais skills).

## 2) A seção já existe? (idempotência)
Procure `## Plano de implementação` no `body`. Existindo, é um **replanejamento** — **não** toque
no corpo; só o comentário se repete (ver SKILL.md, "Replanejamento"). Não existindo, acrescente a
seção **uma vez**, no mesmo ponto do template canônico (depois de "## Critérios de aceitação"),
com o texto fixo:
```
## Plano de implementação
Já existe um plano de implementação para esta issue — resgate-o no comentário desta issue.
```
Grave o corpo por arquivo (evita escaping):
```bash
gh issue view <n> --json body --jq .body > plano-corpo-atual.md   # scratchpad da sessão
# acrescente a seção com Edit/Write
gh issue edit <n> --body-file "<caminho>/plano-corpo-atual.md"
```
Se o corpo da issue **não** seguir o template canônico (issue criada fora do pipeline, sem as
seções padrão), acrescente a seção ao final do corpo mesmo assim — o importante é o ponteiro
existir uma vez.

## 3) Publicar o plano como comentário (sempre)
```bash
gh issue comment <n> --body-file "<caminho>/plano-implementacao.md"
```
Sempre por `--body-file`, nunca `--body "..."` inline (acentos/markdown quebram no PowerShell).
Publique **mesmo em replanejamento** — é o log histórico; comentários antigos não são editados
nem apagados.

## Degradação graciosa
- **Issue não encontrada / sem acesso** → `gh issue view` falha. Avise e pare; não adivinhe número.
- **Sem remote GitHub** ou **`gh` não autenticado** → avise (`gh auth login`) e pare.
- **Corpo fora do template canônico** → acrescente a seção ao final mesmo assim (não recrie o
  requisito; só garanta o ponteiro).
- Esta skill **não** toca o board (Projects v2) — planejar não muda Status/Estimate/Priority.
