# Resumo — binance_trade_bot_tester

## Sessão 2026-10-14 (planejamento padronizado + CI revivida)

- **Resumo:** bot de trading que pode operar dinheiro real; hardening de segurança já concluído em 2026-10-11. CI estava quebrada desde a aposentadoria do `ubuntu-20.04` (~2025) — runner e actions v2 removidos do GitHub.
- **Atividades:** CI modernizada para Ubuntu 24.04, checkout v7, setup-python v7 (3.12/3.13), pre-commit executado diretamente (sem action v2), buildx/qemu/login/build-push nas SHAs atuais, `fetch-depth: 0` para PR paths-filter funcionar.
- **Validações:** CI remota roda pre-commit + buildx; python -m py_compile OK nos fontes.
- **ACHADO CRÍTICO:** `.user.cfg` local contém **chaves reais de API da Binance** (api_key/secret_key). Preservado em `.local-preserved/binance_trade_bot_tester/` com hash; .gitignore já cobre. O dono deve considerar rotação.
- **Resultado:** [x] CI verde; [x] docs; [x] credenciais preservadas fora do Git.
- **Continuidade:** HEAD sincronizado; checkout removível. **Nunca commitar `.user.cfg`.**
