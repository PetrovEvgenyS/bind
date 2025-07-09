#!/bin/bash

# Прерывать выполнение скрипта при любой ошибке
set -e

# Переменные
ZONE="local"
ZONE_FILE="/etc/bind/db.${ZONE}"
DNS_IP="$1"              # IP BIND-сервера
ALLOWED_NET="$2"         # Разрешённая подсеть

### ЦВЕТА ##
ESC=$(printf '\033') RESET="${ESC}[0m" MAGENTA="${ESC}[35m" RED="${ESC}[31m" GREEN="${ESC}[32m"

### Функции цветного вывода ##
magentaprint() { echo; printf "${MAGENTA}%s${RESET}\n" "$1"; }
errorprint() { echo; printf "${RED}%s${RESET}\n" "$1"; }
greenprint() { echo; printf "${GREEN}%s${RESET}\n" "$1"; }


# ----------------------------------------------------------------------------------------------- #


# Проверка наличия аргументов (IP-адрес DNS и разрешённая подсеть)
if [ -z "$1" ] || [ -z "$2" ]; then
  errorprint "Ошибка: Не указаны обязательные параметры."
  echo "Пожалуйста, укажите IP-адрес сервера BIND и разрешённую подсеть."
  echo "Использование: $0 <DNS_IP> <ALLOWED_NET>"
  echo "Пример: $0 10.100.10.251 10.100.10.0/24"
  echo "Где:"
  echo "  <DNS_IP> - IP-адрес сервера BIND"
  echo "  <ALLOWED_NET> - Разрешённая подсеть для доступа к DNS"
  exit 1
fi

magentaprint "Установка bind9..."
apt install -y bind9 dnsutils

magentaprint "Настройка /etc/bind/named.conf.options..."
cat <<EOF > /etc/bind/named.conf.options
// ACL Data
acl "ext" { 127.0.0.0/8; };
acl "int" { 10.0.0.0/8; 172.16.0.0/12; 192.168.0.0/16; };
acl "mgmt" { 127.0.0.0/8; 10.100.10.0/24; };

options {
    directory "/var/cache/bind";
    listen-on { any; };
    allow-query { localhost; ${ALLOWED_NET}; };
    recursion yes;
    dnssec-validation no;
    auth-nxdomain no;
    listen-on-v6 { none; };
};

// Включение статистики на интерфейсте
statistics-channels {
    inet ${DNS_IP} port 80 allow { mgmt; };
};
EOF

magentaprint "Настройка зоны в /etc/bind/named.conf.local..."
cat <<EOF > /etc/bind/named.conf.local
zone "${ZONE}" {
    type master;
    file "${ZONE_FILE}";
};
EOF

magentaprint "Создание файла зоны: ${ZONE_FILE}"
cat <<EOF > ${ZONE_FILE}
\$TTL    86400
@       IN      SOA     ns.${ZONE}. admin.${ZONE}. (
                            2025070901  ; Serial
                            604800      ; Refresh
                            86400       ; Retry
                            2419200     ; Expire
                            86400 )     ; Negative Cache TTL
;
@       IN      NS      ns.${ZONE}.
ns      IN      A       ${DNS_IP}

; Локальные записи
zabbix  IN      A       10.100.10.253
gitlab  IN      A       10.100.10.250
app     IN      A       10.100.10.200
EOF

magentaprint "Проверка конфигурации..."
named-checkconf
named-checkzone ${ZONE} ${ZONE_FILE}

# Настройка разрешения DNS
magentaprint "Настройка /etc/resolv.conf..."
sed -i "/^nameserver 127.0.0.53/i nameserver ${DNS_IP}" /etc/resolv.conf

magentaprint "Перезапуск BIND..."
systemctl restart bind9

greenprint "Готово! Проверь с клиента:"
echo "  dig @${DNS_IP} zabbix.${ZONE}"
echo "  dig @${DNS_IP} gitlab.${ZONE}"
echo "  dig @${DNS_IP} app.${ZONE}"
