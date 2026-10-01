# 重置管理员密码

进入程序安装目录(即 docker-compose.yml 所在目录)，执行以下命令：

```bash
docker compose exec -it mysql bash
```

可以看到提示符变为 `bash-4.4#`，执行以下命令：

```bash
mysql -uroot -p
```

提示输入密码，输入 `123456`，回车，进入 mysql 命令行，执行以下命令：

```sql
USE cool;
UPDATE base_sys_user SET password = 'e10adc3949ba59abbe56e057f20f883e' WHERE username = 'admin';
```

执行完毕，退出 mysql 命令行，执行以下命令：

```bash
exit
```

退出容器，执行以下命令：

```bash
exit
```

这样就完成了重置管理员密码的操作，新密码为 `123456`。
