# 02. DNS: от системных вызовов Linux до Kubernetes CoreDNS
## 1. Цепочка резолвинга в Linux (Name Resolution Flow)
Когда приложение вызывает `getaddrinfo()`, операционная система проходит следующий путь:
1. **`/etc/nsswitch.conf`** — диспетчер служб имён.
   ```text
   hosts: files dns

files — сначала проверяется локальный файл /etc/hosts.  
dns — если запись не найдена, опрашиваются DNS-серверы из /etc/resolv.conf.
  
/etc/resolv.conf — конфигурация серверов имён (nameserver).
 
В классических серверах часто указываются апстримы напрямую (например, 8.8.8.8, 1.1.1.1).
В дистрибутивах с systemd часто работает локальный stub-резолвер systemd-resolved на 127.0.0.53:53.
  
2. Основные типы DNS-записей
  
Тип	  Назначение	                        Пример
A	    Сопоставление имени с IPv4-адресом	api.site.com -> 192.0.2.1
AAAA	Сопоставление имени с IPv6-адресом	api.site.com -> 2001:db8::1
CNAME	Каноническое имя (псевдоним). 
Нельзя вешать на apex/root домен	        www.site.com -> site.com
TXT	  Текстовые данные (SPF, DKIM, DMARC, 
валидация владения доменом)	v=spf1        include:_spf.google.com ~all
MX	  Почтовые серверы с приоритетом	10  mail.site.com
SRV	  Определение хоста и порта сервиса	  _sip._tcp.example.com
PTR	  Обратная зона (IP -> домен)	        1.2.0.192.in-addr.arpa
 
3. Диагностика DNS с помощью dig
dig (Domain Information Groper) — замена устаревшему nslookup. Показывает сырые DNS-ответы со всеми флагами.

```bash
# Базовый запрос A-записи
dig yandex.ru
# Краткий ответ (только IP)
dig yandex.ru +short
# Полная трассировка от корневых серверов (Root -> TLD -> Authoritative)
dig +trace yandex.ru
# Запрос к конкретному DNS-серверу
dig @1.1.1.1 yandex.ru A

  
Ключевые поля вывода dig:

status: NOERROR — успешный запрос.
status: NXDOMAIN — домен не существует (Non-Existent Domain).
Флаги qr rd ra:
qr (Query Response) — получен ответ от сервера.
rd (Recursion Desired) — клиент запросил рекурсивный поиск.
ra (Recursion Available) — DNS-сервер поддерживает рекурсию.
TTL (Time To Live) — время в секундах, на которое запись кэшируется клиентом/резолвером.
 
4. DNS в Kubernetes и проблема ndots:5
Внутри любого пода /etc/resolv.conf сконфигурирован Kubelet'ом:
text
search <namespace>.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5

# В чём заключается проблема ndots:5:
Если количество точек в запрашиваемом домене меньше 5 (например, во внешнем адресе api.stripe.com всего 2 точки), резолвер glibc сначала по очереди подставляет все суффиксы из списка search:
 
api.stripe.com.<namespace>.svc.cluster.local ➔ NXDOMAIN
api.stripe.com.svc.cluster.local ➔ NXDOMAIN
api.stripe.com.cluster.local ➔ NXDOMAIN
api.stripe.com. ➔ Успешный ответ
 
Это генерирует в 4 раза больше мусорных запросов к CoreDNS на каждый внешний вызов, вызывая перегрузку DNS и таймауты в приложении.
Способы решения:
 
Точка на конце (FQDN): указывать внешние адреса в конфигах приложений как api.stripe.com. (с точкой).
Тюнинг dnsConfig в манифесте пода:
  
yaml
spec:
  dnsConfig:
    options:
      - name: ndots
        value: "2"

Использование NodeLocal DNSCache в кластере для локального кэширования DNS на каждом узле.
