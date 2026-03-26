# Chuwi CoreBook X — TLP и профили энергопотребления (Ubuntu 24.04)

Репозиторий для ноутбука **CHUWI CoreBook X** с настройкой **TLP** вместо штатного **power-profiles-daemon**, три пользовательских режима питания и ярлыки в сессии GNOME.

**Оповещения:** после переключения режима из ярлыка в GNOME показывается **системное уведомление** (название профиля и краткое описание): используются **`notify-send`** / **`gdbus`**; пароль администратора запрашивается через **zenity** и **`sudo -A`** — **без открытия окна терминала**.

---
**Автор:** [AntyanMS](https://github.com/AntyanMS)  
**Публичный репозиторий:** [github.com/AntyanMS/Performance_Mode](https://github.com/AntyanMS/Performance_Mode)  
Если будут вопросы или понадобится помощь — пишите в GitHub Issues или напрямую в Telegram: [@Cmint](https://t.me/cmint)
---

## Аппаратная платформа (эталонная конфигурация)

| Параметр | Значение |
|----------|----------|
| Производитель / модель | CHUWI Innovation And Technology — **CoreBook X** (маркетинговое имя; в DMI может быть «Default string») |
| Платформа | Ноутбук, UEFI |
| Процессор | **AMD Ryzen 5 7430U** with Radeon Graphics |
| Масштабирование частот | Драйвер **amd-pstate-epp** (в cmdline часто `amd_pstate=active`) |
| Доступные губернаторы | Обычно **powersave** и **performance** (без `schedutil`) |
| ACPI `platform_profile` | **Нет** — профили «тихо/производительность» вентилятора из Linux недоступны, поведение кулера задаёт EC/BIOS |
| Подсветка | Типично **amdgpu_bl*** в `/sys/class/backlight/` |
| ОС (целевая) | **Ubuntu 24.04 LTS** (Noble), ядро **6.8+** / **6.17** (HWE) |

Другие модели Chuwi и процессоры могут отличаться: проверяйте `sudo tlp-stat -p` и при необходимости правьте числа в `config/power-mode.sh`.

---

## Зачем отключать power-profiles-daemon

В GNOME **«Параметры → Питание»** используют **power-profiles-daemon** (PPD). **TLP** тоже меняет governor, EPP, ASPM и т.д. Одновременная работа двух механизмов даёт гонки и непредсказуемый результат. Скрипт установки **останавливает, отключает и маскирует** сервис `power-profiles-daemon`. Слайдер режимов в настройках GNOME после этого исчезнет — это нормально; режимы задаются **ярлыками** или **`power-mode.sh`**.

Опция `./install.sh --purge-power-profiles` полностью снимает пакет PPD (по желанию).

---

## Состав репозитория

Каталог после клонирования (в инструкции ниже — в **`$HOME/chuwi`**; если клонировали без целевого пути, имя папки будет **`Performance_Mode`** — это нормально).

```
.
├── .gitignore
├── README.md                 # этот файл
├── install.sh                # установка под выбранного пользователя
├── config/
│   ├── power-mode.sh         # логика eco / balanced / performance / reset
│   ├── chuwi-askpass          # пароль для sudo -A (zenity)
│   ├── chuwi-tlp-runner.sh    # ярлык GNOME → sudo -A → root-скрипт
│   ├── chuwi-tlp-notify-root.sh
│   ├── tlp/
│   │   └── 98-chuwi-radios.conf   # не отключать Wi‑Fi/BT на батарее
│   └── desktop/
│       ├── tlp-quiet.desktop
│       ├── tlp-balanced.desktop
│       ├── tlp-performance.desktop
│       └── tlp-reset.desktop
└── scripts/
    └── export-installed-packages.sh   # вспомогательный экспорт списка пакетов
```

После установки в домашний каталог копируется **`$HOME/power-mode.sh`**; в **`/usr/local/bin/`** ставятся **`chuwi-tlp-runner`**, **`chuwi-tlp-notify-root`**, **`chuwi-askpass`** (графический пароль через **zenity** + **`sudo -A`** — **без pkexec и без окна терминала**). Ярлыки — в **`$HOME/.local/share/applications/`**. В **`/etc/tlp.d/`** появляются `97-chuwi-readme.conf`, `98-chuwi-radios.conf`; **`99-chuwi-active-mode.conf`** перезаписывается при запуске `power-mode.sh`.

### Ярлыки без терминала и уведомления

Ярлыки **`tlp-*.desktop`** вызывают **`/usr/local/bin/chuwi-tlp-runner`**: окно **zenity** запрашивает пароль, **`sudo -A`** запускает сценарий от root, затем **`notify-send`** (пакеты **`zenity`**, **`libnotify-bin`** ставит **`install.sh`**); запасной вариант — **`gdbus`**.

**Если уведомлений не видно:** «Не беспокоить», настройки уведомлений; тест: `notify-send -a TLP test "сообщение"`.

**Снимите с дока старые значки TLP** и закрепите заново из меню после обновления.

Ручной запуск: **`sudo "$HOME/power-mode.sh" …`**.

---

## Установка

1. Клонировать репозиторий (или скопировать каталог):

   ```bash
   git clone https://github.com/AntyanMS/Performance_Mode.git "$HOME/chuwi"
   cd "$HOME/chuwi"
   ```

2. Сделать установщик исполняемым и запустить **из сессии того пользователя**, для которого настраивается TLP (ярлыки и **`$HOME/power-mode.sh`** попадут в его домашний каталог):

   ```bash
   chmod +x install.sh
   ./install.sh
   ```

   Установщик сам запросит `sudo`. Целевой пользователь по умолчанию берётся из **`SUDO_USER`**, а если его нет — из **`USER`** (при обычном `./install.sh` это текущий пользователь).

3. Явно задать пользователя, если скрипт не должен брать текущий логин (удобно из **сессии root**, где **`USER=root`**):

   ```bash
   sudo TARGET_USER="имя_пользователя" ./install.sh
   ```

   Если вы обычный пользователь и запускаете `./install.sh` сами, шаг 3 не нужен — достаточно п. 2.

4. После установки применить комфортный режим (все логические CPU, яркость 100 %):

   ```bash
   sudo "$HOME/power-mode.sh" performance
   ```

Зависимости ставятся через **apt**: пакеты **`tlp`** и **`tlp-rdw`** (рекомендуется для переключателей радиомодулей).

---

## Профили режимов (кратко)

| Режим | Команда | Идея |
|--------|---------|------|
| **eco** | `sudo "$HOME/power-mode.sh" eco` | Минимум энергии: низкий потолок P-state, без turbo, **только 2** логических CPU, яркость **~1 %**, агрессивный PCIe ASPM; Wi‑Fi/BT **включены** |
| **balanced** | `sudo "$HOME/power-mode.sh" balanced` | **Половина** потоков, потолок **~36 % / 32 %** (AC / батарея), яркость **30 %** |
| **performance** | `sudo "$HOME/power-mode.sh" performance` | Все потоки, governor **performance**, EPP **performance**, яркость **100 %** |
| **reset** | `sudo "$HOME/power-mode.sh" reset` | Повторно `tlp start` для текущего `99-chuwi-active-mode.conf` |

Тонкая настройка — правка **`config/power-mode.sh`** в репозитории с последующим повторным **`./install.sh`** или ручным копированием в **`$HOME/power-mode.sh`**.

---

## Проверка после установки

```bash
systemctl status power-profiles-daemon   # должен быть inactive / masked
systemctl status tlp
sudo tlp-stat -s
sudo tlp-stat -p
```

---

## Ограничения и замечания

- Нужны права **sudo** для TLP, sysfs (**brightness**, **CPU online**), записи в `/etc/tlp.d/`.
- Отключение логических процессоров (**eco** / **balanced**) использует **CPU hotplug**; **cpu0** на x86 обычно нельзя выключить.
- **Вентилятор** без `platform_profile` управляется прошивкой; «максимум кулера» из ОС недоступен так же, как на ThinkPad с `thinkfan`.
- Параметры **Wi‑Fi power save** в режиме performance (`WIFI_PWR=off`) означают отключение *энергосбережения чипа*, а не отключение адаптера.

---

## Лицензия и отказ от ответственности

Конфигурации предоставляются «как есть». Вы меняете режимы питания и отключаете компоненты GNOME на свой риск. Перед массовым развёртыванием проверяйте систему на тестовой установке Ubuntu 24.04.

Текст лицензии см. файл **LICENSE** (GPL-3.0, как в репозитории на GitHub).
