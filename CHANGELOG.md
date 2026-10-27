# Changelog

面向**部署与使用**的变更记录。只收录会影响部署步骤、配置项、对外行为与升级操作的内容；
后端内部实现细节、开发流程与构建相关的变更不在此列。

日期为发布日，与本仓库 `deploy` 分支以及镜像的 `latest` 标签同步。升级方式见
[README 的「升级」章节](./README.md#升级)。

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

## [2026-10-26]

本次为 10-25 之后的集中发布，包含账号隔离、资料空间、站点、会话导出与 Turnstile
临时停用等变更。数据库表由服务启动时自动迁移，升级无需手工执行 SQL。

### 新增/变更

- **账号误关防护**：请求级 401/402 先调用 `/accounts/check/v4` 复核，确认凭据失效
  才关闭账号；`Model not found`、workspace 权限不足、5xx/网络抖动不再直接关号。
  探针按 carid 合并并发并缓存，成功时同步 `plan_type` / `isPlus`。
- **只读会话与工作区**：工作区停用/移除后的会话返回本地缓存并标记
  `is_read_only: true`，输入框稳定禁用；`workspace_policy` 等接口不再因会话车不可用
  阻断，`SHOW_WORKSPACE=false` 时会强制回到聊天模式。
- **定时任务隔离**：`chatgpt_tasks` 归属表；任务列表/搜索按用户过滤，详情、归档、
  恢复、mark_read、cancel、turns、stream 先校验归属并按登记车转发；旧任务仅在
  关联会话归属明确时认领。
- **资料空间隔离**：`chatgpt_library_objects` 归属图；space 为根，page/file/directory
  继承归属；`spaces`、`pages`、`files`、`library` 接口按 `usertoken` 过滤和校验，
  共享/协作入口关闭。历史无归属资料默认不展示。
- **站点隔离与公开**：website 纳入资料空间归属；`websites` / `hosting` 的列表、详情、
  预览先校验归属；站点创建/详情后自动 PATCH `share_access=public`；旧站点可通过
  所属会话的 project_id 认领并选用正确车。
- **站点预览修复**：web-ui 补齐 `/sites`、`/sites/{projectId}`、`/sites/{projectId}/*`
  SPA 路由，使用 `cindex` 模板渲染；清理本地 DIL runner 中 Cloudflare 注入的
  challenge 脚本，避免跨域 `contentDocument` 异常。
- **会话标题**：SSE `title_generation` 事件即时原子 upsert 本地标题，避免被
  `New chat` 占位记录覆盖。
- **会话导出**：会话页右上角与分享/更多同一行增加“导出 MD / 导出 PDF”；
  Markdown 过滤内部 code/tool JSON、保留深度思考摘要；PDF 嵌入图片附件；
  文件名包含完整 conversation ID；“换号”按钮下移避免重叠。
- **Turnstile 临时停用**：`TurnstileEnabled()` 代码中固定返回 false，即使配置
  `TURNSTILE_SITE_KEY` / `TURNSTILE_SECRET_KEY` 也不注入前端 key、不要求 turnstile、
  不调用 siteverify、不校验 token。不提供环境开关，后续修复后再恢复。
- **固定值接口本地化**：`spaces/v2`、`pins/content`、`pages/mentions/inbox`、
  `conversation/:id/url_safe`、`edge`、`conversation/implicit_message_feedback`、
  `aip/connectors/links/list_accessible` 由 web-ui 本地返回；`POST /v1/rgstr`
  也改为 web-ui 本地 `{"success":true}`，不再经过 share。
- **Images 提示图缓存**：`/images-app/*` 改由 web-ui 从
  `https://persistent.oaistatic.com` 拉取并落盘缓存，不再落到 iOS API 上游；
  `scribble-sheet.webp`、`wanderlust-postcard-sheet.webp` 已验证为有效 WebP。
- **Web UI 工作标签默认隐藏**：compose 设置 `SHOW_WORKSPACE=false`，并兼容新版
  “聊天/工作”切换器；持久化的 work 模式会自动切回 chat。
- **新版侧边栏开关**：新增 `SHOW_SITES_MENU`、`SHOW_EXPLORE_MENU`；同时修正
  `SHOW_PLUGINS_MENU` 对新版 `enabled` 字段的适配。`SHOW_GPT_MENU` /
  `SHOW_AGENTS_MENU` / `SHOW_DEEP_RESEARCH_MENU` 在新版 UI 已没有对应独立入口，
  建议改用 `SHOW_EXPLORE_MENU` 或按旧模板保留。
- **只读提示定位**：会话不可用时提示不再因 composer 尚未挂载/零尺寸而跑到左上角。
- **数据库维护入口**：share 管理后台首页新增“数据库维护”，可检查待补表/列/索引，
  并异步执行补全、清理重复 convid、创建唯一索引；启动前校验磁盘剩余空间。
  自动迁移仍保留 1000 万行阈值，大表需在后台人工触发强制维护。
- **会话重复 convid 清理**：恢复建唯一索引前的去重迁移，避免公共部署存量重复
  数据导致 `uk_convid` 创建失败和会话 404；升级前请备份数据库。
- **管理后台启动 panic 修复**：数据库维护控制器注册时补上 Service，避免 EPS 下
  启动空指针；hotfix 镜像已重新发布。
- **工作台排行榜**：今日车号/用户用量 TOP 直接显示完整 carID / userToken，
  不再读取备注或截断 token。
- **会话占位记录**：SSE 首次出现 conversation_id 时同步写入占位并标记待补全，
  避免用户回复后立即切走、未触发 lat/r 时丢会话。
- **占位写入时间字段**：补齐 `createTime`/`updateTime`，修复新会话因字段
  NOT NULL 无默认值导致写入失败、刷新后从列表消失。
- **数据库维护分阶段**：管理后台拆分为“只清理重复（500 条/批）”“只建索引”
  “完整维护”；不按时间判断高峰。远程 MySQL 不再用 `/app` 磁盘空间阻断，
  仅提示需在数据库服务器确认空间。
- **选车页车辆繁忙状态**：上游用户请求 429 后记录短期 Redis 繁忙状态，选车页
  显示倒计时并允许“仍要进入”；429 且无本地历史时提示换车后新建会话。
  share 和 web-ui 两份选车页均已适配。
- **置顶会话恢复**：新版 UI 的 Pinned 区域调用 `GET /pins?item_type=conversation`；
  share 新增本地实现按 `is_starred` 返回，web-ui 不再固定返回空数组，修复置顶后
  会话从列表消失。
- **置顶聊天打开空白**：普通聊天不再返回空 `gizmo_id`，避免前端生成 `/g/c/<id>`
  错误路由；置顶项现在跳到正确的 `/c/<id>`。
- **Library 文件下载**：直连 openai-proxy 时，`libfile_...`（如“下载Word初稿”）
  改由 iOS 上游 `download_url` 转换为同源 `/backend-api/estuary/content`；
  web-ui 增加 `/api/library/*` 代理。普通 `file_...` 附件下载不变。
- **Binlog 管理（第一阶段）**：数据库维护新增 binlog 状态、文件范围、总大小、
  从库数量和自动保留天数；支持设置 `binlog_expire_logs_seconds`，不执行 PURGE。
- **conversation_origin 补写**：发送和新会话占位时写入聊天/工作来源，仅在值变化时
  UPDATE，避免无意义 binlog。
- **TPP 模型列表**：更新 web-ui `resource/public/tppmodel.json` 的模型列表与文案。
- **429 限流兜底**：会话详情 429 仍展示本地历史，但用 `is_rate_limited=true` 区分，
  不锁输入框，允许继续提问；Codex 用量刷新从 5 分钟降到 30 分钟，会话备份默认
  改为 4 小时，降低后台请求触发 429 的概率。
- **静态资源与缓存**：AVIF 静态资源加入白名单；Service Worker 缓存版本纳入关键
  资源哈希，模板更新后自动切换缓存桶。
- **部署安全**：日志不再输出 accessToken/refreshToken/user token；升级后新日志不会
  再包含凭据，建议轮换历史日志曾外发的 token。

### 修复

- **会话刷新 422**：上游 `num_turns` 上限为 100，备份刷新改用 100。
- **`owner_count` 被 404 路由拦截**：放行
  `/accounts/{account_id}/users/owner_count`，按会话 referer 选择会话车。
- **mounted capabilities 被隔离误伤**：放行
  `/files/library/mounted/capabilities`，避免 Google Drive/Dropbox/SharePoint
  被误判为未连接；mounted 搜索/预览仍隔离。
- **只读会话工作区设置阻断**：`workspace_policy` 在会话车不可用时回退当前 Session
  车，工作区停用返回空策略，前端稳定显示只读提示。
- **文件/附件跨车路由**：附件、图片、文件信息与会话详情统一按会话所属车路由；
  上游详情不可用时回退本地只读备份。

## [2026-10-25]

### 新增/变更

- **Deep Research（深度研究）MCP sandbox 改走单域名 `sandbox.xyhelper.cn`**：
  新版 ChatGPT 模板的 MCP app sandbox 会请求 `mcp-app-*.web-sandbox...` 地址；
  没有泛解析时无法到达。部署时增加一条 `sandbox.xyhelper.cn` DNS（Cloudflare
  可保持 CDN 开启），由 Caddy 以 HTTP:80 回源反代到
  `https://web-sandbox.xyhelper.cn`，不需要 `*.web-sandbox.xyhelper.cn` 泛解析。
  Caddy 配置见 `chatgpt-web-ui` 仓库的 `deploy/sandbox.xyhelper.cn.Caddyfile`。
- **模板更新后需要重新执行 MCP sandbox 补丁**：
  `chatgpt-web-ui/scripts/patch-mcp-sandbox.sh` 会把 sourceUrl 固定到
  `https://sandbox.xyhelper.cn/`，并适配 sourceUrl 校验。模板版本更新后必须
  重新执行一次；当前模板已执行。
- 跨车会话的附件、图片、文件信息与会话详情统一按会话所属车路由；会话详情在
  上游不可用时继续回退本地只读备份。升级后无需数据迁移。
- `ProxyBackendWithCar` 响应新增 `X-Car-Id`，便于前端/排障确认实际会话车号。

### 修复

- **`POST /backend-api/files` 偶发 500**：`devicecheck` 缓存读取不再跟随客户端
  请求取消，避免 Redis `context canceled` 被误报为 500。升级后无需操作。
- **统一 `/backend-api/*` 会话选车兜底**：未知接口也会按 route/query/JSON body/
  `xy-refer` 识别会话，避免逐个漏配路由；同时修复 body 重复发送导致的 502。
  升级后无需操作。
- **避免账号被误关闭**：凭据刷新只在明确判死时关闭账号，5xx/网络抖动等未确认
  错误保留原状态；单个工作区停用不再关闭整个账号。工作区停用/移除后，属于该
  工作区的会话详情直接返回本地缓存并标记 `is_read_only: true`，只读展示。
  升级后无需操作。
- **只读会话不再阻断工作区设置**：`workspace_policy` 等工作区接口在会话车不可用
  时回退当前 Session 车，工作区停用返回空策略；前端输入框和发送按钮稳定禁用，
  并显示“此会话已不可用，仅可查看历史内容”。升级后无需操作。
- **AVIF 静态资源恢复缓存**：`/cdn/assets/*.avif` 已加入静态资源白名单，
  上游 200 后会落盘；之前缺失的 `fallen-pet.*.avif` 不会再 404。
- **Service Worker 缓存版本加入关键资源哈希**：模板 JS 更新后会切换
  `tpl-static-*` 缓存桶，避免老用户继续命中旧模板导致深度研究无法打开。
- **账号误关修复**：请求级 401/402 先用 `/accounts/check/v4` 复核，确认凭据失效
  才关号；`Model not found`、workspace 权限不足等不再关闭账号。探针按 carid 缓存
  并合并并发，成功时同步 `plan_type` / `isPlus`。
- **固定值接口本地化**：web-ui 本地返回 `spaces/v2`、`pins/content`、
  `pages/mentions/inbox`、`conversation/:id/url_safe`、`edge`、
  `conversation/implicit_message_feedback`、`aip/connectors/links/list_accessible`，
  不再经过 share/proxy 逐层透传。
- **定时任务隔离**：新增 `chatgpt_tasks` 归属表，任务列表/搜索按用户过滤，
  详情、归档、恢复、mark_read、cancel、turns、stream 先校验归属并按登记车转发；
  旧任务仅在关联会话归属明确时认领，避免同一账号下的任务跨用户可见。
- **Web UI 工作标签默认隐藏**：部署 compose 设置 `SHOW_WORKSPACE=false`，
  并兼容新版“聊天/工作”切换器结构；需要显示时改为 `true`。已处理上次持久化的
  work 模式会自动切回 chat，避免隐藏切换器后无法切回。
- **资料空间隔离**：新增 `chatgpt_library_objects`，space 为根，page/file/directory
  继承归属；spaces/pages/files 接口按 `usertoken` 过滤和校验，共享/协作入口关闭。
  历史无归属资料默认不展示。
- **会话刷新 422 修复**：上游 `num_turns` 上限为 100，刷新任务改为 100，避免反复 422。
- **站点功能**：website 纳入资料空间归属；站点创建/详情后自动 PATCH
  `share_access=public`；web-ui 补齐 `/sites` 预览路由并清理 DIL runner 中
  Cloudflare challenge 脚本。
- **接口误拦修复**：放行 `accounts/{id}/users/owner_count` 与
  `files/library/mounted/capabilities`。
- **会话标题**：SSE `title_generation` 事件即时原子更新本地标题，避免被
  `New chat` 占位记录覆盖。
- **会话导出**：web-ui 会话页增加“导出 MD / 导出 PDF”，与分享/更多同一行；
  Markdown 保留深度思考摘要、PDF 嵌入图片附件，文件名包含完整 conversation ID；
  “换号”按钮下移避免重叠。

## [2026-10-22]

### 变更

- **会话备份兜底任务默认改为每 4 小时一次**：`docker-compose.yml` 新增
  `CONVERSATION_REFRESH_CRON: "@every 4h"`（原默认每小时）。上游会话列表接口有限流，
  账号/会话较多时每小时一轮容易触发 429；改成 4 小时可显著降低请求量。
  会话备份只用于上游不可用时兜底展示，用户打开会话仍是实时拉取，不受影响。
  可按需改成 `@every 6h` 或恢复为 `@hourly`；修改后
  `docker compose up -d chatgpt-share-server` 重建容器生效（仅改环境变量不会自动生效）。

### 修复

- **会话备份任务对上游会话列表的请求过于频繁，已触发 429**：本地服务器保存会话内容时，
  后台任务会先拉取账号的会话列表判断哪些会话真的变了。原实现按批处理，
  同一账号的会话散落在多个批次时每个批次都会重新请求一次列表，且每次固定翻满 3 页；
  待更新会话多时会持续撞上游限流，导致本地备份刷新失败并进入退避。
  现在单次任务内同一账号最多请求一次列表，目标会话全部找到后立即停止翻页；
  被限流的账号本次任务内不再重试、统一推迟 10 分钟。升级后无需操作，
  会话备份行为与展示逻辑不变。
- **打开历史会话时提示会话不可用（`conversation_inaccessible`）**：部分会话记录的
  「账号 ID」还是旧账号/已移除工作区的值，服务在请求上游时继续携带它，导致即使会话
  仍在当前账号下也会被判为不可访问。现在只在账号 ID 仍属于当前凭据可见范围时才携带，
  个人账号不再携带该头；会话确实属于其他账号身份时仍会提示不可用（属上游数据归属，
  本地无法恢复）。升级后无需操作。
- **会话失效时无法查看本地备份**：新版前端用
  `/backend-api/conversations/<id>?num_turns=...` 加载会话，该接口原来只做转发，
  上游 404（会话不可访问）/401/402/429 时直接报错，本地备份内容没用上。
  现在这类请求失败时会自动返回本地缓存，并以只读方式展示；会话所属账号已下线
  （被禁用或缓存丢失）时同样会回退到本地备份。上游正常时仍返回原始结构。
  升级后无需操作。

## [2026-10-19]

### 新增

- 账号列表新增**「关闭原因」列**：账号被自动关闭时同时记录原因与操作位置
  （形如 `2026-10-19 20:42:52 [RefreshSession] 刷新失败（凭据已失效）：HTTP 401 ...`），
  覆盖刷新失败、对话接口 401、Model not found、unusual activity、账号检测失败、
  后台手动关闭等所有会置为不可用的路径。原因不随账号恢复而清空（相当于最后一次
  故障现场），前端只在账号当前不可用时展示；列内单行省略、悬停看摘要，点开弹窗
  可查看全文并一键复制。新增列由服务启动时自动迁移，升级无需手工 SQL。

### 变更

- **会话备份的更新策略调整（适配上游会话详情接口限流）**：
  - 对话结束后不再立即全量拉取会话内容，改为标记待更新，由后台兜底任务合并处理；
    兜底任务默认每小时一次，可用环境变量 `CONVERSATION_REFRESH_CRON` 调整频率
    （如 `@every 4h`）。
  - 客户端心跳触发的待更新标记 10 分钟内只写一次；同一会话的并发拉取自动去重；
    拉取失败按 1–30 分钟指数退避，避免持续撞限流。
  - 兜底任务会先用**会话列表**（轻量接口）比对每个会话的 `update_time`，
    上游没有变化就不再拉详情；超出最近窗口或时间缺失的会话仍按原方式拉详情。
  - **用户打开会话仍然实时获取最新内容**；本地备份只在账号失效、上游不可用时兜底
    展示，展示方式与降级逻辑不变。
  - 新增 `content_update_ts` / `last_pull_time` / `pull_fail_count` / `next_pull_after`
    列，均由服务启动时自动迁移，升级无需任何操作。
- **支持内嵌账号信息的 accessToken**：部分 accessToken 在 JWT 内写入了
  `chatgpt_account_id` 与 `chatgpt_plan_type`（如 `accessToken-WithId` 格式）。
  使用这类 token 时，请求携带的账号 ID 与记录的套餐类型固定取 token 内的值，
  不再依赖 `accounts/check` 的返回值；普通 accessToken 的行为完全不变，无需配置。

### 修复

- **工作区套餐被误判为「免费号」**：此前按 `accounts/check` 返回的默认账号判断套餐，
  当默认账号指向同账号下的个人免费账号时（如 5x1 的 `self_serve_business_prolite`），
  客户端会显示为免费版。现在只有上游明确返回 `free` 才算免费，其余套餐（含以后
  新增的任意类型）一律按付费处理；`plan_type` 原样记录并在后台「套餐」列展示，
  出现新套餐类型无需改代码。升级后已有账号会在下次刷新成功时自动校正，
  `plan_type` 列由启动时的自动迁移与回填补齐，无需手工操作。
- **上游返回 `404 {"detail":"Model not found"}` 时账号仍被继续派发**：现在命中该响应
  （仅限 404 + JSON + 该 detail）会把账号置为不可用并记录关闭原因，返回给用户的是
  本地化的「账号繁忙」提示，不再是一句 `Model not found`。升级后无需操作。
- **状态徽章在缓存异常时误关账号**：`/status`、`/endpoint` 在本地会话缓存缺失或
  Redis 抖动时，原来会直接把账号置为不可用（公开徽章请求即可触发）。现在会先从
  数据库自动回填缓存并继续判断；缓存/数据库问题只显示「不可用」徽章、不写库，
  只有凭据本身无法解析时才关号。关闭原因记录与「只在启用状态时写入」的规则保持不变。
  升级后无需操作。
- **部分代理接口响应可能被截断或一直等待**：`/_next` 页面数据与
  `/public-api/gizmos/discovery` 在改写响应内容后没有同步 `Content-Length`，
  客户端可能按旧长度读取而卡住/截断。现已统一同步长度，并在上游返回压缩响应时
  保留原始内容。升级后无需操作。
- **兜底代理会让流式响应卡住、大文件额外占内存**：未命中专用接口的 `/backend-api/*`、
  `/g/{id}.data` 请求原来会把整个响应读完再改写域名，流式输出要等上游结束才返回，
  大附件/图片也整段读进内存。现在只改写小体积文本类响应，流式、二进制、压缩内容
  以及超过 2MB 的响应用原始方式直接转发；顺带修复了并发请求之间可能串用改写域名的
  问题。升级后无需操作。
- **日志不再包含凭据**：启动日志不再打印 `AUTHKEY`/`APIAUTH` 的值；会话刷新、登录、
  心跳、批量添加、统计等日志不再输出 accessToken、refreshToken、用户 token 或
  原始账号行，失败日志只保留安全摘要。**如果历史日志曾被外发/集中采集，建议轮换
  相关 token 与密钥**；升级后新日志不会再出现这些内容。
- **同一会话可能出现多条记录、标题生成后不生效**：会话表缺少会话 ID 唯一约束，
  并发打开会话或重复回调时会插入重复行，列表里能看到多条；标题写入要求「恰好一行」
  才执行，出现重复后就再也不更新。现在会为会话 ID 建立唯一索引，并改为幂等的
  写入方式（重复执行只更新、不新增），标题可以正常写回。
  **升级提示**：首次启动时后台任务会先合并历史重复记录（每个会话只保留内容最完整
  的一条），该操作会删除多余行，**建议升级前备份数据库**；表行数超过 1000 万时
  不会自动执行，日志里会给出可直接执行的 SQL，请择机手工处理。

## [2026-10-02]

### 修复

- 修复**车辆不可用时展示的会话备份可能是旧内容**的问题：判断「本地备份是否比上游新」
  时，数据库里的时间被当成了服务器本地时间，而两者的时区并不相同（实际相差 8 小时），
  判断结果几乎恒为「本地更新」，于是只要上游在最近 8 小时内改动过会话，本地备份就
  再也得不到更新。现在改为由数据库统一换算成绝对时间后再比较，升级后无需任何操作。
- 修复**新会话在数据库里缺少记录**的问题：打开一条尚未记录的会话时会创建一条占位
  记录，但创建语句使用了一个不存在的列名，写入必定失败（失败只写进服务日志），这类
  会话因此没有本地备份。现已修正。
- 顺带降低数据库压力：打开会话时不再无条件读取、也不再无条件整篇回写备份内容
  （单条会话的备份内容可达数十万字节），确认时间与内容都没有变化时不产生读写。

## [2026-10-01]

### 新增

**部署包**

- 新增 `chatgpt-web-ui` 服务（宿主机 `8400`）：新的用户入口，以 `share` 模式对接本地
  `chatgpt-share-server`（`UPSTREAM_URL=http://chatgpt-share-server:8001`）。未登录时先
  展示车队列表页（`LOGIN_URL=/list`），登录后进入新版聊天界面。**上线前必须修改
  `FAKE_TOKEN_SECRET`**，详见下方「升级注意」。
- 新增 `chatgpt-file-deletion` 服务（宿主机 `9900`）：定期清理账号在 ChatGPT 侧上传的
  库文件（附件、图片等），避免存储越用越满。`chatgpt-share-server` 已通过环境变量
  `LIBCLEANUPSERVER` 预先接通，全新部署无需额外配置；管理页在 `9900/gpt.html`。
- `auditlimit` 改用「模型 → 限流值」的新配置：每个模型一个配置键，值为 `次数/时间`
  （如 `GPT-5-6: "60/3h"`），未单独配置的模型回落到 `DEFAULT`；把某个模型的值写成
  `DISABLED` 即可禁用该模型（请求返回 403 `model_disabled`）。旧的 `LIMIT` / `PER`
  写法已失效。

**服务端**

- 新增 `GET /backend-api/conversations/:convid` 与
  `GET /backend-api/conversations/:convid/messages` 路由，支持新版前端按复数路径获取
  会话与消息记录。
- 全部面向用户的提示改为按请求语言返回中/英文（语言取自 cookie `oai-locale` →
  请求头 `OAI-Language` → `Accept-Language`，默认英文），不再中英混排。
- `/backend-api/conversation/init` 的会话初始化元数据采集改为**默认开启的固定行为**：
  配置项 `CONVERSATION_INIT_METADATA_ENABLED` 写什么都不会改变它（`CONVERSATION_INIT_METADATA_TTL_SECONDS`
  仍可调，默认 86400 秒）；管理接口 `/adminapi/chatgpt/conversation-init` 的 `/info`、
  `/list` 始终可用。
- 车辆列表在同等可用状态与权重下让 Plus 车辆优先展示。
- 账号凭据额外保留一份「最后一次可用」的备份，并可一键恢复：每次刷新**确实拿到
  凭据**时才更新这份备份，上游返回异常（5xx、网络抖动、响应体异常等）时保持不动，
  因此不会被错误响应冲掉。账号列表新增「历史可用session」列与「恢复session」按钮，
  凭据被写坏的账号可一键换回备份并自动重新刷新（恢复后要等下一次刷新成功才会重新
  上线，无备份的账号会直接提示）；备份全文可在该列点「查看」弹窗阅读、点「复制」
  直接取走，升级后历史账号的备份会在启动时自动补齐，无需手工操作。
- 账号列表新增「套餐」列，记录上游返回的套餐类型（plus / pro / team / free /
  edu_plus 等）。上游并非每次都返回该信息，此时保留原有记录不覆盖，因此不会被
  冲成空白；升级后已有的账号会在下一次刷新成功时自动补上。
- 账号列表的搜索框支持在「全部字段 / 邮箱 / 车号」之间切换，选中邮箱或车号时按
  该字段模糊匹配，不必再输入完整内容；选「全部字段」时与升级前行为一致。
- 账号的「日请求量」保留每日历史：账号列表里的「日请求量」数字现在可以直接点击，
  弹出该账号最近 30 天每天的请求量（含今天的实时值与区间合计），历史保留 90 天。
  升级后从当天开始重新计数，历史的每日用量不会再被后续统计覆盖为零。
- 管理后台首页改为展示实际运行概览：账号总数与在线 / 下线 / 免费 / 检测异常数量、
  用户总数与登录态有效 / 已过期数量、今日请求量与活跃车号 / 活跃用户数、最近 30 天
  请求量趋势、账号套餐分布，以及今日用车号与用量的排名。数据全部来自实时计数与
  每日汇总，不再显示示例数据。

### 变更

- **不再根据上游返回的模型列表长度判断账号是否为付费账号**。该判断原来表现
  为「模型列表不止一个就是付费号」，但上游已不再这样区分，免费账号同样可能返回
  一长串模型，导致账号的付费/非付费属性被随机写错（免费号被当成付费号使用，或
  付费号被降级）。现在改为：默认按付费账号处理，只有上游明确返回免费套餐时才
  降级。升级后账号的属性会在下一次刷新成功时按新规则校正，无需手工操作。
- **移除跨车（换车）功能**：会话所属账号失效时不再自动换车继续对话，改为直接提示
  「请新建对话后重试」。
- **移除 API 模式**：配置项 `APIMODELS` / `APISERVER` / `APISERVERAUTH` 不再生效，会话
  统一走 GPT 对话通道；仍写在 `config.yaml` 里的可以删除。
- **移除 Arkose 验证码代理模块**：`ARKOSE_URL` 配置项与 `/v2/*`、`/fc/*`、`/dapib/*`
  等代理路由已移除（登录流程中与官方验证码交互的部分保留，管理后台登录校验不受影响）。
- `Connection` / `Upgrade` / `TE` 等逐跳请求头不再转发给上游：修复经 nginx 反向代理
  （`proxy_set_header Connection $connection_upgrade;`）时对话发消息失败的问题。
- **日请求量改为按北京时间自然日（00:00）切分**：此前以 UTC 计时，日界落在北京时间
  16:00，与运营和流量统计的习惯不符。现在每天零点清零实时计数并转入历史记录，
  北京时间当天的用量就是后台看到的数字。
- **统计的数据库压力大幅下降**：原先每隔几分钟就要把全部账号 / 用户连表读数、逐个
  写回，现在只处理当天真正产生过请求的账号与用户，并合并成批量写入；当天无人使用时
  全程不访问数据库。同时落库频率由「每小时 + 每 5 分钟两份任务」合并为一份 10 分钟
  任务。
- 账号列表里的「更新时间」不再被统计任务每隔几分钟刷成当前时间，恢复为只反映账号
  自身的变更（刷新凭据、修改备注等）

### 修复

- 修复管理后台首页在窗口宽度较窄时卡片区域出现多余横向滚动条的问题（页面内容
  并未超出容器，属于排版溢出）。
- 修复日用量统计在「同一天有多个账号或用户出现请求变化」时写入失败的问题：此前
  一批统计里只要有两个及以上账号同时发生变化，整批记录就会失败（只有恰好一个账号
  发生变化时才能通过，所以不容易发现），后果是账号列表的「日请求量」与账号详情里
  「最近 30 天」当天的数值长期停在旧值、当天甚至显示为 0，同时服务日志每 10 分钟
  报一次错；后台首页的今日请求量取自实时计数，不受影响。升级到本版本后无需任何
  操作，下一次统计会把当天的用量正确落库。
- 账号刷新时遇到**上游异常**（5xx、网络抖动、响应体异常等）不再覆盖已保存的凭据：
  此前这类错误会把上游的失败响应整段写进 `officialSession`，`refresh_token` 被冲掉、
  账号只能靠人工重新录入才能恢复。现在只有「凭据确实已失效」才会落库失败响应，
  其余情况只把该车暂时下线，凭据原样保留，下一次自动刷新即可恢复。
- **修复升级后接口报 `Unknown column 'sort' in 'order clause'`**：配置项
  `cool.autoMigrate` 在部分版本上读取失效，启动时不再补齐新增字段。现已修复读取逻辑，
  重启容器即自动补齐，**无需手工执行 SQL**。
- **修复大表实例升级后「服务假死」**：启动时的建表 / 补列 / 建索引改为分层策略 ——
  表缺失与列缺失在启动时同步补齐、失败即退出并由容器自动重试（绝不带缺列对外服务）；
  索引缺失在后台异步创建；列定义变更只报告不自动执行。拿不到表锁时按 10s → 20s → 40s
  退避，总预算 5 分钟。**估算行数超过 1000 万的大表会跳过自动建索引**，并在日志中打印
  可直接复制执行的手工 `ALTER` 命令。
- 修复整点会话刷新任务在数据积压时内存爆掉（`OOMKilled`）的问题：改为分批处理，不再
  整行加载巨大的 `content` 字段。
- 修复 SSE 流中的错误提示被丢弃、用户只看到上游英文原文的问题。
- 修复车辆状态徽章中中文 / Emoji 被挤压变形的问题。
- 修复 MySQL 列名大小写不一致导致的部分查询与账号状态更新失效（`carID`、`userToken`、
  `convid`）。
- 修复上游 401 / 402（token 失效、账号欠费）时未真正关闭账号、失效账号仍会被继续分配
  使用的问题；现在会置 `status = 0` 并清除缓存，对用户统一提示「会话所属账号暂时不可用，
  请新建对话」。
- 修复图片等文件内容在进程内无限缓存的问题（缓存改为 1 小时后过期）。

### 安全

- 修复依赖链中的已知漏洞（`govulncheck` 扫描，影响实际调用链的漏洞已清零）。
- 部署包补充安全提示：
  - `docker-compose.yml` 顶部新增「部署后请确认」清单，并在 `mysql`、`redis`、
    `chatgpt-share-server`、`chatgpt-file-deletion`、`watchtower` 处分别注明口令同步
    要求、端口暴露面与镜像自动更新行为
  - `config.yaml` 说明「配置文件优先于同名环境变量」，并标注 `modules.base.jwt.secret`、
    `cool.file.domain`、数据库口令三处默认值的后果
  - `./deploy.sh` 执行后会输出一份安全自检结果（检测上述默认值、提醒管理员口令与
    `8300` / `9900` 的暴露面）。**只提示，不会改写你的文件。**

### 文档

- 用户手册迁入本仓库 [`docs/`](./docs/README.md)：原文档站
  `chatgpt-share-server.xyhelper.cn` 已下线，本仓库的 `docs/` 是唯一对外手册。
- 新增 [数据库结构自动维护](./docs/config/migrate.md)：启动时建表 / 补列 / 建索引的
  分层策略、算法降级链、大表（> 1000 万行）手工建索引 SOP 与时间窗口建议、容器内
  `migrate` 子命令用法。
- 新增 [附带服务配置](./docs/config/services.md)：`chatgpt-web-ui`、
  `chatgpt-file-deletion`、`auditlimit`、`watchtower`、`mysql` / `redis` 的环境变量与
  调用关系。
- 手册按现有代码整体校对，修正了若干与实际不符的描述：上传路由
  （`/files?upload_url=` 并不存在，实际是 `/backend-api/files`）、语音服务默认端点
  （`wss://webrtc.xyhelper.cn`）、多端登录配置键（`PROHIBIT_MULTIPLE_LOGIN`）、
  自由模式 token 长度（6–50）、`FILESERVER` 等已不再生效的配置键说明。
- 「升级」章节强化了「手动 `git pull` 会覆盖 `docker-compose.yml` / `config.yaml`」的
  警示，附三条命令的后果对照表与完整的安全升级步骤。

### 升级注意

- 首次升级到本版本后，**务必修改 `FAKE_TOKEN_SECRET`**：`chatgpt-web-ui` 以 `share`
  模式运行，用它给用户签发登录态，`docker-compose.yml` 中的占位值等同于公开签名密钥。

  ```bash
  cd chatgpt-share
  SECRET=$(openssl rand -hex 32)
  sed -i "s/change-me-to-a-random-secret/$SECRET/" docker-compose.yml
  docker compose up -d chatgpt-web-ui
  ```

  密钥变更后已登录用户的 cookie 会失效、需要重新登录，属正常现象。

- `docker-compose.yml` 与 `config.yaml` 你可能已按需改过。**不要用 `git checkout .` /
  `git reset --hard` 拉取更新**，那会永久丢弃你的改动；请按
  [README → 升级](./README.md#升级) 的步骤先备份再合并。
- 数据库结构会在容器启动时自动补齐，**不需要手工执行 SQL**；升级前建议先备份 `data/`
  目录。升级后首次启动还会顺带跑一轮「可用凭据备份」的历史数据补齐扫描（分批、只读
  单列），数据量大时属正常开销。
- 若 `config.yaml` 中仍保留 `APIMODELS` / `APISERVER` / `APISERVERAUTH` / `ARKOSE_URL`，
  可以删除，已不再生效。

## [2026-09-29]

### 修复

- 修复老库实例升级后接口报 `Unknown column 'sort' in 'order clause'` 的问题（配置项
  `cool.autoMigrate` 在部分版本上读取失效，新增字段不再被自动补齐）。已部署实例无需
  修改 `config.yaml`，重启容器即自动补齐。

## [2026-09-18]

### 变更

- 车辆列表排序在同等条件下让 Plus 车辆优先展示。

## [2026-09-09]

### 修复

- 修复配置文件中的**大写键读取失效**：`APIAUTH`、`CHATPROXY`、`AUTHKEY` 等键在部分版本上
  会静默回退为默认值，导致 APIAUTH 管理接口鉴权等配置形同虚设。**若你依赖
  `/adminapi/chatgpt/*` 对接接口，升级后请确认 `APIAUTH` 仍然生效。**
- 修复经 nginx 反向代理时对话发消息失败（逐跳请求头被原样转发上游）。
- 上游返回 401 时临时关闭对应车辆并提示用户新建会话，不再透传上游错误原文。

## [2026-09-01]

### 修复

- 修复上游返回 401 / 402 时账号未被真正关闭、失效账号仍可能被继续分配使用的问题。

## [2026-08-27]

### 新增

- 新增完整的 i18n 支持，所有面向用户的提示按请求语言返回中/英文。

### 变更

- `/backend-api/conversation/init` 的元数据采集改为默认开启的固定行为。
- 连接器（connectors）相关路由改为直接代理到官方后端，支持真实的连接器列表与操作。

### 修复

- 修复整点会话刷新任务在数据积压时 OOM 的问题。
- 修复会话 / 对话接口把巨大的 `content`、`officialSession` 字段整行载入内存的问题
  （刷新任务改为分批游标处理）。
- 修复车辆状态徽章中中文 / Emoji 被挤压变形的问题。
- 移除不再使用的 Arkose 验证码代理模块与 `ARKOSE_URL` 配置。

### 安全

- 修复依赖链中的已知漏洞。

## [2026-08-26]

### 新增

- 新增 `GET /backend-api/conversations/:convid/messages` 路由。

### 变更

- 文件下载 / 上传相关的响应改写逻辑移除，`download_url` / `upload_url` 不再被改写为
  本地地址。

## [2026-08-22]

### 变更

- 所有「登录已失效」提示改为中英双语。

### 修复

- 修复数据库字段大小写引用错误（`carID`、`userToken`、`convid`），此前会导致部分查询与
  状态更新静默失效。

## [2026-08-21]

### 新增

- 新增 `GET /backend-api/conversations/:convid` 路由。

### 变更

- **移除跨车（换车）功能**：会话所属账号失效时不再自动换车，改为提示用户新建对话。
- **移除 API 模式**：`APIMODELS` / `APISERVER` / `APISERVERAUTH` 配置项移除。
- 车队列表改为随仓库分发的本地静态资源，不再在启动时从上游仓库拉取。

### 改进

- 会话列表查询性能优化（新增复合索引，`LEFT JOIN` 改写为 `EXISTS` 子查询）。

## [2024-08-21] 及更早

早期部署包（`docker-compose.yml`、`deploy.sh`、`quick-install.sh`、初始 SQL 与
`auditlimit` 限流器集成）的历次调整，详见本仓库的提交历史。
