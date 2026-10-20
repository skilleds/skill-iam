---
description: schematize-iam — context compact: grava o handoff no archive e roda /compact.
---
Antes de compactar, **grave o handoff** em `<projeto>/<projeto>_archive/context/` no par **context + checklist** do padrão
da `schematize-archive` (prefixo `AAAA-MM-DD-<slug>-`), FEITO vs ABERTO. Inclua: fases do IAM fechadas e abertas, achados
do `check-iam.sh`/`check-oidc.sh` pendentes, waivers `iam-ok:` declarados com o motivo e o estado do gate F6. Nunca inclua
segredo, chave, token, OTP ou hash. Só então rode `/compact`.
