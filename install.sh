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
echo -e "${BLUE}Подготовка системы...${NC}"

# Снятие блокировок APT (unattended-upgrades)
if pgrep -x unattended-upgr >/dev/null 2>&1; then
    echo -e "${YELLOW}Обнаружен процесс unattended-upgrades, останавливаю...${NC}"
    sudo killall unattended-upgr >/dev/null 2>&1 || true
    sleep 2
fi
sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock >/dev/null 2>&1
sudo dpkg --configure -a >/dev/null 2>&1 || true

echo -e "${BLUE}Устанавливаю Squid и npm...${NC}"

# Установка с sudo (полностью тихая)
sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq >/dev/null 2>&1
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" squid npm >/dev/null 2>&1

# Проверка npm
if command -v npm &>/dev/null; then
    echo -e "${GREEN}npm $(npm --version) установлен${NC}"
else
    echo -e "${YELLOW}npm не удалось установить, OpenCLAW потребует ручной установки npm${NC}"
fi

echo -e "${BLUE}Создаю конфигурацию...${NC}"

sudo mkdir -p /etc/squid

sudo tee /etc/squid/squid.conf > /dev/null << EOF
http_port 3128
via on
forwarded_for off

# Источники
acl localnet src all

# HTTPS
acl SSL_ports port 443
acl CONNECT method CONNECT

# Домены для AI API (через parent proxy)
acl ai_domains dstdomain .anthropic.com
acl ai_domains dstdomain .claude.ai
acl ai_domains dstdomain .openai.com
acl ai_domains dstdomain .openrouter.ai
acl ai_domains dstdomain .x.ai
acl ai_domains dstdomain .googleapis.com

# Разрешения доступа
http_access allow CONNECT SSL_ports
http_access allow all

# Parent proxy для AI доменов
cache_peer ${PROXY_IP} parent ${PROXY_PORT} 0 login=${PROXY_USER}:${PROXY_PASS} name=upstream
cache_peer_access upstream allow ai_domains
cache_peer_access upstream deny all
never_direct allow ai_domains
always_direct deny ai_domains

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

    # Проверка подключения к Anthropic API через parent proxy
    echo -e "${BLUE}Проверяю подключение к Anthropic API...${NC}"

    if curl -s -o /dev/null -x http://localhost:3128 --connect-timeout 10 https://api.anthropic.com; then
        echo -e "${GREEN}Прокси работает! Соединение с api.anthropic.com успешно${NC}"
    else
        echo -e "${YELLOW}Не удалось подключиться к Anthropic API. Проверьте вручную:${NC}"
        echo "  curl -I -x http://localhost:3128 https://api.anthropic.com"
    fi

    echo ""
    echo -e "${BLUE}Установленные версии:${NC}"
    echo -e "  Squid:  $(squid -v 2>&1 | head -1 | awk '{print $4}')"
    echo -e "  npm:    $(npm --version 2>/dev/null || echo 'не установлен')"
    echo -e "  Node.js: $(node --version 2>/dev/null || echo 'не установлен')"
    echo ""
else
    echo -e "${RED}Ошибка: Squid не запустился${NC}"
    sudo journalctl -u squid -n 10 --no-pager
    exit 1
fi
