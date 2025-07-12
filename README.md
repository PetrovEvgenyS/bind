# Установка и настройка BIND (master/slave) на Ubuntu

Этот скрипт автоматизирует установку и настройку связки двух DNS-серверов BIND (master/slave) на Ubuntu.

## Использование

```bash
sudo ./install_bind_ubuntu.sh <DNS_ROLE> <DNS_IP_MASTER> <DNS_IP_SLAVE> <ALLOWED_NET>
```

- `<DNS_ROLE>` — роль сервера: MASTER или SLAVE
- `<DNS_IP_MASTER>` — IP-адрес master-сервера
- `<DNS_IP_SLAVE>` — IP-адрес slave-сервера
- `<ALLOWED_NET>` — подсеть, которой разрешён доступ к DNS (например, 10.100.10.0/24)

## Примеры

### Для master-сервера:
```bash
sudo ./install_bind_ubuntu.sh MASTER 10.100.10.251 10.100.10.252 10.100.10.0/24
```

### Для slave-сервера:
```bash
sudo ./install_bind_ubuntu.sh SLAVE 10.100.10.251 10.100.10.252 10.100.10.0/24
```

## Что делает скрипт
- Устанавливает bind9 и dnsutils
- Очищает стандартные файлы BIND и создаёт структуру директорий
- Генерирует универсальный конфиг с поддержкой master/slave
- На MASTER создаёт файл зоны с NS-записями для обоих серверов и локальными записями
- На SLAVE файл зоны не создаётся, зона подтягивается с master
- Настраивает ACL, logging, статистику, rndc.conf
- Загружает актуальный named.root
- Добавляет оба DNS-сервера в /etc/resolv.conf
- Перезапускает сервис BIND

## named.root
- Используйте в случае, если не работает сайт: `https://www.internic.net/domain/named.root`
- last update: June 26, 2025

