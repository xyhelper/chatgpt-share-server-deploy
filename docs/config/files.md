# 文件服务

share 本体**不保存**用户上传的文件，上传、下载、取文件内容这些请求都由 share 本体就地
转发到上游（接入网关 / `*.oaiusercontent.com`），所以真正需要关心的是接入网关
`CHATPROXY` 是否可用，而不是文件服务域名。

## 相关路由

这些路由都挂在 share 主体上，由它转发给上游：

| 路由 | 说明 |
| - | - |
| `POST /backend-api/files` | 文件上传（multipart） |
| `POST /backend-api/files/process_upload_stream` | 分片上传的续传请求 |
| `POST /backend-api/files/:fileid/uploaded` | 通知上游上传完成 |
| `GET /backend-api/files/:fileid` | 查询文件信息 |
| `GET /backend-api/files/download/:fileid` | 下载文件 |
| `GET /backend-api/files/library/storage/usage` | 查询存储用量 |
| `GET /backend-api/estuary/content` | 取文件内容（走 `CHATPROXY`） |
| `GET /file-{fileid}` | 直连文件的兜底反代，目标固定为 `https://files.oaiusercontent.com` |
| `GET /proxy/{host}/*` | 反代 `https://{host}.oaiusercontent.com`，用于 `web-sandbox` 等子域 |

> **提示：反向代理要放宽请求体**
> 上传是一个几百 MB 的 `POST` 请求，服务端自身的上限是 200MB，nginx 等前置代理
> 的 `client_max_body_size` 不要小于这个值，详见[安装指南的「反代配置」](../install/README.md)。

## 文件直链的域名

上游返回给用户的文件地址仍然是上游域名（`https://files.oaiusercontent.com/...`），
share 本体不会改写它。要让这些地址落在自己的域名下，需要自己在前置代理上用同样的路径
反代过去。share 自带的旧版页面是通过 `resource/public/xy.js` 在浏览器侧做替换的：

- `https://chatgpt.com`、`https://ab.chatgpt.com` → 当前访问的域名
- `https://web-sandbox.oaiusercontent.com` → `https://web-sandbox.xyhelper.cn`
- `https://connector_openai_deep_research.web-sandbox.oaiusercontent.com` → `https://connector_openai_deep_research.xyhelper.cn`

这些替换是写死在前端脚本里的，不读取配置。

## 关于 `FILESERVER`

历史版本用 `FILESERVER` 指定文件服务器域名（`config.yaml` 里还留着
`https://files.oaiusercontent.com`、`https://files.freegpts.org` 这样的注释示例），
但**当前版本的代码里已经没有任何地方读取它**——它只在启动时被打印一次
（`FILESERVER: https://files.xyhelper.cn`），配置成别的值不会改变任何行为。
同样地，`USE_LOCAL_FILE_SERVER` 与 `OAIUSERCONTENT_CDN_DOMAIN` 也属于只读不用的键，
详见[配置指南](./README.md)的「尚未生效」一节。

也就是说：**不需要为了文件功能配置 `FILESERVER`**，把 `CHATPROXY` 配对即可。

## 库文件清理

用户库里的历史文件如果要定期清理，用部署包内置的 `chatgpt-file-deletion` 服务，
在 share 上通过 `LIBCLEANUPSERVER` 配置调用地址（部署包已配好），说明见
[附带服务配置](./services.md)。

## 相关文档

- [配置指南](./README.md) —— 全部配置项与「尚未生效」键列表
- [安装指南](../install/README.md) —— 反向代理与请求体大小
- [附带服务配置](./services.md) —— 库文件清理服务
- [返回文档索引](../README.md)
