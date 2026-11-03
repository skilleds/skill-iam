#!/usr/bin/env bash
# Vermelho primeiro do gate check-iam.sh: cada caso é um mini-repo com UM defeito (e casos verdes).
#
# EXCEÇÃO DECLARADA (piso da schematize-shell, strict mode): harness de teste roda `set -u` sem `-e`
# — precisa continuar depois de um caso vermelho para reportar todos, em vez de parar no primeiro.
set -u
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G="$AQUI/check-iam.sh"
TMP="$(mktemp -d)"
# shellcheck disable=SC2016  # fixture literal: o '$' faz parte do hash de exemplo
A='const h = "$argon2id$v=19$m=19456,t=2,p=1$abc$def";'
trap 'rm -rf "${TMP:?}"' EXIT INT TERM
ok=0; fail=0; D=""; NOME=""

novo() { D="$TMP/$1"; mkdir -p "$D"; NOME="$1"; }
f() { mkdir -p "$(dirname "$D/$1")"; cat >"$D/$1"; }
esperar() { # esperar <exit> <agulha>
  local esp="$1" agulha="$2" saida rc
  saida="$(bash "$G" "$D" 2>&1)"; rc=$?
  if [ "$rc" != "$esp" ]; then echo "  FALHA $NOME: exit $rc, esperado $esp"; printf '%s\n' "$saida" | sed 's/^/      /'; fail=$((fail+1)); return; fi
  if [ -n "$agulha" ] && ! grep -qF -- "$agulha" <<<"$saida"; then echo "  FALHA $NOME: saída sem \"$agulha\""; printf '%s\n' "$saida" | sed 's/^/      /'; fail=$((fail+1)); return; fi
  echo "  ok $NOME"; ok=$((ok+1))
}

# ---- vermelhos
novo implicit; f a.js <<'X'
const u = base + "?response_type=token&client_id=x";
X
esperar 1 "implicit-flow"

novo ropc; f a.py <<'X'
data = {"grant_type": "password", "username": u}
X
esperar 1 "ropc-grant"

novo pkce-ausente; f a.ts <<'X'
const url = `${AUTH}/authorize?response_type=code&client_id=app&redirect_uri=${cb}`;
X
esperar 1 "pkce-ausente"

novo pkce-plain; f a.ts <<'X'
const q = { code_challenge_method: "plain", code_challenge: v };
X
esperar 1 "pkce-plain"

novo redirect-curinga; f c.json <<'X'
{ "redirect_uris": ["https://*.exemplo.com/cb"] }
X
esperar 1 "redirect-curinga"

novo md5-senha; f a.py <<'X'
h = hashlib.md5(password.encode()).hexdigest()
X
esperar 1 "senha-hash-rapido"

novo sha256-senha; f a.js <<'X'
const h = crypto.createHash('sha256').update(senha).digest('hex'); // sha256(senha)
X
esperar 1 "senha-hash-rapido"

novo bcrypt; f a.go <<'X'
hash, _ := bcrypt.GenerateFromPassword(pw, 12)
X
esperar 1 "senha-bcrypt"

novo argon2i; f a.txt.rs <<'X'
let h = "$argon2i$v=19$m=65536,t=3,p=1$abc$def";
X
esperar 1 "argon2-nao-id"

novo jwt-none; f a.js <<'X'
jwt.verify(t, key, { algorithms: ["none"] });
X
esperar 1 "jwt-none"

novo jwt-verify-false; f a.py <<'X'
claims = jwt.decode(tok, options={"verify_signature": False})
X
esperar 1 "jwt-sem-verificacao"

novo jwt-segredo; f a.js <<'X'
const t = jwt.sign(payload, "secret", { algorithm: "HS256" });
X
esperar 1 "jwt-segredo-fraco"

novo localstorage; f a.tsx <<'X'
localStorage.setItem("access_token", data.access_token);
X
esperar 1 "token-em-storage"

novo prng; f a.js <<'X'
const otp = Math.floor(Math.random() * 1000000); // otp
X
esperar 1 "prng-fraco"

novo httponly; f a.py <<'X'
SESSION_COOKIE_HTTPONLY = False
X
esperar 1 "cookie-sem-httponly"

novo samesite; f a.js <<'X'
res.cookie("sid", v, { sameSite: "none", secure: false });
X
esperar 1 "cookie-samesite-none-sem-secure"

novo email-id; f s.sql <<'X'
CREATE TABLE users (email TEXT PRIMARY KEY, hash TEXT);
X
esperar 1 "email-como-id"

novo email-sub; f a.js <<'X'
const claims = { sub: user.email, aal: 2 };
X
esperar 1 "email-como-id"

novo pem; f k.pem <<'X'
-----BEGIN PRIVATE KEY-----
MIIBVQ
-----END PRIVATE KEY-----
X
esperar 1 "chave-privada-no-repo"

# ---- verdes
novo hs-aviso; f a.js <<'X'
const alg = "HS256";
X
esperar 0 "jwt-simetrico"

novo waiver; f a.go <<'X'
// iam-ok: legado-rehash — verifica hash bcrypt e regrava em argon2id no login
ok := bcrypt.CompareHashAndPassword(h, pw)
X
f pk.go <<'X'
// iam-ok: passkey-fase0 teste de waiver (IdP em outro repo)
X
esperar 0 "ok"

novo bom; f passkey.ts <<'X'
const rpID = process.env.WEBAUTHN_RP_ID; const expectedOrigin = cfg.allowedOrigins;
app.post("/webauthn/register", registrar); app.post("/webauthn/authenticate", autenticar);
X
f passkey.test.ts <<'X'
// challenge reutilizado rejeitado
await post("/webauthn/register", opt); await post("/webauthn/authenticate", opt);
X
f a.ts <<'X'
const url = `${AUTH}/authorize?response_type=code&code_challenge=${c}&code_challenge_method=S256`;
const h = "$argon2id$v=19$m=19456,t=2,p=1$abc$def";
const sub = user.id; // ULID
const tok = crypto.randomBytes(32).toString("base64url");
X
f c.json <<'X'
{ "redirect_uris": ["https://app.exemplo.com/api/auth/callback"] }
X
esperar 0 "ok"

novo passkey-ausente; f a.ts <<'X'
const url = `${AUTH}/authorize?response_type=code&code_challenge=${c}&code_challenge_method=S256`;
const h = "$argon2id$v=19$m=19456,t=2,p=1$abc$def";
X
esperar 1 "passkey-fase0"

PKH='app.post("/webauthn/register", r); app.post("/webauthn/authenticate", a);'
PKT='await post("/webauthn/register", o); await post("/webauthn/authenticate", o); // challenge reutilizado rejeitado'

novo passkey-sem-rpid; f pk.ts <<X
$PKH
$A
X
f pk.test.ts <<X
$PKT
X
esperar 0 "sem RP ID/origin"

novo passkey-sem-teste-challenge; f pk.ts <<X
$PKH // rpID = cfg.RPID
$A
X
f pk.test.ts <<'X'
await post("/webauthn/register", o); await post("/webauthn/authenticate", o);
X
esperar 0 "challenge reutilizado"

# P1-14: palavra solta não é passkey. README/JSON/comentário contendo 'passkey' continua vermelho.
novo passkey-palavra-em-json; f a.ts <<X
$A
X
f config.json <<'X'
{ "passkey": true, "webauthn": "enabled", "notes": "/webauthn/register /webauthn/authenticate" }
X
esperar 1 "passkey-fase0"

novo passkey-so-comentario; f a.ts <<X
// TODO passkey: app.post("/webauthn/register") e "/webauthn/authenticate"
$A
X
esperar 1 "sem handler de rota"

novo passkey-sem-teste; f pk.ts <<X
$PKH
$A
X
esperar 1 "sem teste correspondente"

novo passkey-so-register; f pk.ts <<X
app.post("/webauthn/register", r);
$A
X
f pk.test.ts <<X
$PKT
X
esperar 1 "webauthn/authenticate"

novo passkey-waiver; f a.ts <<'X'
// iam-ok: passkey-fase0 serviço só de leitura, IdP é outro repo
const h = "$argon2id$v=19$m=19456,t=2,p=1$abc$def";
X
esperar 0 "ok"

novo so-md; f README.md <<'X'
response_type=token
X
esperar 2 "nada para verificar"

novo ignora-modules; f node_modules/x/a.js <<'X'
response_type=token
X
f a.ts <<'X'
export const ok = 1;
X
esperar 0 "ok"

echo "check-iam: $ok ok, $fail falha(s)"
[ "$fail" -eq 0 ]
