# Autorização — multi-tenant e ReBAC (estilo Zanzibar)

Dona: `schematize-iam` (o modelo e o contrato de PDP/PEP). O contrato HTTP/OpenAPI de authz
(escopos, `403` vs `404`, `problem+json`) é da `schematize-api`; os testes cross-tenant são da
`schematize-pentest`. Base: `schematize-engineering → references/iam.md` §5.

## 1. Princípios

- **Identidade global, autorização por tenant:** 1 identidade, N tenants via **membership**, papéis diferentes por tenant.
- **Motor de relação** (OpenFGA ou SpiceDB): autorização como tuplas `(objeto, relação, sujeito)`. Hand-rolar authz
  é onde vazam privilégios.
- **RBAC granular:** permissão = `recurso:ação`. Papéis-padrão (owner, admin, member, viewer) **e** papéis
  customizados por tenant (viram relations/usersets). **ABAC** por cima via condições (hora, IP, risco, valor).
- **PDP/PEP separados.** PDP = Check API do motor. PEP = middleware em **cada** serviço. **Deny-by-default,
  enforcement no servidor, todo endpoint mapeia 1 permissão.** Recurso novo = negado até liberar.
- **Token fino:** `sub`, tenant, sessão, AAL; sem permissões. Decisão consultada (cache de TTL curto).
- **Toda decisão logada:** quem, o quê, allow/deny, política/tupla que decidiu, `trace_id`.

## 2. As três regras que ninguém escreve

1. **Tupla se escreve por outbox transacional.** A tupla no motor e a linha no banco mudam juntas: grave o
   evento na **mesma transação** do dado; um worker publica no motor, com **idempotência**. Escrever direto no
   motor dentro do handler gera o convite que existe no banco e não no motor, e a remoção que saiu do banco e
   **ficou no motor** (privilégio que sobrevive à revogação).
2. **PDP fail-closed.** Motor fora do ar, timeout ou erro = **deny**, logado e alertado. Nunca "libera até o
   Check responder", nunca cache positivo além do TTL sob falha. Motor lento vira 503, jamais acesso indevido.
3. **Denylist de `jti` consultada em todo caminho** (`sessao.md` §3).

## 3. Modelo base (ver `assets/authz/model.fga`)

Tipos: `user`, `tenant` (owner/admin/member/viewer), `role` (papel customizado, com `assignee`), `resource`
genérico parenteado ao tenant. Permissão computada: `can_approve = member do tenant E assignee de papel que concede`.
Condições (ABAC) por *conditional tuple*. Antes de usar, valide o modelo com o CLI do motor
(`fga model validate`); o arquivo deste repo **não foi validado por execução** nesta rodada (ver `stack-versoes.md`).

## 4. Anti-padrões

- Papel/permissão no JWT longo (authz obsoleta até o token expirar).
- `if user.role == "admin"` espalhado no handler em vez de Check no PEP.
- ID de recurso aceito sem checar o tenant (BOLA/IDOR): o PEP checa `(recurso, relação, sujeito)`, não só autenticação.
- Mass-assignment de papel/tenant vindo do corpo da requisição.
- Tenant escolhido por header sem validar membership.
- Endpoint de listagem que filtra depois de buscar tudo (vaza contagem/existência): use `ListObjects`/consulta já filtrada.
- Authz "temporária" sem dono nem prazo. Admin global da plataforma é um tenant/role como os outros, com auditoria reforçada e step-up.

Pagamento: a decisão "quem pode estornar/cobrar/sacar" é authz como qualquer outra (Check no PEP); o
que é ação financeira e exige step-up é da `schematize-payments`.

## 5. Contrato com os serviços

O serviço declara, em tabela versionada no repo, `rota -> permissão -> objeto resolvido`. O gate de CI
falha se existir rota sem linha na tabela. A resposta para recurso de outro tenant é **404** (não revela
existência) ou 403 com o mesmo corpo e tempo; escolha uma, documente no OpenAPI (`schematize-api`).
