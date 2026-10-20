# Fatores, senha, passkeys e step-up

Dona: `schematize-iam`. Base: `schematize-engineering → references/iam.md` §2-§4. Onde houver
divergência, a base manda e esta página é o defeito.

## 1. Identidade antes de credencial

- `sub` = ID interno opaco e imutável (ULID/UUIDv7). **E-mail e telefone nunca são ID**: são
  identificadores 1..N por usuário, cada um com estado de verificação. Trocar e-mail não muda `sub`.
- Identificador só vale **verificado** (não loga nem recupera sem verificação).
- Ter 2+ e-mails é incentivado (resiliência a brick de provedor). **Nudge** de e-mail secundário:
  detecta o provedor do atual e sugere um de **outro provedor**, com tooltip explicando o motivo;
  é sugestão, nunca obrigação.
- SSO nunca é ponto único de falha: cadastro via SSO força >= 1 fator de recuperação local.
  **Account linking** só com prova de posse de ambos os lados; nunca por e-mail não verificado.

## 2. Tiers de fator (NIST SP 800-63B)

| Tier | Fatores | Uso |
|---|---|---|
| Alto (resistente a phishing) | **passkey/WebAuthn**, chave FIDO2, push aprovado | ações sensíveis, troca de fator, admin, cross-tenant, billing, recuperação |
| Médio | TOTP | reforço do 2º fator |
| Baixo (fallback) | **Email OTP**, SMS/voz | 2º fator baseline; não autoriza ação sensível sozinho |

## 3. A regra que mata o círculo infinito

**Senha + Email OTP já é 2FA baseline** e dá acesso baseline pleno desde o cadastro. Fator forte
(passkey/TOTP) é **incentivado (nudge) e exigido just-in-time só em ação sensível**. É **vetado** barrar
o login por falta de fator forte: não entra sem forte / não enrola forte sem entrar = bug de bootstrap.
Toda exigência degrada o sensível, não bloqueia o baseline, e tem rampa self-service a partir do
estado zero (prova por estado de conta: só senha+e-mail, fator forte perdido, SSO sem local, convidado).

## 4. Senha (padrão cultural, opcional por escolha)

- **argon2id** com o piso numérico da base: `m >= 19456 KiB`, `t >= 2`, `p = 1`, sal >= 16 B CSPRNG,
  saída >= 32 B; calibre para ~0,5-1 s no hardware real e registre em ADR. String codificada completa
  guardada (`$argon2id$v=19$m=...`), nunca só o digest.
- **argon2id-only para senha nova.** bcrypt/PBKDF2/scrypt só como **legado lido e regravado** em argon2id
  no próximo login bem-sucedido (rehash preguiçoso); o leitor legado leva waiver `iam-ok: legado-rehash`.
- Verificar a senha escolhida contra base de vazadas (HIBP, k-anonymity: só o prefixo do SHA-1 sai).
  Comprimento mínimo 8 (12+ recomendado), máximo >= 64, aceitar todos os caracteres, sem regra de
  composição e sem expiração periódica (NIST 800-63B).
- Pepper opcional, em KMS/env fora do banco. Nunca logar senha, hash, sal ou pepper.
- O seletor de modos permite marcar a senha como opcional e viver de passkey/OTP/app.

## 5. Passkeys/WebAuthn (núcleo, fluxo real)

- Registro (attestation) **e** asserção implementados de ponta a ponta; mapear a string `passkey => AAL_ALTO`
  sem fluxo é o furo comum.
- `rpId` = domínio do broker (`auth.<domínio>` ou o domínio registrável escolhido, uma vez e para
  sempre: mudar invalida as passkeys); `origin` conferida no servidor; `challenge` CSPRNG, single-use,
  com TTL curto; contador de assinatura e flags UV/UP conferidos; `userVerification: required` em
  ação sensível. Biblioteca madura de WebAuthn; nunca parser CBOR/COSE próprio.
- Permitir **várias passkeys por conta** e listar/remover (view de dispositivos). Passkeys sincronizadas
  contam como resistentes a phishing, mas sua recuperação depende do cofre do provedor: por isso a conta
  mantém o caminho de recuperação independente (`recuperacao-risco.md`).
- Conditional UI (autofill) no campo de login para fluxo passwordless-first.

## 5.1 Passkey na fase 0 (padrão da casa)

**Regra.** Passkey/WebAuthn é o método de autenticação **padrão** e entra na **FASE 0** de todo projeto: antes de
qualquer feature, o login já oferece registro e asserção de passkey de ponta a ponta (não rótulo). Passwordless-first:
o fluxo ofertado primeiro é passkey; senha + Email OTP continua como fallback/2FA baseline (não remove o piso de
>= 2 fatores nem a recuperação >= login). Recuperação nunca é mais fraca que o login por passkey. Passkey é o fator
de AAL alto para step-up.

**Ceremony de registro (passo a passo).**
1. Usuário já autenticado (ou em cadastro novo) pede `POST /webauthn/register/options`.
2. Servidor gera `challenge` (CSPRNG, >= 32 bytes), grava **single-use**, TTL curto (<= 5 min), **vinculado à sessão**
   (ou ao cadastro em curso), e devolve as options.
3. Browser/OS roda `navigator.credentials.create()`; o autenticador devolve a attestation.
4. `POST /webauthn/register/verify`: servidor consome o challenge (atômico, uma vez), confere `clientDataJSON.type ==
   "webauthn.create"`, `origin` (match exato na allowlist do ambiente), `rpIdHash`, flags **UP** (e **UV** se exigido),
   algoritmo da allowlist, e só então grava `credentialId`, chave pública, `signCount`, `transports`, flags de backup
   (BE/BS), nome e `created_at`.
5. Notifica o usuário (canal verificado) e incentiva a segunda credencial (backup).

**Ceremony de autenticação (asserção).**
1. `POST /webauthn/auth/options`: challenge novo (mesmas regras). Sem `allowCredentials` quando discoverable (login sem
   digitar usuário); com a lista quando o usuário já foi identificado.
2. `navigator.credentials.get()`, em modal ou **conditional UI** (`mediation: "conditional"`).
3. `POST /webauthn/auth/verify`: consome o challenge, confere `type == "webauthn.get"`, `origin`, `rpIdHash`, UP/UV,
   assinatura com a chave pública gravada, `userHandle` == ID interno do dono da credencial e `signCount`.
4. `signCount` que não cresce (quando o autenticador usa contador, ou seja, > 0) é **sinalizado**: evento de risco,
   step-up ou bloqueio da credencial, nunca ignorado. Atualiza `signCount` e `last_used_at`.
5. Emite a sessão com `amr` (`hwk`/`swk`, `user`) e `acr/aal` altos (ver `sessao.md`).

**Parâmetros recomendados** (ajuste só com ADR):

| Parâmetro | Valor |
|---|---|
| `rp.id` / origins | fixados **por ambiente** em config (dev, stg e prd distintos); nunca derivados do header `Host` |
| `user.id` (`userHandle`) | ID interno opaco (ULID/UUIDv7 em bytes), **nunca** email/telefone |
| `authenticatorSelection.residentKey` | `preferred` (`required` se o produto é passwordless puro) |
| `authenticatorSelection.userVerification` | `preferred` no login; `required` em step-up e ação sensível |
| `attestation` | `none` (padrão); `direct`/`enterprise` só com requisito regulatório e ADR |
| `pubKeyCredParams` | `-7` (ES256), `-257` (RS256, Windows Hello), `-8` (EdDSA) nessa ordem de preferência |
| `timeout` | 60000 ms (até 120000 ms com UV) |
| `excludeCredentials` | credenciais já registradas, para não duplicar o mesmo autenticador |
| `authenticatorAttachment` | omitido: aceita sincronizada (iCloud/Google/1Password) e chave de hardware (roaming) |

**Gestão de credenciais.** Várias por usuário (>= 2 incentivado como backup), nome editável ("iPhone da Ana"), data de
criação e último uso, tipo (sincronizada ou hardware), revogação individual com step-up. Remover a última credencial
forte segue o invariante de troca (Y != X, atraso cancelável).

**Bibliotecas de referência** (exemplo por stack, não prescrição): `webauthn-rs` (Rust), `go-webauthn` (Go),
`SimpleWebAuthn` (TS/JS), `fido2-net-lib` (C#), `webauthn-ruby`, `wax` (Elixir). Toda stack usa lib madura que
verifica CBOR/COSE; parser próprio é vetado.

**Armadilhas (cada uma vira teste).**
- **Challenge reutilizável** ou sem vínculo à sessão: replay da asserção. Consumo atômico, TTL curto.
- **Origin check frouxo** (`endsWith`, regex, só o host, `*`): phishing em subdomínio. Match exato; `rpIdHash` também.
- **`userHandle` = email:** vaza PII e quebra quando o email muda. Sempre ID interno opaco.
- **Fallback que enfraquece:** o caminho senha/OTP vira a porta fácil e a passkey, enfeite. O fallback não pula
  o piso de >= 2 fatores nem derruba o nível exigido por rota.
- **Recuperação mais fraca que a passkey:** "1 e-mail e pronto" anula o fator forte (`recuperacao-risco.md`).
- **Conditional UI ausente ou quebrada:** sem `autocomplete="username webauthn"` e sem checagem de
  `PublicKeyCredential.isConditionalMediationAvailable()` o fluxo passwordless-first não aparece. Sem cancelar
  a ceremony pendente (`AbortController`) ao abrir o modal.
- **Rótulo sem fluxo:** `aal = "passkey"` mapeado sem registro nem asserção implementados.
- **Credencial revogada ainda aceita** por cache de lista de credenciais.

**Testes obrigatórios na fase 0** (provados por execução):
1. registro de passkey bem-sucedido;
2. login por passkey bem-sucedido (inclusive discoverable, sem digitar usuário);
3. challenge reutilizado rejeitado;
4. origin ou rpId errado rejeitado;
5. credencial revogada rejeitada;
6. `signCount` regressivo sinalizado;
7. matriz de acesso por rota: usuário autenticado **só com passkey** ainda passa; anônimo não.

O gate `scripts/check-iam.sh` (regra `passkey-fase0`) procura evidência disso no projeto; a prova é o teste rodando.

## 6. TOTP, push e OTP

- TOTP (RFC 6238): segredo **cifrado at-rest** (não em claro no banco), janela +-1 passo, **anti-replay**
  (o mesmo código não vale duas vezes), comparação em tempo constante.
- Email/SMS OTP: 6 dígitos de CSPRNG, **single-use**, TTL curto (<= 10 min), um novo invalida o anterior,
  guardado hasheado, rate-limit por conta+IP+destino, backoff exponencial. Reenvio com cooldown e teto diário.
- Push-approval: mostra contexto (local, dispositivo, ação) e exige número/confirmação para barrar
  fadiga de MFA.

## 7. Escolha de método e invariante de troca

- Login: sem app -> Email OTP; com app -> pergunta app ou e-mail; vários fatores -> **lista todos** e o
  usuário escolhe.
- **Invariante:** para mutar o fator X, apresente um fator Y != X no maior AAL disponível. Toda mudança
  notifica todos os canais verificados. Remover o **último fator forte** é ação com **atraso cancelável**.

## 8. Step-up

Rotas sensíveis declaram o AAL mínimo e a idade máxima da autenticação (`max_age`). O PEP responde
`insufficient_user_authentication` (RFC 9470) com o `acr`/`max_age` exigidos; o cliente leva o usuário ao
broker, que pede o fator forte na hora (e deixa enrolar um, verificado pelo Email OTP). O token novo
carrega `aal` e `auth_time`.

Ação financeira (cobrança, estorno, troca de conta de recebimento, saque) é o caso típico de step-up:
`schematize-payments` define **quais** ações exigem fator forte e papel por tenant; aqui fica o **como**
(AAL, `max_age`, RFC 9470).
