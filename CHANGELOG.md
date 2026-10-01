# Changelog

面向**部署与使用**的变更记录。只收录会影响部署步骤、配置项、对外行为与升级操作的内容；
后端内部实现细节、开发流程与构建相关的变更不在此列。

日期为发布日，与本仓库 `deploy` 分支以及镜像的 `latest` 标签同步。升级方式见
[README 的「升级」章节](./README.md#升级)。

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

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
