# Recuperação de conta, risco adaptativo, anti-automação e auditoria

Dona: `schematize-iam`. Base: `schematize-engineering → references/iam.md` §4 e §9.

## 1. Recuperação (força >= login)

- **Vários caminhos independentes:** mais de um e-mail, **códigos de backup offline** (single-use, hasheados,
  gerados uma vez), telefone, outra passkey. Cada caminho recupera sozinho; **nenhum é bypass de 1 fator**.
- **Reset nunca é "1 e-mail e pronto".** Exige a força do login (2 fatores) ou um processo com **atraso
  cancelável + revisão**: o atraso notifica todos os canais verificados com botão "não fui eu".
- Rate-limit agressivo, token de reset de CSPRNG, single-use, TTL curto, hasheado no store; tudo auditado.
  Reset **revoga todas as sessões** e refresh da conta.
- **Recuperação >= login por passkey:** se a conta tem passkey, nenhum caminho de recuperação entrega acesso com menos
  força que ela (e-mail sozinho não basta): exige outro fator forte (outra passkey, código de backup) ou o processo com
  atraso cancelável + revisão. Remoção/reset de passkey notifica todos os canais.
- **Perdi o fator forte:** o baseline (senha + Email OTP) continua dando acesso baseline; o forte é re-enrolado
  just-in-time, verificado por Email OTP (Y != X). Nenhum estado fica sem saída self-service.
- SSO banido/removido: a conta tem caminho local forçado no cadastro. A saída nunca manda quem está sem sessão
  para página que exige sessão, nem terceiriza ao admin da org o que só o dono faz.
- **Anti-enumeração:** a resposta de "esqueci a senha", login e cadastro é idêntica exista ou não a conta (mensagem,
  status e **tempo**). O caminho de código é o mesmo (hash dummy quando o usuário não existe).

## 2. Risk engine adaptativo

Log de **cada tentativa e sessão**: IP, ASN/reputação, fingerprint, geo, user-agent, horário, resultado, score.
- **Sinais:** IP novo/suspeito (Tor, proxy, ASN de abuso), dispositivo novo, geovelocidade impossível, velocity /
  força bruta, horário fora do padrão, hit de honeypot. Sinal real, não stub fixo.
- **Escalonamento:** risco alto pede **mais um fator** na ordem de força (senha -> e-mail -> app/passkey): 2FA vira 3FA.
- **Negação deceptiva (tarpit)** só com disciplina: em contexto suspeito, mesmo com senha correta responde "inválida"
  **uma vez**, e marca server-side que a próxima tentativa correta passa (já com 3FA). Regras: **mesmo caminho de
  código e tempo constante** (se a negação pula a verificação, o tempo vira oráculo); estado **curto**, atado a
  conta+IP+dispositivo, com TTL; **nunca** vira bloqueio permanente do legítimo; tudo logado com o score.
- **Honeypot:** conta/campo/rota isca; qualquer interação = sinal forte; nunca serve tráfego real.
- **Nunca** bloquear o legítimo sem rampa: o risco escala fatores e atrasa o atacante, não tranca o dono.

## 3. Anti-automação

Rate-limit + backoff exponencial + lockout **progressivo** por conta+IP em senha, OTP, reset e cadastro; OTP
curto e single-use; CAPTCHA/prova de trabalho apenas como degrau sob risco, nunca como único controle. O
burst não derruba o serviço: o limite barra o abuso sem virar DoS contra o dono (lockout por IP+conta, não só conta).

## 4. Notificações

Login novo/suspeito, dispositivo novo, mudança de credencial ou fator, remoção de passkey, reset: aviso em
**todos** os canais verificados, com "não fui eu" (revoga a sessão e força reforço).

## 5. Auditoria

Log **imutável** (append-only, retenção definida) de toda decisão authn/authz e de toda mudança de credencial:
quem, o quê, quando, de onde, resultado, política. Sem senha, OTP, token ou hash no log. Alimenta forense, a
suíte do pentest e a observabilidade (`schematize-observability`). Eventos de segurança com alerta e runbook.

## 6. Migração de auth legado (prioridade 0)

Strangler-fig com dual-run; **rehash preguiçoso** para argon2id no login; mapeia registros ao modelo novo (dedupe
de e-mails, cunha ID interno); ativa Email OTP como 2º fator baseline **sem muro**; revoga sessões legadas; **nunca
confia na authz legada** (re-deriva no ReBAC). O auth migrado nasce como app separada (`topologia.md`).
