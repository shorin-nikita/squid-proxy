#!/bin/bash
set -e

# Загружаем переменные
source ./proxies.conf

# Генерируем конфиг
export PROXY_IP PROXY_PORT PROXY_USER PROXY_PASS
envsubst < squid.conf.template > /etc/squid/squid.conf

echo "Конфиг обновлён: /etc/squid/squid.conf"

# Перезапуск если squid уже работает
if systemctl is-active --quiet squid; then
    systemctl restart squid
    echo "Squid перезапущен"
fi
