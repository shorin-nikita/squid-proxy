#!/bin/bash
set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода в терминал (работает через curl | bash)
print_tty() {
    echo -e "$1" > /dev/tty
}

# Функция для запроса ввода (работает через curl | bash)
prompt_input() {
    local prompt="$1"
    local answer=""
    echo -n "$prompt" > /dev/tty
    read -r answer < /dev/tty
    echo "$answer"
}

# Функция для запроса пароля (скрытый ввод)
prompt_secret() {
    local prompt="$1"
    local answer=""
    echo -n "$prompt" > /dev/tty
    read -rs answer < /dev/tty
    echo "" > /dev/tty
    echo "$answer"
}

# Проверка доступности терминала
if [[ ! -r /dev/tty || ! -w /dev/tty ]]; then
    echo "Ошибка: Нет доступа к терминалу"
    exit 1
fi

print_tty "${BLUE}"
print_tty "╔═══════════════════════════════════════════════════════════╗"
print_tty "║           Установка Squid Proxy для AI API                ║"
print_tty "║      Роутинг к OpenAI, Anthropic, Google AI и др.         ║"
print_tty "╚═══════════════════════════════════════════════════════════╝"
print_tty "${NC}"

# Проверка root
if [ "$EUID" -ne 0 ]; then
    print_tty "${RED}Ошибка: Запустите скрипт с правами root (sudo)${NC}"
    print_tty "Используйте: curl -fsSL URL | sudo bash"
    exit 1
fi

# Проверка ОС
if ! command -v apt-get &> /dev/null; then
    print_tty "${RED}Ошибка: Скрипт поддерживает только Debian/Ubuntu${NC}"
    exit 1
fi

print_tty "${YELLOW}Введите данные вашего parent proxy:${NC}"
print_tty "${YELLOW}(Приобрести прокси рублями: https://ru.dashboard.proxy.market/?ref=E000154645)${NC}"
print_tty ""

# Запрос переменных
PROXY_IP=$(prompt_input "IP адрес прокси: ")
PROXY_PORT=$(prompt_input "Порт прокси: ")
PROXY_USER=$(prompt_input "Логин: ")
PROXY_PASS=$(prompt_secret "Пароль: ")

# Валидация
if [ -z "$PROXY_IP" ] || [ -z "$PROXY_PORT" ] || [ -z "$PROXY_USER" ] || [ -z "$PROXY_PASS" ]; then
    print_tty "${RED}Ошибка: Все поля обязательны для заполнения${NC}"
    exit 1
fi

print_tty ""
print_tty "${BLUE}=== Установка Squid ===${NC}"
apt-get update -qq
apt-get install -y squid > /dev/null

print_tty "${BLUE}=== Создание конфигурации ===${NC}"

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

print_tty "${BLUE}=== Запуск Squid ===${NC}"
systemctl enable squid > /dev/null 2>&1
systemctl restart squid

# Ждём запуска
sleep 2

# Проверка статуса
if systemctl is-active --quiet squid; then
    print_tty ""
    print_tty "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    print_tty "${GREEN}║                                                           ║${NC}"
    print_tty "${GREEN}║         УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА!                      ║${NC}"
    print_tty "${GREEN}║                                                           ║${NC}"
    print_tty "${GREEN}║   Squid прокси работает на порту 3128                     ║${NC}"
    print_tty "${GREEN}║                                                           ║${NC}"
    print_tty "${GREEN}║   Используйте: http://localhost:3128                      ║${NC}"
    print_tty "${GREEN}║                                                           ║${NC}"
    print_tty "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    print_tty ""
    print_tty "${YELLOW}Полезные команды:${NC}"
    print_tty "  sudo systemctl status squid   - статус сервиса"
    print_tty "  sudo systemctl restart squid  - перезапуск"
    print_tty "  sudo systemctl stop squid     - остановка"
    print_tty "  sudo tail -f /var/log/squid/access.log - логи"
    print_tty ""
    print_tty "${YELLOW}Проверка работы:${NC}"
    print_tty "  curl -x http://localhost:3128 https://api.anthropic.com"
    print_tty ""
else
    print_tty "${RED}Ошибка: Squid не запустился. Проверьте логи:${NC}"
    print_tty "  sudo journalctl -u squid -n 50"
    exit 1
fi
