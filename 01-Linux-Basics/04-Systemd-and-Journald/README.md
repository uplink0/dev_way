# Тема 1.4. Архитектура Systemd, управление службами и системный журнал Journald
## 1. Анатомия Unit-файла (`.service`)

Пользовательские юниты размещаются в `/etc/systemd/system/` (имеют наивысший приоритет над системными из
 `/lib/systemd/system/`).

```ini
[Unit]
Description=My Custom Backend API
After=network.target postgresql.service   # Запускать ПОСЛЕ готовности сети и базы
Wants=postgresql.service                # Мягкая зависимость (база желательна, но не критична)
Requires=postgresql.service          # Жёсткая зависимость (если база упала — сервис не запустится)
[Service]
Type=simple                             # simple, forking, oneshot, notify
User=www-data
Group=www-data
WorkingDirectory=/opt/app
ExecStart=/usr/bin/python3 /opt/app/main.py
ExecReload=/bin/kill -HUP $MAINPID      # Сигнал для graceful reload
Restart=always                          # always, on-failure, no
RestartSec=5                            # Пауза перед рестартом при падении
LimitNOFILE=65535                       # Лимит открытых файловых дескрипторов
[Install]
WantedBy=multi-user.target              # Автозагрузка при старте стандартного режима ОС

  

  
2. Разница ключевых директив:
  
Параметр	Поведение
Requires=	Жёсткая зависимость: если зависимый сервис завершается с ошибкой или остановлен, наш сервис немедленно останавливается.
Wants=	Мягкая зависимость: запускает соседний сервис, но если тот упал — наш сервис продолжает работу. Рекомендуемый стандарт.
After= / Before=	Определяет только порядок запуска, но не создаёт зависимость!

  

  
3. Управление жизненным циклом (systemctl)
  
systemctl restart <unit>: полностью останавливает процесс (SIGTERM -> SIGKILL) и запускает заново. Все активные клиентские соединения обрываются.

systemctl reload <unit>: отправляет сигнал SIGHUP. Процесс перечитывает конфигурационные файлы без остановки и без сброса активных сессий (Zero Downtime).

systemctl daemon-reload: обязательная команда после любого ручного редактирования unit-файла на диске, чтобы Systemd перечитал конфигурацию в память.
  
4. Диагностика логов через Journald (journalctl)

Systemd Journald собирает stdout и stderr всех служб в бинарный кольцевой журнал.
 
```bash
# Чтение логов сервиса в реальном времени (follow):
journalctl -u nginx.service -f

# Вывод только ошибок (Priority: err, crit, alert, emerg):
journalctl -u nginx.service -p err -b

# Логи за последние 15 минут:
journalctl -u nginx.service --since "15 minutes ago"

# Логи за конкретный интервал времени:
journalctl -u nginx.service --since "2026-10-24 10:00:00" --until "2026-10-24 10:30:00"

# Ограничение размера логов на диске (очистка диска при переполнении):
sudo journalctl --vacuum-size=200M
