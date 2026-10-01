# 配置指南

Chatgpt-Share-Server 提供了丰富的配置选项，可以通过环境变量或者配置文件进行配置。

主要配置文件为 `config.yaml`，**配置文件的优先级高于环境变量**：同一个键两处都写了，
以 `config.yaml` 里的为准；只有 `config.yaml` 中没写的键，才会回落到同名环境变量。

环境变量一般通过`docker-compose.yml`进行配置，本部署包也正是这么做的，例如
`AUDIT_LIMIT_URL`、`LIBCLEANUPSERVER` 这类键特意没有写进 `config.yaml`，就是留给
环境变量生效。下表列出的配置项，加在 `docker-compose.yml` 的 `environment` 或
`config.yaml` 中都有效（注意上一条优先级）。

> **提示**
> 写进 `config.yaml` 时，键名要按下表**原样、区分大小写**地书写（例如必须写 `CHATPROXY`，
> 写成 `chatproxy` 不会被读取）；写进 `docker-compose.yml` 的 `environment` 时使用键名的大写形式。

> **提示**
> 修改配置后需要重启服务才能生效。
> 重启服务的命令为`docker compose restart`。

## 通用

| 键 | 默认值 | 说明 |
| - | - | - |
| `PORT` | `8001` | 容器内监听端口。部署包固定映射 `8300:8001`，一般不需要改 |
| `CHATPROXY` | `https://demo.xyhelper.cn` | 接入网关地址，即请求最终转发到的上游服务 |
| `AUTHKEY` | `xyhelper` | 接入网关的 authkey，与 `CHATPROXY` 配套使用 |
| `ASSET_PREFIX` | `https://oaistatic-cdn.closeai.biz` | 前端静态资源（JS/CSS/字体）前缀 |
| `WSSERVER` | `wss://ws.xyhelper.cn` | 前端 WebSocket 服务地址 |

## 登录与会话

| 键 | 默认值 | 说明 |
| - | - | - |
| `OAUTH_URL` | `http://127.0.0.1:<PORT>/auth/oauth` | OAuth 服务地址。不配置时回落到服务自身的演示接口，即由本地数据库校验用户 |
| `SESSION_MAX_AGE` | `720` | 登录会话最长存活时间，单位小时，默认 720 小时（30 天），超时后要求重新登录 |
| `PROHIBIT_MULTIPLE_LOGIN` | `false` | 禁止多端登录：为 `true` 时同一个 userToken 只能在一处保持登录 |
| `ALLOW_DUPLICATE_USER_TOKEN` | `false` | 允许把同一个 userToken 重复加入账号池。默认 `false`，后台新增账号时会校验 userToken 唯一 |
| `ALLOW_CHANGE_CAR_ON_429` | `false` | 允许在 429 时会话换车。需同时把 `RECORD_CONVERSATION` 设为 `true`，否则不生效 |

## 聊天记录

| 键 | 默认值 | 说明 |
| - | - | - |
| `RECORD_CONVERSATION` | `false` | 记录对话。开启后如遇账号失效，会尝试在当前车重建会话 |
| `DISALLOW_ROAM` | `false` | 禁止漫游：为 `true` 时聊天记录不会在不同车之间同步 |
| `ConversationNotifyUrl` | 空 | 对话回调地址。配置后每次提问都会以原请求体 `POST` 到该地址（详见下方说明） |
| `CONVERSATION_INIT_METADATA_TTL_SECONDS` | `86400` | 会话初始化元数据在 Redis 中的保留秒数，默认 1 天 |
| `SHOWGPTSLIST` | `false` | 为 `true` 时显示未被隔离的 GPTs 列表 |

## 文件与语音

| 键 | 默认值 | 说明 |
| - | - | - |
| `VOICESERVER` | `wss://webrtc.xyhelper.cn` | 语音服务（基于 LiveKit）地址，详见[语音服务](./voice.md) |
| `LIBCLEANUPSERVER` | 空 | 库文件清理服务地址。部署包在 `docker-compose.yml` 中指向内置的 `chatgpt-file-deletion`，详见[文件服务](./files.md) |

## 内容审核与限流

| 键 | 默认值 | 说明 |
| - | - | - |
| `AUDIT_LIMIT_URL` | 空 | 内容审核 / 频率限制服务地址。部署包在 `docker-compose.yml` 中指向内置的 `auditlimit`，详见[审计限流](./auditlimit.md) |
| `PROHIBIT_CONCURRENT_REQUEST` | `false` | 禁止同一 userToken 并发提问：为 `true` 时同一用户的第二个并发请求直接返回 429 |

## 其他

| 键 | 默认值 | 说明 |
| - | - | - |
| `APIAUTH` | 空 | 设置后启用 `/adminapi/chatgpt/*` 对接接口，详见 [API 对接](./apiauth.md) |
| `CLOSE_ACCOUNT_ON_UNUSUAL_ERROR` | `false` | 遇到异常错误时关闭（停用）当前账号，避免持续报错 |
| `CONVERSATION_INIT_METADATA_ENABLED` | `true` | 会话初始化元数据采集。**当前版本为固定行为**，写配置或环境变量都不会改变它 |

## 关于 `ConversationNotifyUrl`

配置该地址后，每次发起对话都会在后台以原请求体 `POST` 到该地址，并带上以下请求头：

| 请求头 | 内容 |
| - | - |
| `Authorization` | `Bearer <用户 userToken>` |
| `ChatGPT-Account-ID` | 账号 ID |
| `Carid` | 车牌号 |
| `Model` | 模型名 |
| `System-Hints` | `system_hints` 的多个值以 `,` 拼接 |
| `Cookie` / `Referer` / `User-Agent` | 转发原请求的同名请求头 |

回调是异步执行的（不等结果，不影响用户响应速度），失败只记日志。

## 说明：以下键当前版本尚未生效

以下键会被读取并打印到启动日志，但当前版本没有其他地方使用，配置后不会产生实际效果，
列出仅供排查配置时参考：

- `FILESERVER`（默认 `https://files.xyhelper.cn`）—— 文件相关请求现在由 share 本体自己反代，详见[文件服务](./files.md)
- `TRY_TO_BREAK_RATE_LIMIT`（默认 `false`）
- `USE_LOCAL_FILE_SERVER`（默认 `false`）
- `OAIUSERCONTENT_CDN_DOMAIN`（默认 `xyhelper.cn`）

## 相关文档

- [数据库结构自动维护](./migrate.md) —— 启动时自动建表、补列、建索引的分层策略，以及大表场景的处理办法
- [文件服务](./files.md) —— 上传/下载路由与文件直链域名
- [返回文档索引](../README.md) —— 全部文档列表
