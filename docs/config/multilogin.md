# 限制单点登陆

如果您的系统需要限制同一个用户 token 只能在一处登陆，可以通过配置 `PROHIBIT_MULTIPLE_LOGIN` 来实现。

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
      # 禁止同一个用户token在多个地方登录 默认值为 false 不限制
      PROHIBIT_MULTIPLE_LOGIN: true
    volumes:
      - ./config.yaml:/app/config.yaml
      - ./data/chatgpt-share-server/:/app/data/
    labels:
      - "com.centurylinklabs.watchtower.scope=xyhelper-chatgpt-share-server"
# 其他配置省略
```

> **提示**
> - 也可以写在 `config.yaml` 里（键名写作 `PROHIBIT_MULTIPLE_LOGIN`）。两处都写了时以
>   `config.yaml` 为准，详见[配置指南](./README.md)。
> - 开启后，同一用户 token 的后一次登陆会把前一次的会话顶掉，前一个设备上的请求会被拒绝。
> - 修改后需要重启服务才能生效：`docker compose restart chatgpt-share-server`。
