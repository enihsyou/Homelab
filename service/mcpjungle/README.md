# MCPJungle

本目录记录两套互相独立的 MCPJungle，状态快照采集于 2026-11-02。CLI 的 `--registry` 使用服务根地址；MCP 客户端使用 `/mcp` 网关。工具和提示词的完整启禁状态见 [Local 快照](local-state.md) 和 [Shared 快照](shared-state.md)。状态会随上游工具更新而变化。

## Shared：远程 Docker

- Compose 文件为 [docker-compose.yml](docker-compose.yml)，`task start` 执行 `docker compose up -d`。容器 `mcpjungle` 使用 `ghcr.io/mcpjungle/mcpjungle:latest-stdio`，当前服务版本 v0.4.6，enterprise 模式、容器内端口 80，连接外部 `docker` 网络。
- 数据库为 `postgresql.docker:5432/mcpjungle_enterprise`，用户 `mcpjungle`；密码从本目录未纳入 Git 的 `.env` 中的 `POSTGRES_PASSWORD` 读取。启动前需准备网络、PostgreSQL、数据库及对应权限。数据库包含注册、用户、客户端和开关状态，应另行安全备份。
- Registry：`http://mcpjungle.docker`；MCP 网关：`http://mcpjungle.docker/mcp`。该地址需由客户端所在环境解析并访问；Compose 没有发布宿主机端口。enterprise 客户端通过 `Authorization: Bearer <客户端令牌>` 连接。当前有 `claude-code` 和 `codex` 两个客户端，均允许访问 `*`。
- 当前注册 `exa`、`firecrawl`、`grafana`、`minimax`、`parallel`、`tavily`、`tinyfish`，配置见 [servers/Shared/](servers/Shared/)。其中 Grafana 和 MiniMax 使用容器中的 `uvx` stdio；其余使用 Streamable HTTP。Tavily 使用 keyless 请求头。没有工具组。

### Shared 恢复

优先恢复 PostgreSQL 的一致性备份及 `.env`，然后启动服务。全新数据库启动 enterprise 后，使用可访问 Registry 的 CLI 执行 `mcpjungle init-server --registry http://mcpjungle.docker`，按提示初始化管理员，再执行 `mcpjungle login --registry http://mcpjungle.docker`。不要对已有数据库重复初始化。

若需要从注册配置重建，在本目录的 PowerShell 中执行：

```powershell
$registry = 'http://mcpjungle.docker'
mcpjungle login --registry $registry
$env:MINIMAX_API_KEY = '<从安全存储获取>'
$env:GRAFANA_SERVICE_ACCOUNT_TOKEN = '<从安全存储获取>'
Get-ChildItem ./servers/Shared/*.json | ForEach-Object {
    mcpjungle register --registry $registry --conf $_.FullName
}
```

变量由执行注册的 CLI 解析。OAuth 授权及令牌不在 JSON 中，需重新授权；注册前确认上游依赖、权限和地址可用。同名注册不要盲目使用 `--force`，它会删除原注册。重建客户端可使用 `mcpjungle create mcp-client <名称> --allow '*' --registry $registry`，将生成的令牌安全保存并配置到对应客户端；不要提交或公开命令输出。按 Shared 快照恢复工具及提示词开关。数据库备份之外的 JSON 不包含客户端、授权或开关状态。

## Local：Windows 本机

- 运行 `C:/Users/enihsyou/.local/bin/mcpjungle.exe`，当前版本 v0.4.6，绑定 `127.0.0.1:38479`；SQLite 数据库位于 `C:/Users/enihsyou/AppData/Local/MCPJungle/mcpjungle.db`。当前进程由计划任务 `MCPJungle Local` 通过同目录的 `start.vbs` 启动。
- Registry：`http://127.0.0.1:38479`；MCP 网关：`http://127.0.0.1:38479/mcp`。仅本机可访问，当前为 development 模式。
- 注册 `xerj` 和 `ida`，均为 stdio；没有工具组或提示词。`xerj` 连接本机 `http://127.0.0.1:9200`，`ida` 依赖本机项目和 IDA 环境。

### Local：安装 Windows 服务

XERJ 使用 `%LOCALAPPDATA%/xerj/config.toml` 中配置的统一数据目录；该文件需要事先存在。NSSM 已安装时，以管理员身份运行 `./install-xerj-service.ps1`，在打开的配置窗口 **Log on** 页选择当前用户账户并输入密码，再保存。脚本使用 `--insecure`，本机其他进程也能访问索引。停止已运行的 XERJ 进程后，运行 `Start-Service -Name XERJ`，避免两个进程同时使用同一端口和数据目录。

NSSM 已安装时，以管理员身份运行 `./install-mcp-service.ps1`。脚本创建延迟自动启动的 `MCP Jungle` 服务并打开 NSSM 配置窗口。在 **Log on** 页选择当前用户账户并输入密码，保存配置；如系统要求，为该账户授予“作为服务登录”权限。使用当前账户是为了让 stdio 子服务继续访问用户目录和配置。不要使用默认的 LocalSystem 账户启动；服务配置完成之前不要重启电脑。

保存账户配置后，在管理员 PowerShell 中停止旧任务并启动新服务：

```powershell
Stop-ScheduledTask -TaskName 'MCPJungle Local'
Start-Service -Name 'MCP Jungle'
```

确认 `http://127.0.0.1:38479` 和需要的工具可用后，禁用旧任务：

```powershell
Disable-ScheduledTask -TaskName 'MCPJungle Local'
```

如果服务启动失败或工具不可用，可停止服务并通过 `Start-ScheduledTask -TaskName 'MCPJungle Local'` 恢复原启动方式。服务与计划任务使用同一个数据库和端口，不要同时启动。
### Local 恢复

优先安全备份并恢复 SQLite 数据库（包括一致性备份所需的 WAL 状态）；它保存注册和开关。恢复到新位置时同步调整启动参数。需要手动启动时：

```powershell
& 'C:/Users/enihsyou/.local/bin/mcpjungle.exe' start --host 127.0.0.1 --port 38479 --sqlite-db-path 'C:/Users/enihsyou/AppData/Local/MCPJungle/mcpjungle.db'
```

如果没有数据库，可使用 [servers/Local/](servers/Local/) 中的原始注册配置。先按实际机器调整路径，再在本目录的 PowerShell 中注册：

```powershell
$registry = 'http://127.0.0.1:38479'
Get-ChildItem ./servers/Local/*.json | ForEach-Object {
    mcpjungle register --registry $registry --conf $_.FullName
}
```

注册后按照 Local 快照恢复工具开关。两个实例都可分别用 `mcpjungle list servers`、`mcpjungle list tools`、`mcpjungle list prompts` 加 `--registry <根地址>` 查看；针对单项执行 `mcpjungle enable tool <完整名称> --registry <根地址>` 或 `mcpjungle disable tool <完整名称> --registry <根地址>`，提示词使用 `enable prompt` / `disable prompt`。先核对目标实例及上游实际提供的名称，避免错误修改另一套服务。
