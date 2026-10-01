# 附带服务配置

部署包一共编排了 6 个服务，其中只有 `chatgpt-share-server` 是本项目的程序，另外几个
分别是用户入口、辅助任务与基础设施。本页给出每个服务的关键配置项，完整的行内注释见
仓库根目录的 `docker-compose.yml`。

| 服务 | 镜像 | 宿主机端口 | 作用 |
| - | - | - | - |
| `chatgpt-share-server` | `xyhelper/chatgpt-share-server:latest` | `8300` | 核心服务：旧版页面、管理后台、所有 API |
| `chatgpt-web-ui` | `ghcr.io/xyhelper/chatgpt-web-ui:latest` | `8400` | 用户入口，新版页面 + 车队列表页 |
| `chatgpt-file-deletion` | `ghcr.io/xyhelper/chatgpt-file-deletion:latest` | `9900` | 库文件清理与其管理页 |
| `auditlimit` | `xyhelper/auditlimit` | 不暴露 | 内容审核与频率限制 |
| `mysql` | `mysql:8` | 不暴露 | 业务数据库 |
| `redis` | `redis` | 不暴露 | 缓存、会话与清理队列 |
| `watchtower` | `containrrr/watchtower` | 不暴露 | 镜像自动更新 |

## chatgpt-web-ui

| 环境变量 | 默认值 | 说明 |
| - | - | - |
| `TZ` | `Asia/Shanghai` | 时区 |
| `PORT` | `80` | 容器内监听端口，需与端口映射保持一致 |
| `UPSTREAM_URL` | `http://chatgpt-share-server:8001` | 上游 API 地址。容器之间用服务名互访，不要写宿主机端口 |
| `RUN_MODE` | `share` | 运行模式，与 `chatgpt-share-server` 的车队模式配套 |
| `LOGIN_URL` | `/list` | 未登录时跳转到的地址，默认先展示车队列表页 |
| `FAKE_TOKEN_SECRET` | `change-me-to-a-random-secret` | **必须修改**。share 模式下用它签发 access token，占位值等同于公开签名密钥 |

该服务是无状态的，登录态保存在浏览器 cookie 中，不挂载数据卷；`/healthz` 是独立探活
端点，不渲染页面、不请求上游、不依赖登录态，`docker-compose.yml` 中的 healthcheck 用的就是它。

它会把 `/backend-api`、`/public-api`、`/realtime`、`/carpage` 等请求在容器网络内反代到
`chatgpt-share-server`，所以两者必须一起运行，共用同一套车队/账号数据。

完整配置项与自定义说明见上游仓库：<https://github.com/xyhelper/chatgpt-web-ui-deploy>

## chatgpt-file-deletion

| 环境变量 | 默认值 | 说明 |
| - | - | - |
| `TZ` | `Asia/Shanghai` | 时区 |
| `GPTPROXY` | `https://demo.xyhelper.cn` | ChatGPT 接入点地址，**必须与 `chatgpt-share-server` 的 `CHATPROXY` 保持一致** |
| `WEBHOOKURL` | 空（注释状态） | 企业微信机器人 webhook，留空则不发送通知 |
| `CONCURRENCY` | `1` | 账号并发处理数，调大可以加快队列消化，但会加重上游压力 |
| `CLEAN_MINTUNES` | `1440` | 只清理该时长（分钟）之前上传的文件，必须是整数 |
| `CLEAN_PROPORTION` | `0.5` | 存储使用率超过该比例时才触发清理，须为小于 1 的小数 |

调用关系：`chatgpt-share-server` 通过 `LIBCLEANUPSERVER` 调用它的
`POST /gpt/library/clean/file`，请求体为 `{"accessToken": "..."}`。管理页在
`http://服务器IP:9900/gpt.html`。

它复用同一个 `redis` 服务（镜像内置配置已指向 `redis:6379`），因此给 redis 加密码时
记得同步修改它的配置。

完整配置项见上游仓库：<https://github.com/xyhelper/chatgpt-file-deletion-deploy>

## auditlimit

只在容器网络内被 `chatgpt-share-server` 通过 `AUDIT_LIMIT_URL` 调用，默认不映射宿主机
端口。限流规则与禁止词配置见[审计限流](./auditlimit.md)。

## watchtower

```yaml
command: --scope xyhelper-chatgpt-share-server --cleanup
```

- 只处理带 `com.centurylinklabs.watchtower.scope=xyhelper-chatgpt-share-server` 标签
  的服务，也就是本部署包自己的 5 个服务，不会动宿主机上的其他容器。
- `--cleanup` 会在更新后删除被替换掉的旧镜像。
- 更新是无人值守的，`latest` 镜像里包含数据库结构变更，会在容器重启时自动应用；介意这
  一点的话，**在升级前先备份 `data/` 目录**。
- 不希望自动更新时，停掉它即可：`docker compose stop watchtower`，之后升级就变成手动
  `docker compose pull && docker compose up -d`（参考[安装指南](../install/README.md)的升级一节）。

## mysql / redis

两者都只在容器网络内可达，不映射宿主机端口。

| 服务 | 需要同步的配置 |
| - | - |
| `mysql` | `MYSQL_ROOT_PASSWORD` 必须与 `config.yaml` 的 `database.default.pass` 一致 |
| `redis` | 取消 `--requirepass` 注释后，要同时在 `config.yaml` 的 `redis.cool` 下补 `pass: "<密码>"` |

`mysql` 的 `docker-entrypoint-initdb.d/` 只在 `data/mysql` 为空时导入一次初始 SQL，
之后表结构由 `chatgpt-share-server` 启动时按需补齐，详见
[数据库结构自动维护](./migrate.md)。

## 相关文档

- [安装指南](../install/README.md) —— 部署步骤、服务与端口、反向代理与升级
- [配置指南](./README.md) —— `chatgpt-share-server` 本身的配置项
- [返回文档索引](../README.md)
