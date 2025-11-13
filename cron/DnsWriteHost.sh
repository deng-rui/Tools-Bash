#!/bin/bash
# 0 * * * * /home/DnsWriteHost.sh >> /dev/null 2>&1

DOMAIN1=""
DOMAIN2=""
HOSTS_FILE="/etc/hosts"

# 获取DOMAIN2的当前IPv4地址（过滤IPv6）
CURRENT_IP=$(nslookup "$DOMAIN2" 2>/dev/null | grep -A 10 "Non-authoritative" | grep "Address:" | grep -E '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1 | awk '{print $2}')

# 如果上面的方法不行，尝试其他方法获取IPv4
if [[ -z "$CURRENT_IP" ]]; then
    CURRENT_IP=$(dig "$DOMAIN2" A +short 2>/dev/null | head -1)
fi

if [[ -z "$CURRENT_IP" ]]; then
    CURRENT_IP=$(host "$DOMAIN2" 2>/dev/null | grep -E 'has address' | awk '{print $4}' | head -1)
fi

if [[ -n "$CURRENT_IP" ]]; then
    # 删除旧记录并添加新记录
    sed -i "/$DOMAIN1/d" "$HOSTS_FILE"
    echo "$CURRENT_IP $DOMAIN1" >> "$HOSTS_FILE"
    echo "$(date): 已更新 $DOMAIN1 -> $DOMAIN2 ($CURRENT_IP)"
else
    echo "$(date): 错误: 无法获取 $DOMAIN2 的IPv4地址"
fi
