# 限制单点登陆

如果您的系统需要限制用户只能在一个地方登陆，可以通过配置`multilogin`来实现。

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
      # 文件服务地址
      FILESERVER: "https://files.closeai.biz"
      # 禁止同一个用户token在多个地方登录 默认值为false 不限制
      PROHIBIT_MULTIPLE_LOGIN: true 
    volumes:
      - ./config.yaml:/app/config.yaml
      - ./data/chatgpt-share-server/:/app/data/
    labels:
      - "com.centurylinklabs.watchtower.scope=xyhelper-chatgpt-share-server"
# 其他配置省略
```
