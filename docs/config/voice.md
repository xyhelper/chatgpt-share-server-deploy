# 语音服务

## 端点配置

语音对话基于 LiveKit 实现,服务端通过配置项 `VOICESERVER` 把语音服务地址下发给前端,默认值为 `wss://webrtc.xyhelper.cn`,可以在 `docker-compose.yml` 或 `config.yaml` 中修改。

```yaml
# docker-compose.yml
# 其他配置省略
  chatgpt-share-server:
    image: xyhelper/chatgpt-share-server:latest
    restart: always
    ports:
      - 8300:8001
    environment:
      TZ: Asia/Shanghai # 指定时区
      # 接入网关地址
      CHATPROXY: "https://demo.xyhelper.cn"
      # 接入网关的authkey
      AUTHKEY: "xyhelper"
      # 内容审核及速率限制
      AUDIT_LIMIT_URL: "http://auditlimit:8080/audit_limit"
      # 语音服务地址
      VOICESERVER: "wss://webrtc.xyhelper.cn"
    volumes:
      - ./config.yaml:/app/config.yaml
      - ./data/chatgpt-share-server/:/app/data/
    labels:
      - "com.centurylinklabs.watchtower.scope=xyhelper-chatgpt-share-server"
# 其他配置省略

```

> **提示**
> `VOICESERVER` 填的是前端直连的 WebSocket 地址,须以 `wss://`(本地调试时可为 `ws://`)开头,
> 不要填普通的 `https://` 地址。

## 自建语音服务

语音服务已发布为 docker 镜像,可以通过 docker-compose 部署, 镜像地址为 `xyhelper/chatgpt-voice-server`。

```yaml
# docker-compose.yml
services:
  voice:
    image: xyhelper/chatgpt-voice-server
    restart: always
    ports:
      - 3005:3005
```

自建完成后,把 `chatgpt-share-server` 的 `VOICESERVER` 指向该服务的对外 WebSocket 地址
(例如经反向代理后的 `wss://voice.yourdomain.com`),并确认该地址能从浏览器直接访问。
