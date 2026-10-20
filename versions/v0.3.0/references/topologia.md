# Topologia — o broker `auth.<domínio>` e quem fala com ele

Dona: `schematize-iam`. Base normativa: `schematize-engineering → references/iam.md` §1.

## 1. Regras de topologia

1. **Auth é aplicação separada** (`<projeto>_auth_<lang>` + `<projeto>_authfront`), em `auth.<domínio>`,
   com repo, deploy, usuário Linux e unit/container próprios. Comprometer o app principal não
   compromete o IdP. Nunca apensado ao monolito.
2. **Broker único.** Todo login e todo cadastro acontece em `auth.<domínio>`. Ferramentas e fronts
   **não têm tela de login própria**: redirecionam (authorization code + PKCE) ou usam device flow
   (CLI/TV). Um front com formulário de senha próprio é defeito de topologia.
3. **A chave de assinatura vive só no auth**, vinda de PEM/segredo de runtime. Sem a chave configurada
   em `prd`, o serviço **recusa subir** (nunca gera chave efêmera: todo token invalidaria a cada restart).
4. **Consumidores validam por JWKS público** (`jwks_uri` do discovery), com cache e rotação por `kid`.
   Nunca guardam a chave privada, nunca validam "só a presença do cookie".
5. **`iss` do token == URL pública do auth** (`https://auth.<domínio>`), não o default de dev.
6. **Registro de clientes por allowlist** (`client_id` -> `redirect_uri`s exatas). Match **exato**:
   curinga ou prefixo é open redirect (roubo de `code`). Allowlist vem de config/env do auth, não de
   código de consumidor.
7. **Isolamento de dados:** o banco do auth não é lido por nenhum consumidor. Consumidor recebe o que
   precisa no token fino (`sub`, tenant, sessão, AAL) e consulta o PDP para o resto.
8. **Front do auth** (telas de login, cadastro, recuperação, dispositivos) é parte do broker: mesmo
   domínio de cookie do IdP, CSP estrita, sem terceiros.

## 2. Quem delega como

| Cliente | Fluxo | Observação |
|---|---|---|
| Web com servidor (SSR/BFF) | authorization code + PKCE, **cliente confidencial** no BFF | token fica no servidor; o browser só vê cookie `HttpOnly` |
| SPA pura | authorization code + PKCE, cliente público | preferir BFF; token em memória, nunca `localStorage` |
| Mobile/desktop | authorization code + PKCE com navegador do sistema (RFC 8252) | sem WebView embutida; `schematize-mobile → references` para o cliente nativo |
| CLI/TV/sem navegador | device flow (RFC 8628) | `user_code` curto, polling com `slow_down`, expira |
| Serviço para serviço | `client_credentials` com escopo mínimo | identidade de máquina, nunca token de usuário reaproveitado |

## 3. Operação do broker

- Discovery completo (`/.well-known/openid-configuration`) e JWKS; valide com `scripts/check-oidc.sh`.
- Saúde separada de prontidão (`/healthz`, `/ready`); o auth sobe mesmo com provedores externos fora,
  mas **recusa** operar sem chave de assinatura e sem provider de e-mail real em `prd`.
- E-mail e SMS: provider plugável (Resend e Twilio como defaults), **real só em `prd`**; fora de `prd` o
  default é o **sink** (Mailpit/log) com guard de domínio de teste e cap por execução
  (`schematize-engineering → references/efeitos-externos.md`). Seed em massa sem sink queima a
  reputação do domínio de envio.
- Deploy e rollback como o resto da casa (`schematize-infra → references/entrega.md`); migrations
  reversíveis; backup do banco do auth testado por restore.
- DNS de e-mail do domínio de envio (SPF, DKIM, DMARC) é pré-requisito do OTP chegar; sem DMARC o
  primeiro e-mail de domínio novo tende a cair em spam.
