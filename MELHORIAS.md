# MELHORIAS — binance_trade_bot_tester

> **Gerado por análise de código em 2026-10-02** · Stack: Python (Flask + SQLAlchemy + Socket.IO + Apprise) · bot de trading para Binance
> Branch `master` · base `524edf7` · 2.078 LOC · **0 testes** · CI presente (`.github/workflows/cicd.yaml`)
>
> **Este arquivo é um plano de execução.** Cada item tem ID, `arquivo:linha`, mudança exata,
> critério de aceite e comando de verificação.
>
> **⚠️ Este projeto executa ordens de compra e venda com dinheiro real.** Os itens classificados P0
> são os que podem levar a perda de dinheiro ou a exposição de credencial de conta de trading.

---

## 0. Como usar este documento

1. Execute na ordem **P0 → P1 → P2 → P3**, respeitando as ondas da §8.
2. Ao terminar um item: marque `- [x]`, rode o **Verificação**, comite `fix(<ID>): descrição`.
3. **Não troque a stack de trading.** O `BinanceAPIManager` + `AutoTrader` + estratégias são o
   núcleo funcional e não foram analisados como reescrita — os itens aqui são de **contorno**
   (exposição da API, segurança do painel, proteção contra ordem duplicada).
4. **Testes:** este repo tem `backtest.py` (simulação), mas **nenhum teste automatizado** — `DEVOPS-03`.
5. **Idioma:** comentários/docs em português (padrão do autor); commits em inglês com
   `fix:`/`feat:`/`docs:`.

---

## 1. Diagnóstico executivo

Bot de trading que roda um loop de *scouting* (observar preço e decidir comprar/vender via ponte
USDT) com persistência em SQLAlchemy e um painel Flask para visualizar histórico de trades.

**O que está bem (não refaça):**

| Item | Evidência |
|---|---|
| Chaves por env com fallback para cfg | `config.py:51-52` (`os.environ.get("API_KEY") or config.get(...)`) |
| Arquivo de exemplo de config presente | `user.cfg.example` (placeholders `sua_api_key_aqui`) |
| Dockerfile copia exemplo se faltar cfg | `Dockerfile` — `RUN test -f user.cfg \|\| cp user.cfg.example user.cfg` |
| `.gitignore` existe (14 linhas) | cobre `user.cfg` — ver `SEC-01` para a exceção |
| Filtro de período parametrizado | `api_server.py:34-45` — não há injeção via `period` |
| Queries ORM (sem SQL concatenado) | `api_server.py:53,58,85,101` — SQLAlchemy com binds |
| Lógica de compra com `min_notional` checado | `auto_trader.py:30-36` |
| CI configurado | `.github/workflows/cicd.yaml` (lint) |

**O que está quebrado — e é dinheiro em jogo:**

1. **O painel Flask não tem autenticação nenhuma** (`api_server.py`): nenhuma rota exige token,
   usuário ou senha. Ele expõe **histórico completo de trades, saldos e pares** de qualquer IP que
   alcance a porta.
2. **CORS `*` e Socket.IO sem restrição** (`api_server.py:18,20`) — qualquer origem pode chamar a
   API e assinar eventos.
3. **`debug=True` em produção** (`api_server.py:153`) — com o debugger do Werkzeug, isso é
   **execução remota de código** na maioria das versões.
4. **A API é publicada na porta 5123 do host** (`docker-compose.yml:26-28`) com `gunicorn -b 0.0.0.0:5123`,
   e um **`sqlitebrowser` ocupa a porta 3000 com o banco de trades** (`docker-compose.yml:36-44`).
   Duas portas expostas, zero autenticação.
5. **`.user.cfg` está versionado** (`git ls-files` o lista) — hoje contém as chaves de **exemplo** do
   projeto upstream (idênticas a `.user.cfg.example`, confirmado por hash), não as suas. O risco é
   **estrutural**: é o arquivo de uso real, e qualquer troca futura por chaves verdadeiras seria
   commitada em silêncio — o `.gitignore` cobre `user.cfg` mas **não** `.user.cfg`.

Nada disso está no `backtest.py` — é infraestrutura de exposição, não de estratégia.

---

## 2. Tabela de prioridades

| ID | Título | Sev | Arquivo | Depende de |
|---|---|---|---|---|
| SEC-01 | `.user.cfg` (arquivo de uso real) está versionado | **P0** | `.user.cfg` | — |
| SEC-02 | Painel Flask sem nenhuma autenticação | **P0** | `api_server.py:17` | — |
| SEC-03 | API publicada em `0.0.0.0:5123` no host | **P0** | `docker-compose.yml:26-28` | SEC-02 |
| SEC-04 | CORS `*` + Socket.IO `cors_allowed_origins="*"` | **P0** | `api_server.py:18,20` | SEC-02 |
| SEC-05 | `sqlitebrowser` publica o banco de trades na porta 3000 | **P1** | `docker-compose.yml:36-44` | — |
| SEC-06 | `debug=True` no `socketio.run` (RCE do Werkzeug) | **P1** | `api_server.py:153` | — |
| SEC-07 | Compose usa a imagem upstream, não o `Dockerfile` local | **P1** | `docker-compose.yml:7,21` | DEVOPS-02 |
| BUG-01 | Sem proteção contra ordem duplicada (idempotência) | **P1** | `auto_trader.py:37-44` | — |
| BUG-02 | `filter_period` devolve `None` para período inválido | **P1** | `api_server.py:28-45` | — |
| BUG-03 | `current_coin()` devolve `None` sem status code | **P1** | `api_server.py:112-115` | — |
| SEC-08 | Log em arquivo com `DEBUG` sem rotação/mascaramento | **P2** | `logger.py:20` | — |
| TEST-01 | Zero testes automatizados | **P1** | *(ausente)* | BUG-02, BUG-03 |
| TEST-02 | Sem teste das estratégias | **P2** | *(ausente)* | TEST-01 |
| DEVOPS-01 | CI usa `ubuntu-20.04` e Python 3.7 (ambos EOL) | **P1** | `.github/workflows/cicd.yaml` | — |
| DEVOPS-02 | `Dockerfile` em `python:3.8-slim` (EOL) | **P1** | `Dockerfile:1,8` | — |
| DEVOPS-03 | Sem `pytest`/suite de testes | **P1** | *(ausente)* | TEST-01 |
| DEVOPS-04 | `runtime.txt` `python-3.8.11` + `Procfile` desatualizados | **P3** | `runtime.txt` | DEVOPS-02 |
| IMP-01 | Sem healthcheck/métrica: bot parado é silencioso | **P2** | *(ausente)* `/health` | SEC-02 |
| DOC-01 | README não avisa sobre o painel exposto | **P2** | `README.md` | SEC-02 |
| DOC-02 | Falta `SECURITY.md` | **P3** | *(ausente)* | — |

**Placar: 4 P0 · 9 P1 · 3 P2 · 2 P3 = 18 itens.**

---

## 3. Segurança
### SEC-01 · `.user.cfg` (arquivo de uso real) está versionado · [P0]

- **Arquivo:** `.user.cfg` (12 linhas)
- **Evidência:** `git ls-files | grep cfg` → `.user.cfg`, `.user.cfg.example`, `user.cfg.example`.
  O `.gitignore:8` ignora **`user.cfg`** (sem ponto), mas o arquivo real em disco se chama
  **`.user.cfg`** (com ponto) — padrões do gitignore não casam com nomes diferentes.
  Verificação de conteúdo: `api_key` e `api_secret_key` têm 64 caracteres e são **idênticos** aos de
  `.user.cfg.example` (hashes iguais) — portanto são as chaves de **exemplo do projeto upstream**
  (`edeng23/binance-trade-bot`), **não** credenciais suas.
- **Impacto:** **não há vazamento ativo de chave real** — registrei isso para não alarmar
  desnecessariamente. O risco é **estrutural e latente**: este é o arquivo que o `config.py:51-52`
  lê quando `API_KEY` não vem do ambiente. Se você editar `.user.cfg` com suas chaves verdadeiras
  (que é exatamente o fluxo esperado de uso), elas serão commitadas no próximo `git add -A` —
  e uma chave de Binance com permissão de trading permite **sacar ou operar** na sua conta.
  Além disso, `.user.cfg.example` traz um par de chaves formatado como reais; quem ler pode
  confundir exemplo com credencial.
- **Mudança:**
  1. `git rm --cached .user.cfg` (tira do índice, **mantém** no disco) e adicionar ao `.gitignore`:
     ```
     user.cfg
     .user.cfg
     .user.cfg.*.bak
     ```
  2. **Nunca** remover do disco o `.user.cfg` local — ele é a sua config.
  3. Trocar as chaves do `.user.cfg.example` por marcadores óbvios:
     `api_key=COLE_SUA_API_KEY_AQUI` / `api_secret_key=COLE_SUA_API_SECRET_AQUI` — evita ambiguidade.
  4. Adicionar checagem de segurança: se as chaves do `.user.cfg` forem iguais às do example, o bot
     **recusa subir** (defesa contra o Dockerfile fazer `cp user.cfg.example user.cfg`).
- **Aceite:** `.user.cfg` não está no índice; `.gitignore` cobre o nome com ponto; example tem
  placeholder inequívoco.
- **Verificação:**
  ```bash
  git ls-files | grep -x '.user.cfg' && echo 'FALHA: ainda versionado' || echo 'OK'
  git check-ignore -q .user.cfg && echo 'OK: ignorado'
  grep -q 'COLE_SUA_API_KEY_AQUI' user.cfg.example && echo 'OK: placeholder novo'
  ```

### SEC-02 · Painel Flask sem nenhuma autenticação · [P0]

- **Arquivo:** `binance_trade_bot/api_server.py` (15 linhas de rotas, nenhuma de auth)
- **Evidência:** `grep -n 'auth\|token\|before_request\|login' api_server.py` → **nenhum resultado**.
  As 9 rotas públicas (`value_history`, `total_value_history`, `trade_history`,
  `scouting_history`, `current_coin`, `current_coin_history`, `coins`, `pairs`, `usage`) são
  registradas com `@app.route(...)` puro e não têm middleware algum. O `app = Flask(__name__)` da
  linha 17 não é protegido por nada.
- **Impacto:** **qualquer pessoa que alcance a porta 5123** lê: histórico **completo de trades**
  (linhas 81-90 — ativo, preço, quantidade, data), **saldo** (`total_value_history`, linhas 65-78 —
  soma de `btc_value` e `usd_value`), e a **moeda que o bot está segurando agora** (`current_coin`,
  linha 112). Isso é: dinheiro em custódia + histórico de operações + posição atual, tudo sem senha.
  Serve ainda de **alvo para golpe**: saber a posição do bot permite antecipar o movimento do mercado
  de quem o observa (o valor é público por aqui).
- **Mudança:**
  1. Exigir token: middleware `before_request` comparando um token de longa duração vindo de env
     (`API_TOKEN`), no header `Authorization: Bearer ...`. Falha → `401`.
  2. Rotas de Socket.IO: `cors_allowed_origins` já coberto pelo `SEC-04`, mas o namespace
     `/backend` (linha 147) também precisa de handshake autenticado.
  3. **Não expor a porta por padrão** — ver `SEC-03`.
- **Aceite:** `GET /api/trade_history` sem token → `401`; com token válido → `200`.
- **Verificação:**
  ```bash
  curl -s -o /dev/null -w '%{http_code}\n' http://localhost:5123/api/trade_history      # 401
  curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $API_TOKEN" \
    http://localhost:5123/api/trade_history                                             # 200
  ```

### SEC-03 · API publicada em `0.0.0.0:5123` no host · [P0]

- **Arquivo:** `docker-compose.yml:26-28`
- **Evidência:**
  ```yaml
  api:
    ports:
      - 5123:5123
    command: gunicorn binance_trade_bot.api_server:app -k eventlet -w 1 --threads 1 -b 0.0.0.0:5123
  ```
  `ports:` (não `expose:`) publica a porta em **todas** as interfaces do host, e o `gunicorn -b 0.0.0.0`
  escuta em tudo dentro do container também.
- **Impacto:** combinado com o `SEC-02` (zero auth), isso transforma o painel de trades em serviço
  **público** na máquina. Num servidor com porta 5123 liberada no firewall (ou atrás de um reverse
  proxy mal configurado), qualquer um da internet vê seus saldos e histórico. Mesmo numa LAN,
  qualquer host da rede acessa.
- **Mudança:** (1) por padrão, remover `ports:` e deixar só `expose:` (acessível apenas de dentro da
  rede do compose); (2) se precisar de acesso externo, publicar só em loopback:
  `ports: ["127.0.0.1:5123:5123"]`; (3) exigir o token do `SEC-02` mesmo assim; (4) documentar no
  README como acessar de forma segura (SSH tunnel).
- **Aceite:** `ss -lntp | grep 5123` **não** mostra `0.0.0.0` no host; fora da rede do compose, a
  porta não responde.
- **Verificação:**
  ```bash
  docker compose up -d api && sleep 4
  ss -lntp | grep 5123     # esperado: ausente, ou 127.0.0.1 apenas
  curl -s --max-time 3 http://localhost:5123/api/coins || echo 'OK: nao responde fora'
  ```

### SEC-04 · CORS `*` e Socket.IO sem restrição de origem · [P0]

- **Arquivo:** `binance_trade_bot/api_server.py:18` e `:20`
- **Evidência:**
  ```python
  cors = CORS(app, resources={r"/api/*": {"origins": "*"}})
  socketio = SocketIO(app, cors_allowed_origins="*")
  ```
- **Impacto:** com `origins: "*"`, **qualquer página da web** pode fazer requisições autenticadas
  (ou não) para a API a partir do navegador do próprio operador. Se o operador abrir um site
  malicioso com o painel aberto, o atacante lê saldos e histórico via `fetch` (com o token, se ele
  estiver no localStorage, é roubo direto). O Socket.IO com `cors_allowed_origins="*"` permite que
  qualquer origem assine o namespace `/backend` e receba os eventos de atualização de trade.
- **Mudança:** (1) restringir a origem explícita via env (`PANEL_ORIGIN`, ex.:
  `http://localhost:3000`); (2) trocar `cors_allowed_origins="*"` por lista concreta;
  (3) se não houver front separado, desativar CORS totalmente (mesma origem) — o `SEC-02` já exige
  token, e CORS aberto só alarga a superfície.
- **Aceite:** resposta a `Origin: https://evil.example` **não** traz
  `Access-Control-Allow-Origin`.
- **Verificação:**
  ```bash
  curl -sI http://localhost:5123/api/coins -H 'Origin: https://evil.example' \
    | grep -i 'access-control-allow-origin'   # nao deve aparecer
  ```
### SEC-05 · `sqlitebrowser` publica o banco de trades na porta 3000 · [P1]

- **Arquivo:** `docker-compose.yml:36-44`
- **Evidência:**
  ```yaml
  sqlitebrowser:
    image: ghcr.io/linuxserver/sqlitebrowser
    volumes:
      - ./data/config:/config
      - ./data:/data
    ports:
      - 3000:3000
  ```
  O serviço monta `./data` (onde fica `data/crypto_trading.db`, conforme
  `database.py:19`: `sqlite:///data/crypto_trading.db`) e publica a porta **3000** no host.
- **Impacto:** um **cliente gráfico de SQLite** exposto na porta 3000 com o banco de trades montado.
  Diferente da API (`SEC-02`), isso costuma permitir **escrita** direta no banco — alterar registros
  de trade, apagar histórico ou corromper o arquivo. Combinado com a falta de auth geral, é o caminho
  mais curto para adulterar dados de operação. Além disso o `linuxserver/sqlitebrowser` é uma imagem
  de UI pesada que não precisa rodar o tempo todo.
- **Mudança:** (1) remover o serviço da composição padrão e torná-lo opt-in
  (profile `debug`, algo como `docker compose --profile debug up sqlitebrowser`); (2) se mantido,
  publicar só em loopback `127.0.0.1:3000:3000`; (3) nunca montar `./data` em serviço de UI exposto
  — usar cópia temporária quando precisar inspecionar.
- **Aceite:** `docker compose up -d` **não** sobe o `sqlitebrowser`; quando sobe pelo profile, fica
  em `127.0.0.1`.
- **Verificação:**
  ```bash
  docker compose up -d && sleep 4
  docker ps --format '{{.Names}}' | grep -q sqlitebrowser && echo 'FALHA: sobe por padrao' || echo 'OK'
  ss -lntp | grep 3000   # ausente (ou 127.0.0.1 no profile debug)
  ```

### SEC-06 · `debug=True` no `socketio.run` · [P1]

- **Arquivo:** `binance_trade_bot/api_server.py:153`
- **Evidência:**
  ```python
  if __name__ == "__main__":
    socketio.run(app, debug=True, port=5123)
  ```
- **Impacto:** **precisão importante:** no `docker-compose.yml:28` o serviço usa
  `gunicorn ... api_server:app`, então **esse bloco não roda em produção** — o `debug=True` só
  vale para `python -m binance_trade_bot.api_server` (execução direta/local). Ainda assim é perigoso
  porque: (a) é o caminho documentado para rodar localmente; (b) com `debug=True`, o Werkzeug ativa
  o **interactive debugger**, que permite execução de código via console na página de erro; (c) se
  alguém trocar o gunicorn por `python ... api_server.py` (mudança de 1 linha), vira RCE imediata.
  Não é o P0 que a primeira leitura sugere, mas é um pronta-bomba.
- **Mudança:** ler de env: `debug=os.environ.get("FLASK_DEBUG", "0") == "1"`, com default **False**;
  adicionar comentário explícito de que o debugger nunca deve estar ativo com a porta publicada.
- **Aceite:** rodar `python -m binance_trade_bot.api_server` inicia com debugger **desligado**.
- **Verificação:**
  ```bash
  grep -n 'debug=True' binance_trade_bot/api_server.py && echo 'FALHA' || echo 'OK'
  python -m binance_trade_bot.api_server & sleep 3
  curl -s http://localhost:5123/rota-inexistente | grep -qi 'werkzeug debugger' && echo FALHA || echo OK
  ```

### SEC-07 · Compose usa a imagem upstream, não o `Dockerfile` local · [P1]

- **Arquivo:** `docker-compose.yml:7` e `:21` (`image: edeng23/binance-trade-bot`)
- **Evidência:** os dois serviços (exceto `sqlitebrowser`) usam `image: edeng23/binance-trade-bot`,
  **sem** bloco `build:`. O `Dockerfile` local (18 linhas) portanto **não é usado** por nenhum
  serviço do compose.
- **Impacto:** qualquer correção feita no `Dockerfile` local é **silenciosamente ignorada** —
  incluindo o `DEVOPS-02` (python 3.8 → 3.11) e o `SEC-01` (checagem de chave placeholder). Pior:
  a imagem upstream pode ser atualizada (ou comprometida, caso o repositório original mude de
  dono) e você puxa **código que não auditou** num bot com suas chaves de trading. Também explica
  por que o `user.cfg` é montado via volume — a imagem não conhece o seu estado.
- **Mudança:** (1) trocar `image: edeng23/binance-trade-bot` por
  `build: { context: . }` (mantendo `image:` com nome local, ex.: `binance-trade-bot:local`);
  (2) puxar a imagem upstream só se houver decisão explícita de seguir o fork original; (3) se
  manter a upstream, fixar por **digest** (`image: edeng23/binance-trade-bot@sha256:...`).
- **Aceite:** `docker compose config` mostra `build` apontando para este diretório; a imagem rodada
  é a construída localmente.
- **Verificação:**
  ```bash
  docker compose config | grep -E 'image|build' | head
  # a imagem em uso deve ser local:
  docker inspect binance_trader --format '{{.Config.Image}}'
  ```

### SEC-08 · Log em arquivo com `DEBUG` e sem rotação · [P2]

- **Arquivo:** `binance_trade_bot/logger.py:20-24`
- **Evidência:**
  ```python
  self.Logger.setLevel(logging.DEBUG)
  fh = logging.FileHandler(f"logs/{logging_service}.log")
  fh.setLevel(logging.DEBUG)
  ```
  Sem `RotatingFileHandler`, sem formato de data no nome e sem mascaramento. O `docker-compose.yml:17`
  monta `./logs` como volume persistente.
- **Impacto:** (a) o arquivo cresce **sem limite** enquanto o bot roda 24/7 — esgota disco e para o
  bot no meio de uma operação (disco cheio = escrita de `crypto_trading.db` falha);
  (b) nível `DEBUG` grava tudo, incluindo payloads de requisição à Binance — se algum erro de
  exceção vazar cabeçalho `X-MBX-APIKEY`, a chave vai para o arquivo; (c) `./logs` é volume persistente
  e **não** está no `.gitignore` de forma explícita (só `*.log` cobre os arquivos, não o diretório).
- **Mudança:** (1) `RotatingFileHandler` com `maxBytes=10*1024*1024, backupCount=5`; (2) arquivo em
  `DEBUG` só quando `LOG_LEVEL=debug`; (3) filtro que redige `X-MBX-APIKEY`, `api_key` e `secret` em
  qualquer mensagem; (4) alerta de disco.
- **Aceite:** o log não passa de 10 MB + 5 backups; nenhuma chave aparece em `grep` no diretório.
- **Verificação:**
  ```bash
  grep -rn 'X-MBX-APIKEY\|api_key\|api_secret' logs/ && echo 'FALHA: segredo no log' || echo 'OK'
  grep -n 'RotatingFileHandler' binance_trade_bot/logger.py   # deve existir
  ```
---

## 4. Bugs e defeitos funcionais

### BUG-01 · Sem proteção contra ordem duplicada (idempotência) · [P1]

- **Arquivo:** `binance_trade_bot/auto_trader.py:37-44`
- **Evidência:**
  ```python
  if can_sell and self.manager.sell_alt(pair.from_coin, self.config.BRIDGE) is None:
      self.logger.info("Couldn't sell, going back to scouting mode...")
      return None
  result = self.manager.buy_alt(pair.to_coin, self.config.BRIDGE)
  if result is not None:
      self.db.set_current_coin(pair.to_coin)
  ```
  Não há checagem de ordem já em andamento, nem lock, nem verificação de `orderId` existente. O
  `database.py:274` (`set_ordered`) guarda estado, mas nada impede o loop de chamar
  `transaction_through_bridge` de novo antes do `set_complete` (linha 284).
- **Impacto:** em bot de trading, ordem duplicada = **dinheiro duplicado em posição errada**. Se o
  ciclo roda duas vezes (restart, timeout de rede, exceção capturada fora), o bot vende e compra
  **duas vezes**, pagando spread e taxa duas vezes, e pode acabar com posição que a estratégia não
  previa. Como `buy_alt` é assíncrono em relação ao estado local (rede), a janela existe.
- **Mudança:** (1) **lock de máquina de estados**: só entrar em `transaction_through_bridge` se
  não houver ordem `ordered` sem `complete` (usar `set_ordered`/`set_complete` que já existem em
  `database.py:274,284`); (2) guardar `clientOrderId` gerado de forma determinística (hash do par +
  timestamp arredondado) e rejeitar se a Binance devolver a mesma; (3) `try/except` com rollback do
  estado em falha intermediária, para não ficar "preso" vendido sem comprar.
- **Aceite:** forçar duas chamadas consecutivas de `transaction_through_bridge` → só **uma** ordem é
  enviada.
- **Verificação:**
  ```bash
  # com mock do manager contando chamadas:
  python -m pytest tests/test_idempotencia.py -q   # apos TEST-01
  # ou manual: reiniciar o bot no meio de uma ordem e conferir que nao há 2 ordens no banco
  sqlite3 data/crypto_trading.db 'select count(*) from trade_log where id = <id>;'
  ```

### BUG-02 · `filter_period` devolve `None` para período inválido · [P1]

- **Arquivo:** `binance_trade_bot/api_server.py:28-45`
- **Evidência:** a função tem `if period == "all": return query` (linha 31) e depois quatro
  `if "x" in period: return ...` (linhas 36-45). **Não há `return` final**. Chamada com
  `?period=xyz`, nenhum `if` casa e a função cai no fim → devolve `None` (o próprio `# pylint:` da
  linha 28 admite: `inconsistent-return-statements`).
- **Impacto:** `query = filter_period(query, CoinValue)` vira `None` na sequência (linha 55), e a
  linha seguinte `query.filter(...)`/`query.all()` lança `AttributeError: 'NoneType' object has no
  attribute 'filter'` → **500**. É um crash trivial por parâmetro de URL: qualquer um com a porta
  aberta (`SEC-03`) derruba o handler. Note também o bug silencioso da linha 34:
  `re.search(r"(\d*)[shdwm]", "1d")` — a regex é aplicada à **string literal `"1d"`**, não à
  `period` variável, então `num` é **sempre 1** (o período `10d` conta como 1 dia).
- **Mudança:** (1) devolver `query` no final (fallback `all`); (2) validar `period` contra
  `re.fullmatch(r"\d+[shdwm]", period)` e devolver `400` se inválido; (3) **corrigir a regex para
  usar `period`** e não `"1d"` — provavelmente a causa original era evitar erro de regex vazia;
  (4) tratar `period` vazio.
- **Aceite:** `?period=xyz` → `400`; `?period=10d` filtra **10 dias** (não 1); `?period=all` inalterado.
- **Verificação:**
  ```bash
  for p in all 10d xyz '' 7h; do
    curl -s -o /dev/null -w "period=$p -> %{http_code}\n" \
      "http://localhost:5123/api/value_history?period=$p" -H "Authorization: Bearer $API_TOKEN"
  done
  # all/10d/7h -> 200 ; xyz -> 400 ; nunca 500
  ```

### BUG-03 · `current_coin()` devolve `None` sem status code · [P1]

- **Arquivo:** `binance_trade_bot/api_server.py:112-115`
- **Evidência:**
  ```python
  @app.route("/api/current_coin")
  def current_coin():
      coin = db.get_current_coin()
      return coin.info() if coin else None
  ```
  Quando `coin` é `None` (bot sem posição ainda), a função devolve `None`. Flask não sabe serializar
  `None` como resposta de corpo — dependendo da versão, lança `TypeError` ou devolve `200` vazio.
- **Impacto:** logo após o primeiro start (antes de qualquer compra) a rota **falha ou responde
  vazio**, e o front que espera objeto não sabe se é erro ou "sem posição". É o estado **mais comum**
  de um bot recém-ligado, então é o caminho feliz que quebra. Sem status code, o cliente não
  distingue `404` (nada aposentado) de `500` (falha real).
- **Mudança:** devolver status explícito e shape estável:
  ```python
  coin = db.get_current_coin()
  if coin is None:
      return jsonify({"status": "empty", "coin": None}), 200   # ou 404, documentar
  return jsonify(coin.info()), 200
  ```
  (Alinhado ao `IMP-02`: contrato de resposta uniforme em todas as rotas.)
- **Aceite:** com bot sem posição, `GET /api/current_coin` devolve `200` + JSON `{"status":"empty"}`.
- **Verificação:**
  ```bash
  rm -f data/crypto_trading.db   # estado limpo (cuidado: só em dev)
  curl -s -o /dev/null -w '%{http_code}\n' http://localhost:5123/api/current_coin \
    -H "Authorization: Bearer $API_TOKEN"      # 200, com corpo JSON
  curl -s http://localhost:5123/api/current_coin -H "Authorization: Bearer $API_TOKEN" | jq .status
  ```

---

## 5. Qualidade: testes, arquitetura e observabilidade

### TEST-01 · Zero testes automatizados · [P1]

- **Arquivo:** *(ausente)* — `find . -name 'test*'` só devolve `backtest.py` (simulação de estratégia,
  não é teste unitário) e `.github/workflows/cicd.yaml` não roda nenhum teste (só `Lint`).
- **Evidência:** não existe `tests/`, nem `pytest` em `requirements.txt`/`dev-requirements.txt`, nem
  etapa de teste no workflow. O `docker-compose.yml` também não tem serviço de teste.
- **Impacto:** para um bot que **executa ordens com dinheiro real**, não haver rede de segurança
  é inaceitável. Os bugs `BUG-02` e `BUG-03` são exatamente do tipo que um `pytest` pegaria em
  segundos (chamar a função com entrada inválida). Sem teste, toda mudança de estratégia ou de
  API da Binance é validada **na coragem**.
- **Mudança:** criar `tests/` com `pytest`, cobrindo primeiro o que é barato e determinístico:
  | Caso | Assertivo |
  |---|---|
  | `filter_period` com `all`, `10d`, `xyz`, vazio | `query` nunca `None`; `xyz` → erro |
  | `current_coin()` sem posição | `200` + `{"status":"empty"}` |
  | `Config` sem `API_KEY` | falha explícita (ligar ao `SEC-01`) |
  | `Logger` com mensagem contendo `api_key` | redigido no arquivo de log |
  | `transaction_through_bridge` duas vezes | **1** ordem (idempotência, `BUG-01`) |
  | `set_ordered` sem `set_complete` | nova chamada é bloqueada |
  Adicionar `pytest` ao `dev-requirements.txt` e etapa `test` no `cicd.yaml`.
- **Aceite:** `pytest` roda no CI e falha se qualquer um dos bugs acima regressar.
- **Verificação:**
  ```bash
  pip install -r dev-requirements.txt && pytest -q    # todos passam
  # reintroduzir o return None do BUG-02 -> pytest deve FALHAR
  ```

### TEST-02 · Sem teste das estratégias de trading · [P2]

- **Arquivo:** *(ausente)* · lógica em `binance_trade_bot/strategies/default_strategy.py` (65 linhas)
  e `multiple_coins_strategy.py` (46 linhas)
- **Evidência:** as estratégias são o coração do bot e não têm teste algum. O `backtest.py` simula
  histórico, mas não é executado no CI (`cicd.yaml` só tem lint) e não cobre as funções de decisão
  unitariamente.
- **Impacto:** a regra que decide **comprar ou vender** é a mais crítica do sistema e a menos
  testada. Um refactor aparentemente inofensivo em `default_strategy.py` pode inverter a condição de
  venda e ninguém percebe até perder dinheiro.
- **Mudança:** testes unitários com dados sintéticos (sem rede, mock de `get_ticker_price`):
  (1) limiar de compra atingido → sinal de compra; (2) abaixo do limiar → nada; (3) `scout_margin`
  vs `scout_multiplier` respeitam `use_margin`; (4) moeda sem preço → não opera (não devia
  `NoneType`). Adicionar ao `pytest` do `TEST-01`.
- **Aceite:** as 4 situações de decisão têm teste; cobertura das estratégias medida (>80% da lógica).
- **Verificação:**
  ```bash
  pytest tests/test_strategy.py -q --cov=binance_trade_bot/strategies
  ```

### IMP-01 · Sem métricas de saúde do bot · [P2]

- **Arquivo:** *(ausente)* — `logger.py` escreve em arquivo/console/notificação, mas não expõe métrica
- **Evidência:** não há `/metrics`, nem contador de ordens, nem alerta de "bot parado". O
  `NotificationHandler` (`notifications.py`) só notifica eventos de negócio (via Apprise), não saúde.
- **Impacto:** um bot 24/7 que **para no meio da noite** (exceção, disco cheio, Binance fora) é
  detectado só quando o operador olha — ou quando nota o saldo parado. Para operação contínua,
  ausência de healthcheck é perda silenciosa de oportunidade e de proteção de posição.
- **Mudança:** (1) healthcheck simples em `api_server` (`/health` com timestamp do último ciclo do
  bot e `stale` se > 2× `scout_sleep_time`); (2) notificação Apprise quando o ciclo falha N vezes
  seguidas; (3) alerta de disco cheio (ligado ao `SEC-08`); (4) expor contadores básicos
  (ordens_executadas, erros_api) no `/health`.
- **Aceite:** derrubar a Binance por 5 min → chega notificação; `/health` reporta `stale`.
- **Verificação:**
  ```bash
  curl -s localhost:5123/health -H "Authorization: Bearer $API_TOKEN" | jq '{status,last_cycle,stale}'
  # simular erro de API e ver a notificacao chegar
  ```
---

## 6. DevOps / Infra

### DEVOPS-01 · CI em `ubuntu-20.04` e Python 3.7 (ambos EOL) · [P1]

- **Arquivo:** `.github/workflows/cicd.yaml` (`runs-on: ubuntu-20.04`, `python-version: 3.7`)
- **Evidência:** o workflow usa `actions/checkout@v2` e `actions/setup-python@v2` (ambos desatualizados)
  sobre `ubuntu-20.04` (EOL desde abril/2024) e Python **3.7** (EOL desde junho/2023).
- **Impacto:** runner sem patch de segurança e interpreter sem correção; ações v2 usam `node16`,
  que o GitHub já descontinuou (podem parar de funcionar). O lint roda numa base incompatível com o
  código real (o `Dockerfile` usa 3.8, o CI testa 3.7) — o CI **não representa** o ambiente de
  produção.
- **Mudança:** (1) `runs-on: ubuntu-latest`; (2) `python-version: '3.11'` (alinhado ao `DEVOPS-02`);
  (3) `actions/checkout@v4`, `actions/setup-python@v5`, `dorny/paths-filter@v3`; (4) adicionar etapa
  de teste (liga ao `TEST-01`) além do lint.
- **Aceite:** CI verde em runner atual e Python alinhado ao Dockerfile.
- **Verificação:**
  ```bash
  grep -E 'runs-on|python-version|uses: actions/' .github/workflows/cicd.yaml
  # sem ubuntu-20.04, sem python 3.7, actions em @v4/@v5
  ```

### DEVOPS-02 · `Dockerfile` em `python:3.8-slim` (EOL) · [P1]

- **Arquivo:** `Dockerfile:1` e `:8` (`FROM python:3.8-slim`)
- **Evidência:** Python 3.8 está **fora de suporte desde outubro/2024**; a imagem `3.8-slim` não
  recebe mais patches de segurança. O `requirements.txt` é instalado sem pin de hash.
- **Impacto:** o bot roda com interpreter sem correção de segurança — e este bot **carrega chaves de
  API de trading** e faz requisições a serviço financeiro. Qualquer CVE no runtime Python ou numa
  dependência transitiva permanece aberto. Agravante: o `SEC-07` mostra que este `Dockerfile` nem é
  usado pelo compose (que puxa a imagem upstream), então há **duas** bases possíveis, ambas desatualizadas.
- **Mudança:** (1) `FROM python:3.12-slim` (LTS da casa) em ambas as estágias; (2) pinar dependências
  com `pip install --require-hashes` (gerar `requirements.txt` a partir de `pip freeze`);
  (3) `USER nonroot` (hoje roda como root — `COPY . .` sem `USER`); (4) **alinhar ao `SEC-07`** para
  que o compose de fato use esta imagem.
- **Aceite:** imagem em Python 3.12, processo não-root, `docker compose config` usando `build` local.
- **Verificação:**
  ```bash
  docker build -t btb . && docker run --rm btb python -V     # 3.12.x
  docker run --rm --entrypoint id btb                        # nao-root
  ```

### DEVOPS-03 · Sem `pytest`/suite de testes · [P1]

- **Arquivo:** *(ausente)* `tests/` · `dev-requirements.txt` sem `pytest`
- **Evidência:** `grep -i pytest dev-requirements.txt requirements.txt` → nada; não existe diretório
  `tests/`. É a mesma lacuna do `TEST-01`, vista do lado de infra: nem a dependência nem a
  estrutura existem.
- **Impacto:** sem `pytest` instalado, o `TEST-01` e o `TEST-02` não podem ser executados nem no CI
  nem localmente. É bloqueio de cadeia: `TEST-01` depende deste item.
- **Mudança:** (1) `pytest`, `pytest-cov`, `responses` (para mock HTTP da Binance) em
  `dev-requirements.txt`; (2) `tests/__init__.py` + `pytest.ini`/`pyproject` com `testpaths = tests`;
  (3) etapa `test` no `cicd.yaml` (após o `DEVOPS-01`).
- **Aceite:** `pytest` roda e encontra a suite; CI executa antes do lint falhar.
- **Verificação:**
  ```bash
  pip install -r dev-requirements.txt && pytest --collect-only -q
  ```

### DEVOPS-04 · `runtime.txt` e `Procfile` desatualizados · [P3]

- **Arquivo:** `runtime.txt` (`python-3.8.11`), `Procfile` (`web: python -m binance_trade_bot`)
- **Evidência:** `runtime.txt` fixa **Python 3.8.11** (patch de 2021, EOL); `Procfile` declara processo
  `web` rodando o bot (não o `api_server`), enquanto `docker-compose.yml:28` roda o `api_server` via
  gunicorn. Há **duas** definições de processo divergentes.
- **Impacto:** quem fizer deploy via Heroku/Procfile usa Python EOL e **não sobe o painel** (o
  `api_server` fica órfão); quem usa compose não usa o Procfile. Fonte de confusão operacional e
  mais um lugar onde o interpreter desatualizado sobrevive.
- **Mudança:** (1) `runtime.txt` → `python-3.12.x` (ou remover, deixando o `Dockerfile` decidir);
  (2) declarar `web` e `worker` explicitamente se Heroku continuar sendo alvo, ou **remover**
  `Procfile`/`runtime.txt` se o compose for o único caminho; (3) documentar qual é o método oficial.
- **Aceite:** um único caminho de deploy documentado; nenhum pin para Python EOL.
- **Verificação:**
  ```bash
  grep -R '3\.8' runtime.txt Dockerfile .github/workflows/ 2>/dev/null || echo 'OK: sem pin 3.8'
  ```

---

## 7. Documentação

### DOC-01 · README não avisa sobre o painel exposto · [P2]

- **Arquivo:** `README.md` (197 linhas)
- **Evidência:** o README explica instalação e configuração de chaves, mas não menciona que o
  `docker-compose.yml` publica a **porta 5123** (API com trades/saldos) e a **porta 3000**
  (`sqlitebrowser` com o banco), nem que o painel **não tem autenticação**.
- **Impacto:** quem sobe `docker compose up -d` conforme o README expõe dados financeiros sem saber.
  É o item de documentação de maior consequência desta lista — o README está desatualizado em
  relação ao próprio compose.
- **Mudança:** seção "Acesso e segurança" listando: portas expostas, ausência de auth (até o
  `SEC-02`/`SEC-03` serem feitos), como restringir a `127.0.0.1`, e o token de acesso; mais aviso
  de que `.user.cfg` **não deve** ser commitado (liga ao `SEC-01`).
- **Aceite:** quem lê o README sabe que precisa restringir a porta antes de usar em rede.
- **Verificação:** `grep -n '5123\|127.0.0.1\|autentic' README.md` retorna a seção.

### DOC-02 · Falta `SECURITY.md` · [P3]

- **Arquivo:** *(ausente)* `SECURITY.md`
- **Evidência:** o repositório tem `LICENSE` (GPL) mas nenhum guia de reporte de vulnerabilidade.
- **Impacto:** num bot de dinheiro real, um pesquisador que encontre algo (ex.: o painel aberto do
  `SEC-02`) não tem canal para reportar. As decisões de segurança também não ficam registradas.
- **Mudança:** criar com: canal de reporte; threat model (chave de API roubada, painel exposto,
  ordem duplicada, log com segredo); e a regra de que **segredos nunca vão para o Git** (o `SEC-01`
  é a prova de que isso já falhou uma vez).
- **Aceite:** arquivo existe com canal de reporte e as 4 ameaças mapeadas.
- **Verificação:** `ls SECURITY.md && grep -cE 'report|ameaca|chave' SECURITY.md`

---

## 8. Ordem de execução (waves)

### Wave 1 — Parar exposição de dados financeiros (P0)
1. **`SEC-01`** — tirar `.user.cfg` do índice e blindar o `.gitignore` (rápido e irreversível).
2. **`SEC-03`** — tirar as portas `5123`/`3000` de `0.0.0.0` (loopback ou só `expose`).
3. **`SEC-02`** — exigir token no painel.
4. **`SEC-04`** — restringir CORS e origem do Socket.IO.

> Depois da Wave 1, saldos e histórico deixam de estar a qualquer um na rede.

### Wave 2 — Blindar a operação (P1)
5. **`SEC-05`** — `sqlitebrowser` opt-in, nunca com `./data` exposto.
6. **`SEC-07`** — fazer o compose usar o `Dockerfile` local (sem imagem upstream não auditada).
7. **`BUG-01`** — idempotência de ordem (o item de dinheiro mais direto).
8. **`BUG-02`** e **`BUG-03`** — `filter_period` e `current_coin` (crash por parâmetro).
9. **`SEC-06`** — `debug=False` por default.
10. **`DEVOPS-01`**, **`DEVOPS-02`**, **`DEVOPS-03`** — CI e imagem em versão suportada + pytest.
11. **`TEST-01`** — rede de segurança dos itens 7-8.

### Wave 3 — Qualidade (P2)
12. **`SEC-08`** — rotação e mascaramento de log.
13. **`TEST-02`**, **`IMP-01`** — testes de estratégia e healthcheck.
14. **`DOC-01`** — README com portas e segurança.

### Wave 4 — Higiene (P3)
15. **`DEVOPS-04`**, **`DOC-02`**.

**Dependências que não podem ser invertidas:**
`SEC-03` antes de `SEC-02` (não faz sentido autenticar porta pública — feche primeiro) ·
`SEC-07` antes de `DEVOPS-02` (corrigir o `Dockerfile` só importa se ele for usado) ·
`DEVOPS-03` antes de `TEST-01`/`TEST-02` (sem `pytest` não há suite) ·
`BUG-02` antes de `TEST-01` (o teste precisa do comportamento correto como alvo).

---

## 9. Fora de escopo / riscos

| Item | Decisão | Motivo |
|---|---|---|
| Reescrever a estratégia de trading | **Não** | O `AutoTrader`/estratégias são o produto e não apresentaram defeito comprovado. `TEST-02` cobre sem reescrever. |
| Trocar Flask/FastAPI | **Não** | O painel é pequeno e a falha é de auth, não de framework. |
| Substituir Binance por outra corretora | **Não** | Fora do escopo. |
| Remover o `sqlitebrowser` do repositório | **Não, ainda** | Torná-lo opt-in resolve o risco sem perder a utilidade de inspeção (`SEC-05`). |
| Usar API key com permissão de saque | **Nunca** | Regra de operação: a chave do bot deve ter **apenas permissão de trade**, sem saque e sem transferência. |

**Riscos desta execução:**

- **`SEC-01` exige cuidado com o arquivo local.** `git rm --cached` tira do Git **mas mantém em
  disco** — nunca use `git rm` sem `--cached`, senão apaga a sua config. Confirme o disco antes.
- **`SEC-03`/`SEC-05` podem quebrar acesso legítimo.** Se você usa o painel de outra máquina, mover
  para `127.0.0.1` exige tunnel (SSH). Mapear como você acessa antes de fechar.
- **`SEC-07` muda a imagem em uso.** Passar da upstream para a local altera versões de dependência;
  valide o boot **antes** de deixar o bot rodar sozinho — não troque imagem com o bot operando.
- **`BUG-01` mexe no caminho de execução de ordem.** Teste em modo simulado (o próprio `backtest.py`)
  antes de aplicar em conta real; idempotência mal feita pode **bloquear** ordens legítimas.
- **`DEVOPS-02` (Python 3.12) pode quebrar `eventlet`.** O compose usa `-k eventlet`, que é
  problemático em Python ≥3.12 — avaliar trocar para `gthread`/`uvicorn` e validar o Socket.IO.

---

## 10. Definição de pronto (DoD)

**Segurança**
- [ ] `SEC-01` — `.user.cfg` fora do índice e ignorado; example com placeholder inequívoco
- [ ] `SEC-02` — painel exige `Authorization: Bearer`
- [ ] `SEC-03` — portas fora de `0.0.0.0` (loopback ou só `expose`)
- [ ] `SEC-04` — CORS e Socket.IO com origem explícita
- [ ] `SEC-05` — `sqlitebrowser` opt-in e em loopback
- [ ] `SEC-06` — `debug` False por default
- [ ] `SEC-07` — compose usa `build` local, sem imagem upstream não auditada
- [ ] `SEC-08` — log com rotação e sem segredos

**Funcional**
- [ ] `BUG-01` — duas chamadas de trade geram **1** ordem
- [ ] `BUG-02` — `period=xyz` → 400; `period=10d` filtra 10 dias
- [ ] `BUG-03` — `current_coin` sem posição → 200 + JSON

**Testes e infra**
- [ ] `TEST-01` — `pytest` com os 6 casos críticos no CI
- [ ] `TEST-02` — estratégias testadas (>=80% da lógica)
- [ ] `DEVOPS-01` — CI em runner atual, Python 3.11+, actions v4/v5
- [ ] `DEVOPS-02` — imagem Python 3.12 e processo não-root
- [ ] `DEVOPS-03` — `pytest` em `dev-requirements.txt`
- [ ] `DEVOPS-04` — sem pin para Python EOL

**Operação e documentação**
- [ ] `IMP-01` — `/health` com `stale` e notificação de falha
- [ ] `DOC-01` — README lista portas e como restringir
- [ ] `DOC-02` — `SECURITY.md` com threat model

**Validação final:**
```bash
pytest -q
docker compose config -q
ss -lntp | grep -E '5123|3000'    # nao deve mostrar 0.0.0.0
git ls-files | grep -x '.user.cfg' || echo 'OK: cfg fora do git'
```

---

*Fim do plano. Gerado por leitura direta do código em 2026-10-02. Nenhum item já estava corrigido*
*— todos apontam para defeitos ainda presentes. Nota: verifiquei que o `.user.cfg` contém as chaves*
*de exemplo do upstream, não chaves reais — o item `SEC-01` é preventivo, não remediativo.*
