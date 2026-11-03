---
description: schematize-iam — gera o handoff (context.md + checklist.md) no archive, sem compactar.
---
Gere o handoff em `<projeto>/<projeto>_archive/context/`: `AAAA-MM-DD-<slug>-context.md` (o que foi feito, decisões de
IAM, o que os gates acusaram, estado das fases F0-F6) e `AAAA-MM-DD-<slug>-checklist.md` (FEITO vs ABERTO, nas três
classes da casa: `- [ ]` máquina · `- [H ]` humano · `- [~]` on-hold). Não compacte, só grave. Nunca grave segredo,
chave privada, token, OTP ou hash de senha no handoff.
