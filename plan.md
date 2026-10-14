# Plan — binance_trade_bot_tester

## 1. Visão geral
Bot de trading da Binance (Python/Flask + SQLAlchemy + Socket.IO + Apprise), fork do ecossistema edeng23/binance-trade-bot. **Executa ordens com dinheiro real** — segurança classificada com P0 de perda financeira.

## 2. Arquitetura e tecnologias
Python 3.12/3.13, Flask (apenas local), SQLAlchemy, Socket.IO, Apprise, Binance API. Docker multi-arch; pre-commit (trailing whitespace, AST, pyupgrade, sort-coins).

## 3. Funcionalidades existentes
- [x] `debug=True` porta fixa corrigido; CORS restrito; API com auth — SEC-01..05/IMP em 2026-10-11.
- [x] Docker/Compose funcional.
- [ ] CI — **modernizada nesta sessão** (Ubuntu 24.04 dos `ubuntu-20.04` aposentados; actions v7/v4 pinadas).

## 4. Objetivos futuros
- OBJ-01 (P2, concluído nesta sessão): CI revivida (estava quebrada por runner aposentado).
- OBJ-02 (P0, operacional): **NUNCA** commitar `.user.cfg` (já há `.user.cfg.example` de referência).
- OBJ-03 (P3): rodar o bot em modo scout de teste (paper trading) em janela controlada, fora desta esteira.

## 5–9. Melhorias/Roadmap/Riscos/Ideias
- **Risco crítico existente:** credenciais reais no arquivo local `.user.cfg` — preservado fora do Git em `.local-preserved/`; **deve ser rotacionado** se algum dia foi exposto.
- **Risco de segurança:** o bot executa ordens reais; habilitar 2FA na conta Binance e IP allowlist antes de qualquer execução em produção.

*(Gerado em 2026-10-14 pelo agente orquestrador — análise restrita a estática)*
