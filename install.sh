#!/bin/bash
set -e

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║           Установка Squid Proxy для AI API                ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Проверка ОС
if ! command -v apt-get &>/dev/null; then
    echo -e "${RED}Ошибка: Только Debian/Ubuntu${NC}"
    exit 1
fi

# Проверка доступа к терминалу
if [[ ! -r /dev/tty || ! -w /dev/tty ]]; then
    echo -e "${RED}Ошибка: Нет доступа к терминалу${NC}"
    exit 1
fi

echo -e "${YELLOW}Введите данные прокси в формате: ip:port@login:password${NC}"
echo -e "${YELLOW}Пример: 209.127.41.191:8000@user:pass${NC}"
echo ""

# Читаем из /dev/tty напрямую
echo -n "Прокси: "
read PROXY_STRING < /dev/tty

# Парсинг ip:port@login:password
if [[ ! "$PROXY_STRING" =~ ^([^:]+):([^@]+)@([^:]+):(.+)$ ]]; then
    echo -e "${RED}Ошибка: Неверный формат${NC}"
    exit 1
fi

PROXY_IP="${BASH_REMATCH[1]}"
PROXY_PORT="${BASH_REMATCH[2]}"
PROXY_USER="${BASH_REMATCH[3]}"
PROXY_PASS="${BASH_REMATCH[4]}"

echo ""
echo -e "${BLUE}Устанавливаю Squid...${NC}"

# Установка с sudo (полностью тихая)
sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq >/dev/null 2>&1
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" squid >/dev/null 2>&1

echo -e "${BLUE}Создаю конфигурацию...${NC}"

sudo mkdir -p /etc/squid

sudo tee /etc/squid/squid.conf > /dev/null << EOF
http_port 3128
via on
forwarded_for off

acl localnet src 127.0.0.1/32
acl localnet src 10.0.0.0/8
acl localnet src 172.16.0.0/12
acl localnet src 192.168.0.0/16
http_access allow localnet
http_access deny all

cache_peer ${PROXY_IP} parent ${PROXY_PORT} 0 login=${PROXY_USER}:${PROXY_PASS} name=paidproxy

acl to_proxy dstdomain .anthropic.com .claude.ai
acl to_proxy dstdomain .openai.com .api.openai.com
acl to_proxy dstdomain .openrouter.ai
acl to_proxy dstdomain .x.ai api.x.ai
acl to_proxy dstdomain .googleapis.com
acl to_proxy dstdomain api.ipify.org

cache_peer_access paidproxy allow to_proxy
cache_peer_access paidproxy deny all
never_direct allow to_proxy
always_direct deny to_proxy

dns_nameservers 1.1.1.1 8.8.8.8
EOF

echo -e "${BLUE}Запускаю Squid...${NC}"

sudo systemctl enable squid >/dev/null 2>&1
sudo systemctl restart squid >/dev/null 2>&1

sleep 2

if sudo systemctl is-active --quiet squid; then
    # Получаем IP сервера
    SERVER_IP=$(hostname -I | awk '{print $1}')

    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА!                      ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Прокси доступен:${NC}"
    echo -e "  Локально:   http://localhost:3128"
    echo -e "  Удалённо:   http://${SERVER_IP}:3128"
    echo ""

    # Проверка через api.ipify.org (роутится через parent proxy)
    echo -e "${BLUE}Проверяю подключение через parent proxy...${NC}"

    DETECTED_IP=$(curl -s -x http://localhost:3128 --connect-timeout 10 https://api.ipify.org 2>/dev/null || echo "error")

    if [[ "$DETECTED_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${GREEN}Прокси работает! IP: ${DETECTED_IP}${NC}"
    else
        echo -e "${YELLOW}Не удалось определить IP. Проверьте вручную:${NC}"
        echo "  curl -x http://localhost:3128 https://api.ipify.org"
    fi
    echo ""
else
    echo -e "${RED}Ошибка: Squid не запустился${NC}"
    sudo journalctl -u squid -n 10 --no-pager
    exit 1
fi
