#!/bin/bash

# Set default theme to luci-theme-aurora
uci set luci.main.mediaurlbase='/luci-static/aurora'
uci commit luci

# Disable IPV6 ula prefix
# sed -i 's/^[^#].*option ula/#&/' /etc/config/network

# LAN 网络默认配置（静态 IP / 网关 / DNS，关闭 DHCP 与 IPv6 服务）
uci -q delete network.lan.dns
uci set network.lan.netmask='255.255.255.0'
uci set network.lan.gateway='192.168.0.1'
uci add_list network.lan.dns='192.168.0.1'
uci -q delete network.lan.ip6assign
uci set network.lan.delegate='0'
uci set dhcp.lan.ignore='1'
uci set dhcp.lan.ra='disabled'
uci set dhcp.lan.dhcpv6='disabled'
uci set dhcp.lan.ndp='disabled'
uci commit network
uci commit dhcp

# 防火墙默认配置：关闭 SYN-flood 防御，lan 区域开启 IP 动态伪装
uci set firewall.@defaults[0].synflood_protect='0'
uci set firewall.@zone[0].masq='1'
uci commit firewall

# Check file system during boot
# uci set fstab.@global[0].check_fs=1
# uci commit fstab

exit 0
