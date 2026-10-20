---
name: schematize-iam
metadata:
  version: 0.2.1
description: >-
  Broker de identidade: OIDC/OAuth 2.1 + PKCE, passkeys, 2FA, sessão, ReBAC multi-tenant, recuperação. Use ao projetar/revisar login, token, IdP ou authz. Gates. Teste: schematize-pentest.
---
<!-- cross-skill: iam.md, iam-checklist.md, efeitos-externos.md, orquestracao.md -> schematize-engineering; iam-testing.md -> schematize-pentest -->

# IAM — o broker de identidade da casa (schematize-iam)

Disciplina normativa do **`auth.<domínio>`**: o serviço que sabe **quem** é a pessoa e **prova** isso aos
outros apps. A tese: **identidade não é e-mail, autorização não é identidade, e o login não pode ser um muro**.
Quem confunde identidade com e-mail perde a conta no primeiro brick de provedor; quem cola papéis no token
longo vaza privilégio; quem exige fator forte antes do login cria o círculo infinito. Esta skill é a
**dona** do desenho do broker; a `schematize-engineering` guarda o piso geral (`references/iam.md` e o checklist
exaustivo por fase) e aponta para cá.

**Versão:** skill `schematize-iam` v0.2.1. Changelog em `CHANGELOG.md`.

## Precedência e herança (leia antes de divergir)

<!-- herdado:engineering/precedencia:dominio intro="Esta skill é o recorte **identidade e autorização (broker `auth.<domínio>`)** do piso da base: o desenho do IdP, dos fatores, da sessão e do ReBAC; **serviço de identidade**, não biblioteca de login do app." cmd="iam" -->Esta skill é o recorte **identidade e autorização (broker `auth.<domínio>`)** do piso da base: o desenho do IdP, dos fatores, da sessão e do ReBAC; **serviço de identidade**, não biblioteca de login do app.

1. **Onde esta skill divergir da base, a BASE MANDA.** Aqui mora a especialização do domínio ou da
   ferramenta — o como, o padrão, o gate. Divergência de *piso* é defeito desta skill, não variante local.
2. **O que não está repetido aqui é HERDADO, não dispensado.** Esta skill herda os pisos da base e
   os comandos dela cobrem o **domínio**, não o piso geral. Valem integralmente, sem cópia local:
   - **§28 Archive** — `<projeto>/<projeto>_archive/` é **repositório git próprio, PRIVADO e
     obrigatório**, criticidade 0 (`schematize-archive`).
   - **§35 Definition of Done** e a lista de anti-padrões (citada por **título**, nunca por número).
   - **§39 Índice/MAPA** — enumeração exaustiva (uma entrada por unidade chamável, `M == N`) e grafo
     com arestas em ASCII (`A -> B`), nunca a seta unicode.
   - **IAM** (`schematize-engineering` → `references/iam.md`): identidade ≠ email, ≥2 fatores, ReBAC
     multi-tenant, argon2id-only para senha nova, sessão longa e logout irreversível.
   - **Efeito externo** nunca sai de não-produção (`schematize-engineering` →
     `references/efeitos-externos.md`).
   - **Orquestração** (`schematize-engineering` → `references/orquestracao.md` §9): o principal não
     desenvolve (é Claude Opus); executor mais barato que resolve — `haiku`/`sonnet` → Codex Terra → Cursor → `opus` só após falha; visual direto ao Codex; imagem nunca pelo Claude: detecta Codex/Gemini e pergunta ao usuário qual usar (Codex é a sugestão, não automática), nunca API paga.
3. **QA, ops, IAM e índice não têm comando próprio aqui:** vêm da base `/eng-*`. Para trabalho
   contínuo use `/eng-overdev`; para planejar `/eng-plan`; para varrer a base `/eng-scan`; para
   revisão geral `/eng-review` (e `/eng-ops`, `/eng-iam`, `/eng-index`). Os comandos
   `/iam-*` cobrem o domínio desta skill; o piso geral é o da base.<!-- /herdado -->

## Fronteira com as outras skills

| Assunto | Dono | Ponteiro |
|---|---|---|
| Piso geral de IAM (princípios-âncora, checklist da DoD), checklist exaustivo F0-F6 e o `/eng-iam` | `schematize-engineering` | `schematize-engineering → references/iam.md`, `iam-checklist.md` |
| **Desenho do broker:** topologia, OIDC/OAuth 2.1/PKCE, tokens e JWKS, fatores, passkeys, sessão, ReBAC, recuperação, risco | **esta skill** | `references/*.md` abaixo |
| Testar o IAM: cross-tenant, priv-esc, abuso de fluxo, reachability, gate F6 | `schematize-pentest` | `schematize-pentest → references/iam-testing.md`, `/pentest-iam`, `/pentest-authz` |
| Contrato HTTP de authz e de erro (escopos no OpenAPI, `problem+json`, 401/403/404) | `schematize-api` | esta skill define a regra, a api publica o contrato (`schematize-api → references/contrato-rest.md`) |
| Pagamento: quais ações financeiras exigem step-up e papel por tenant | `schematize-payments` | aqui o **como** do step-up (AAL, `max_age`); lá o **onde** |
| Cliente web (BFF, formulários do front de auth, passkey no browser) | `schematize-web` | `/web-iam` |
| Cliente mobile (OIDC/PKCE nativo, Keychain/Keystore, passkey nativa) | `schematize-mobile` | `schematize-mobile → /mobile-auth` |
| Implementação do IdP em Go, Rust, Elixir, C#, Ruby, Zig | skill da linguagem | `/go-iam`, `/rust-iam`, `/elixir-iam`, `/cs-iam`, `/ruby-iam`, `/zig-iam` |
| Schema das tabelas de identidade | `schematize-database` | modelagem; aqui só as regras (ID imutável, N identificadores) |
| Cofre, rotação de chave, deploy do serviço | `schematize-infra` | segredos e entrega |
| Efeito externo do OTP (e-mail/SMS só em prd) | `schematize-engineering` | `references/efeitos-externos.md` |
| Telemetria e alerta de eventos de segurança | `schematize-observability` | log de auditoria alimenta; aqui o conteúdo |

## Comandos (Claude Code)

| Comando | O que faz |
|---|---|
| `/iam-help` | lista os comandos |
| `/iam-load` | carrega à força o corpo normativo (topologia, protocolos, fatores, sessão, authz, recuperação) |
| `/iam-review` | revisa código/config de auth: roda `check-iam.sh` e `check-oidc.sh`, depois lê o que a máquina não lê |
| `/iam-client` | registra/integra um cliente no broker (authorization code + PKCE, BFF, redirect exato, refresh no consumidor) |
| `/iam-authz` | modela a autorização ReBAC de um serviço: tabela rota -> permissão, tuplas, outbox, fail-closed |
| `/iam-recover` | desenha/audita recuperação de conta e step-up por estado de conta, com prova de reachability |
| `/iam-audit` | mede a cobertura do IAM contra o checklist F0-F6 da base, item por item, com prova |
| `/iam-claude` | cria/mescla o `CLAUDE.md` sempre-on de IAM na raiz do repo |
| `/iam-cc` · `/iam-handoff` | context compact / handoff arquivado |

## Como usar

1. **Rode os gates antes de discutir estilo:** `bash scripts/check-iam.sh .` (código e config) e
   `bash scripts/check-oidc.sh <discovery.json|URL>` (contrato público do IdP). `0` passa · `1` reprova · `2` **nada
   para verificar** (não é aprovação). Waiver rastreável no código: `iam-ok: <motivo>`.
2. **Topologia primeiro** (`references/topologia.md`): auth separada, broker único, chave só no auth, JWKS.
3. **Protocolo** (`references/protocolos.md`): authorization code + PKCE S256, tokens finos, validação obrigatória.
4. **Fatores** (`references/fatores.md`): 2FA baseline sem muro, passkey real, argon2id, step-up. **A Fase 0 do IAM inclui
   passkey** (registro + asserção + testes, §5.1) antes de qualquer feature; o gate `passkey-fase0` cobra a evidência.
5. **Sessão** (`references/sessao.md`): 7d/90d, refresh rotativo exercido pelo consumidor, logout irreversível.
6. **Autorização** (`references/authz-rebac.md`): ReBAC, PDP/PEP, outbox, fail-closed.
7. **Recuperação e risco** (`references/recuperacao-risco.md`): força >= login, risk engine, auditoria.
8. **Prove** com `/iam-audit` e feche com o gate F6 da `schematize-pentest`.

Mapa de references:

| Tarefa | Reference |
|---|---|
| Auth como app separada, broker único, chave e JWKS, allowlist de clientes, fluxo por tipo de cliente, e-mail/SMS só em prd | `references/topologia.md` |
| Fluxos vetados e permitidos, authorization code passo a passo, tokens (JWT, refresh opaco), validação, JWKS, OIDC, DPoP | `references/protocolos.md` |
| Identidade, senha argon2id, passkeys, TOTP/OTP, nudge, a regra anti círculo infinito, invariante Y != X, step-up | `references/fatores.md` |
| Sessão multi-dispositivo, refresh rotativo, logout irreversível, denylist de `jti`, cookies | `references/sessao.md` |
| Multi-tenant, ReBAC, PDP/PEP, as três regras do motor, anti-padrões, `assets/authz/model.fga` | `references/authz-rebac.md` |
| Recuperação, risk engine, tarpit, honeypot, anti-automação, notificações, auditoria, migração de legado | `references/recuperacao-risco.md` |
| Padrões e versões voláteis (RFC 9700, OAuth 2.1, WebAuthn L3, NIST 800-63-4, OpenFGA/SpiceDB), o que foi executado | `references/stack-versoes.md` |

## Pisos inegociáveis (vetam o atalho)

1. **Auth é aplicação separada** em `auth.<domínio>`, com serviço, front, repo e usuário próprios. **Broker único:** todo
   login e cadastro acontece lá; apps delegam por authorization code + PKCE ou device flow, sem tela de login própria.
2. **Chave de assinatura só no auth**, de PEM/segredo de runtime; sem ela em `prd` o serviço **recusa subir**. Consumidores
   validam por **JWKS**; `iss` == URL pública do auth.
3. **Authorization code + PKCE S256 para todo cliente.** Implicit, ROPC e PKCE `plain` vetados. `redirect_uri` por **match
   exato** de allowlist.
4. **JWT assimétrico** (RS256/ES256/EdDSA), algoritmo em allowlist no consumidor, `none` e `HS*` rejeitados, `aud` por
   recurso. **Token fino** (sem permissões). Access curto; **refresh opaco, CSPRNG, hasheado, rotativo com detecção de reuso**.
5. **ID interno imutável e opaco é o `sub`.** E-mail e telefone nunca são ID; N identificadores por usuário, só valem verificados.
6. **>= 2 fatores sempre; senha + Email OTP já é 2FA baseline e dá acesso pleno.** Fator forte (passkey/app) é nudge e
   step-up just-in-time. **Muro pré-login de fator forte é vetado** (círculo infinito).
7. **Passkey/WebAuthn é núcleo, com fluxo real** (registro e asserção), não um rótulo de AAL. **É o método padrão e entra na
   Fase 0, passwordless-first** (senha + Email OTP é fallback/2FA baseline): `references/fatores.md` §5.1.
8. **Senha é argon2id-only** (`m >= 19456`, `t >= 2`, `p = 1`) + verificação contra vazadas; bcrypt/PBKDF2/scrypt só como legado com rehash.
9. **Invariante de fator:** mutar X exige Y != X no maior AAL; notifica todos os canais; remover o último forte = atraso cancelável.
10. **Recuperação com força >= login**, vários caminhos independentes, nunca bypass de 1 fator; resposta anti-enumeração idêntica em conteúdo e tempo.
11. **Autorização por ReBAC multi-tenant, deny-by-default, PDP/PEP, enforcement no servidor**, toda decisão auditada. Tupla escrita por **outbox**; PDP **fail-closed**.
12. **Sessão longa (7d, 90d confiável) com refresh silencioso exercido pelo consumidor; logout irreversível** (revoga refresh+família, apaga sessão, `jti` na denylist, em **todo** caminho que aceita token). Token nunca em `localStorage`.
13. **Risk engine adaptativo** (score real, escalonamento a 3FA, tarpit com resposta e tempo idênticos, honeypot), anti-automação com backoff, notificação de "não fui eu".
14. **Toda aleatoriedade de segurança vem de CSPRNG** (token, OTP, sal, `state`, `nonce`, id de sessão, link de reset).
15. **Efeito externo (e-mail/SMS do OTP) só em `prd`**; fora dele, sink + guard de domínio de teste + cap por execução (`schematize-engineering → references/efeitos-externos.md`).
16. **Auth legado migra como prioridade 0** (strangler-fig, rehash preguiçoso, sessões legadas revogadas, authz re-derivada).
17. <!-- herdado:engineering/iam-desenho:invariantes cmd="eng" -->**ID interno imutável (ULID/UUIDv7) — email/telefone nunca é ID** (N emails por usuário; SSO com recuperação local). **≥2 fatores sempre**: passkey/WebAuthn no núcleo, TOTP/push, email OTP always-on, Twilio para telefone; senha argon2id+HIBP por padrão, mas opcional; invariante de troca de fator (Y≠X no maior AAL); **recuperação ≥ login**. Senha + Email OTP já é **2FA baseline**: o PEP libera o baseline e exige AAL alto **só por rota sensível** (step-up just-in-time), nunca barra o login. **Multi-tenant RBAC/ABAC granular via ReBAC** (OpenFGA/SpiceDB; deny-default, PDP=Check API, PEP no servidor, token fino). **Multi-dispositivo, sessão 7d/90d, logout irreversível** (revoga refresh+família, `jti` na denylist, não só cookie). **Passkey/WebAuthn é o método PADRÃO e entra na FASE 0** (registro+asserção reais e2e antes de qualquer feature; passwordless-first, senha+Email OTP fica de fallback/2FA baseline; teste: registro, login, challenge reutilizado, origin/rpId errado e credencial revogada rejeitados) — a implementação mora no IAM da casa (`auth.<domínio>`), o app cliente só integra via OIDC/PKCE. **Toda rota exposta nasce com teste de matriz de acesso no CI** (anônimo/não privilegiado/privilegiado/burlas; status e corpo; deny-by-default; inventário derivado, M == N) — detalhe na `schematize-qa` (`scripts/check-route-authz.sh`). **Migrar auth legado = prioridade 0.** Scaffold/auditoria por **`/eng-iam`**; testes cross-tenant/priv-esc na `schematize-pentest`.<!-- /herdado -->
18. <!-- herdado:engineering/efeito-externo:invariantes -->**Cap por execução** (`MAIL_MAX_PER_RUN`, default 50) com abort; **fail-closed** (ambiente ausente/desconhecido ⇒ não-prd; só o valor exato de produção entrega de verdade); **chave sandbox** fora de prd. Todo endereço sintético (fixture, seed, persona, demo, carga) é `<papel>+<run-id>-<n>@test.<domain>` — domínio em **rota nula** (null MX RFC 7505 + SPF `-all` + DMARC `p=reject`) ou TLD reservado (`.test`/`.invalid`/`.example`); **VETADO** `@gmail.com`, domínio de cliente/terceiro, e-mail de pessoa real (**inclusive o seu**) e o domínio de produção. A recusa é **erro**, nunca warning nem sucesso silencioso. Entregar de verdade fora de prd exige **as cinco** (ADR + allowlist ≤5 + cap + janela + subdomínio separado). Motivo: bounce/complaint em massa **queima IP e domínio** e derruba o transacional de prd — inclusive o **OTP de login** — com semanas de warm-up e utilidade zero (o incidente dos 5.000 e-mails só existiu porque nada contava).<!-- /herdado -->
19. <!-- herdado:engineering/orquestracao:curto -->**Orquestrador não desenvolve; subagent barato executa.** O agent principal só planeja, despacha e revisa; ação onerosa vira micro-tasks para o executor mais barato que resolve: `haiku` (mecânico) / `sonnet` (código; falhou → mesmo subagent corrige, até 2 rodadas) → Codex `gpt-5.6-terra` → Cursor → subagent `opus` (motivo) → `park`; **visual vai direto ao Codex**; **imagem nunca pelo Claude: detectar Codex/Gemini e perguntar ao usuário qual usar (Codex é a sugestão), nunca API de imagem paga**; papéis em `agentes.toml`. No overdev, cada item do checklist vai a um subagent e o principal revisa antes do `- [x]`. **Sem frota ociosa:** idle com pendência volta ao trabalho; dependente de outro agent → mata e enfileira com gatilho; terminou → mata (§9.6). Detalhe: `schematize-engineering` → `references/orquestracao.md` §9.<!-- /herdado -->

## Regra de mídia

Diagrama de fluxo vai em Mermaid ou texto no repo. Imagem ou mídia gerada (tela de login, ilustração, marca) **nunca**
por modelo Claude: detecte Codex e Gemini disponíveis e **pergunte ao usuário qual usar**. Nenhum disponível: avise sem
rodeio que visual gerado pelo Claude tem qualidade inversamente proporcional à de código (sai ruim de verdade) e
ofereça alternativas: instalar Codex ou Gemini, imagem de banco com licença comercial, ou asset do cliente. Claude é
o melhor em código.

## Relação com as outras skills

- **`schematize-engineering`** — a base: piso geral de IAM, checklist exaustivo F0-F6 e o `/eng-iam` (scaffold restritivo
  sob o overdev). O `iam.md` da base manda onde houver divergência.
- **`schematize-pentest`** — o juiz: a rotina agressiva (cross-tenant, priv-esc, abuso de fluxo, reachability) é o gate de
  conclusão. Esta skill constrói; ela tenta quebrar.
- **`schematize-api`** — como o contrato publica escopos, erros e paginação das rotas autenticadas.
- **`schematize-web`** e **`schematize-mobile`** — os clientes que delegam ao broker.
- **Skills de linguagem** — a implementação do IdP; a lib e o idioma, não o piso.
- **`schematize-infra`** e **`schematize-observability`** — operação do serviço e alerta dos eventos de segurança.
- **`schematize-docs`** — ADR de motor de authz, parâmetros do argon2id e política de sessão; runbook de rotação de chave.
