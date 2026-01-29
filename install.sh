#!/bin/bash
set -e

echo "=== Установка Squid ==="
apt-get update
apt-get install -y squid

echo "=== Настройка конфига ==="
./setup.sh

echo "=== Запуск Squid ==="
systemctl enable squid
systemctl restart squid

echo "=== Готово! Squid работает на порту 3128 ==="
systemctl status squid --no-pager
