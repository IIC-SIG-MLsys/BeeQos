FROM python:3.10-slim

WORKDIR /app
COPY server.py /app/server.py

# 放 TLS 证书（K8s Secret 挂载时用）
RUN mkdir /app/certs

RUN pip3 install -i https://pypi.tuna.tsinghua.edu.cn/simple \
    trio quart quart_trio hypercorn

CMD ["sh", "-c", "python server.py & sleep infinity"]
