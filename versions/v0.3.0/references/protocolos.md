# Protocolos — OAuth 2.1, OIDC, PKCE, tokens e JWKS

Dona: `schematize-iam`. Estado dos padrões e versões: `references/stack-versoes.md`.

## 1. Fluxos permitidos e vetados

| Fluxo | Estado | Nota |
|---|---|---|
| Authorization code + **PKCE S256** | **obrigatório** para todo cliente | público e confidencial; `code_verifier` de 43-128 chars de CSPRNG |
| Device authorization (RFC 8628) | permitido | CLI/TV |
| `client_credentials` | permitido | só máquina; escopo mínimo |
| Refresh token | permitido, **rotativo** com detecção de reuso | ver `sessao.md` |
| **Implicit** (`response_type=token`) | **vetado** | removido do OAuth 2.1 e deprecado pela BCP do RFC 9700 |
| **ROPC** (`grant_type=password`) | **vetado** | o cliente nunca vê a senha |
| PKCE `plain` | **vetado** | só S256 |

## 2. Authorization code, passo a passo (o que o servidor e o cliente fazem)

1. Cliente gera `state` (CSRF) e `nonce` (OIDC) por CSPRNG, `code_verifier` e `code_challenge = BASE64URL(SHA256(verifier))`.
2. Redireciona a `/authorize?response_type=code&client_id&redirect_uri&scope&state&nonce&code_challenge&code_challenge_method=S256`.
3. O broker autentica (fatores, risco, `prompt`/`max_age`/`acr_values`), consente se for o caso e devolve
   `code` **curto (<= 60 s), single-use, atado a client_id + redirect_uri + code_challenge**, mais `state`
   e `iss` (RFC 9207, mitiga mix-up).
4. Cliente confere `state` e `iss`, troca `code` + `code_verifier` em `/token`. Reuso de `code` revoga os
   tokens já emitidos por ele.
5. Cliente valida o `id_token`: assinatura por JWKS, `iss`, `aud`, `exp`, `nonce`, `azp`.

## 3. Tokens

- **Access token curto** (padrão 15 min), JWT assinado com **RS256/ES256/EdDSA** (chave assimétrica de PEM),
  perfil RFC 9068: `iss`, `sub`, `aud`, `exp`, `iat`, `jti`, `client_id`, `scope`, mais `tid` (tenant),
  `sid` (sessão) e `aal`. **Token fino:** sem lista de permissões (evita authz obsoleta em token longo).
- **Verificação obrigatória no consumidor:** algoritmo em **allowlist** (nunca o que o header disser;
  `none` e `HS*` rejeitados), `kid` conhecido, `iss`/`aud` esperados, `exp`/`nbf` com folga pequena,
  `jti` fora da denylist. Boas práticas de JWT: RFC 8725.
- **Refresh token opaco**, CSPRNG >= 32 bytes, **hasheado no store**, comparação em tempo constante.
- **`aud` por recurso:** token de um serviço não vale em outro. Escopos descrevem capacidade do cliente;
  quem pode o quê no tenant é decisão do PDP (`authz-rebac.md`).
- **JWKS:** publicar chave nova antes de assinar com ela; manter a antiga até o último token expirar;
  `kid` estável; cache com `Cache-Control` e refetch em `kid` desconhecido (com limite, para não virar DoS).
- **Sender-constrained (opcional, sobe a régua):** DPoP (RFC 9449) ou mTLS (RFC 8705) para clientes
  de alto valor; token roubado não serve sem a chave.
- **Introspecção/revogação:** `/revoke` (RFC 7009) existe e derruba refresh + família; recursos que
  precisam de revogação imediata consultam a denylist de `jti` ou introspectam.

## 4. OIDC

- Discovery completo e coerente com o comportamento real (`scripts/check-oidc.sh`).
- `id_token` é para o **cliente**, nunca para chamar API. Claims mínimas; e-mail como claim
  informativa com `email_verified`, **nunca** como `sub`.
- **Logout:** RP-initiated logout + back-channel logout quando houver mais de um cliente na sessão
  SSO; o logout do broker é **irreversível** (`sessao.md`).
- SSO silencioso por cookie de sessão do broker (`prompt=none`); `max_age` e `acr_values` forçam
  reautenticação/step-up (`fatores.md`).

## 5. O que o gate `check-iam.sh` pega neste tema

`implicit-flow`, `ropc-grant`, `pkce-ausente`, `pkce-plain`, `redirect-curinga`, `jwt-none`,
`jwt-sem-verificacao`, `jwt-segredo-fraco`, `jwt-simetrico` (aviso), `chave-privada-no-repo`. O que
o gate não lê (allowlist de `aud`, rotação de `kid`, tempo de vida do `code`) vai para `/iam-review`.

Vincular a conta do usuário ao bot por OAuth (Entrar com Discord/Slack): identidade do bot ≠ do usuário; ver `schematize-bots → references/credenciais-e-token.md`.
