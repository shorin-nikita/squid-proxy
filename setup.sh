#!/bin/bash
set -e

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Обновление конфигурации Squid ===${NC}"

# Проверка root
if [ "$EUID" -ne 0 ]; then
    echo "Запустите с правами root: sudo ./setup.sh"
    exit 1
fi

# Запрашиваем данные
echo -e "${YELLOW}Введите новые данные прокси:${NC}"
echo ""

read -p "IP адрес прокси: " PROXY_IP
read -p "Порт прокси: " PROXY_PORT
read -p "Логин: " PROXY_USER
read -s -p "Пароль: " PROXY_PASS
echo ""

if [ -z "$PROXY_IP" ] || [ -z "$PROXY_PORT" ] || [ -z "$PROXY_USER" ] || [ -z "$PROXY_PASS" ]; then
    echo "Ошибка: Все поля обязательны"
    exit 1
fi

# Генерируем конфиг
cat > /etc/squid/squid.conf << EOF
# Squid Proxy Configuration

# --- Base Configuration ---
http_port 3128
via on
forwarded_for off

# Allow Docker networks and localhost
acl localnet src 127.0.0.1/32
acl localnet src 10.0.0.0/8
acl localnet src 172.16.0.0/12
acl localnet src 192.168.0.0/16
http_access allow localnet
http_access deny all

# --- Parent Proxy Configuration ---
cache_peer ${PROXY_IP} parent ${PROXY_PORT} 0 login=${PROXY_USER}:${PROXY_PASS} name=paidproxy

# --- Route API domains via parent proxy ---
acl to_proxy dstdomain .anthropic.com .claude.ai
acl to_proxy dstdomain .openai.com .api.openai.com
acl to_proxy dstdomain .openrouter.ai
acl to_proxy dstdomain .x.ai api.x.ai
acl to_proxy dstdomain .googleapis.com

cache_peer_access paidproxy allow to_proxy
cache_peer_access paidproxy deny all
never_direct allow to_proxy
always_direct deny to_proxy

# --- DNS Configuration ---
dns_nameservers 1.1.1.1 8.8.8.8
EOF

echo -e "${GREEN}Конфиг обновлён: /etc/squid/squid.conf${NC}"

# Перезапуск squid
if systemctl is-active --quiet squid; then
    systemctl restart squid
    echo -e "${GREEN}Squid перезапущен${NC}"
fi
