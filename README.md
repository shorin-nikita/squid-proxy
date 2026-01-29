# Squid Proxy

Простая настройка Squid прокси-сервера с parent proxy для роутинга трафика к AI API.

## Что делает

- Поднимает локальный Squid прокси на порту `3128`
- Весь трафик к AI сервисам (OpenAI, Anthropic, OpenRouter, xAI, Google AI) идёт через ваш parent proxy
- Остальной трафик идёт напрямую

## Установка

```bash
# Клонируем репозиторий
git clone https://github.com/shorin-nikita/squid-proxy.git
cd squid-proxy

# Создаём конфиг с прокси
cp proxies.conf.example proxies.conf
nano proxies.conf

# Устанавливаем и запускаем
sudo ./install.sh
```

## Настройка прокси

Отредактируйте `proxies.conf`:

```bash
PROXY_IP="1.2.3.4"
PROXY_PORT="8080"
PROXY_USER="myuser"
PROXY_PASS="mypassword"
```

## Команды

| Команда | Описание |
|---------|----------|
| `sudo ./install.sh` | Первая установка Squid |
| `sudo ./setup.sh` | Обновить конфиг после смены прокси |
| `sudo systemctl status squid` | Статус сервиса |
| `sudo systemctl restart squid` | Перезапуск |
| `sudo systemctl stop squid` | Остановка |

## Проверка

```bash
# Проверка что прокси работает
curl -x http://localhost:3128 https://api.anthropic.com

# Логи
sudo tail -f /var/log/squid/access.log
```

## Роутинг

Через parent proxy идут домены:
- `.anthropic.com`, `.claude.ai`
- `.openai.com`, `.api.openai.com`
- `.openrouter.ai`
- `.x.ai`, `api.x.ai`
- `.googleapis.com`

Изменить список: отредактируйте `squid.conf.template` → запустите `sudo ./setup.sh`
