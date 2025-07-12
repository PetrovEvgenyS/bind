#!/bin/bash

# Переменные
DNS_ROLE="$1"
DNS_IP_MASTER="$2"
DNS_IP_SLAVE="$3"
ALLOWED_NET="$4"
DNS_NAME_MASTER="dns01"
DNS_NAME_SLAVE="dns02"
ZONE="local"
ZONE_FILE="/etc/bind/int/db.${ZONE}"

### ЦВЕТА ##
ESC=$(printf '\033') RESET="${ESC}[0m" MAGENTA="${ESC}[35m" RED="${ESC}[31m" GREEN="${ESC}[32m"

### Функции цветного вывода ##
magentaprint() { echo; printf "${MAGENTA}%s${RESET}\n" "$1"; }
errorprint() { echo; printf "${RED}%s${RESET}\n" "$1"; }
greenprint() { echo; printf "${GREEN}%s${RESET}\n" "$1"; }


# ----------------------------------------------------------------------------------------------- #


# Проверка наличия аргументов (IP-адрес DNS и разрешённая подсеть)
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
  errorprint "Ошибка: Не указаны обязательные параметры."
  echo "Пожалуйста, укажите IP-адрес сервера BIND и разрешённую подсеть."
  echo "Использование: $0 <DNS_ROLE> <DNS_IP_MASTER> <DNS_IP_SLAVE> <ALLOWED_NET>"
  echo "Пример: $0 MASTER 10.100.10.251 10.100.10.252 10.100.10.0/24"
  echo "Где:"
  echo "  <DNS_ROLE> - Роль DNS-сервера (MASTER или SLAVE)"
  echo "  <DNS_IP_MASTER> - IP-адрес сервера BIND MASTER"
  echo "  <DNS_IP_SLAVE> - IP-адрес сервера BIND SLAVE"
  echo "  <ALLOWED_NET> - Разрешённая подсеть для доступа к DNS"; echo
  exit 1
fi

magentaprint "Установка bind9..."
apt install -y bind9 dnsutils

magentaprint "Удаление стандартных файлов bind9..."
cd /etc/bind/
rm -rf db.0 db.127 db.255 db.empty db.local named.conf.local named.conf.options named.conf.default-zones zones.rfc1918

magentaprint "Создание необходимых директоиий для bind9..."
mkdir dump ext int stats working /var/log/named
chown -R bind:bind dump ext int stats working /var/log/named

magentaprint "Настройка /etc/bind/named.conf..."
cat <<EOF > /etc/bind/named.conf
// ACL Data
// Группировка IP-адресов для удобного управления доступом.
acl "ext" { 127.0.0.0/8; };
acl "int" { 10.0.0.0/8; 172.16.0.0/12; 192.168.0.0/16; };
acl "mgmt" { 127.0.0.0/8; ${ALLOWED_NET}; };


// DNS Key
// Для удалённое управление BIND через утилиту rndc.
// Используется в секции controls.
key "rndc-key" {
    algorithm hmac-sha256;
    secret "AZR8VALTYOBOG6C2j20EliWWnML1iSd+RJ2fpy0PN1I=";
};


// Control
// Разрешаем подключение к BIND для управления по интерфейсам из mgmt-сети:
controls {
    inet 127.0.0.1 port 953 allow { mgmt; } keys { "rndc-key"; };
    inet $( [ "$DNS_ROLE" = "MASTER" ] && echo "$DNS_IP_MASTER" || echo "$DNS_IP_SLAVE" ) port 953 allow { mgmt; } keys { "rndc-key"; };
};


// Основные настройки
options {
    directory "/etc/bind/working";                  // Рабочая директория
    pid-file "/var/run/named/named.pid";            // Файл PID
    dump-file "/etc/bind/dump/named_dump.db";       // Дамп кэша
    statistics-file "/etc/bind/stats/named.stats";  // Статистика
    bindkeys-file "/etc/bind/bind.keys";            // DNSSEC-ключи

    empty-zones-enable no;                          // Не создавать пустые зоны
    notify no;                                      // Отключить уведомления slaves

    recursion no;                                   // Глобально запрещаем рекурсию
    allow-recursion { none; };                      // Дополнительная страховка
    allow-query { any; };                           // Запросы разрешены от всех

    dnssec-validation yes;                          // Валидация DNSSEC
    max-cache-size 1024m;                           // Лимит кэша
    allow-transfer { ext; int; mgmt; };             // Кто может запрашивать трансфер зон

    listen-on { any; };                             // Слушать на всех интерфейсах IPv4
    listen-on-v6 { any; };                          // И IPv6
};


// Включение веб-статистики на порту 80
statistics-channels {
    inet $( [ "$DNS_ROLE" = "MASTER" ] && echo "$DNS_IP_MASTER" || echo "$DNS_IP_SLAVE" ) port 80 allow { mgmt; };
};


// Логирование
logging {
    channel bind_log {
        file "/var/log/named/named.log" versions 4 size 128m;
        print-time yes;
        print-category yes;
        print-severity yes;
    };

    channel update_log {
        file "/var/log/named/update.log" versions 4 size 128m;
        print-time yes;
        print-category yes;
        print-severity yes;
    };

    channel xfer_log {
        file "/var/log/named/xfer.log" versions 4 size 128m;
        print-time yes;
        print-category yes;
        print-severity yes;
    };

    channel security_log {
        file "/var/log/named/security.log" versions 4 size 128m;
        print-time yes;
        print-category yes;
        print-severity yes;
    };

    channel query_log {
        file "/var/log/named/query.log" versions 4 size 128m;
        print-time yes;
        print-category yes;
        print-severity yes;
    };

    category default { bind_log; };
    category xfer-in { xfer_log; };
    category xfer-out { xfer_log; };
    category update { update_log; };
    category security { security_log; };
    category queries { query_log; };
    category lame-servers { null; };
    category edns-disabled { bind_log; };
};


// Internal view section
view "int-in" {
    match-clients { int; };
    recursion yes;
    allow-recursion { int; };

    // Root zone
    zone "." {
        type hint;
        file "/etc/bind/named.root";
    };

    // Zone for local domain
    zone "${ZONE}" {
        type $( [ "${DNS_ROLE}" = "MASTER" ] && echo master || echo slave );
        file "${ZONE_FILE}";
$( [ "${DNS_ROLE}" = "MASTER" ] && echo -e "        notify yes;\n        also-notify { $DNS_IP_SLAVE; };\n        allow-update { mgmt; };" )
$( [ "${DNS_ROLE}" = "SLAVE" ] && echo "        masters { $DNS_IP_MASTER; };" )
    };
};
EOF

if [ "${DNS_ROLE}" = "MASTER" ]; then
  magentaprint "Создание файла зоны: ${ZONE_FILE}"
  cat <<EOF > ${ZONE_FILE}
\$TTL 600
\$ORIGIN ${ZONE}.
@                   IN  SOA ${DNS_NAME_MASTER}.${ZONE}. admin.${ZONE}.ru. (
                            2025071201  ; Serial number
                            600         ; Refresh
                            60          ; Retry
                            600         ; Expire
                            600         ; Minimum
                            )

@                   IN  NS        ${DNS_NAME_MASTER}.${ZONE}.
@                   IN  NS        ${DNS_NAME_SLAVE}.${ZONE}.

${DNS_NAME_MASTER}               IN  A         ${DNS_IP_MASTER}
${DNS_NAME_SLAVE}               IN  A         ${DNS_IP_SLAVE}

; Локальные записи
zabbix                          IN  A         10.100.10.253
gitlab                          IN  A         10.100.10.250
kvm                             IN  A         10.100.10.200
node-vm01                       IN  A         10.100.10.1
node-vm02                       IN  A         10.100.10.2
node-vm03                       IN  A         10.100.10.3
node-vm04                       IN  A         10.100.10.4
node-vm05                       IN  A         10.100.10.5
node-vm06                       IN  A         10.100.10.6
EOF
fi


magentaprint "Создание файла named.root"
magentaprint "Загрузка актуального named.root..."
wget -O /etc/bind/named.root https://www.internic.net/domain/named.root || \
    errorprint "Не удалось загрузить named.root с https://www.internic.net/domain/named.root" \
    magentaprint "Скопирйте named.root с GitHub в /etc/bind/named.root и перезагрузите bind9:" \
    magentaprint "https://github.com/PetrovEvgenyS/bind/blob/main/named.root"


magentaprint "Проверка конфигурации..."
named-checkconf
if [ "${DNS_ROLE}" = "MASTER" ]; then
  named-checkzone ${ZONE} ${ZONE_FILE}
fi

# Настройка разрешения DNS
magentaprint "Настройка /etc/resolv.conf..."
# Добавляем оба DNS-сервера перед 127.0.0.53
sed -i "/^nameserver 127.0.0.53/i nameserver ${DNS_IP_MASTER}\nnameserver ${DNS_IP_SLAVE}" /etc/resolv.conf


magentaprint "Перезапуск BIND..."
systemctl restart bind9

greenprint "Готово! Проверь с клиента:"
echo "  dig @${DNS_IP_MASTER} zabbix.${ZONE}"
echo "  dig @${DNS_IP_SLAVE} zabbix.${ZONE}"

