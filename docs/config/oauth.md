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

其实更准确地是，用户登陆界面post或get接收到的所有数据都将被POST转发到该地址



允许用户登陆接口应返回 json 数据

```json
{
  "code": 1,
  "msg": "登陆失败时的提示信息"
}
```

其中 code 为 1 时表示允许登陆，其他值表示不允许登陆

msg 为登陆失败时的提示信息
