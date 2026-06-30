#!/bin/sh
# ddns-go 启动脚本：
#   1. 等到全局 IPv6 地址就绪（沿用 openlist sidecar 的写法）
#   2. 仅在持久化目录里还没有 config 时，从模板渲染 env:VAR 占位
#   3. exec 启动 ddns-go，配置文件指向持久化目录里的副本
#
# 这样用户通过 web UI 改的 config 会落到命名卷里，
# 容器重建 / 镜像升级后修改不会丢。
set -eu

TEMPLATE=/root/.ddns_go_config.yaml.template
STATE_DIR=/root/ddns-config
CONFIG=$STATE_DIR/ddns_go_config.yaml

while ! ip -6 addr show scope global | grep -q 'inet6 [23]'; do
    sleep 1
done

mkdir -p "$STATE_DIR"

# 用 awk 的 ENVIRON 做替换，避免 shell/sed 转义陷阱
# 匹配 env:[A-Za-z_][A-Za-z0-9_]*，找不到对应变量就留空
render() {
    awk '
    {
        line = $0
        while (match(line, /env:[A-Za-z_][A-Za-z0-9_]*/)) {
            var = substr(line, RSTART + 4, RLENGTH - 4)
            val = (var in ENVIRON) ? ENVIRON[var] : ""
            line = substr(line, 1, RSTART - 1) val substr(line, RSTART + RLENGTH)
        }
        print line
    }' "$TEMPLATE"
}

# 只在首次（卷是空的）渲染模板，之后保留用户在 web UI 里的改动
if [ ! -f "$CONFIG" ]; then
    render > "$CONFIG"
fi

exec /app/ddns-go -c "$CONFIG" -f 600