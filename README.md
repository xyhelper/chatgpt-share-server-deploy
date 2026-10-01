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
| `auditlimit` | 不对外暴露 | 内容审核与频率限制 |
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

对外提供访问时，参考主项目安装文档配置反向代理。

## 文档

[https://chatgpt-share-server.xyhelper.cn](https://chatgpt-share-server.xyhelper.cn)


## 交流群

![交流群](https://xyhelper.cn/xyhelper-kf-2-0828.png)