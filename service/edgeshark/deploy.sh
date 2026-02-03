#!/usr/bin/env sh
wget -q --no-cache -O - https://github.com/siemens/edgeshark/raw/main/deployments/wget/docker-compose.yaml \
  | sed 's/ghcr.io/ghcr.nju.edu.cn/g' \
  | docker compose -f - up
