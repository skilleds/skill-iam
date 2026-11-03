---
description: schematize-iam — desenha/audita recuperação de conta e step-up, com prova de reachability por estado de conta
argument-hint: "[diretório do auth]"
---

# /iam-recover — todo estado de "perdi acesso" tem saída

1. **Liste os estados de conta:** só senha+e-mail, fator forte perdido, e-mail principal perdido, SSO sem caminho local, convidado,
   passkey sincronizada perdida.
2. Para **cada** estado, escreva: o acesso baseline que existe, o caminho self-service de saída, o fator que o verifica (Y != X) e o
   que fica degradado até a saída. **Estado que bloqueia o login por falta de fator forte é bug de bootstrap.**
3. **Recuperação com força >= login:** vários caminhos independentes (e-mails, códigos de backup offline, telefone, outra passkey);
   reset exige 2 fatores ou atraso cancelável com notificação em todos os canais; reset revoga todas as sessões.
4. **Anti-enumeração:** mesma resposta e mesmo tempo existindo ou não a conta; rate-limit e backoff em reset e OTP.
5. **Step-up:** rotas sensíveis declaram AAL e idade máxima; `insufficient_user_authentication` leva ao broker, que pede o forte e
   deixa enrolar um na hora.
6. **Prove:** um teste de reachability por estado (a saída nunca manda quem está sem sessão para página que exige sessão). Escreva
   o teste primeiro e veja-o falhar. Execução ofensiva: `schematize-pentest → references/iam-testing.md`.
