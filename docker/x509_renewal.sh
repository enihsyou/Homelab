cd /etc/docker
step certificate create "Docker Daemon" \
  --san docker.lan.kokomi.site \
  --san docker.pve.kokomi.site \
  cert.csr --key key.pem --csr
step ca sign cert.csr cert.pem --not-after 8760h
systemctl restart docker
