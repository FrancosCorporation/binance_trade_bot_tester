FROM python:3.8-slim AS builder

WORKDIR /install

RUN apt-get update && apt-get install -y rustc

COPY requirements.txt /requirements.txt
RUN pip install --prefix=/install -r /requirements.txt

FROM python:3.8-slim

WORKDIR /app

COPY --from=builder /install /usr/local
COPY . .
RUN test -f user.cfg || cp user.cfg.example user.cfg

CMD ["python", "-m", "binance_trade_bot"]
