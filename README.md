# Инструкция по установке и обновлению

## Файлы проекта

- `S99monitor` - init.d скрипт
- `monitor-devices.sh` - основной скрипт мониторинга
- `notify-telegram.sh` - скрипт отправки уведомлений
- `devices.conf` - конфигурация устройств (MAC -> имя)
- `telegram.conf` - конфигурация Telegram бота

## Предварительные требования

На Keenetic должен быть установлен curl:
```sh
opkg update
opkg install curl
```

## Установка

### 1. Создать директорию для конфигурации
```sh
mkdir -p /opt/etc/monitor-devices
```

### 2. Скопировать файлы конфигурации
```sh
# Скопировать конфигурационные файлы
cp devices.conf /opt/etc/monitor-devices/
cp telegram.conf /opt/etc/monitor-devices/

# Установить права доступа для telegram.conf (скрыть токен)
chmod 600 /opt/etc/monitor-devices/telegram.conf
```

### 3. Скопировать скрипты
```sh
# Скопировать скрипты
cp monitor-devices.sh /opt/bin/
cp notify-telegram.sh /opt/bin/
cp S99monitor /opt/etc/init.d/

# Установить права на выполнение
chmod +x /opt/bin/monitor-devices.sh
chmod +x /opt/bin/notify-telegram.sh
chmod +x /opt/etc/init.d/S99monitor
```

### 4. Настроить устройства (опционально)

Отредактировать `/opt/etc/monitor-devices/devices.conf`:
```sh
vi /opt/etc/monitor-devices/devices.conf
```

Формат: `MAC=Имя` через пробел
```bash
DEVICES="2c:d2:6b:71:8a:26=TV 86:30:67:51:43:d9=Pixel"
```

### 5. Настроить Telegram (опционально)

Отредактировать `/opt/etc/monitor-devices/telegram.conf`:
```sh
vi /opt/etc/monitor/devices/telegram.conf
```

### 6. Запустить мониторинг
```sh
/opt/etc/init.d/S99monitor start
```

## Управление

```sh
# Запуск
/opt/etc/init.d/S99monitor start

# Остановка
/opt/etc/init.d/S99monitor stop

# Перезапуск
/opt/etc/init.d/S99monitor restart

# Статус
/opt/etc/init.d/S99monitor status

# Просмотр логов
/opt/etc/init.d/S99monitor log

# Также можно смотреть логи напрямую
tail -f /opt/var/log/monitor-devices.log
tail -f /opt/var/log/telegram-notify.log
```

## Тестирование

### Тест отправки уведомления
```sh
/opt/bin/notify-telegram.sh test
```

### Тест мониторинга (без отправки уведомлений)
```sh
# Запустить вручную и посмотреть вывод
/opt/bin/monitor-devices.sh
```

## Автозагрузка

Скрипт `S99monitor` автоматически запустится после перезагрузки роутера благодаря механизму init.d в Entware.

## Структура файлов после установки

```
/opt/
├── etc/
│   ├── init.d/
│   │   └── S99monitor
│   └── monitor-devices/
│       ├── devices.conf
│       └── telegram.conf
├── bin/
│   ├── monitor-devices.sh
│   └── notify-telegram.sh
└── var/
    └── log/
        ├── monitor-devices.log
        └── telegram-notify.log
```

## Удаление

```sh
# Остановить мониторинг
/opt/etc/init.d/S99monitor stop

# Удалить файлы
rm -rf /opt/etc/monitor-devices
rm -f /opt/bin/monitor-devices.sh
rm -f /opt/bin/notify-telegram.sh
rm -f /opt/etc/init.d/S99monitor

# Удалить логи (опционально)
rm -rf /opt/var/log/monitor-devices.log
rm -rf /opt/var/log/telegram-notify.log
```
