#!/bin/bash
set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Проверка доступности терминала
if [[ ! -r /dev/tty || ! -w /dev/tty ]]; then
    echo "Ошибка: Нет доступа к терминалу"
    exit 1
fi

echo -e "${BLUE}" > /dev/tty
echo "╔═══════════════════════════════════════════════════════════╗" > /dev/tty
echo "║           Установка Squid Proxy для AI API                ║" > /dev/tty
echo "║      Роутинг к OpenAI, Anthropic, Google AI и др.         ║" > /dev/tty
echo "╚═══════════════════════════════════════════════════════════╝" > /dev/tty
echo -e "${NC}" > /dev/tty

# Проверка root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Ошибка: Запустите скрипт с правами root (sudo)${NC}" > /dev/tty
    echo "Используйте: curl -fsSL URL | sudo bash" > /dev/tty
    exit 1
fi

# Проверка ОС
if ! command -v apt-get &> /dev/null; then
    echo -e "${RED}Ошибка: Скрипт поддерживает только Debian/Ubuntu${NC}" > /dev/tty
    exit 1
fi

echo -e "${YELLOW}Введите данные вашего parent proxy:${NC}" > /dev/tty
echo -e "${YELLOW}(Приобрести прокси рублями: https://ru.dashboard.proxy.market/?ref=E000154645)${NC}" > /dev/tty
echo "" > /dev/tty

# Запрос переменных напрямую через /dev/tty
printf "IP адрес прокси: " > /dev/tty
read -r PROXY_IP < /dev/tty

printf "Порт прокси: " > /dev/tty
read -r PROXY_PORT < /dev/tty

printf "Логин: " > /dev/tty
read -r PROXY_USER < /dev/tty

printf "Пароль: " > /dev/tty
read -rs PROXY_PASS < /dev/tty
echo "" > /dev/tty

# Валидация
if [ -z "$PROXY_IP" ] || [ -z "$PROXY_PORT" ] || [ -z "$PROXY_USER" ] || [ -z "$PROXY_PASS" ]; then
    echo -e "${RED}Ошибка: Все поля обязательны для заполнения${NC}" > /dev/tty
    exit 1
fi

echo "" > /dev/tty
echo -e "${BLUE}=== Установка Squid ===${NC}" > /dev/tty
apt-get update -qq
apt-get install -y squid > /dev/null

echo -e "${BLUE}=== Создание конфигурации ===${NC}" > /dev/tty

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

echo -e "${BLUE}=== Запуск Squid ===${NC}" > /dev/tty
systemctl enable squid > /dev/null 2>&1
systemctl restart squid

# Ждём запуска
sleep 2

# Проверка статуса
if systemctl is-active --quiet squid; then
    echo "" > /dev/tty
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}" > /dev/tty
    echo -e "${GREEN}║                                                           ║${NC}" > /dev/tty
    echo -e "${GREEN}║         УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА!                      ║${NC}" > /dev/tty
    echo -e "${GREEN}║                                                           ║${NC}" > /dev/tty
    echo -e "${GREEN}║   Squid прокси работает на порту 3128                     ║${NC}" > /dev/tty
    echo -e "${GREEN}║                                                           ║${NC}" > /dev/tty
    echo -e "${GREEN}║   Используйте: http://localhost:3128                      ║${NC}" > /dev/tty
    echo -e "${GREEN}║                                                           ║${NC}" > /dev/tty
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}" > /dev/tty
    echo "" > /dev/tty
    echo -e "${YELLOW}Полезные команды:${NC}" > /dev/tty
    echo "  sudo systemctl status squid   - статус сервиса" > /dev/tty
    echo "  sudo systemctl restart squid  - перезапуск" > /dev/tty
    echo "  sudo systemctl stop squid     - остановка" > /dev/tty
    echo "  sudo tail -f /var/log/squid/access.log - логи" > /dev/tty
    echo "" > /dev/tty
    echo -e "${YELLOW}Проверка работы:${NC}" > /dev/tty
    echo "  curl -x http://localhost:3128 https://api.anthropic.com" > /dev/tty
    echo "" > /dev/tty
else
    echo -e "${RED}Ошибка: Squid не запустился. Проверьте логи:${NC}" > /dev/tty
    echo "  sudo journalctl -u squid -n 50" > /dev/tty
    exit 1
fi
