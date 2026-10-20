---
description: Mapa da skill schematize-iam (o broker de identidade auth.<domínio>: OIDC/PKCE, fatores, sessão, ReBAC, recuperação).
---
**schematize-iam** — dona do desenho do broker de identidade da casa. Identidade não é e-mail; o login não é um muro.

| Comando | O que faz |
|---|---|
| `/iam-help` | esta lista |
| `/iam-load` | carrega à força TODO o corpo normativo (topologia, protocolos, fatores, sessão, authz, recuperação) e passa a aplicá-lo |
| `/iam-review` | revisa código/config de auth: roda `check-iam.sh` e `check-oidc.sh`, depois lê o que a máquina não lê |
| `/iam-client` | integra um cliente ao broker: authorization code + PKCE, BFF, redirect exato, refresh no consumidor |
| `/iam-authz` | modela a autorização ReBAC de um serviço: rota -> permissão, tuplas, outbox, fail-closed |
| `/iam-recover` | desenha/audita recuperação e step-up por estado de conta, com prova de reachability |
| `/iam-audit` | mede a cobertura contra o checklist F0-F6 da base, item por item, com prova |
| `/iam-claude` | cria ou mescla o `CLAUDE.md` sempre-on de IAM na raiz do repo |
| `/iam-cc` · `/iam-handoff` | context compact / handoff no archive |

Pareia com: `schematize-engineering` (piso geral, `/eng-iam`), `schematize-pentest` (testar: `/pentest-iam`),
`schematize-api` (contrato de authz), `schematize-web` e `schematize-mobile` (clientes).
