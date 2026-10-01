#!/bin/bash
set -e

## 克隆仓库到本地
echo "clone repository..."
git clone -b deploy  --depth=1 https://github.com/xyhelper/chatgpt-share-server-deploy.git chatgpt-share

## 进入目录
cd chatgpt-share

## 生成随机JWT secret
echo "生成随机JWT secret..."
JWT_SECRET=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
echo "生成的JWT secret: $JWT_SECRET"

## 替换config.yaml中的JWT secret
echo "更新配置文件中的JWT secret..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/secret: \"chatgpt-share-server\"/secret: \"$JWT_SECRET\"/" config.yaml
else
    # Linux
    sed -i "s/secret: \"chatgpt-share-server\"/secret: \"$JWT_SECRET\"/" config.yaml
fi

docker compose pull
docker compose up -d --remove-orphans

## 检查 chatgpt-web-ui 的自签 token 密钥是否仍为默认值
## share 模式下该密钥用于给用户签发 access token,默认值等同于公开密钥,
## 任何人都能伪造任意账号的登录态。这里只提示,不自动改写用户文件。
if grep -q 'change-me-to-a-random-secret' docker-compose.yml; then
  echo
  echo "======================================================================"
  echo "警告: FAKE_TOKEN_SECRET 仍是默认值,可被伪造登录态,请尽快修改:"
  echo '  cd chatgpt-share'
  echo '  SECRET=$(openssl rand -hex 32)'
  echo '  sed -i "s/change-me-to-a-random-secret/$SECRET/" docker-compose.yml'
  echo '  docker compose up -d chatgpt-web-ui'
  echo "======================================================================"
fi

## 提示信息
echo "服务启动成功，请访问 http://localhost:8400"
echo "库文件清理管理页 http://localhost:9900/gpt.html"
echo "管理员后台地址 http://localhost:8300/xyhelper"
echo "管理员账号: admin"
echo "管理员密码: 123456"
echo "请及时修改管理员密码"
