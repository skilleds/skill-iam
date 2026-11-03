#!/usr/bin/env bash
# Vermelho primeiro do gate check-oidc.sh: discovery bom e discoveries com UM defeito cada.
#
# EXCEÇÃO DECLARADA (piso da schematize-shell, strict mode): harness de teste roda `set -u` sem `-e`
# — precisa continuar depois de um caso vermelho para reportar todos, em vez de parar no primeiro.
set -u
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G="$AQUI/check-oidc.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP:?}"' EXIT INT TERM
ok=0; fail=0

BOM='{"issuer":"https://auth.exemplo.com","authorization_endpoint":"https://auth.exemplo.com/authorize","token_endpoint":"https://auth.exemplo.com/token","jwks_uri":"https://auth.exemplo.com/.well-known/jwks.json","revocation_endpoint":"https://auth.exemplo.com/revoke","response_types_supported":["code"],"grant_types_supported":["authorization_code","refresh_token","urn:ietf:params:oauth:grant-type:device_code"],"code_challenge_methods_supported":["S256"],"id_token_signing_alg_values_supported":["RS256","ES256"],"authorization_response_iss_parameter_supported":true}'

# caso <nome> <exit> <agulha> <jq-filtro-que-estraga>
caso() {
  local nome="$1" esp="$2" agulha="$3" filtro="$4" saida rc
  printf '%s' "$BOM" | jq "$filtro" >"$TMP/$nome.json"
  saida="$(bash "$G" "$TMP/$nome.json" 2>&1)"; rc=$?
  if [ "$rc" != "$esp" ] || ! grep -qF -- "$agulha" <<<"$saida"; then
    echo "  FALHA $nome: exit $rc (esperado $esp), agulha \"$agulha\""; printf '%s\n' "$saida" | sed 's/^/      /'; fail=$((fail+1)); return
  fi
  echo "  ok $nome"; ok=$((ok+1))
}

caso bom 0 "check-oidc: ok" '.'
caso issuer-http 1 "issuer-nao-https" '.issuer="http://auth.exemplo.com"'
caso sem-jwks 1 "sem-jwks-uri" 'del(.jwks_uri)'
caso sem-s256 1 "pkce-sem-s256" '.code_challenge_methods_supported=["plain"]'
caso plain 1 "pkce-plain" '.code_challenge_methods_supported=["S256","plain"]'
caso implicito 1 "response-type-implicito" '.response_types_supported=["code","id_token token"]'
caso grant-password 1 "grant-implicito-ou-password" '.grant_types_supported+=["password"]'
caso alg-none 1 "alg-none" '.id_token_signing_alg_values_supported+=["none"]'
caso sem-revocation 1 "sem-revocation" 'del(.revocation_endpoint)'
caso hs-aviso 0 "alg-simetrico" '.id_token_signing_alg_values_supported+=["HS256"]'

# entrada inválida nunca é verde
echo 'nao e json' >"$TMP/ruim.json"
saida="$(bash "$G" "$TMP/ruim.json" 2>&1)"; rc=$?
if [ "$rc" = 2 ]; then echo "  ok json-invalido"; ok=$((ok+1)); else echo "  FALHA json-invalido: exit $rc"; fail=$((fail+1)); fi
bash "$G" "$TMP/nao-existe.json" >/dev/null 2>&1; rc=$?
if [ "$rc" = 2 ]; then echo "  ok arquivo-ausente"; ok=$((ok+1)); else echo "  FALHA arquivo-ausente: exit $rc"; fail=$((fail+1)); fi

echo "check-oidc: $ok ok, $fail falha(s)"
[ "$fail" -eq 0 ]
