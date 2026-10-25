# 04. Маршрутизация, NAT и фаервол Linux (iptables, conntrack, ip route)
## 1. Архитектура сетевого стека Linux: Таблицы и Цепочки
Пакет в ядре Linux проходит через фиксированные цепочки в зависимости от его назначения:
```text
Входящий пакет из сети
       │
       ▼
 [ PREROUTING ] ──► (Таблицы: raw -> mangle -> nat [DNAT: подмена IP назначения])
       │
       ▼
[ Решение о маршрутизации (Routing Decision) ]
       ├─────────────────────────────────┐
       │ (Пакет предназначен ЭТОМУ хосту)│ (Транзитный пакет: чужой IP)
       ▼                                 ▼
   [ INPUT ]                         [ FORWARD ]
 (mangle -> filter)               (mangle -> filter)
       │                                 │
       ▼                                 │
[ Локальный процесс (Nginx, Go-app) ]   │
       │                                 │
       ▼                                 │
   [ OUTPUT ]                            │
 (raw -> mangle -> nat -> filter)        │
       │                                 │
       ▼                                 │
[ Решение о маршрутизации ]             │
       │                                 │
       ├─────────────────────────────────┘
       ▼
 [ POSTROUTING ] ──► (Таблицы: mangle -> nat [SNAT/MASQUERADE: подмена IP отправителя])
       │
       ▼
Отправка в сетевую карту (NIC)

  
Основные таблицы:

  

  
filter (по умолчанию): фильтрация трафика (ACCEPT, DROP, REJECT). Цепочки: INPUT, FORWARD, OUTPUT.

  
nat: трансляция сетевых адресов. Цепочки: PREROUTING, POSTROUTING, OUTPUT.

  
mangle: изменение заголовков пакетов (TTL, TOS, маркировка).

  
raw: исключение пакетов из системы отслеживания состояний (NOTRACK).

  

  

  
2. DNAT vs SNAT

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
Параметр	DNAT (Destination NAT)	SNAT / MASQUERADE (Source NAT)
Что изменяется?	IP-адрес и порт назначения	IP-адрес и порт отправителя
В какой цепочке?	PREROUTING (до маршрутизации)	POSTROUTING (перед выходом в провод)
Применение	Проброс портов (Port Forwarding), реализация ClusterIP / NodePort в Kubernetes	Выход подов и локальных сетей в публичный интернет через один IP

  

  
3. Подсистема отслеживания соединений conntrack

  

Модуль ядра Linux, отслеживающий состояние сетевых потоков (NEW, ESTABLISHED, RELATED, INVALID).


  
Опасность переполнения:

  

  
Размер таблицы ограничен параметром net.netfilter.nf_conntrack_max.

  
При переполнении (100%) ядро отбрасывает новые пакеты:

  [kernel] nf_conntrack: table full, dropping packet

  
Это вызывает полный отказ в обслуживании новых соединений при свободном CPU и RAM.

  

  
bash
# Текущее количество и лимит соединений conntrack
sudo sysctl net.netfilter.nf_conntrack_count net.netfilter.nf_conntrack_max

  

  
4. Как Kubernetes использует iptables под капотом

  

В Kubernetes виртуальные IP сервисов (ClusterIP) физически отсутствуют на интерфейсах хоста.


  

  
Демон kube-proxy генерирует правила в таблице nat цепочки KUBE-SERVICES.

  
При обращении к ClusterIP (например, 10.108.2.98:80) iptables делает DNAT, подменяя виртуальный адрес сервиса на реальный IP пода (192.168.x.x).

  
BGP-маршрутизатор (например, Calico BIRD) динамически добавляет маршруты к подам других нод через оверлейные туннели (tunl0 IP-in-IP).

  

  
Полезные команды диагностики:

  
bash
# Просмотр маршрутов и проверка шлюза ядра
ip route show
ip route get 8.8.8.8
# Просмотр правил NAT сервисов Kubernetes
sudo iptables -t nat -L KUBE-SERVICES -n -v

  

