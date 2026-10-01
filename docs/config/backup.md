# 数据备份

> **警告**
> 以下备份相关命令均要求在`docker-compose.yml`文件所在目录执行

## 备份完整数据库

```bash
docker compose exec mysql sh -c 'exec mysqldump --all-databases -uroot -p"$MYSQL_ROOT_PASSWORD"' >./all-$(date +%Y%m%d-%H%M%S).sql
```

备份文件将存储到当前目录下名为 all-日期.sql 的文件中

## 恢复完整数据库

注意修改`all-日期.sql`为实际备份文件名

```bash
docker compose exec -T mysql sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD"' <./all-日期.sql
```

## 备份指定数据库

share 使用的数据库默认名称为 `cool`，以下命令将备份数据库`cool`

```bash
docker compose exec mysql sh -c 'exec mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" cool' >./cool-$(date +%Y%m%d-%H%M%S).sql
```

## 恢复指定数据库

注意修改`cool-日期.sql`为实际备份文件名

```bash
docker compose exec -T mysql sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" cool' <./cool-日期.sql
```

## 备份完整项目

share 使用`docker-compose.yml`文件进行项目配置，以下命令将备份整个项目,注意修改`/path/to/backup`为实际要存储备份文件的目录

```bash
DATE=$(date +%Y%m%d-%H%M%S)
docker compose down
tar -zcvf share-$DATE.tar.gz .
mv share-$DATE.tar.gz /path/to/backup
docker compose up -d
```

## 在新环境恢复项目

注意修改`share-日期.tar.gz`为实际备份文件名

```bash
mkdir chatgpt-share
mv share-日期.tar.gz chatgpt-share
cd chatgpt-share
tar -zxvf share-日期.tar.gz
rm share-日期.tar.gz
docker compose up -d
```
