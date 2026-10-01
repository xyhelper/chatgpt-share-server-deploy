# 数据库结构自动维护

服务启动时会自动检查并维护业务表结构（建表、补列、建索引），**无需任何配置**。
这一节说明它做了什么、为什么这么设计，以及大表场景下需要注意什么。

> **提示**
> 升级镜像后直接重启即可，不需要执行任何 SQL，也不需要修改 `config.yaml`。

## 分层策略

维护动作按「缺失后果」而不是「耗时」分为三层：

| 层级       | 缺失后果                             | 执行时机      | 失败处理                     |
| ---------- | ------------------------------------ | ------------- | ---------------------------- |
| 表缺失     | 接口 500                             | 启动时**同步** | 启动失败并退出               |
| **列缺失** | 接口 500（`1054 Unknown column`）    | 启动时**同步** | 启动失败并退出（不会降级放行） |
| 列定义不符 | 语义漂移，但不会 500                 | **不自动执行** | 仅打印日志提示               |
| 索引缺失   | 只是变慢，不会 500                   | 启动后**后台** | 只告警，下次重启自动重试      |

关键点：

- **缺列比缺索引严重得多**，所以补列是同步的，且失败就直接退出进程
  （容器 `restart: always` 会自动重试），绝不带着缺列对外提供服务。
- **列定义变更（`MODIFY COLUMN`）永不自动执行**。MySQL 8 下 `MODIFY COLUMN`
  默认使用 `ALGORITHM=COPY`，会整表重建并阻塞读写；而 `ADD COLUMN` 可以走
  `ALGORITHM=INSTANT`（纯元数据操作，毫秒级）。本项目对存量表**只做加法不做改法**。

## 补列是怎么做的

按下列算法依次降级，任一成功即结束，**全部失败才算失败**：

1. `ALGORITHM=INSTANT` —— 纯元数据操作，毫秒级（MySQL 8.0.12+，行格式 DYNAMIC/COMPRESSED）
2. `ALGORITHM=INPLACE, LOCK=NONE` —— 重建表但不阻塞并发读写
3. 不指定算法 —— 交给 MySQL 自行选择（最终兜底）

> **注意：为什么会有第 2、3 步**
> MySQL 对单表「瞬时增删列」的次数有上限（8.4 实测第 65 次会报
> `ERROR 4092 Maximum row versions reached`），此时必须降级到重建表的方式。

另外，执行期间会临时把当前连接的 `lock_wait_timeout` 从默认的 **一年** 收敛到 **10 秒**：

> MySQL 默认 `lock_wait_timeout = 31536000`。一旦有长事务占住表的元数据锁（MDL），
> `ALTER` 会长时间等待，而它在等待期间已经占住了 MDL 队列头，
> 于是后续所有访问该表的语句全部排队 —— 现场表现就是**整个服务假死**。

拿不到锁时会在 5 分钟预算内按 10s → 20s → 40s… 指数退避重试；
**一旦拿到锁，DDL 本身不设超时**（列必须补上，不做超时放弃）。

## 索引是怎么做的

- 后台异步执行，**不阻塞服务启动**
- 同一张表的多条索引**合并成一条 `ALTER`**，只扫一遍全表
- 跨实例互斥使用 **表级** `GET_LOCK`（按索引名加锁会让同表两条索引互相争抢 MDL）
- 建完后会复核索引确实存在
- 失败后每 30 分钟自动重试，最多 3 次

## 大表怎么办

当表的估算行数超过 **1000 万** 时，索引创建会被跳过（只打印告警），例如：

```text
表 chatgpt_conversations 估算行数 15234111 超过阈值 10000000，本次不自动创建索引。
超大表上的在线 DDL 会长时间占用 innodb_online_alter_log_max_size（默认 128MB），
溢出报 error 1799 后整条 ALTER 会回滚，白耗数小时。请择机手工执行：
  ALTER TABLE `chatgpt_conversations` ADD INDEX `idx_need_update` (`need_update`), ALGORITHM=INPLACE, LOCK=NONE;
建议避开整点 :00 / :30 的定时任务窗口；如需更强控制可改用 gh-ost / pt-online-schema-change。
```

告警里的 `ALTER` 已经拼好，可以直接复制执行。

原因是超大表上的在线 DDL 会长时间占用 `innodb_online_alter_log_max_size`（默认 128MB），
溢出报 `error 1799` 后**整条 ALTER 会回滚**，白耗数小时。

此时建议在业务低峰期手工处理：

```sql
-- 1. 先看看表有多大
SELECT table_rows, ROUND(data_length/1024/1024) AS data_mb
FROM information_schema.tables
WHERE table_schema = DATABASE() AND table_name = 'chatgpt_conversations';

-- 2. 手工建索引（构建期间不阻塞读写）
ALTER TABLE chatgpt_conversations
  ADD INDEX idx_need_update (need_update),
  ALGORITHM=INPLACE, LOCK=NONE;

-- 3. 建完更新统计信息
ANALYZE TABLE chatgpt_conversations;
```

如果表特别大或写入特别频繁，建议使用 `gh-ost` / `pt-online-schema-change`，
它们支持限流和可控切换。

> **提示：时间窗口**
> 本项目自身的定时任务如下，`ALTER` 应尽量避开这些窗口：
>
> | 任务                              | 周期               | 涉及表                   |
> | --------------------------------- | ------------------ | ------------------------ |
> | `SyncAllUserCount`                | 每 5 分钟（`:00`） | `chatgpt_user`           |
> | `SyncAllCount`                    | 每小时 `:30`       | `chatgpt_session`        |
> | `RefreshAllNeedUpdateConversations` | 每小时 `:00`     | `chatgpt_conversations`  |
> | `RefreshAllSession`               | 每 12 小时         | `chatgpt_session`        |
>
> 也就是说整点 `:00` 和 `:30` 都在跑批，建议把大表 DDL 放在 `:05`~`:25` 之间的时间窗。
> 避开这些窗口可以显著降低撞上长事务的概率。

## 手工检查与执行

镜像内的 `WORKDIR` 就是 `/app`，可以直接进容器执行维护命令。下面的命令需要在
`docker-compose.yml` 所在目录执行（容器名由 compose 自动生成，所以用 `docker compose exec`
按服务名进入，不要直接 `docker exec chatgpt-share-server`）：

```bash
# 只检查，列出待处理项（默认行为，不执行任何 DDL）
docker compose exec chatgpt-share-server /app/main migrate

# 立即执行建表与补列（正常启动时也会自动做）
docker compose exec chatgpt-share-server /app/main migrate --apply

# 同时同步创建缺失索引（大表慎用，正常启动时是后台自动做）
docker compose exec chatgpt-share-server /app/main migrate --apply --indexes
```

> **提示**
> 在脚本或 CI 等没有 TTY 的环境里执行时，加上 `-T`：
> `docker compose exec -T chatgpt-share-server /app/main migrate`。

输出示例：

```text
发现 2 项待处理:
  - 列 chatgpt_session.sort 缺失，将执行: ALTER TABLE `chatgpt_session` ADD COLUMN `sort` bigint DEFAULT 0 COMMENT '排序', ALGORITHM=INSTANT
  - 索引 chatgpt_conversations.idx_need_update (need_update) 缺失，将由后台自动创建
当前为检查模式，未执行任何 DDL；如需执行请追加 --apply
```

## 关闭自动维护

项目复用 cool-admin 框架已有的配置项：

```yaml
cool:
  autoMigrate: false
```

配置为 `false` 后，**本服务与框架都不再自动维护表结构**，适合用专门的迁移工具统一管理
数据库的团队。默认值（以及现有配置文件里未显式配置时）为 `true`。

## 常见问题

**Q：升级后容器一直重启，日志里有「数据库结构同步失败」？**

说明补齐某列失败。日志会精确给出表名、列名以及可以手工执行的 SQL，
形如：

```text
[ERRO] cmd: 数据库结构同步失败，进程退出以避免带缺列提供服务：
  - 补齐列 chatgpt_session.sort 超出 5m0s 的同步预算仍未成功（最后错误: ... Error 1205 (HY000): Lock wait timeout exceeded ...）
```

常见原因：数据库用户没有 `ALTER` 权限，或表被长事务/备份任务占用了元数据锁。
按日志提示处理后重启即可。

> **提示：为什么日志里没有 Go 调用栈**
> 这条错误刻意用不打印调用栈的日志器输出（gf 默认从 ERROR 级起会附加完整调用栈），
> 避免几十行栈帧把「哪张表缺哪列」挤到后面，用户可以直接把这几行贴给运维。

**Q：接口报 `1054 Unknown column 'xxx' in 'field list'`？**

正常情况下不会出现 —— 补列失败时进程会直接退出而不是带缺列服务。
如果确实出现，请先执行 `docker compose exec chatgpt-share-server /app/main migrate` 查看待处理项。

**Q：为什么索引建了很久都没建上？**

看日志里的「估算行数」与「跳过」告警。超过 1000 万行的表会被主动跳过，
需要按上面的「大表怎么办」手工处理。
