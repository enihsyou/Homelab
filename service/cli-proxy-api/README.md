# CLI Proxy API

该服务使用现有的 `docker` macvlan 网络，由 Caddy 提供 HTTPS；[打开管理界面](https://cli-proxy-api.home.kokomi.site/management.html)。Compose 不发布宿主机端口。

## 首次部署

1. 在本目录的 `.env` 中设置 `MANAGEMENT_KEY` 和 `KEEPER_LOGIN_PASSWORD`，使用不同的高强度随机值。`.env` 被 Git 忽略；不要提交密钥。
2. 使用 ~/.dotfiles/pwsh 中的 `docker-pull-mirror` 函数拉取 `eceasy/cli-proxy-api` 和 `ghcr.io/willxup/cpa-usage-keeper:latest`。在本目录执行 `task init` 和 `task up`。`task init` 替换 `config.yaml` 中的 `${变量名}` 并将结果复制到远程 Docker Engine；替换值按 YAML 字符串编码，生成的临时文件会被删除。
3. 在管理页面配置客户端 API 密钥、上游模型和认证密钥。初始状态没有客户端 API 密钥，API 请求无需认证；配置密钥后才会启用客户端认证。执行 `task codex-login`，按照提示完成 Codex Device Flow 授权。Codex CLI 使用 `http://cli-proxy-api.docker:8317/v1`；Claude Code 将 `ANTHROPIC_BASE_URL` 设为 `http://cli-proxy-api.docker:8317`、`ANTHROPIC_AUTH_TOKEN` 设为客户端 API 密钥、`ANTHROPIC_MODEL` 设为配置的模型名。

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

管理界面对配置所做的修改保存在 `cli-proxy-api-config` 卷中，OAuth 凭据保存在 `cli-proxy-api-auth` 卷中，插件保存在 `cli-proxy-api-plugins` 卷中。这些卷包含机密或不可替代的数据，应安全备份。`task init` 仅用于首次部署，会用初始配置覆盖卷中的配置；日常重启或升级不要执行它。

Caddy 到服务之间使用内网 HTTP；Caddy 的域名有公网 IPv6 DNS 记录，是否可从公网访问取决于防火墙设置。

用量统计面板位于 https://cpa-usage-keeper.home.kokomi.site，使用 `.env` 中的 `KEEPER_LOGIN_PASSWORD` 登录。历史记录和备份存储在外部卷 `cpa-usage-keeper-data` 中，包含敏感数据，应安全备份。

配置字段和供应商登录方式参见 [官方配置示例](https://github.com/router-for-me/CLIProxyAPI/blob/main/config.example.yaml) 和 [Docker Compose 文档](https://help.router-for.me/docker/docker-compose)。
