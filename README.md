# ChatGPT-Share-Server

便捷的账号共享服务

## 使用前必看

### 本服务为商业服务，自2024年4月16日0:00不再提供免费接入点。需付费使用。

1.流量大使用付费接入点或者小流量拼车付费接入点的，可打开以下链接选择适合自己的方案
https://xyhelper.cn/access

2.流量小或者小团队自用的，可使用蟑螂v1，目前蟑螂v1可正常使用，了解详情请访问:
CockroachAi（又名蟑螂）
https://github.com/cockroachai/cockroachai



## 部署

快速部署

```bash
curl -sSfL https://raw.githubusercontent.com/xyhelper/chatgpt-share-server-deploy/deploy/quick-install.sh | bash
```

手动部署：

```bash
git clone -b deploy --depth=1 https://github.com/xyhelper/chatgpt-share-server-deploy.git chatgpt-share
cd chatgpt-share
./deploy.sh
```

部署完成后：

| 入口 | 地址 | 说明 |
| --- | --- | --- |
| 用户聊天页（新版 Web UI） | `http://服务器IP:8400` | 未登录先展示车队列表页 → 选择车队 → 用 userToken 登录 |
| 库文件清理管理页 | `http://服务器IP:9900/gpt.html` | 查看各账号库文件占用并手动触发清理 |
| 旧版页面 + 管理后台 | `http://服务器IP:8300` | 管理后台地址 `http://服务器IP:8300/xyhelper`，账号 `admin` / 密码 `123456` |

### ⚠️ 部署后务必修改 FAKE_TOKEN_SECRET

新版 Web UI 以 `share` 模式运行，需要用 `FAKE_TOKEN_SECRET` 给用户签发 access token。
`docker-compose.yml` 中预置的是占位值，直接使用等同于把签名密钥公开，**任何人都可以伪造任意账号的登录态**：

```bash
cd chatgpt-share
SECRET=$(openssl rand -hex 32)
sed -i "s/change-me-to-a-random-secret/$SECRET/" docker-compose.yml
docker compose up -d chatgpt-web-ui
```

密钥变更后已登录用户的 cookie 会失效，需要重新登录，属正常现象。

### ⚠️ 部署后建议修改的其他配置

`config.yaml` 里还有几处默认值不适合直接对外服务。`./deploy.sh` 每次执行都会把这几项
的检查结果打印出来（只提示，不会改写你的文件）：

| 配置项 | 默认值 | 不改的后果 |
| --- | --- | --- |
| `modules.base.jwt.secret` | `chatgpt-share-server` | 该值属于 cool-admin 内置的弱密钥名单，启动时会被替换成**每次启动都不同**的随机值，容器每重启一次（watchtower 自动更新镜像同样会触发）后台登录态就全部失效 |
| `cool.file.domain` | `http://127.0.0.1:8300` | 后台「上传管理 / 用户头像」返回的文件地址指向访客自己的电脑，图片无法显示 |
| `database.default.pass` | `123456` | MySQL 不映射宿主机端口，只在容器网络内可达，风险有限；若要修改，请与 `docker-compose.yml` 的 `MYSQL_ROOT_PASSWORD` 同时改 |

修改示例：

```bash
cd chatgpt-share
SECRET=$(openssl rand -hex 32)
sed -i "s/secret: \"chatgpt-share-server\"/secret: \"$SECRET\"/" config.yaml
sed -i 's|domain: "http://127.0.0.1:8300"|domain: "https://admin.yourdomain.com"|' config.yaml
docker compose up -d --force-recreate chatgpt-share-server
```

`cool.file.domain` 要填实际对外可访问的地址，通常是反向代理到 `8300` 的那个域名。

### 服务与端口

| 服务 | 宿主机端口 | 作用 |
| --- | --- | --- |
| `chatgpt-web-ui` | `8400` → 容器 `80` | 新版 Web UI，请求 `/backend-api` 等接口反代到 `chatgpt-share-server` |
| `chatgpt-share-server` | `8300` → 容器 `8001` | 车队/账号数据、旧版页面、管理后台 |
| `chatgpt-file-deletion` | `9900` → 容器 `8001` | 库文件清理服务，管理页 `/gpt.html` |
| `mysql` / `redis` | 不对外暴露 | 数据存储（`./data/`）；`redis` 同时提供清理服务的任务队列 |
| `auditlimit` | 不对外暴露 | 按「用户 token + 模型」限流，可选叠加内容审核 |
| `watchtower` | — | 按 `scope` 标签自动升级上述容器镜像 |

### 库文件清理（可选但推荐）

`chatgpt-file-deletion` 会定期清理账号在 ChatGPT 侧上传的库文件（附件/图片等），
避免账号存储越用越满。`chatgpt-share-server` 已经通过环境变量 `LIBCLEANUPSERVER`
预先指向它，全新部署无需任何额外配置即会自动生效。

- 触发时机：每次账号登录态刷新（`RefreshAllSession`）时把该账号加入清理队列
- 清理策略：清理 `CLEAN_MINTUNES`（默认 1440 分钟）以前上传的文件；存储使用率超过
  `CLEAN_PROPORTION`（默认 0.5）时也会触发清理
- 企业微信通知：取消 `docker-compose.yml` 中 `WEBHOOKURL` 的注释并填入机器人地址即可
- `GPTPROXY` 需与 `chatgpt-share-server` 的 `CHATPROXY`（同一个接入点）保持一致

不想使用该服务的话，注释掉 `docker-compose.yml` 中整个 `chatgpt-file-deletion` 服务，
并删除 `chatgpt-share-server` 的 `LIBCLEANUPSERVER` 环境变量即可。

### 内容审核与频率限制

`auditlimit` 按「用户 token + 模型」两个维度分别限流，由 `chatgpt-share-server` 通过
环境变量 `AUDIT_LIMIT_URL` 调用，全新部署已预先接通，无需额外配置。

限流值写在 `docker-compose.yml` 中 `auditlimit` 的 `environment` 里，格式为 `次数/时间`：

```yaml
# 兜底值:未单独配置的模型都用这一项
DEFAULT: "20/3h"
# 模型 gpt-5-6 单独放宽到每 3 小时 60 次
GPT-5-6: "60/3h"
```

- 配置键的生成规则：模型名**转为大写**，并把 `.` 换成 `_`
  （`gpt-5.6-sol-wm` → `GPT-5_6-SOL-WM`）
- 时间单位支持 `s` / `m` / `h`，也可组合（如 `1h30m`）；值必须恰好包含一个 `/`，
  格式非法时回落到内置兜底值 `40/3h`
- 把某个模型的值写成 `DISABLED` 即禁止使用该模型，请求返回 **403**（`model_disabled`），
  与额度耗尽的 **429**（`model_cap_exceeded`）区分开
- `research` / `agent` 由请求体的 `system_hints` 触发，`auto` 对应模型选择器的「Auto」档，
  它们都是普通模型键：删掉并不会「不受限制」，而是回落到 `DEFAULT`
- 禁止词：新建 `data/auditlimit/keywords.txt` 并每行写一个词，命中后返回 400
- 内容审核（可选）：只有在取消注释并填入 `OAIKEY` 后才会调用审核接口；调用失败时按
  「通过」放行，不会连带影响主业务

不需要限流的话，删除 `chatgpt-share-server` 的 `AUDIT_LIMIT_URL` 环境变量即可。

### 对外暴露面

管理后台（`8300/xyhelper`）与库文件清理管理页（`9900/gpt.html`）都**没有额外的身份
校验**，且默认口令是 `admin` / `123456`。建议：

- 登录后台后立即修改管理员密码
- `8300`、`9900` 不要直接对公网开放，用反向代理 + HTTPS（配置见 [安装指南 → 反代配置](./docs/install/README.md#反代配置)），并按需加 IP 白名单或基本认证
- 只对外暴露用户入口 `8400`（或经反向代理后的 `80` / `443`），并用防火墙限制其余端口

防火墙示例：

```bash
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

更多内容（系统优化参数、反向代理完整示例、数据备份与管理命令）见[安装指南](./docs/install/README.md)。

### 升级

镜像更新由 `watchtower` 自动完成，日常无需手动操作。**只更新镜像不需要动仓库文件。**

#### ⚠️ 手动拉取更新前，务必先备份 `docker-compose.yml` 与 `config.yaml`

`./deploy.sh` **只拉取镜像，不会覆盖 `docker-compose.yml` / `config.yaml`** —— 这两
个文件你多半已经改过（`FAKE_TOKEN_SECRET`、上传域名、数据库口令等），所以脚本
不会替你动它们。

但**用 `git` 命令拉取仓库更新时，会碰到这两个文件**：

| 命令 | 后果 |
| --- | --- |
| `git pull` | 本地改过的文件与远程冲突，拉取直接中断 |
| `git checkout .` | **丢弃 `docker-compose.yml` / `config.yaml` 的全部改动** |
| `git reset --hard` | **同上，且不可恢复** |

也就是说，为了「把更新拉下来」而执行了后两条，你改过的 `FAKE_TOKEN_SECRET`、上传
域名、数据库口令等配置会被**永久删除**，除了你自己的备份之外**无法找回**。

正确的升级步骤（先备份，再拉取，最后手工合并）：

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

合并完成后，对照 `.bak` 确认三处关键配置还在，没问题再删备份：

- `docker-compose.yml` 的 `FAKE_TOKEN_SECRET`
- `config.yaml` 的 `modules.base.jwt.secret`
- `config.yaml` 的 `cool.file.domain`

```bash
rm docker-compose.yml.bak config.yaml.bak
```

## 文档

完整的部署与配置手册在 [`docs/`](./docs/README.md)：

- [安装指南](./docs/install/README.md) —— 前置条件、系统优化、部署、反向代理、管理后台、常用管理命令与升级
- [配置指南](./docs/config/README.md) —— 常用环境变量一览，以及限流、备份、多端登录、语音、OAuth 等专题
- [界面预览](./docs/preview/README.md)

`docker-compose.yml` 与 `config.yaml` 里也有对应的行内注释。

## 交流群

![交流群](https://xyhelper.cn/xyhelper-kf-2-0828.png)
