
## Proxmox VE Helper-Scripts

我在本地服务器上部署了一套带有修改的复刻，更适合在不易连接到 GitHub 的环境下使用。
文件清单可直接访问 <https://pve-files.enihsyou.synology.me/helper-scripts/>，使用示例如下：

```shell
export HELPER_SCRIPTS_ROOT="https://pve-files.enihsyou.synology.me/helper-scripts"
bash -c "$(curl -fsSL https://pve-files.enihsyou.synology.me/helper-scripts/ct/alpine.sh)"
```

关于如何部署到服务器上的可以看 [这里](https://github.com/enihsyou/ProxmoxVE/blob/main/Taskfile.yml)。
