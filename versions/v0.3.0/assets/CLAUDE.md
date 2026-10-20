# Piso de IAM (schematize-iam) — sempre-on

Auth é o broker `auth.<domínio>`: identidade não é e-mail, o login não é um muro.

1. **Auth é app separada**, broker único: todo login/cadastro lá; apps delegam por authorization code + PKCE (ou device flow). Sem tela de login própria.
2. **Chave de assinatura só no auth** (PEM de config; sem ela em `prd` o serviço não sobe). Consumidores validam por **JWKS**; `iss` == URL pública do auth.
3. **PKCE S256 sempre.** Implicit, ROPC e PKCE `plain` vetados. `redirect_uri` por match exato.
4. **JWT assimétrico**, algoritmo em allowlist no consumidor (`none` e `HS*` rejeitados), `aud` por recurso, **token fino**. Refresh **opaco, CSPRNG, hasheado, rotativo** (reuso revoga a família).
5. **`sub` = ID interno imutável e opaco.** E-mail/telefone nunca são ID; N identificadores, só valem verificados.
6. **Senha + Email OTP já é 2FA baseline com acesso pleno.** Fator forte = nudge + step-up just-in-time. **Muro pré-login é vetado.** Passkey/WebAuthn é núcleo, com fluxo real.
7. **Senha argon2id-only** (`m >= 19456`, `t >= 2`, `p = 1`) + HIBP; bcrypt/PBKDF2 só legado com rehash (`iam-ok: legado-rehash`).
8. **Mutar o fator X exige Y != X** no maior AAL; recuperação com força >= login, nunca bypass de 1 fator; anti-enumeração idêntica em conteúdo e tempo.
9. **Authz por ReBAC multi-tenant**, deny-by-default, PDP/PEP no servidor, tupla por **outbox**, PDP **fail-closed**.
10. **Sessão 7d/90d com refresh exercido pelo consumidor; logout irreversível**, denylist de `jti` em **todo** caminho. Token nunca em `localStorage`; cookie `HttpOnly`+`Secure`+`SameSite`.
11. **Todo valor de segurança vem de CSPRNG.** Risk engine com score real, 3FA sob risco, tarpit no mesmo caminho de código, auditoria imutável.
12. Efeito externo (OTP por e-mail/SMS) só em `prd`; fora dele, sink + guard + cap.
13. <!-- herdado:engineering/orquestracao:curto -->**Orquestrador não desenvolve; subagent barato executa.** O agent principal só planeja, despacha e revisa; ação onerosa vira micro-tasks para o executor mais barato que resolve: `haiku` (mecânico) / `sonnet` (código; falhou → mesmo subagent corrige, até 2 rodadas) → Codex `gpt-5.6-terra` → Cursor → subagent `opus` (motivo) → `park`; **visual vai direto ao Codex**; **imagem nunca pelo Claude: detectar Codex/Gemini e perguntar ao usuário qual usar (Codex é a sugestão), nunca API de imagem paga**; papéis em `agentes.toml`. No overdev, cada item do checklist vai a um subagent e o principal revisa antes do `- [x]`. **Sem frota ociosa:** idle com pendência volta ao trabalho; dependente de outro agent → mata e enfileira com gatilho; terminou → mata (§9.6). Detalhe: `schematize-engineering` → `references/orquestracao.md` §9.<!-- /herdado -->

Mídia: imagem/visual gerado nunca por modelo Claude; detecte Codex/Gemini e pergunte qual usar.

Gate: `bash .claude/skills/schematize-iam/scripts/check-iam.sh .` e `check-oidc.sh <discovery>`. Waiver: `iam-ok: <motivo>`.
