# 文件服务

文件服务用于处理用户的上传下载请求,可通过环境变量 FILESERVER 指定。

OAI官方默认值为 `https://files.oaiusercontent.com`。

系统默认代理地址为 `https://files.xyhelper.cn`。

可选代理地址为 `https://files.closeai.biz`。

也可使用share本体做为文件服务器，此时FILESERVER应指向share本体地址。例如：`https://share.freegpts.org`。

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
    volumes:
      - ./config.yaml:/app/config.yaml
      - ./data/chatgpt-share-server/:/app/data/
    labels:
      - "com.centurylinklabs.watchtower.scope=xyhelper-chatgpt-share-server"
# 其他配置省略
```
