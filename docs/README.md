# ChatGPT-Share-Server 文档

面向部署与运维的完整手册。只想快速跑起来的话，看[部署仓库 README](../README.md) 即可。

## 安装与运维

- [安装指南](./install/README.md) —— 前置条件、常用系统优化、部署、服务与端口、反向代理、管理后台、常用管理命令与升级

## 配置指南

- [配置指南](./config/README.md) —— 常用环境变量一览
- [附带服务配置](./config/services.md) —— 部署包中其余 5 个服务（Web UI、库文件清理、限流、数据库、自动更新）的配置项
- [审计限流](./config/auditlimit.md) —— 限流规则、禁用模型、禁止词与内容审核
- [选车页面](./config/list.md) —— 车队列表页与公告
- [数据备份](./config/backup.md) —— 备份与恢复
- [数据库结构自动维护](./config/migrate.md) —— 启动时的建表 / 补列 / 建索引策略
- [限制单点登陆](./config/multilogin.md)
- [会话漫游](./config/roma.md)
- [公益模式](./config/freemode.md)
- [文件服务](./config/files.md)
- [语音服务](./config/voice.md)
- [OAuth](./config/oauth.md)
- [API 对接](./config/apiauth.md)
- [重置管理员密码](./config/resetpasswd.md)

## 其他

- [界面预览](./preview/README.md)
- [变更日志](../CHANGELOG.md) —— 影响部署步骤、配置项与升级操作的版本变更
