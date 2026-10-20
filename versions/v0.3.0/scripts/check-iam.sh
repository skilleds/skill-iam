#!/usr/bin/env bash
# check-iam.sh — gate estático da schematize-iam: varre código e config por anti-padrões de IAM.
#
# Motivo: os erros que viram incidente de identidade (implicit flow, senha com hash rápido, JWT
# `alg: none`, token em localStorage, fluxo de código sem PKCE, e-mail usado como ID) são visíveis
# no texto do repo, antes de qualquer pentest. Heurística de linha, sem parser de linguagem: o que
# ela não prova, a schematize-pentest prova.
# Como funciona: grep por regra sobre os arquivos de código/config (ignora .git, node_modules,
# vendor, target, dist, versions, *.md e lockfiles); cada achado sai como
# `arquivo:linha: [ERRO|AVISO regra] mensagem`.
# Entrada: $1 = diretório (default .).
# Saída: exit 0 passa · 1 reprova (algum ERRO) · 2 NADA para verificar (não é aprovação).
# Waiver rastreável: `iam-ok: <motivo>` na linha ou na linha de cima (ex.: leitura de hash bcrypt
# legado que faz rehash para argon2id no login).
#
# Regras (id): implicit-flow · ropc-grant · pkce-ausente · pkce-plain · redirect-curinga ·
#   senha-hash-rapido · senha-bcrypt · argon2-nao-id · argon2-fraco · jwt-none · jwt-sem-verificacao ·
#   jwt-segredo-fraco · jwt-simetrico · token-em-storage · prng-fraco · cookie-sem-httponly ·
#   cookie-samesite-none-sem-secure · email-como-id · chave-privada-no-repo · passkey-fase0.
# passkey-fase0: se o projeto tem IAM (authorize/OIDC/JWT/argon2/sessão), exige EVIDÊNCIA de passkey
#   (WebAuthn/passkey/navigator.credentials) = ERRO se nenhuma; AVISO se faltar RP ID/origin em config ou
#   teste de challenge reutilizado. Waiver do projeto inteiro: `iam-ok: passkey-fase0 <motivo>` em qualquer arquivo.
set -euo pipefail

RAIZ="${1:-.}"
[ -d "$RAIZ" ] || { echo "check-iam: '$RAIZ' não é diretório" >&2; exit 2; }

ACHADOS="$(mktemp)"
LISTA="$(mktemp)"
trap 'rm -f "$ACHADOS" "$LISTA"' EXIT INT TERM

# Arquivos candidatos (código e configuração; docs ficam de fora para não acusar exemplo em prosa).
find "$RAIZ" \( -name .git -o -name node_modules -o -name vendor -o -name target -o -name dist \
  -o -name build -o -name versions -o -name .next -o -name .venv \) -prune -o -type f \
  \( -name '*.js' -o -name '*.mjs' -o -name '*.cjs' -o -name '*.ts' -o -name '*.tsx' -o -name '*.jsx' \
  -o -name '*.py' -o -name '*.go' -o -name '*.rs' -o -name '*.ex' -o -name '*.exs' -o -name '*.cs' \
  -o -name '*.rb' -o -name '*.php' -o -name '*.java' -o -name '*.kt' -o -name '*.swift' -o -name '*.dart' \
  -o -name '*.sql' -o -name '*.toml' -o -name '*.yaml' -o -name '*.yml' -o -name '*.json' \
  -o -name '*.env' -o -name '.env*' -o -name '*.conf' -o -name '*.ini' -o -name '*.pem' -o -name '*.key' \) \
  ! -name 'package-lock.json' ! -name 'pnpm-lock.yaml' ! -name 'yarn.lock' ! -name 'Cargo.lock' \
  ! -name '*.min.js' ! -name '*.map' -print 2>/dev/null | sort >"$LISTA"

if [ ! -s "$LISTA" ]; then
  echo "check-iam: nenhum arquivo de código/config em '$RAIZ' — nada para verificar (não é aprovação)" >&2
  exit 2
fi

# regra <id> <ERRO|AVISO> <regex ERE, case-insens.> <mensagem>
regra() {
  local id="$1" sev="$2" re="$3" msg="$4" hit arq ln prev
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    arq="${hit%%:*}"; hit="${hit#*:}"; ln="${hit%%:*}"; hit="${hit#*:}"
    case "$hit" in *iam-ok:*) continue ;; esac
    if [ "$ln" -gt 1 ]; then
      prev="$(sed -n "$((ln-1))p" "$arq")"
      case "$prev" in *iam-ok:*) continue ;; esac
    fi
    printf '%s:%s: [%s %s] %s\n' "$arq" "$ln" "$sev" "$id" "$msg" >>"$ACHADOS"
  done < <(xargs -d '\n' grep -HnIiE -- "$re" <"$LISTA" 2>/dev/null | sed -E 's/^([^:]+):([0-9]+):/\1:\2:/' || true)
}

regra implicit-flow ERRO \
  "response_type[\"' =:]+(id_)?token\b|response_type[\"' =:]+token id_token|\"implicit\"[^,]*(true|enabled)|implicitFlowEnabled[\"' :=]+true|implicit_?grant_?enabled[\"' :=]+true" \
  "implicit flow: removido do OAuth 2.1 (RFC 9700); use authorization code + PKCE"
regra ropc-grant ERRO \
  "grant_type[\"' =:]+password\b|grant_types?[^\\n]{0,40}[\"']password[\"']" \
  "grant 'password' (ROPC): removido do OAuth 2.1; o cliente nunca vê a senha, delegue ao broker"
regra pkce-plain ERRO \
  "code_challenge_method[\"' =:]+plain\b|code_challenge_methods_supported[^\\n]*[\"']plain[\"']" \
  "PKCE 'plain' anula a proteção; só S256"
regra redirect-curinga ERRO \
  "redirect_uris?[\"' :=\[]+[^\\n]*(https?://)?[^\\n\"' ,]*\*|redirect_uri[\"' ]*(=|:)[ ]*[\"']?\*" \
  "redirect_uri com curinga: match EXATO ou open redirect (roubo de code)"
regra senha-hash-rapido ERRO \
  "(md5|sha1|sha-?256|sha-?512|sha224|sha384)[a-z_]*[\"'(\.: ]+[^\\n]{0,60}(passw|passwd|senha|pwd)|(passw|passwd|senha|pwd)[^\\n]{0,60}(md5|sha1|sha-?256|sha-?512)\(|hashlib\.(md5|sha1|sha256|sha512)\([^\\n]*(passw|senha|pwd)" \
  "hash rápido (MD5/SHA-*) para senha: use argon2id (m>=19456, t>=2, p=1)"
regra senha-bcrypt ERRO \
  "bcrypt|pbkdf2|scrypt" \
  "bcrypt/PBKDF2/scrypt: legado a migrar por rehash no login; senha NOVA é argon2id. Se é o leitor legado, marque 'iam-ok: legado-rehash'"
regra argon2-nao-id ERRO \
  "\\\$argon2(i|d)\\\$|argon2(i|d)\b[^\\n]{0,20}(hash|new|config|variant|type)|Argon2(Type|Variant)\.(I|D)\b|Algorithm::Argon2(i|d)\b" \
  "argon2i/argon2d puros: o piso é argon2id"
regra jwt-none ERRO \
  "alg(orithms?)?[\"' =:\[]+[^\\n]{0,20}[\"']none[\"']|algorithm[\"' =:]+none\b|alg[\"']?[ ]*[:=][ ]*[\"']none|Algorithm::None|alg=none" \
  "JWT com alg 'none': nunca aceite token sem assinatura"
regra jwt-sem-verificacao ERRO \
  "verify_signature[\"' ]*[:=][ ]*(false|False)|verify[ ]*=[ ]*False|ignoreExpiration[\"' ]*[:=][ ]*true|verify_exp[\"' ]*[:=][ ]*(false|False)|insecure_disable_signature_validation|jwt\.decode\([^\\n)]*\)[ ]*;?[ ]*//.*(no|sem) verif" \
  "validação de JWT desligada (assinatura/expiração)"
regra jwt-segredo-fraco ERRO \
  "(jwt|jws|sign|secret|hs256|hs384|hs512)[^\\n]{0,40}[\"'](secret|changeme|change-me|password|123456|12345678|supersecret|super-secret|jwt_secret|jwtsecret|my-secret|mysecret|default|test|dev|s3cr3t)[\"']" \
  "segredo de JWT fraco/literal: chave assimétrica (RS256/ES256/EdDSA) vinda de PEM de config"
regra jwt-simetrico AVISO \
  "[\"'](HS256|HS384|HS512)[\"']|Algorithm::HS(256|384|512)|SigningMethodHS(256|384|512)" \
  "JWT simétrico (HS*): o broker assina com chave assimétrica e os consumidores validam por JWKS; HS só interno, com ADR"
regra token-em-storage ERRO \
  "(localStorage|sessionStorage)\.(setItem\([\"'][^\"']*(token|jwt|refresh|session|auth)[^\"']*[\"']|(access|refresh|id)?_?token[a-z_]*[ ]*=)|(localStorage|sessionStorage)\[[\"'][^\"']*(token|jwt|refresh)" \
  "token em localStorage/sessionStorage: cookie HttpOnly+Secure+SameSite via BFF"
regra prng-fraco ERRO \
  "(Math\.random|random\.random|random\.randint|random\.choice|mt_rand|rand\(\)|math/rand|rand::random|Random\.new|new Random\()[^\\n]{0,80}(token|otp|code|codigo|reset|session|nonce|state|salt)|(token|otp|code|codigo|reset|session|nonce|state|salt)[^\\n]{0,80}(Math\.random|random\.random|random\.randint|mt_rand|math/rand)" \
  "PRNG comum em valor de segurança: use o CSPRNG da plataforma (>=32 bytes para token)"
regra cookie-sem-httponly ERRO \
  "httponly[\"' ]*[:=][ ]*(false|False)|SESSION_COOKIE_HTTPONLY[ ]*=[ ]*False|;[ ]*httponly=false|http_only[\"' ]*[:=][ ]*false" \
  "cookie de sessão sem HttpOnly"
regra cookie-samesite-none-sem-secure ERRO \
  "samesite[\"' =:]+none\b[^\\n]*secure[\"' =:]+(false|False)|secure[\"' =:]+(false|False)[^\\n]*samesite[\"' =:]+none\b" \
  "cookie SameSite=None sem Secure"
regra email-como-id ERRO \
  "email[a-z_ ]+(text|varchar|string)[^\\n]*primary key|primary key[ ]*\([ ]*email[ ]*\)|[\"']?sub[\"']?[ ]*[:=][ ]*[a-z_.]*\.?(user|usuario|account|u)\.email\b|\bsub[\"']?[ ]*[:=][ ]*email\b" \
  "e-mail/telefone como ID ou como 'sub': o ID é interno, opaco e imutável (ULID/UUIDv7)"
regra chave-privada-no-repo ERRO \
  "-----BEGIN ((RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY)-----" \
  "chave privada commitada: a chave de assinatura vive só no auth, vinda de segredo de runtime"

# pkce-ausente: arquivo que inicia fluxo de código (response_type=code) sem mencionar PKCE.
while IFS= read -r arq; do
  if grep -qIiE "response_type[\"' =:\[]+code\b" "$arq" 2>/dev/null \
     && ! grep -qIiE "code_challenge|code_verifier|pkce" "$arq" 2>/dev/null \
     && ! grep -qIE "iam-ok:" "$arq" 2>/dev/null; then
    ln="$(grep -nIiE "response_type[\"' =:\[]+code\b" "$arq" | head -1 | cut -d: -f1)"
    printf '%s:%s: [ERRO pkce-ausente] fluxo authorization code sem PKCE (code_challenge S256): obrigatório para todo cliente\n' "$arq" "$ln" >>"$ACHADOS"
  fi
done <"$LISTA"

# passkey-fase0: passkey é padrão e entra na fase 0; projeto com IAM sem nenhuma evidência reprova.
# Evidência é heurística de texto (rota/handler/teste); a prova real é o teste de passkey rodando.
TEM_IAM="$(xargs -d '\n' grep -lIiE "response_type[\"' =:\[]+code\b|/authorize\b|/\.well-known/(openid|jwks)|jwks_uri|issuer[\"' ]*[:=]|argon2id?|jwt\.(sign|verify|decode)|SESSION_COOKIE|refresh_token" <"$LISTA" 2>/dev/null | head -1 || true)"
if [ -n "$TEM_IAM" ] && ! xargs -d '\n' grep -qIE "iam-ok:[ ]*passkey-fase0" <"$LISTA" 2>/dev/null; then
  PK_RE="webauthn|passkey|navigator\.credentials|PublicKeyCredential|fido2|simplewebauthn|go-webauthn|webauthn-rs"
  if ! xargs -d '\n' grep -qIiE "$PK_RE" <"$LISTA" 2>/dev/null; then
    printf '%s:1: [ERRO passkey-fase0] projeto com IAM sem evidência de passkey/WebAuthn: registro e asserção reais entram na fase 0 (fatores.md 5.1)\n' "$TEM_IAM" >>"$ACHADOS"
  else
    xargs -d '\n' grep -qIiE "rp_?id|rpID|relying_?party|WEBAUTHN_(RP|ORIGIN)|expected_?origin|allowed_?origins" <"$LISTA" 2>/dev/null \
      || printf '%s:1: [AVISO passkey-fase0] passkey sem RP ID/origin fixados em config (por ambiente)\n' "$TEM_IAM" >>"$ACHADOS"
    xargs -d '\n' grep -qIiE "(reus|replay|reutiliz|repeat|stale|single[_ -]?use|consumed)[^\n]{0,60}challenge|challenge[^\n]{0,60}(reus|replay|reutiliz|repeat|stale|single[_ -]?use|consumed|expired)" <"$LISTA" 2>/dev/null \
      || printf '%s:1: [AVISO passkey-fase0] sem teste de challenge reutilizado rejeitado\n' "$TEM_IAM" >>"$ACHADOS"
  fi
fi

if [ -s "$ACHADOS" ]; then
  sort -u "$ACHADOS"
  erros="$(grep -c '\[ERRO ' "$ACHADOS" || true)"
  avisos="$(grep -c '\[AVISO ' "$ACHADOS" || true)"
  echo "check-iam: $erros erro(s), $avisos aviso(s)"
  [ "$erros" -gt 0 ] && exit 1
  exit 0
fi
echo "check-iam: ok ($(wc -l <"$LISTA") arquivo(s) verificados)"
