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
| `mysql` / `redis` | 不对外暴露 | 数据存储（`./data/`） |
| `auditlimit` | 不对外暴露 | 内容审核与频率限制 |
| `watchtower` | — | 按 `scope` 标签自动升级上述容器镜像 |

对外提供访问时，参考主项目安装文档配置反向代理。

## 文档

[https://chatgpt-share-server.xyhelper.cn](https://chatgpt-share-server.xyhelper.cn)


## 交流群

![交流群](https://xyhelper.cn/xyhelper-kf-2-0828.png)