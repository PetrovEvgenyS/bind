#!/bin/bash

# Прерывать выполнение скрипта при любой ошибке
# set -e

# Переменные
ZONE="local"
ZONE_FILE="/etc/bind/db.${ZONE}"
DNS_IP="10.100.10.251"        # IP BIND-сервера
ALLOWED_NET="10.100.10.0/24"  # Разрешённая подсеть

echo "Установка bind9..."
apt install -y bind9 dnsutils

echo "Настройка /etc/bind/named.conf.options..."
cat <<EOF > /etc/bind/named.conf.options
options {
    directory "/var/cache/bind";
    listen-on { any; };
    allow-query { localhost; ${ALLOWED_NET}; };
    recursion yes;
    dnssec-validation no;
    auth-nxdomain no;
    listen-on-v6 { none; };
};
EOF

echo "Настройка зоны в /etc/bind/named.conf.local..."
cat <<EOF > /etc/bind/named.conf.local
zone "${ZONE}" {
    type master;
    file "${ZONE_FILE}";
};
EOF

echo "Создание файла зоны: ${ZONE_FILE}"
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

echo "Проверка конфигурации..."
named-checkconf
named-checkzone ${ZONE} ${ZONE_FILE}

echo "Перезапуск BIND..."
systemctl restart bind9

echo "Готово! Проверь с клиента:"
echo "  dig @${DNS_IP} zabbix.${ZONE}"
echo "  dig @${DNS_IP} gitlab.${ZONE}"
echo "  dig @${DNS_IP} app.${ZONE}"
