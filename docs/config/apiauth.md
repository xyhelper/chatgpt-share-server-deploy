# API对接

当配置了环境变量 `APIAUTH` 或在 `config.yaml` 中配置了 `APIAUTH` 时，将启用 API 对接功能。  

后台管理页面使用到的`/admin/chatgpt/xxx`接口，将会有一份同样功能的副本 `/adminapi/chatgpt/xxx`，这些接口将会使用 API 对接的方式进行访问。

具体使用即在 header 中传递 `apiauth` 字段，值为 `APIAUTH`，即可访问。
