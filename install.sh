#!/bin/bash
set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║           Установка Squid Proxy для AI API                ║"
echo "║      Роутинг к OpenAI, Anthropic, Google AI и др.         ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Проверка root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Ошибка: Запустите скрипт с правами root (sudo)${NC}"
    echo "Используйте: curl -fsSL URL | sudo bash"
    exit 1
fi

# Проверка ОС
if ! command -v apt-get &> /dev/null; then
    echo -e "${RED}Ошибка: Скрипт поддерживает только Debian/Ubuntu${NC}"
    exit 1
fi

echo -e "${YELLOW}Введите данные вашего parent proxy:${NC}"
echo -e "${YELLOW}(Приобрести прокси рублями: https://ru.dashboard.proxy.market/?ref=E000154645)${NC}"
echo ""

# Запрос переменных
read -p "IP адрес прокси: " PROXY_IP
read -p "Порт прокси: " PROXY_PORT
read -p "Логин: " PROXY_USER
read -s -p "Пароль: " PROXY_PASS
echo ""

# Валидация
if [ -z "$PROXY_IP" ] || [ -z "$PROXY_PORT" ] || [ -z "$PROXY_USER" ] || [ -z "$PROXY_PASS" ]; then
    echo -e "${RED}Ошибка: Все поля обязательны для заполнения${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}=== Установка Squid ===${NC}"
apt-get update -qq
apt-get install -y squid gettext-base > /dev/null

echo -e "${BLUE}=== Создание конфигурации ===${NC}"

# Создаём директорию если нет
mkdir -p /etc/squid

# Генерируем конфиг напрямую
cat > /etc/squid/squid.conf << EOF
# Squid Proxy Configuration
# Автоматически сгенерировано установщиком

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

echo -e "${BLUE}=== Запуск Squid ===${NC}"
systemctl enable squid > /dev/null 2>&1
systemctl restart squid

# Ждём запуска
sleep 2

# Проверка статуса
if systemctl is-active --quiet squid; then
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                           ║${NC}"
    echo -e "${GREEN}║         УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА!                      ║${NC}"
    echo -e "${GREEN}║                                                           ║${NC}"
    echo -e "${GREEN}║   Squid прокси работает на порту 3128                     ║${NC}"
    echo -e "${GREEN}║                                                           ║${NC}"
    echo -e "${GREEN}║   Используйте: http://localhost:3128                      ║${NC}"
    echo -e "${GREEN}║                                                           ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Полезные команды:${NC}"
    echo "  sudo systemctl status squid   - статус сервиса"
    echo "  sudo systemctl restart squid  - перезапуск"
    echo "  sudo systemctl stop squid     - остановка"
    echo "  sudo tail -f /var/log/squid/access.log - логи"
    echo ""
    echo -e "${YELLOW}Проверка работы:${NC}"
    echo "  curl -x http://localhost:3128 https://api.anthropic.com"
    echo ""
else
    echo -e "${RED}Ошибка: Squid не запустился. Проверьте логи:${NC}"
    echo "  sudo journalctl -u squid -n 50"
    exit 1
fi
