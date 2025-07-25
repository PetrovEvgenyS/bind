# statistics

## statistics_1.py

`statistics_1.py` - Python-скрипт предназначен для парсинга логов DNS-сервера Bind9, подсчёта статистики (по IP-адресам, доменам и типам записей) и записи результатов в три файла. 

### Первый файл 2025.07.x01.log

Файл с информацией вида IP адрес и количество запросов. Пример:

```
10.100.10.100   36975
10.100.10.253   17708
10.100.10.250   13224
10.100.10.152   10718
10.100.10.155   2868
10.100.10.252   1277
10.100.10.251   561
10.100.10.1     522
10.100.10.249   455
10.100.10.3     437
...
```

### Второй файл 2025.07.x01.log

Файл с информацией о том, какими записями сколько раз интересовались. Пример:

```
gitlab.lan                                     12129
3f4-a64-207gv.stream-balancer-allo-1.live      6557
252.10.100.10.in-addr.arpa                     3378
251.10.100.10.in-addr.arpa                     3331
www.youtube.com                                3136
main.vscode-cdn.net                            2900
1.10.100.10.in-addr.arpa                       2581
3.10.100.10.in-addr.arpa                       2574
api.browser.yandex.net                         1920
api.browser.yandex.ru                          1756
...
```

### Третий файл 2025.07.x01.log

Файл с более детальной информацией, указывающей какими именно типами записей интересовались. Пример:

```
A       gitlab.lan                                      6065
AAAA    gitlab.lan                                      6064
PTR     252.10.100.10.in-addr.arpa                      3378
PTR     251.10.100.10.in-addr.arpa                      3331
A       3f4-a64-207gv.stream-balancer-allo-1.live       3280
HTTPS   3f4-a64-207gv.stream-balancer-allo-1.live       3277
PTR     1.10.100.10.in-addr.arpa                        2581
PTR     3.10.100.10.in-addr.arpa                        2574
PTR     2.10.100.10.in-addr.arpa                        699
A       www.youtube.com                                 1580
...
```