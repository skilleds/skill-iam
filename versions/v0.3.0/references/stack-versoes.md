# Anexo volátil — padrões, versões e o que foi (ou não) verificado

> Parte da skill **schematize-iam**. **Fato volátil** (versão, status de RFC/draft, release) mora aqui,
> com data e fonte. O corpo normativo diz princípio; o número fica neste anexo.
>
> **Verificado em: 2026-10-14** via WebSearch (uma consulta por tema). Cadência: revisão trimestral e antes de
> cada release da skill. O que não foi confirmado leva `<!-- reverificar -->`.

## Padrões

| Item | Estado em 2026-10-14 | Fonte |
|---|---|---|
| RFC 9700 (OAuth 2.0 Security BCP, BCP 240) | publicado, janeiro de 2025; depreca modos inseguros (implicit, ROPC) | rfc-editor.org/rfc/rfc9700 |
| OAuth 2.1 (`draft-ietf-oauth-v2-1`) | **ainda draft** nas fontes achadas (rev. 12 submetida ao IESG em 2025); sem número de RFC confirmado <!-- reverificar --> | datatracker.ietf.org (oauth) |
| WebAuthn Level 3 | **W3C Recommendation** em 2026-08-25 (relatado por FIDO Alliance e imprensa especializada); L2 foi de abril de 2021 | fidoalliance.org |
| NIST SP 800-63-4 | **final**, publicado em julho de 2025 (volumes A, B, C) | csrc.nist.gov/pubs/sp/800/63/4/final |
| OWASP/RFC 9106 argon2id | piso `m=19456, t=2, p=1` herdado de `schematize-engineering → references/iam.md` §2.1 | base da casa |
| RFCs usados pelo corpo | 7636 (PKCE), 8252 (apps nativos), 8628 (device), 9068 (JWT access token), 8725 (JWT BCP), 9207 (`iss` na resposta), 9449 (DPoP), 8705 (mTLS), 7009 (revogação), 9470 (step-up) | numeração conhecida; conteúdo não rebuscado nesta rodada <!-- reverificar --> |

## Motores de autorização

| Item | Versão vista | Fonte / ressalva |
|---|---|---|
| OpenFGA | v1.18.1 (espelho SourceForge; v1.18.0 de 2026-06-17) | página oficial de releases **não** consultada <!-- reverificar --> |
| SpiceDB | v1.56.0 (listagem Chocolatey, 2026-07-24) | página oficial **não** confirmada <!-- reverificar --> |

## O que foi executado e o que não foi

- **Executado:** `scripts/check-iam.test.sh` (24 casos) e `scripts/check-oidc.test.sh` (12 casos), `shellcheck` limpo.
- **Não executado:** `assets/authz/model.fga` nunca passou pelo `fga model validate` (CLI ausente nesta máquina);
  nenhum IdP real foi exercitado pelo `check-oidc.sh` via URL (testado só com arquivos).
- **Não verificado:** conteúdo atual de cada RFC listado acima; versões de bibliotecas de WebAuthn por linguagem
  (a skill não fixa biblioteca).
