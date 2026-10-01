<!--
  本文件是从内部底稿 docs/install/README.md 同步过来的，只做了 GitHub 渲染适配
  （去掉 VuePress 的 front matter 与 ::: 容器）。改动建议先改底稿再同步，避免两边不一致。
-->
# 安装指南

## 前置条件

- 1 台 2C2G 以上服务器,推荐使用 Ubuntu 20.04 LTS 以上版本,服务器不强制要求可以访问官网,但需要能够访问 `xyhelper接入点`
- 安装 Docker 及 docker compose,推荐使用[官方安装脚本](https://docs.docker.com/engine/install/ubuntu/#install-using-the-convenience-script)
- 安装 git,推荐使用`apt install git`
- 安装`caddy`或`nginx`等反向代理服务器,推荐使用`caddy`,推荐使用[官方安装脚本](https://caddyserver.com/docs/install#debian-ubuntu-raspbian)
- 使用 root 用户安装,不建议使用非 root 用户通过`sudo`安装，可能会导致权限问题。

## 常用系统优化

### 系统时间同步

```bash
apt install ntpdate -y
ntpdate time.windows.com
```

### 系统时区设置

```bash
timedatectl set-timezone Asia/Shanghai
```

### 设置最大文件打开数

```bash
echo "fs.inotify.max_user_instances=5120" >> /etc/sysctl.conf
echo "fs.inotify.max_user_watches=2621440" >> /etc/sysctl.conf
echo "fs.file-max=65535" >> /etc/sysctl.conf

sysctl -p
```

### 限制 docker 日志大小

```bash
mkdir -p /etc/docker

cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

systemctl restart docker
```

### 设置防火墙

```bash
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 22/tcp

ufw enable
```

## 安装

### 安装 ChatGPT-Share-Server

```bash
curl -sSfL https://raw.githubusercontent.com/xyhelper/chatgpt-share-server-deploy/deploy/quick-install.sh | bash
```

### 安装 ChatGPT-Share-Server(手动)

```bash
git clone -b deploy --depth=1 https://github.com/xyhelper/chatgpt-share-server-deploy.git chatgpt-share
cd chatgpt-share
./deploy.sh
```

## 服务与端口

部署包会同时启动三个对外入口(其余服务仅在容器网络内使用):

| 入口 | 宿主机端口 | 说明 |
| --- | --- | --- |
| 新版 Web UI(`chatgpt-web-ui`) | `8400` | 用户聊天页,未登录先展示车队列表页,选车队后用 userToken 登录 |
| 旧版页面 + 管理后台(`chatgpt-share-server`) | `8300` | 管理后台在 `/xyhelper`,`/backend-api` 等接口也由它提供 |
| 库文件清理管理页(`chatgpt-file-deletion`) | `9900` | 访问 `/gpt.html`,查看各账号库文件占用并手动触发清理 |

此外 `mysql`、`redis` 与 `auditlimit` 不映射宿主机端口,只在容器网络内相互访问。

`chatgpt-web-ui` 的 `/backend-api`、`/public-api`、`/realtime`、`/carpage` 等请求都在容器内反代到 `chatgpt-share-server`,两者需一起运行,共用同一套车队/账号数据。

还有一个不对外暴露的 `watchtower`,负责把上面这些服务的镜像自动升级到 `latest`(只作用于带 `watchtower.scope` 标签的服务)。各服务可配置的环境变量见[附带服务配置](../config/services.md)。

### 库文件清理

`chatgpt-share-server` 通过环境变量 `LIBCLEANUPSERVER` 指向 `chatgpt-file-deletion`,每次账号登录态刷新时自动把该账号加入清理队列,清理其在 ChatGPT 侧上传的库文件(附件/图片等),避免账号存储越用越满,无需额外配置。

清理策略由 `docker-compose.yml` 中的 `CLEAN_MINTUNES`(默认清理 1440 分钟以前的文件)与 `CLEAN_PROPORTION`(存储使用率阈值)控制;`GPTPROXY` 需与 `chatgpt-share-server` 的 `CHATPROXY` 使用同一个接入点。不需要该服务时,注释掉整个 `chatgpt-file-deletion` 服务并删除 `LIBCLEANUPSERVER` 即可。

### ⚠️ 部署后必须修改 FAKE_TOKEN_SECRET

`chatgpt-web-ui` 以 `share` 模式运行时,需要用 `FAKE_TOKEN_SECRET` 给用户签发 access token。`docker-compose.yml` 中的值只是占位符,直接使用等同于公开签名密钥,**任何人都可以伪造任意账号的登录态**:

```bash
cd chatgpt-share
SECRET=$(openssl rand -hex 32)
sed -i "s/change-me-to-a-random-secret/$SECRET/" docker-compose.yml
docker compose up -d chatgpt-web-ui
```

修改后已登录用户的 cookie 会失效,需要重新登录,属正常现象。

### ⚠️ 部署后建议修改的其他配置

`config.yaml` 里还有几处默认值不适合直接对外服务。`./deploy.sh` 每次执行都会把这几项
的检查结果打印出来(只提示,不会改写你的文件):

| 配置项 | 默认值 | 不改的后果 |
| --- | --- | --- |
| `modules.base.jwt.secret` | `chatgpt-share-server` | 该值属于 cool-admin 内置的弱密钥名单,启动时会被替换成**每次启动都不同**的随机值,容器每重启一次(watchtower 自动更新镜像同样会触发)后台登录态就全部失效 |
| `cool.file.domain` | `http://127.0.0.1:8300` | 后台「上传管理 / 用户头像」返回的文件地址指向访客自己的电脑,图片无法显示 |
| `database.default.pass` | `123456` | MySQL 不映射宿主机端口,只在容器网络内可达,风险有限;若要修改,请与 `docker-compose.yml` 的 `MYSQL_ROOT_PASSWORD` 同时改 |

修改示例:

```bash
cd chatgpt-share
SECRET=$(openssl rand -hex 32)
sed -i "s/secret: \"chatgpt-share-server\"/secret: \"$SECRET\"/" config.yaml
sed -i 's|domain: "http://127.0.0.1:8300"|domain: "https://admin.yourdomain.com"|' config.yaml
docker compose up -d --force-recreate chatgpt-share-server
```

`cool.file.domain` 要填实际对外可访问的地址,通常是反向代理到 `8300` 的那个域名。

### 内容审核与频率限制

`chatgpt-share-server` 通过环境变量 `AUDIT_LIMIT_URL` 指向同容器网络内的 `auditlimit`
服务,按「用户 token + 模型」两个维度分别限流,部署包已预先接通,无需额外配置。

限流值写在 `docker-compose.yml` 中 `auditlimit` 的 `environment` 里,格式为 `次数/时间`,
模型名**转为大写**并把 `.` 换成 `_` 即为配置键(如 `gpt-5.6-sol-wm` → `GPT-5_6-SOL-WM`),
未单独配置的模型统一落到 `DEFAULT`:

```yaml
DEFAULT: "20/3h" # 未单独配置的模型:每 3 小时最多 20 次
GPT-5-6: "60/3h" # 模型 gpt-5-6:每 3 小时最多 60 次
```

把某个模型的值写成 `DISABLED` 即可禁止使用该模型,请求会返回 **403**(`model_disabled`),
与额度耗尽的 **429**(`model_cap_exceeded`)区分开。禁止词可写在 `data/auditlimit/keywords.txt`
中(每行一个词),命中后返回 400。取消 `OAIKEY` 的注释并填入 key 后会额外调用内容审核接口。

不需要限流时,删除 `chatgpt-share-server` 的 `AUDIT_LIMIT_URL` 环境变量即可。

## 反代配置

### Caddy

推荐把主域名反代到新版 Web UI(`8400`),管理后台单独用一个域名反代到 `8300`。

假定用户入口域名为`xxx.yourdomain.com`,管理后台域名为`admin.yourdomain.com`,请将两个域名都解析到服务器 IP,然后执行以下命令,注意替换成你自己的域名。

```bash
cat > /etc/caddy/Caddyfile <<EOF
xxx.yourdomain.com {
    reverse_proxy 127.0.0.1:8400
}
admin.yourdomain.com {
    reverse_proxy 127.0.0.1:8300
}
EOF

systemctl reload caddy
```

Caddy 会自动处理 WebSocket 升级,无需额外配置(聊天实时流走 `/realtime/*`)。

仍想继续使用旧版页面的话,把上面的 `127.0.0.1:8400` 换成 `127.0.0.1:8300` 即可,新旧两个页面共用同一套数据,可随时切换。

> **注意：使用 nginx 时注意两点**
> 1. 上传文件走 `/backend-api/files`（multipart 上传，还有 `/backend-api/files/process_upload_stream` 的分片上传），需放宽请求体大小，例如 `client_max_body_size 512m;`（服务端自身的上限是 200MB，nginx 的限制不要小于这个值）
> 2. 实时流使用 WebSocket，`location` 中需带上 `proxy_http_version 1.1;` 与 `proxy_set_header Upgrade $http_upgrade;`、`proxy_set_header Connection "upgrade";`

## 管理

后台管理地址: `http://admin.yourdomain.com/xyhelper`(未配域名时用 `http://服务器IP:8300/xyhelper`)

默认账号: `admin`

默认密码: `123456`

> **注意：管理后台与清理页没有额外的身份校验**
> 未配反向代理时,`8300`(旧版页面 + 管理后台)与 `9900`(库文件清理管理页 `/gpt.html`)
> 都是直接对公网开放的,只有默认口令一道防线。请:
>
> - 首次登录后立即修改管理员密码
> - 用防火墙只放行 `22` / `80` / `443`,不要长期把 `8300`、`9900` 裸对公网
> - 需要远程访问时改用反向代理 + HTTPS(见上一节),并按需加 IP 白名单或基本认证

## 数据与备份

所有持久化数据都在部署目录的 `data/` 下:

| 目录 | 内容 |
| --- | --- |
| `data/mysql` | 业务库(车队、账号、会话等) |
| `data/redis` | 缓存与库文件清理服务的任务队列 |
| `data/chatgpt-share-server` | 运行数据与日志 |
| `data/auditlimit` | 禁止词表 `keywords.txt` |

备份或迁移只需打包 `data/` 以及 `config.yaml`、`docker-compose.yml`。

> **升级 MySQL 大版本前务必先备份**
> 升级时会就地升级 `data/mysql` 中的数据文件,且不可回退。

## 常用管理命令

### 查看状态

```bash
cd chatgpt-share
docker compose ps
```

### 重启

```bash
cd chatgpt-share
docker compose restart
```

### 停止

```bash
cd chatgpt-share
docker compose stop
```

### 启动

```bash
cd chatgpt-share
./deploy.sh
```

### 升级

镜像更新由 `watchtower` 自动完成,日常无需手动操作。**只更新镜像不需要动仓库文件。**

#### ⚠️ 手动拉取更新前,务必先备份 `docker-compose.yml` 与 `config.yaml`

`./deploy.sh` 只拉取镜像,**不会覆盖 `docker-compose.yml` / `config.yaml`**:这两个
文件你可能已经按自己的需要改过(`FAKE_TOKEN_SECRET`、上传域名、数据库口令等),
所以脚本不会替你动它们。

但**用 `git` 命令拉取仓库更新时,会碰到这两个文件**:

| 命令 | 后果 |
| --- | --- |
| `git pull` | 本地改过的文件与远程冲突,拉取直接中断 |
| `git checkout .` | **丢弃 `docker-compose.yml` / `config.yaml` 的全部改动** |
| `git reset --hard` | **同上,且不可恢复** |

也就是说,为了「把更新拉下来」而执行了后两条,你改过的 `FAKE_TOKEN_SECRET`、上传
域名、数据库口令等配置会被**永久删除**,除了你自己的备份之外**无法找回**。

正确的升级步骤(先备份,再拉取,最后手工合并):

```bash
cd chatgpt-share
cp docker-compose.yml docker-compose.yml.bak   # 1. 先备份
cp config.yaml        config.yaml.bak
git stash                                      # 2. 暂存你的改动
git pull --ff-only                             # 3. 拉取更新
git stash pop                                  # 4. 恢复并手工合并
# 报冲突就编辑 docker-compose.yml / config.yaml 逐个确认
./deploy.sh                                    # 5. 重启生效
```

合并完成后,对照 `.bak` 确认三处关键配置还在,没问题再删备份:

- `docker-compose.yml` 的 `FAKE_TOKEN_SECRET`
- `config.yaml` 的 `modules.base.jwt.secret`
- `config.yaml` 的 `cool.file.domain`

```bash
rm docker-compose.yml.bak config.yaml.bak
```

### 查看日志

```bash
cd chatgpt-share
docker compose logs -f
```

---

文档索引见 [docs/README.md](../README.md)。
