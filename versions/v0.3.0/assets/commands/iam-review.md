---
description: schematize-iam — revisa código/config de auth contra o piso: roda os gates e lê o que a máquina não lê
argument-hint: "[diretório do repo] [discovery.json|URL do issuer]"
---

# /iam-review — auth é a porta de entrada de tudo

## 1. A máquina primeiro

```bash
bash .claude/skills/schematize-iam/scripts/check-iam.sh "${1:-.}"                 # anti-padrões no código e na config
bash .claude/skills/schematize-iam/scripts/check-oidc.sh "${2:-https://auth.<domínio>}"   # contrato público do IdP (se houver)
```
`0` passa · `1` reprova · `2` **nada para verificar** (não é aprovação; diga o que faltou: jq, URL, arquivos).
Waiver: `iam-ok: <motivo>` na linha ou na de cima (ex.: `legado-rehash`).

## 2. Depois, o que a máquina não lê

- **Topologia:** o auth é app separada? Há tela de login fora do broker? A chave de assinatura sai só de PEM de config e o serviço recusa subir sem ela em `prd`? `iss` bate com a URL pública?
- **Cliente:** `redirect_uri` por match exato? `state`, `nonce`, `iss` conferidos? O consumidor valida por JWKS com allowlist de algoritmo, `aud` e `exp`? Consulta a denylist de `jti` em **todo** caminho (API, WebSocket, job)?
- **Fatores:** senha+Email OTP dá acesso baseline? Existe algum estado que barra o login por falta de fator forte? Passkey tem registro e asserção reais? Mutação de fator exige Y != X?
- **Sessão:** o consumidor exercita o refresh? Refresh opaco, hasheado, rotativo com reuso revogando a família? Logout revoga de verdade (não só o cookie)?
- **Authz:** todo endpoint mapeia uma permissão? Deny-by-default? PDP fail-closed? Tupla por outbox? Recurso de outro tenant dá 404/403 idêntico?
- **Recuperação e risco:** reset exige força >= login? Resposta anti-enumeração idêntica em conteúdo e tempo? Tarpit no mesmo caminho de código?
- **Efeito externo:** em hml/dev o OTP vai para sink? Guard de domínio de teste e cap por execução?

## 3. Feche

Achado vira correção no mesmo PR ou item de checklist com dono. Prova do gate: `bash scripts/check-iam.test.sh` e
`bash scripts/check-oidc.test.sh`. Teste ofensivo é da `schematize-pentest` (`/pentest-iam`).
