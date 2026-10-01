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

对外提供访问时，参考主项目安装文档配置反向代理。

## 文档

[https://chatgpt-share-server.xyhelper.cn](https://chatgpt-share-server.xyhelper.cn)


## 交流群

![交流群](https://xyhelper.cn/xyhelper-kf-2-0828.png)