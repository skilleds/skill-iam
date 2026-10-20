#!/usr/bin/env bash
# check-oidc.sh — valida o documento de discovery OIDC (/.well-known/openid-configuration) de um IdP.
#
# Motivo: o discovery é o contrato público do broker; um `plain` em code_challenge_methods, um
# response_type `token` ou um `none` nos algoritmos de assinatura anunciam a falha antes de qualquer
# cliente tentar. Valida também o JWKS quando o endereço é URL.
# Como funciona: lê o JSON (arquivo ou URL https/http) com jq e confere as regras abaixo.
# Entrada: $1 = arquivo .json ou URL do discovery (ou da base do issuer). Env: OIDC_PERMITE_HTTP=1
#   aceita issuer http:// (só dev local).
# Saída: `[ERRO|AVISO regra] msg`; exit 0 passa · 1 reprova · 2 nada a verificar (jq/curl ausente,
#   entrada ilegível — nunca falso verde).
#
# Regras: issuer-nao-https · sem-jwks-uri · pkce-sem-s256 · pkce-plain · response-type-implicito ·
#   grant-implicito-ou-password · alg-none · alg-simetrico · sem-authorization-endpoint ·
#   sem-token-endpoint · sem-revocation · sem-iss-resposta (aviso).
set -euo pipefail

ENTRADA="${1:-}"
[ -n "$ENTRADA" ] || { echo "uso: check-oidc.sh <arquivo.json|URL>" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "check-oidc: jq ausente — instale para validar (nada verificado)" >&2; exit 2; }

DOC="$(mktemp)"
trap 'rm -f "$DOC"' EXIT INT TERM
case "$ENTRADA" in
  http://*|https://*)
    command -v curl >/dev/null 2>&1 || { echo "check-oidc: curl ausente (nada verificado)" >&2; exit 2; }
    URL="$ENTRADA"
    case "$URL" in */.well-known/openid-configuration) ;; *) URL="${URL%/}/.well-known/openid-configuration" ;; esac
    curl -fsS --max-time 15 "$URL" >"$DOC" || { echo "check-oidc: falha ao buscar $URL" >&2; exit 2; } ;;
  *)
    [ -f "$ENTRADA" ] || { echo "check-oidc: '$ENTRADA' não existe" >&2; exit 2; }
    cp "$ENTRADA" "$DOC" ;;
esac
jq -e 'type=="object"' "$DOC" >/dev/null 2>&1 || { echo "check-oidc: JSON inválido (nada verificado)" >&2; exit 2; }

erros=0
e() { printf '[ERRO %s] %s\n' "$1" "$2"; erros=$((erros+1)); }
a() { printf '[AVISO %s] %s\n' "$1" "$2"; }
tem() { jq -e "$1" "$DOC" >/dev/null 2>&1; }

iss="$(jq -r '.issuer // ""' "$DOC")"
case "$iss" in
  https://*) ;;
  http://*) [ "${OIDC_PERMITE_HTTP:-0}" = 1 ] || e issuer-nao-https "issuer '$iss' não é https" ;;
  *) e issuer-nao-https "issuer ausente ou inválido" ;;
esac
tem '.jwks_uri | type=="string" and length>0' || e sem-jwks-uri "jwks_uri ausente: consumidores validam por JWKS"
tem '.authorization_endpoint | type=="string"' || e sem-authorization-endpoint "authorization_endpoint ausente"
tem '.token_endpoint | type=="string"' || e sem-token-endpoint "token_endpoint ausente"
tem '.code_challenge_methods_supported | index("S256")' || e pkce-sem-s256 "code_challenge_methods_supported sem S256 (PKCE S256 é obrigatório)"
tem '.code_challenge_methods_supported | index("plain")' && e pkce-plain "PKCE 'plain' anunciado"
tem '[.response_types_supported[]? | select(test("(^|[ ])token([ ]|$)"))] | length>0' \
  && e response-type-implicito "response_types_supported inclui token (implicit/hybrid com token)"
tem '[.grant_types_supported[]? | select(.=="implicit" or .=="password")] | length>0' \
  && e grant-implicito-ou-password "grant_types_supported inclui implicit ou password"
for campo in id_token_signing_alg_values_supported token_endpoint_auth_signing_alg_values_supported \
             request_object_signing_alg_values_supported introspection_endpoint_auth_signing_alg_values_supported; do
  tem ".$campo | index(\"none\")" && e alg-none "$campo inclui 'none'"
  tem "[.${campo}[]? | select(test(\"^HS\"))] | length>0" && a alg-simetrico "$campo inclui HS*: broker assina com chave assimétrica"
done
tem '.revocation_endpoint | type=="string"' || e sem-revocation "revocation_endpoint ausente: logout irreversível exige revogar refresh"
tem '.authorization_response_iss_parameter_supported == true' || a sem-iss-resposta "authorization_response_iss_parameter_supported ausente (RFC 9207, mitigação de mix-up)"

if [ "$erros" -gt 0 ]; then echo "check-oidc: $erros erro(s)"; exit 1; fi
echo "check-oidc: ok ($iss)"
