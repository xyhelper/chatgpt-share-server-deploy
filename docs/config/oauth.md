# OAUTH


配置环境变量或在 config.yaml 中配置

```yaml
OAUTH_URL: https://xxxxx.xxx.com/oauth
```

当该值被配置后，用户登陆时将向该地址 POST 以下数据

```
usertoken: 用户Token
carid: 车牌号
```

其实更准确地是，用户登陆界面 post 或 get 接收到的所有数据都将被 POST 转发到该地址
(登陆表单里除上面两项外还包括 `resptype` 等字段)。

不配置 `OAUTH_URL` 时，它会回落到 `http://127.0.0.1:<PORT>/auth/oauth`，也就是由服务自身
的演示接口校验用户：从本地 `chatgpt_user` 表里按 `userToken` 查找未过期记录，因此
**默认情况下用户 Token 需要在后台「用户管理」里先添加**。

## 允许用户登陆接口应返回的数据

```json
{
  "code": 1,
  "msg": "登陆失败时的提示信息",
  "expireTime": "2026-10-01 12:00:00",
  "carid": "车牌号",
  "usertoken": "覆盖用的用户Token"
}
```

| 字段 | 是否必需 | 说明 |
| - | - | - |
| `code` | 必需 | `1` 表示允许登陆，其他值表示不允许登陆 |
| `msg` | 可选 | 登陆失败时的提示信息，`code` 不为 `1` 时展示给用户 |
| `expireTime` | 可选 | 用户 Token 的过期时间，写入会话，用于前端提示 |
| `carid` | 可选 | 返回非空时会**覆盖**请求中的车牌号 |
| `usertoken` | 可选 | 返回非空时会**覆盖**请求中的用户 Token |
| `isPlus` | 可选 | 是否 Plus 用户，演示接口会返回，`Login` 流程不读取该字段 |

> **提示**
> `/auth/login`、`/auth/logintoken`、`/auth/login/token` 等接口都会把上面这份约定用于
> 请求中的 `OAUTH_URL`，其中带 `resptype=json` 的接口在失败时返回 `{"code":0,"msg":"..."}`
> 而不是渲染错误页。

仓库内自带的演示实现见 `auth/oauth.go` 的 `Oauth` 与 `OauthFree`，可以直接参照它对接
自己的用户系统。
