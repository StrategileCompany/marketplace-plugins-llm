# Sincronizar a branch com a base remota (antes de codar)

Objetivo: garantir que o ponto onde você vai escrever código **contém os últimos commits da base
remota** (`origin/main` ou `origin/master`). O método é **rebase** — histórico linear, sem commit
de merge ruidoso no meio da implementação.

## 1. Descobrir a base remota (nunca hardcode `main`)
```bash
git fetch origin --prune
BASE=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
# se vazio, o HEAD remoto não está cacheado localmente — resolva e tente de novo:
[ -z "$BASE" ] && git remote set-head origin --auto >/dev/null 2>&1 && \
  BASE=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
# último recurso: pergunte ao remoto
[ -z "$BASE" ] && BASE=$(git remote show origin | sed -n '/HEAD branch/s/.*: //p')
CUR=$(git rev-parse --abbrev-ref HEAD)
echo "base=$BASE  atual=$CUR"
```

Já está em dia? (0 = a base remota não tem nada que você não tenha)
```bash
git rev-list --count "HEAD..origin/$BASE"
```
Se der `0`, **não faça nada** — diga "já está atualizada" e siga.

## 2. Árvore suja → stash automático
```bash
DIRTY=$(git status --porcelain)
[ -n "$DIRTY" ] && git stash push -u -m "sync-antes-de-codar"
```
Avise o usuário que guardou as alterações. Depois do rebase:
```bash
git stash pop
```
Se o `pop` conflitar, **pare e chame o usuário** (o stash continua em `git stash list` — não o
descarte).

## 3. Rebase
```bash
if [ "$CUR" = "$BASE" ]; then
  git pull --rebase origin "$BASE"
else
  git rebase "origin/$BASE"
fi
```

**Branch nova para a issue** (decidida no passo 2 da skill): crie já a partir da base atualizada —
aí o rebase é desnecessário.
```bash
git fetch origin
git switch -c "feat/<N>-<slug>" "origin/$BASE"
```

## 4. Conflito de rebase → pare
Não aborte, não force, não "resolva do jeito que parecer certo" em silêncio. Mostre o estado e
chame o usuário:
```bash
git status --short          # arquivos em conflito (UU/AA)
git diff --name-only --diff-filter=U
```
As saídas possíveis, para o usuário escolher:
- resolver os arquivos juntos → `git add <arquivos>` → `git rebase --continue`
- desistir e voltar ao estado anterior → `git rebase --abort`

## 5. Rebase reescreveu commits já publicados → force-with-lease (com "ok")
Só acontece quando a branch **já tinha commits no remoto**. Detecte a divergência:
```bash
git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1 && \
  echo "à frente: $(git rev-list --count '@{u}..HEAD')  atrás: $(git rev-list --count 'HEAD..@{u}')"
```
Se **ambos** forem > 0, o histórico divergiu: o `git push` normal vai falhar. Peça o "ok" e só
então:
```bash
git push --force-with-lease
```
Nunca `--force` puro (o `--force-with-lease` recusa se alguém tiver empurrado algo depois do seu
último fetch). **Nunca** force-push na própria `main`/`master`.

## 6. Degradação graciosa
- **Sem remote `origin`** (`git remote` vazio) → repo local; avise ("sem origin, nada a
  sincronizar") e siga.
- **`git fetch` falha** (offline, sem credencial) → avise com a mensagem do erro e pergunte se
  segue assim mesmo. Não trave a implementação por rede.
- **Base remota não encontrada** (nem `main` nem `master`) → mostre `git branch -r` e pergunte
  qual é a base.
- **Repositório com submódulos/worktree em rebase pendente** (`git rebase --continue` pendente de
  antes) → não empilhe: mostre o estado e chame o usuário.
