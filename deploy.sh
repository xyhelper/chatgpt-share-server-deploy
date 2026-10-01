#!/bin/bash

set -e

docker compose pull
docker compose up -d --remove-orphans

## =====================================================================
## 部署后安全自检
##   这里只做「提示」,不自动改写任何文件 —— 你很可能已经按自己的需求调整过
##   docker-compose.yml / config.yaml,脚本擅自修改容易覆盖掉你的改动。
##   下面每条都给出改法与生效命令,按需执行即可。
## =====================================================================

echo
echo "开始安全自检(只提示,不修改文件):"

## 输出带分隔线的提示块,提示内容从标准输入读取,不做变量展开
warn() {
  echo "  --------------------------------------------------------------------"
  cat
  echo "  --------------------------------------------------------------------"
}

## 1) chatgpt-web-ui 以 share 模式运行时,FAKE_TOKEN_SECRET 用于签发 access token。
##    默认值等同于公开密钥,任何人都能伪造任意账号的登录态。
if grep -q 'change-me-to-a-random-secret' docker-compose.yml; then
  warn <<'EOF'
  ⚠️ FAKE_TOKEN_SECRET 仍是默认值,任何人都能伪造任意账号的登录态,请尽快修改:
       SECRET=$(openssl rand -hex 32)
       sed -i "s/change-me-to-a-random-secret/$SECRET/" docker-compose.yml
       docker compose up -d chatgpt-web-ui
     修改后已登录用户的 cookie 会失效,需要重新登录,属正常现象。
EOF
else
  echo "  ✅ FAKE_TOKEN_SECRET 已修改"
fi

## 2) 后台 JWT 密钥。默认值在 cool-admin 的弱密钥名单里,框架会在进程启动时把它
##    替换成「每次启动都不同」的随机值,容器一重启后台登录态就全部失效
##    (watchtower 自动更新镜像同样会触发)。
if grep -qE '^[[:space:]]*secret:[[:space:]]*"?chatgpt-share-server"?[[:space:]]*$' config.yaml; then
  warn <<'EOF'
  ⚠️ config.yaml 的 modules.base.jwt.secret 仍是默认值:
     框架会把它替换成每次启动都变化的随机值,容器重启后后台登录态会失效。
     建议改成固定的强随机串:
       SECRET=$(openssl rand -hex 32)
       sed -i "s/secret: \"chatgpt-share-server\"/secret: \"$SECRET\"/" config.yaml
       docker compose up -d --force-recreate chatgpt-share-server
EOF
else
  echo "  ✅ modules.base.jwt.secret 已修改"
fi

## 3) 上传文件的访问域名。默认值写死 127.0.0.1,后台返回的文件地址会指向访客本机。
if grep -qE 'domain:[[:space:]]*"https?://127\.0\.0\.1' config.yaml; then
  warn <<'EOF'
  ⚠️ config.yaml 的 cool.file.domain 仍指向 127.0.0.1:
     后台「上传管理 / 用户头像」返回的文件地址会指向访客自己的电脑,图片无法显示。
     请改成对外可访问的地址(通常是反向代理到 8300 的域名),例如:
       cool:
         file:
           mode: "local"
           domain: "https://admin.yourdomain.com"
EOF
else
  echo "  ✅ cool.file.domain 已修改"
fi

## 4) 管理后台默认口令与对外暴露面(无法自动检测是否已改,固定提示)
warn <<'EOF'
  📌 管理后台默认账号 admin / 密码 123456,请访问 http://服务器IP:8300/xyhelper
     登录后立即修改密码。
     8300(旧版页面 + 管理后台)与 9900(库文件清理管理页)建议不要直接对公网开放,
     改用反向代理 + HTTPS,并按需加 IP 白名单 / 基本认证;
     对外只需要暴露用户入口 8400(或经反向代理后的 80/443)。
EOF

## 5) 升级说明。这一段单独用更重的边框:git 相关命令用错会永久删掉你改过的
##    compose / config,是整个升级流程里最容易出事的一步,值得喊得响一点。
danger() {
  echo "  ######################################################################"
  echo "  ###  $1"
  echo "  ######################################################################"
  cat
  echo "  ######################################################################"
}

danger "升级前必读:用错命令会永久删掉你改过的配置" <<'EOF'

    本脚本只拉取新镜像,不会覆盖 docker-compose.yml / config.yaml
    —— 你很可能已经改过它们(FAKE_TOKEN_SECRET、上传域名、数据库口令等),
       所以脚本不会替你动这两个文件。

    !! 但下面这些 git 命令会覆盖它们,执行前必须先备份:

       git pull             本地改过的文件与远程冲突,拉取会直接中断
       git checkout .       直接丢弃 docker-compose.yml / config.yaml 的全部改动
       git reset --hard     同上,且不可恢复

    !! 一旦为了「把更新拉下来」而执行了后两条,你改过的 FAKE_TOKEN_SECRET、
       上传域名、数据库口令等配置会被永久删除,无法找回(除了你自己的备份)。

    安全步骤:先备份,再拉取,最后手工合并。

       cd 部署目录
       cp docker-compose.yml docker-compose.yml.bak   # 1. 先备份
       cp config.yaml        config.yaml.bak
       git stash                                      # 2. 暂存你的改动
       git pull --ff-only                             # 3. 拉取更新
       git stash pop                                  # 4. 恢复并手工合并
       #  报冲突就编辑 docker-compose.yml / config.yaml 逐个确认
       #  合并完对照 .bak 检查三处关键配置是否还在:
       #    docker-compose.yml 的 FAKE_TOKEN_SECRET
       #    config.yaml 的 modules.base.jwt.secret
       #    config.yaml 的 cool.file.domain
       ./deploy.sh                                    # 5. 重启生效

    只更新镜像、不动仓库文件的话,什么都不用做 —— watchtower 会自动完成。
EOF
echo
