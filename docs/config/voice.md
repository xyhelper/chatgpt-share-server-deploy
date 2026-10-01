# 语音服务

## 端点配置

系统默认提供了两个语音服务端点,分别是 `https://voice.xyhelper.cn` 和 `https://voice.closeai.biz` , 你可以在 `docker-compose.yml` 配置文件中进行切换。

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
      VOICESERVER: "https://voice.closeai.biz"
    volumes:
      - ./config.yaml:/app/config.yaml
      - ./data/chatgpt-share-server/:/app/data/
    labels:
      - "com.centurylinklabs.watchtower.scope=xyhelper-chatgpt-share-server"
# 其他配置省略

```

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
