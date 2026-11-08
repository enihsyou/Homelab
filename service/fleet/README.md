# Fleet

[Fleet](https://fleetdm.com/) 用于管理内网设备。服务通过 Caddy 访问：
https://fleet.home.kokomi.site。客户端需要信任签发 HTTPS 证书的 Smallstep 根证书。

## 部署

- 将 `.env.example` 复制为 `.env`，为 MySQL root 用户和 `fleet` 用户设置不同的密码，并将 `FLEET_SERVER_PRIVATE_KEY` 设置为随机生成的 32 字节 Base64 值。妥善备份 `.env`，不要提交到 Git。
- 确保远程 Docker Engine 上存在外部 `docker` 网络，并配置好 Caddy 的 Fleet 站点。
- 在本目录运行 `task up` 创建数据卷并启动服务，`task open` 打开管理界面，`task logs` 查看日志，`task down` 停止服务。

MySQL 和 Redis 分别使用外部卷 `fleet_mysql` 和 `fleet_redis`；停止服务不会删除数据。Fleet 镜像使用 `latest`，MySQL 和 Redis 分别固定在 8.4 和 7 的主版本。升级 Fleet 时，先备份数据库和 `.env`，再更新镜像并启动服务。

## Apple MDM 和 Edge

在 Fleet 的 Settings > Integrations > MDM 中连接 Apple Push Notification service（APNs）。APNs 证书需要每年使用同一个 Apple 账户续期。Mac 手动注册后，可以在 Fleet 中上传 [edge-newtab.mobileconfig](edge-newtab.mobileconfig)，将 Edge 新标签页设为本地页面。
