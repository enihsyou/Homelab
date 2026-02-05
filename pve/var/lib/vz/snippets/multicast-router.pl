#!/usr/bin/perl
# Enable multicast routing for a Proxmox VE container's network interface on vmbr0

# You can set this via pct/qm with
# pct set 104 --hookscript local:snippets/multicast-router.pl

use strict;
use warnings;

# First argument is the vmid
my $vmid = shift;
# Second argument is the phase
my $phase = shift;

if ($phase eq 'post-start') {
    # 定义网桥名称 (通常是 vmbr0，根据实际情况修改)
    my $bridge = "vmbr0";

    # 定义可能的接口名称模式
    # 1. veth${vmid}i0 : 对应 net0，防火墙关闭时
    # 2. fwpr${vmid}p0 : 对应 net0，防火墙开启时
    # 如果你的 OpenWrt 使用的是 net1，请相应修改为 i1 / p1
    my @interfaces = ("veth${vmid}i0", "fwpr${vmid}p0");

    # 稍微等待一下，防止脚本执行时内核还未完成接口创建
    sleep(1);

    foreach my $iface (@interfaces) {
        # 构建 sysfs 路径
        my $path = "/sys/class/net/$bridge/brif/$iface/multicast_router";

        # 检查路径是否存在（即接口是否已连接到网桥）
        if (-e $path) {
            # 尝试写入 '2' (强制开启)
            if (open(my $fh, '>', $path)) {
                print $fh "2";
                close $fh;
                print "HOOK: Set multicast_router=2 for VM $vmid interface $iface\n";
                last; # 找到一个即可退出循环
            } else {
                warn "HOOK: Failed to write to $path: $!\n";
            }
        }
    }
}

exit(0);
