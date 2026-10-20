---
description: schematize-iam — mede a cobertura do IAM contra o checklist F0-F6 da base, item por item, com prova
argument-hint: "[diretório do projeto]"
---

# /iam-audit — checkbox sem prova não fecha

1. Leia `schematize-engineering → references/iam-checklist.md` (checklist exaustivo F0-F6). Onde o checklist e o `iam.md` divergirem, o `iam.md` manda.
2. Rode os gates: `check-iam.sh` no repo e `check-oidc.sh` no discovery do auth.
3. Para **cada item**, marque `- [x]` só com prova que roda **hoje** (teste que passa, endpoint que responde, `arquivo:linha`, gate verde);
   `- [ ]` sem prova; `- [H ]` decisão humana; `- [~]` on-hold com a pergunta parkeada. "Suspeito" não é "feito".
4. Meça a cobertura por fase e aponte o **primeiro GATE vermelho**: não se avança de `Fn` sem o `GATE Fn-1` verde.
5. Relate: itens abertos por fase, achados dos gates, waivers `iam-ok:` sem motivo. Para fechar os abertos use `schematize overdev delegar`
   (o overdev trava a parada com item aberto); a conclusão exige o **GATE F6** da `schematize-pentest` verde.
