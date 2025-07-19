import re
from collections import Counter
from datetime import datetime
import sys

def parse_bind9_log(log_file):
    # Регулярное выражение для извлечения IP, домена и типа записи из строки лога BIND9
    pattern = r'client @0x[0-9a-f]+ (\d+\.\d+\.\d+\.\d+)#\d+ \((.*?)\):.*?query:.*? IN (\w+)'
    ip_counts = Counter()           # Счетчик для IP-адресов
    domain_counts = Counter()       # Счетчик для доменов
    type_domain_counts = Counter()  # Счетчик для пар "тип записи + домен"
    
    try:
        with open(log_file, 'r') as f:
            for line in f:
                # Ищем совпадение по регулярному выражению в каждой строке лога
                match = re.search(pattern, line)
                if match:
                    ip_address = match.group(1)  # Извлекаем IP-адрес
                    domain = match.group(2)      # Извлекаем домен
                    record_type = match.group(3) # Извлекаем тип записи (A, AAAA, MX и т.д.)
                    ip_counts[ip_address] += 1
                    domain_counts[domain] += 1
                    type_domain_counts[f"{record_type}\t{domain}"] += 1
    except FileNotFoundError:
        print(f"Ошибка: Файл лога {log_file} не найден")
        sys.exit(1)
    except Exception as e:
        print(f"Ошибка обработки лога: {e}")
        sys.exit(1)
    
    # Возвращаем три счетчика: по IP, по доменам, по парам "тип+домен"
    return ip_counts, domain_counts, type_domain_counts

def write_stats(ip_counts, domain_counts, type_domain_counts, date_prefix):
    try:
        # Файл 1: IP и количество запросов
        with open(f"{date_prefix}.x01.log", 'w') as f:
            for ip, count in ip_counts.most_common():
                f.write(f"{ip}\t{count}\n")
        
        # Файл 2: Домены и количество запросов, с выравниванием по ширине самого длинного домена
        max_domain_length = max(len(domain) for domain in domain_counts)  # Находим максимальную длину домена
        with open(f"{date_prefix}.x02.log", 'w') as f:
            for domain, count in domain_counts.most_common():
                # Выравниваем для читаемости
                f.write(f"{domain:<{max_domain_length + 2}}{count}\n")
        
        # Файл 3: Тип записи и домен с количеством запросов, с выравниванием
        max_domain_length_x03 = max(len(domain.split('\t')[1]) for domain in type_domain_counts)  # Находим максимальную длину домена
        with open(f"{date_prefix}.x03.log", 'w') as f:
            for type_domain, count in type_domain_counts.most_common():
                record_type, domain = type_domain.split('\t')
                # Выравниваем для читаемости
                f.write(f"{record_type:<8}{domain:<{max_domain_length_x03 + 2}}{count}\n")
    except Exception as e:
        print(f"Ошибка записи в файлы: {e}")
        sys.exit(1)

def main():
    log_file = "/var/log/named/query.log"           # Путь к файлу лога BIND9
    date_prefix = datetime.now().strftime("%Y.%m")  # Префикс для файлов статистики (год.месяц)
    ip_counts, domain_counts, type_domain_counts = parse_bind9_log(log_file)    # Получаем статистику по логам
    write_stats(ip_counts, domain_counts, type_domain_counts, date_prefix)      # Записываем статистику в файлы
    print(f"Статистика записана в файлы {date_prefix}.x01.log, {date_prefix}.x02.log, {date_prefix}.x03.log")

if __name__ == "__main__":
    main()
