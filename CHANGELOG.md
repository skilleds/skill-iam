# Changelog — schematize-iam

Todas as mudanças relevantes deste pacote, no formato [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
com versionamento [SemVer](https://semver.org/lang/pt-BR/).
## [0.3.0] — 2026-10-20
### Adicionado
- **Passkey na fase 0 como padrão** (`fatores.md` §5.1): ceremonies de registro e asserção, parâmetros WebAuthn, gestão de credenciais, armadilhas e 7 testes obrigatórios; passwordless-first.
- Regra `passkey-fase0` no `check-iam.sh` (ERRO sem evidência de passkey em projeto com IAM; AVISO sem RP ID ou teste de challenge reutilizado).
- Recuperação >= login por passkey e `amr/acr/aal` altos na sessão.
- Porquê: passkey é o método mais confortável e seguro; adiá-la vira dívida de IAM.


## [0.2.1] — 2026-10-14
Ponteiro para a skill nova `schematize-bots` (piso curto, sem duplicar).

### Alterado
- ponteiro para vincular conta ao bot por OAuth.

## [0.2.0] — 2026-10-14
Integração ao catálogo: orçamento de description e ponteiros entre as irmãs novas.

### Alterado
- `description` <=190 (orçamento do catálogo).
- Ponteiros: step-up em ação financeira -> `schematize-payments` (fatores.md, authz-rebac.md, fronteira); authz do contrato -> `schematize-api → references/contrato-rest.md`.
- Motivo: o catálogo estourou o orçamento de listagem com 45 skills; cada fronteira aponta a dona em vez de duplicar.

## [0.1.0] — 2026-10-14
Primeira versão. O desenho do broker `auth.<domínio>` vivia espalhado: o piso na `schematize-engineering`
(`references/iam.md`), o cliente na web, a implementação em cada linguagem e o teste no pentest, sem uma skill
dona do domínio e sem nenhum gate executável sobre o código de auth.

### Adicionado
- `SKILL.md` com 19 pisos de IAM (broker único, PKCE sempre, JWT assimétrico, `sub` imutável, 2FA baseline sem muro, passkey com fluxo real, argon2id-only, Y != X, ReBAC com outbox e PDP fail-closed, logout irreversível, CSPRNG, efeito externo só em prd) e a tabela de fronteira com engineering, pentest, api, web, mobile e as linguagens.
- `references/`: `topologia`, `protocolos`, `fatores`, `sessao`, `authz-rebac`, `recuperacao-risco`, `stack-versoes` (anexo volátil com fonte e data).
- `scripts/check-iam.sh`: 19 regras sobre código e config (implicit, ROPC, PKCE ausente/plain, redirect com curinga, hash rápido de senha, bcrypt, argon2i/d, JWT `none`/sem verificação/segredo fraco/HS*, token em storage, PRNG fraco, cookie sem HttpOnly, SameSite=None sem Secure, e-mail como ID, chave privada no repo); waiver `iam-ok:`. `check-iam.test.sh`: 24 casos com vermelhos plantados e verdes.
- `scripts/check-oidc.sh`: valida o discovery do IdP (arquivo ou URL) com `jq`; `check-oidc.test.sh`: 12 casos.
- `assets/authz/model.fga` (modelo ReBAC multi-tenant base, não validado por execução), `assets/CLAUDE.md`.
- Comandos `/iam-help`, `-load`, `-claude`, `-handoff`, `-cc`, `-review`, `-client`, `-authz`, `-recover`, `-audit`.
