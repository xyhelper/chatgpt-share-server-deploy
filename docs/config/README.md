# 配置指南

Chatgpt-Share-Server 提供了丰富的配置选项，可以通过环境变量或者配置文件进行配置。

主要配置文件为 `config.yaml`，**配置文件的优先级高于环境变量**：同一个键两处都写了，
以 `config.yaml` 里的为准；只有 `config.yaml` 中没写的键，才会回落到同名环境变量。

环境变量一般通过`docker-compose.yml`进行配置，本部署包也正是这么做的，例如
`AUDIT_LIMIT_URL`、`LIBCLEANUPSERVER` 这类键特意没有写进 `config.yaml`，就是留给
环境变量生效。下表列出的配置项，加在 `docker-compose.yml` 的 `environment` 或
`config.yaml` 中都有效（注意上一条优先级）。

> **提示**
> 修改配置后需要重启服务才能生效。
> 重启服务的命令为`docker compose restart`。

## 常用配置

| 参数名                       | 默认值                              | 描述                                                                                                         |
| ---------------------------- | ----------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| `CHATPROXY`                  | `https://demo.xyhelper.cn`          | 网关/接入点地址                                                                                              |
| `ALLOW_DUPLICATE_USER_TOKEN` | `false`                             | 是否允许重复的用户 token                                                                                     |
| `DISALLOW_ROAM`              | `false`                             | 是否禁止漫游 配置为 true 后聊天记录将不会在不同车间漫游                                                      |
| `SHOWGPTSLIST`               | `false`                             | 是否显示 GPTs 列表,如果配置为 true,则会显示未隔离的 GPTs 列表                                                |
| `PROHIBIT_MULTIPLE_LOGIN`    | `false`                             | 是否禁止多端登录 配置为 true 后用户只能在一个设备登录                                                        |
| `RECORD_CONVERSATION`        | `false`                             | 是否记录对话,开记对话记录后,如遇到账号失效,将会尝试在当前车重建会话                                          |
| `OAUTH_URL`                  | `空字符串`                          | OAuth 服务地址,开启后认证将由 OAuth 服务接管                                                                 |
| `FILESERVER`                 | `https://files.xyhelper.cn`         | 文件服务器地址,用于代理官方文件服务器,也可配置为 share 本身对外服务域名(注意开启 https)                      |
| `ASSET_PREFIX`               | `https://oaistatic-cdn.closeai.biz` | 静态资源前缀                                                                                                 |
| `VOICESERVER`                | `https://voice.closeai.biz`         | 语音服务器地址,基于 livekit,用于语音对话                                                                     |
| `SESSION_MAX_AGE`            | `720`                               | 用户登陆会话最大存活时间,单位小时,超过时间后将要求重新登陆,默认为 720 小时,即 30 天                          |
| `ALLOW_CHANGE_CAR_ON_429`    | `false`                             | 是否允许在 429 时会话换车,默认为 false,设置为 true 且 RECORD_CONVERSATION 为 true 时,在 429 时会提示会话换车 |
## 相关文档

- [数据库结构自动维护](./migrate.md) —— 启动时自动建表、补列、建索引的分层策略，以及大表场景的处理办法
- [返回文档索引](../README.md) —— 全部文档列表
