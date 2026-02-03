#!/bin/bash
set -e

# Переключаем stdin на терминал
exec 0</dev/tty

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

# Проверка root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Ошибка: Запустите с правами root (sudo)${NC}"
    exit 1
fi

# Проверка ОС
if ! command -v apt-get &> /dev/null; then
    echo -e "${RED}Ошибка: Только Debian/Ubuntu${NC}"
    exit 1
fi

echo -e "${YELLOW}Введите данные прокси в формате:${NC}"
echo -e "${YELLOW}ip:port@login:password${NC}"
echo -e "${YELLOW}Пример: 209.127.41.191:8000@user:pass${NC}"
echo ""

read -p "Прокси: " PROXY_STRING

# Парсинг строки ip:port@login:password
if [[ ! "$PROXY_STRING" =~ ^([^:]+):([^@]+)@([^:]+):(.+)$ ]]; then
    echo -e "${RED}Ошибка: Неверный формат. Используйте ip:port@login:password${NC}"
    exit 1
fi

PROXY_IP="${BASH_REMATCH[1]}"
PROXY_PORT="${BASH_REMATCH[2]}"
PROXY_USER="${BASH_REMATCH[3]}"
PROXY_PASS="${BASH_REMATCH[4]}"

echo ""
echo -e "${BLUE}Устанавливаю Squid...${NC}"

# Неинтерактивная установка
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" squid

echo -e "${BLUE}Создаю конфигурацию...${NC}"

mkdir -p /etc/squid

cat > /etc/squid/squid.conf << EOF
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

cache_peer_access paidproxy allow to_proxy
cache_peer_access paidproxy deny all
never_direct allow to_proxy
always_direct deny to_proxy

dns_nameservers 1.1.1.1 8.8.8.8
EOF

echo -e "${BLUE}Запускаю Squid...${NC}"

systemctl enable squid >/dev/null 2>&1
systemctl restart squid

sleep 2

if systemctl is-active --quiet squid; then
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА!                      ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Прокси работает на: http://localhost:3128${NC}"
    echo ""
    echo -e "${YELLOW}Проверка работы:${NC}"
    echo "  curl -x http://localhost:3128 https://api.anthropic.com"
    echo ""
else
    echo -e "${RED}Ошибка: Squid не запустился${NC}"
    echo "Логи: sudo journalctl -u squid -n 20"
    exit 1
fi
