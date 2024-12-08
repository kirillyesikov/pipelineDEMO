#!/bin/bash
apt install net-tools
sudo swapoff -a
cd /usr/local/
wget https://github.com/containerd/containerd/releases/download/v2.0.0/containerd-2.0.0-linux-amd64.tar.gz
tar Cxzvf /usr/local containerd-2.0.0-linux-amd64.tar.gz
cd /usr/local/lib/
mkdir systemd
cd systemd/
mkdir system
cd system/
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
systemctl daemon-reload
systemctl enable --now containerd
cd /usr/local/sbin/
wget https://github.com/opencontainers/runc/releases/download/v1.2.1/runc.amd64
install -m 755 runc.amd64 /usr/local/sbin/runc
mkdir -p /opt/cni/bin
cd /opt/cni/bin/
wget https://github.com/containernetworking/plugins/releases/download/v1.6.0/cni-plugins-linux-amd64-v1.6.0.tgz
tar zxvf cni-plugins-linux-amd64-v1.6.0.tgz