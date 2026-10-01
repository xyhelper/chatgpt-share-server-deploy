#!/bin/bash

set -e

docker compose pull
docker compose up -d --remove-orphans

## chatgpt-web-ui 以 share 模式运行时,FAKE_TOKEN_SECRET 用于签发 access token。
## 默认值等同于公开密钥,可被伪造任意账号的登录态,这里做一次提醒。
if grep -q 'change-me-to-a-random-secret' docker-compose.yml; then
  echo "警告: chatgpt-web-ui 的 FAKE_TOKEN_SECRET 仍是默认值,建议改为随机值"
  echo "      SECRET=\$(openssl rand -hex 32) && sed -i \"s/change-me-to-a-random-secret/\$SECRET/\" docker-compose.yml"
  echo "      修改后执行 docker compose up -d chatgpt-web-ui 生效"
fi
