# Sessão, multi-dispositivo, refresh e logout irreversível

Dona: `schematize-iam`. Base: `schematize-engineering → references/iam.md` §6.

## 1. Modelo

- **Sessão de servidor** (`sid`) por dispositivo, com rótulo amigável ("Chrome no Windows"), IP/geo, primeiro
  e último uso, nível de confiança. N sessões simultâneas por usuário; nenhuma derruba a outra.
- **View de dispositivos:** lista, revoga uma, "sair de todos". Revogar mata refresh + família + push token
  daquele dispositivo.
- **Sessão emitida após passkey** carrega `amr` (`hwk`/`swk` + `user` se UV) e `acr/aal` altos; a sessão guarda o
  `auth_time` da asserção, e o step-up reaproveita esse AAL dentro do `max_age` (`fatores.md` §5.1).
- **Sessão longa sem chute:** access token 15 min com **refresh silencioso** -> sessão de **7 dias** por padrão;
  pergunta se o dispositivo é confiável -> **90 dias**. Ação sensível pede step-up fresco mesmo na sessão longa.

## 2. Refresh token

- **Opaco**, CSPRNG >= 32 B, **hasheado no store** (SHA-256 basta), comparação em tempo constante.
- **Rotativo:** cada uso emite novo refresh e invalida o anterior; **reuso do antigo revoga a família inteira**
  e notifica o usuário. Concorrência legítima (duas abas) tem janela de tolerância curta e idempotente, não
  uma brecha: documente o número.
- Binding opcional ao dispositivo (DPoP) para clientes de alto valor.
- **O consumidor tem de exercitar o refresh.** Não basta o IdP rotacionar: o BFF/cliente precisa de rota
  que renova com o refresh quando o access expira (BFF sem rota de refresh = sessão que morre em 15 min).

## 3. Logout IRREVERSÍVEL

Botão "Sair" visível. Apagar o cookie não é logout. O servidor, na ordem:
1. revoga o refresh token **e a família**;
2. apaga o registro de sessão server-side;
3. põe o `jti` do access token na **denylist** até `exp`;
4. desassocia o push token do dispositivo;
5. propaga por back-channel logout aos clientes da sessão SSO.
Depois disso: replay, refresh ou "voltar o cookie" não ressuscitam a sessão (teste de refresh-reuse pós-logout).

**A denylist de `jti` é consulta obrigatória em todo caminho que aceita token:** API, WebSocket, job que
carrega token anexado, refresh. Um só caminho que pula a consulta anula o logout; é sempre o que ninguém
lembrou (WebSocket, worker).

## 4. Cookies

- `HttpOnly`, `Secure`, `SameSite=Lax` (ou `Strict`), prefixo `__Host-` quando possível, escopo mínimo.
  `SameSite=None` só com `Secure` e motivo escrito. Token **nunca** em `localStorage`/`sessionStorage`.
- Rotacionar o id de sessão no login e no step-up (anti fixation). CSRF: `SameSite` + token anti-CSRF em
  rota que muda estado + checagem de `Origin`.
- Cookie do broker (`sz_sess`-like) e cookie do BFF de cada cliente são distintos; o do cliente guarda
  referência, não o token em claro quando houver store server-side.

## 5. Gate

`token-em-storage`, `cookie-sem-httponly`, `cookie-samesite-none-sem-secure`, `prng-fraco`. A rotação de
refresh, a denylist em todos os caminhos e o logout real são provados pela suíte do pentest
(`schematize-pentest → references/iam-testing.md`).
