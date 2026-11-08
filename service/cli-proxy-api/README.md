# CLI Proxy API

该服务使用现有的 `docker` macvlan 网络，由 Caddy 提供 HTTPS；[打开管理界面](https://cli-proxy-api.home.kokomi.site/management.html)。Compose 不发布宿主机端口。

## 首次部署

1. 在本目录的 `.env` 中设置 `MANAGEMENT_KEY`、`CLIENT_API_KEY`、`MINIMAX_API_KEY` 和 `KEEPER_LOGIN_PASSWORD`。管理密钥、客户端密钥和 Keeper 登录密码使用不同的高强度随机值。`.env` 被 Git 忽略；不要提交密钥。
2. 使用 ~/.dotfiles/pwsh 中的 `docker-pull-mirror` 函数拉取 `eceasy/cli-proxy-api` 和 `ghcr.io/willxup/cpa-usage-keeper:latest`。在本目录执行 `task init` 和 `task up`。`task init` 替换 `config.yaml` 中的 `${变量名}` 并将结果复制到远程 Docker Engine；替换值按 YAML 字符串编码，生成的临时文件会被删除。
3. 执行 `task codex-login`，按照提示完成 Codex Device Flow 授权。Codex CLI 使用 `http://cli-proxy-api.docker:8317/v1`；Claude Code 将 `ANTHROPIC_BASE_URL` 设为 `http://cli-proxy-api.docker:8317`、`ANTHROPIC_AUTH_TOKEN` 设为客户端 API 密钥、`ANTHROPIC_MODEL` 设为 `MiniMax-M3.1-Flash`。

MBP 的 Codex 在 `~/.codex/config.toml` 中使用以下 provider 配置，并使用客户端 API 密钥认证：

```toml
model_provider = "cli-proxy-api"

[model_providers.cli-proxy-api]
name = "CLI Proxy API"
base_url = "https://cli-proxy-api.home.kokomi.site/v1"
wire_api = "responses"
requires_openai_auth = true
supports_websockets = true
```

管理界面对配置所做的修改保存在 `cli-proxy-api-config` 卷中，OAuth 凭据保存在 `cli-proxy-api-auth` 卷中。两个卷都包含机密或不可替代的数据，应安全备份。`task init`、`task push` 和 `task reload` 会用本地文件覆盖管理界面修改；日常重启或升级不要执行它们。需要重新上传配置时，先用 `docker cp cli-proxy-api:/config/config.yaml <仓库外的备份路径>` 备份卷中的当前配置；备份文件包含机密。

Caddy 到服务之间使用内网 HTTP；Caddy 的域名有公网 IPv6 DNS 记录，是否可从公网访问取决于防火墙设置。

用量统计面板位于 https://cpa-usage-keeper.home.kokomi.site，使用 `.env` 中的 `KEEPER_LOGIN_PASSWORD` 登录。历史记录和备份存储在外部卷 `cpa-usage-keeper-data` 中，包含敏感数据，应安全备份。

配置字段和供应商登录方式参见 [官方配置示例](https://github.com/router-for-me/CLIProxyAPI/blob/main/config.example.yaml) 和 [Docker Compose 文档](https://help.router-for.me/docker/docker-compose)。
