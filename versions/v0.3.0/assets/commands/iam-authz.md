---
description: schematize-iam — modela a autorização ReBAC multi-tenant de um serviço (rota -> permissão, tuplas, outbox, fail-closed)
argument-hint: "<serviço ou diretório>"
---

# /iam-authz — quem pode o quê, decidido no servidor

1. **Levante as rotas** do serviço e monte a tabela versionada `rota -> permissão (recurso:ação) -> objeto resolvido`. Rota sem
   linha = defeito (deny-by-default).
2. **Modele** a partir de `assets/authz/model.fga`: tipos, papéis-padrão e **papéis customizados por tenant**, recurso parenteado
   ao tenant, condições (ABAC) quando o valor/horário/risco importar. Valide com o CLI do motor antes de adotar.
3. **PEP no servidor** (middleware) chamando o Check do PDP; token fino, sem permissões. Listagens usam `ListObjects` ou consulta já
   filtrada.
4. **Escrita de tupla por outbox transacional**, com publicação idempotente (`references/authz-rebac.md` §2).
5. **PDP fail-closed:** erro/timeout/motor fora = deny + log + alerta; sem cache positivo além do TTL.
6. **Auditoria:** cada decisão loga quem, o quê, allow/deny, política, `trace_id`.
7. **Prove:** teste de recurso de outro tenant (negado), de papel baixo em ação alta (negado), de revogação (tupla removida no
   motor junto com o banco). A suíte agressiva é da `schematize-pentest` (`/pentest-authz`); o contrato HTTP dos erros (401/403/404, RFC 9457), da `schematize-api → references/contrato-rest.md`.
