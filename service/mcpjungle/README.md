# MCPJungle

`servers/` 保存当前注册的 MCP 服务器配置，可用于重新注册。MiniMax 的 API 密钥通过环境变量提供，不保存在配置文件中。

重新部署并初始化 MCPJungle 后，使用管理员账号登录 MCPJungle CLI，并将以下命令中的地址替换为客户端可访问的服务地址：

```powershell
$registry = 'http://<MCPJungle 地址>'
mcpjungle login --registry $registry
$env:MINIMAX_API_KEY = '<MiniMax API 密钥>'
Get-ChildItem ./servers/*.json | ForEach-Object {
    mcpjungle register --registry $registry --conf $_.FullName
}
```

请在 `service/mcpjungle` 目录下运行；CLI 必须能够访问 MCPJungle。注册已有同名服务器前需先确认是否需要替换，`--force` 会删除原注册并重新注册。配置文件不包含 OAuth 授权信息；需要 OAuth 的服务器在恢复后须重新授权。
