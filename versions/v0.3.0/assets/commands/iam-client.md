---
description: schematize-iam — integra um cliente (web/BFF, SPA, mobile, CLI) ao broker com authorization code + PKCE
argument-hint: "<nome do cliente> [web|spa|mobile|cli]"
---

# /iam-client — o cliente delega, não autentica

1. **Escolha o fluxo pelo tipo** (`references/topologia.md` §2): web com servidor -> code + PKCE como cliente
   confidencial no BFF; SPA -> preferir BFF, senão público com token em memória; mobile -> navegador do sistema (RFC 8252);
   CLI/TV -> device flow (RFC 8628). Nunca implicit, nunca ROPC, nunca tela de login própria.
2. **Registre** no allowlist do auth: `client_id`, `redirect_uri`s **exatas** (sem curinga), escopos mínimos, tipo de cliente.
   O allowlist vive em config do auth, não no código do consumidor.
3. **Implemente o fluxo:** `state`, `nonce`, `code_verifier` de CSPRNG, `code_challenge_method=S256`; confira `state` e `iss` na
   volta; troque o `code` no servidor; valide o `id_token` (assinatura por JWKS, `iss`, `aud`, `exp`, `nonce`).
4. **Sessão do cliente:** cookie `HttpOnly` + `Secure` + `SameSite`, token só no servidor; **rota de refresh implementada**
   (access expira em 15 min, a sessão sobrevive); rota de logout que chama `/revoke` e o logout do broker.
5. **Validação de token nas APIs:** JWKS com cache e refetch em `kid` desconhecido, allowlist de algoritmo, `aud`, denylist de `jti`.
6. **Prove:** `bash scripts/check-iam.sh <repo do cliente>` verde; fluxo ponta a ponta contra o auth de hml (OTP no sink); teste de
   sessão após expirar o access; logout pós-teste não ressuscita. Cliente web/mobile: `/web-iam`, `/mobile-auth`.
