# 05. Архитектура Reverse Proxy (Nginx, заголовки, SSL Termination, HTTP/1.1 - HTTP/3)

## 1. Forward Proxy vs Reverse Proxy
| Характеристика 	     | **Forward Proxy (Прямой прокси)**       | **Reverse Proxy (Обратный прокси)**           |
| 			:--- | 					  :--- |					  :--- |
| **Для кого установлен?**   | Для **клиентов** (пользователей, офиса) | Для **серверов** (бэкендов, микросервисов)    |
| **Что скрывает?**	     | Скрывает реальные IP клиентов от сайтов | Скрывает топологию и реальные IP бэкендов от интернета |
| **Задачи**		     | Фильтрация трафика офиса, обход блокировок, кэширование внешних ресурсов | Балансировка нагрузки, SSL/TLS Termination, WAF, отдача статики |
---
## 2. Проблема потери клиентского IP и заголовки проксирования
Когда запрос проходит через прокси, бэкенд видит адрес прокси (`127.0.0.1`), а не реального пользователя. Для сохранения исходных данных используются заголовки:

```nginx

# Передача реального IP клиента
proxy_set_header X-Real-IP $remote_addr;

# Цепочка всех прокси: client, proxy1, proxy2
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

# Протокол исходного подключения (http или https)
# Предотвращает циклы бесконечных редиректов при SSL Termination
proxy_set_header X-Forwarded-Proto $scheme;

# Исходный домен из запроса клиента
proxy_set_header Host $host;

3. SSL/TLS Termination
Процесс расшифровки HTTPS-трафика на уровне прокси:
  
Плюсы: разгрузка CPU бэкендов от криптографии, единое место хранения и ротации SSL-сертификатов (Certbot, Let's Encrypt).
  
Минусы: трафик внутри приватной сети между прокси и бэкендом идет открытым текстом (в критичных окружениях решается с помощью mTLS / Service Mesh).
  
4. Эволюция протоколов HTTP: от 1.1 до HTTP/3

Протокол	Транспорт	Ключевая особенность	Главный недостаток
HTTP/1.1	TCP (текст)	Поддержка Keep-Alive соединений	Head-of-Line Blocking на уровне HTTP: 1 запрос на соединение единовременно. Браузеры открывают до 6 TCP-сессий на домен.
HTTP/2	TCP (бинарный)	Мультиплексирование: параллельные потоки внутри одного TCP-соединения, сжатие заголовков HPACK	Head-of-Line Blocking на уровне TCP: потеря 1 TCP-пакета блокирует обработку всех параллельных потоков соединения.
HTTP/3	UDP (QUIC)	Независимые потоки поверх UDP, встроенный TLS 1.3, миграция соединения при смене сети (0-RTT)	Требует поддержки UDP 443 на всей цепочке сетевого оборудования.
  
5. Эталонный конфиг Nginx Reverse Proxy

nginx
upstream backend_app {
    server 127.0.0.1:8080 max_fails=3 fail_timeout=10s;
    keepalive 32;
}
server {
    listen 80;
    server_name example.com;
    return 301 https://$host$request_uri;
}
server {
    listen 443 ssl;
    http2 on;
    server_name example.com;
    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    location / {
        proxy_pass http://backend_app;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 5s;
        proxy_read_timeout 60s;
    }
}
