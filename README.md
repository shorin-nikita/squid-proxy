# Squid Proxy

Простая настройка Squid прокси-сервера с parent proxy для роутинга трафика к AI API.

## Что делает

- Поднимает локальный Squid прокси на порту `3128`
- Весь трафик к AI сервисам (OpenAI, Anthropic, OpenRouter, xAI, Google AI) идёт через ваш parent proxy
- Остальной трафик идёт напрямую

## Приобрести прокси рублями можно [здесь](https://ru.dashboard.proxy.market/?ref=E000154645)

## Установка одной командой

```bash
sudo bash <(curl -fsSL https://raw.githubusercontent.com/shorin-nikita/squid-proxy/main/install.sh)
```

Скрипт запросит:
- IP адрес прокси
- Порт прокси
- Логин
- Пароль

После ввода данных Squid автоматически установится и запустится.

## Команды

| Команда | Описание |
|---------|----------|
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

## Изменение конфигурации

Конфиг находится в `/etc/squid/squid.conf`. После изменений:

```bash
sudo systemctl restart squid
```

## Переустановка

Для изменения данных прокси просто запустите установку заново:

```bash
sudo bash <(curl -fsSL https://raw.githubusercontent.com/shorin-nikita/squid-proxy/main/install.sh)
```
