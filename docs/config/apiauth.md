# API对接

当配置了环境变量 `APIAUTH` 或在 `config.yaml` 中配置了 `APIAUTH` 时，将启用 API 对接功能。

后台管理页面使用到的 `/admin/chatgpt/xxx` 接口，在 `/adminapi/chatgpt/xxx` 下有一份
功能相同的副本。这些接口不走后台登录态，而是使用 `apiauth` 请求头鉴权。

具体使用即在 header 中传递 `apiauth` 字段，值为 `APIAUTH`，即可访问。

```
apiauth: <你在配置里填的值>
```

对外提供的接口前缀如下，每个前缀下都有 cool-admin 标准的 `add` / `delete` / `update` / `info` / `list` / `page`：

| 前缀 | 对应后台功能 |
| - | - |
| `/adminapi/chatgpt/session` | 车队管理 |
| `/adminapi/chatgpt/user` | 用户管理 |
| `/adminapi/chatgpt/conversations` | 会话记录 |
| `/adminapi/chatgpt/conversation-init` | 会话初始化元数据（额外提供 `GET /info`、`GET /list`） |

> **注意**
> - `APIAUTH` 的默认值为空字符串。为空时这些接口仍然注册，但请求头 `apiauth` 为空或与配置
>   不一致都会直接返回 **403**（`apiauth is empty` / `apiauth is error`）。
> - 这组接口属于管理能力，请只在内网或加白名单的反向代理后暴露，不要直接对公网开放 `8300`。
> - 该功能按 `APIAUTH` 的原始大小写读取，写进 `config.yaml` 时键名必须是 `APIAUTH`。
