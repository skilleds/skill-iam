---
description: schematize-iam — carrega à força TODO o corpo normativo de IAM e passa a aplicá-lo nesta sessão.
---
Carregue **agora** o corpo normativo da skill `schematize-iam`. A partir daqui, nesta sessão, isto **não é opcional**.

1. **Leia na íntegra, sem trabalhar de memória.** Caminho: `.claude/skills/schematize-iam/references/*.md` (projeto) ou
   `~/.claude/skills/schematize-iam/references/*.md` (global):
   - `topologia.md` — auth como app separada, broker único, chave só no auth, JWKS, allowlist de clientes.
   - `protocolos.md` — authorization code + PKCE, fluxos vetados, tokens, validação, OIDC.
   - `fatores.md` — identidade, argon2id, passkeys, 2FA baseline sem muro, invariante Y != X, step-up.
   - `sessao.md` — 7d/90d, refresh rotativo, logout irreversível, denylist de `jti`, cookies.
   - `authz-rebac.md` — multi-tenant, ReBAC, PDP/PEP, outbox, fail-closed.
   - `recuperacao-risco.md` — recuperação, risk engine, tarpit, auditoria, migração de legado.
   - `stack-versoes.md` — anexo volátil (padrões, versões, o que foi verificado).
2. **Rode os gates no repo atual** antes de opinar:
   `bash .claude/skills/schematize-iam/scripts/check-iam.sh .`
3. **Aplique daqui em diante** a todo código de auth que escrever ou tocar e diga qual piso está aplicando quando ele
   mudar o que você ia fazer. **Nunca** crie muro pré-login de fator forte, token em `localStorage` ou tela de login fora do broker.
