# Матрица точек сборки GLV Log

Проверено 2026-10-28 на этой машине (`bash .pi/skills/pascal-build-probe/scripts/build.sh all`, см. журнал
`doc/skills_plan_ru.md`). Все пути — от корня репозитория.

## 1. Точки сборки

| Точка | Файл проекта | Юниты | Требует | Куда пишет |
|---|---|---|---|---|
| lib v2 contract | `lib/pkg/lz/glv_log_contract.lpk` | `GLV.Log`, `GLV.Log.Engine`, `GLV.Log.Lvl` | FCL | `lib/out/$(TargetCPU)-$(TargetOS)/$(BuildMode)` |
| lib v2 engines | `lib/pkg/lz/glv_log_def_engine.lpk` | `GLV.Log.ConsoleEngine`, `GLV.Log.SyncFileEngine` | FCL + `glv_log_contract` | там же |
| lib v1 (CodeTyphon) | `lib/pkg/ct/glv_log_def_engine.ctpkg` | 8 юнитов `GlvLog*` (без `GlvLogConsole`, `GlvLogContract`, `GlvLogEngine`) | `adFCL` | `lib/out/<cpu>-<os>/…` |
| тесты unit | `test/pkg/lz/Test.lpi` | `Test.lpr`, `LogTestUnit`, `TestEnv`, `TestFileUtils`, `TestReport` | `glv_log_def_engine`, `glv_log_contract`, `GlvTestCross` | `test/out/<cpu>-<os>/{debug,release}` |
| тесты int | `test/pkg/lz/TestInt.lpi` | `TestInt.lpr`, `LogTestInt`, `TestEnv`, `TestFileUtils`, `TestReport` | `glv_log_def_engine`, `GlvTestCross` | `test/out/<cpu>-<os>/{debug,release}` |
| демо Lazarus (V2 engine) | `demos/simple/pkg/lz/Demo.lpi` | `Demo.lpr` | `glv_log_def_engine`, `glv_log_contract` | `demos/simple/out/<cpu>-<os>/$BuildMode` |
| демо Lazarus (Builder) | `demos/builder/pkg/lz/BuilderDemo.lpi` | `BuilderDemo.lpr`, `BuilderDemoApp` | `glv_log_def_engine`, `glv_log_contract` | `demos/builder/out/<cpu>-<os>/$BuildMode` |
| демо CodeTyphon | `demos/simple/pkg/ct/Demo.ctpr` | `Demo.lpr` | CodeTyphon IDE | — (не проверялось) |
| демо Delphi | `demos/simple/pkg/delphi/Demo.dproj` | `DemoApp` + `Demo.dpr` | Delphi + `demo.inc` (отсутствует) | — (не проверялось) |

Наблюдения, важные при чтении логов:

- `glv_log_def_engine` компилирует `GLV.Log.SyncFileEngine.pas`, а тот в
  `implementation` использует `GlvLog` → при сборке v2-пакета в лог попадают
  компиляции всех v1-юнитов. Это не ошибка пакета.
- Пакеты Lazarus собираются в режим `default` (`lib/out/<cpu>-<os>/default`),
  даже если проект тестов собран в `debug`. Разные каталоги — норма.
- `Test.lpi`/`TestInt.lpi` дополнительно берут `..\..\src` в `OtherUnitFiles`,
  поэтому один и тот же тест-юнит может компилироваться и из пакета, и из
  исходников. Дубликаты не «исправлять» здесь — это задача `pascal-package-sync`.
- В `demos/simple` отсутствует `demo.inc`; `DemoApp.pas` не входит в
  `Demo.lpi` (в `.dproj` входит). Демо через Lazarus собирается, через
  Delphi — нет. `demos/builder` не использует `demo.inc` и собирает
  `BuilderDemoApp.pas` в составе `BuilderDemo.lpi`.

## 2. Команды

```bash
# Тулчейн (ничего не собирает)
bash .pi/skills/pascal-build-probe/scripts/probe.sh

# Одна цель / все цели (lazbuild с фолбэком на fpc)
bash .pi/skills/pascal-build-probe/scripts/build.sh tests
bash .pi/skills/pascal-build-probe/scripts/build.sh demo-builder
bash .pi/skills/pascal-build-probe/scripts/build.sh all

# Другой режим и принудительный фолбэк
BUILD_MODE=Release bash .pi/skills/pascal-build-probe/scripts/build.sh tests
LAZBUILD=off       bash .pi/skills/pascal-build-probe/scripts/build.sh all

# Вручную, без скилла
"$LAZARUSDIR/lazbuild.exe" --build-mode=Debug test/pkg/lz/Test.lpi
"$LAZARUSDIR/lazbuild.exe" lib/pkg/lz/glv_log_contract.lpk
```

`lazbuild --build-mode=` применим к `.lpi` (режимы `Debug`/`Release` есть в
проектах); к `.lpk` режим не передаётся. `.ctpkg` через `lazbuild` не
собирается вообще — только IDE CodeTyphon; `build.sh lib-v1-ct` проверяет
компилируемость фасада `GlvLog.pas` напрямую через FPC.

## 3. Где что лежит и почему имена разные

- `lib/out/<cpu>-<os>/` — пакеты: `default/`, `Debug/`, `Release/`.
- `test/out/<cpu>-<os>/` — проекты: `debug/`, `release/` (строчные, заданы
  явно в `.lpi`).
- `demos/simple/out/<cpu>-<os>/` и `demos/builder/out/<cpu>-<os>/` —
  `Debug/` (через `$(BuildMode)`).
- `out/probe/` — логи и временные юниты скилла; в git не входит.

Каталоги `BuildMode` не унифицированы. Не «приводить к одному виду» без
отдельного решения: это ломает пути в `.lpi`.

## 4. Ловушки окружения (эта машина)

| Ловушка | Как выглядит | Что делать |
|---|---|---|
| Компилятор не в `PATH` | `which fpc` пуст, но `C:/dev/tools/lazarus/fpc/3.2.2/bin/i386-win32/fpc.exe` есть | `probe.sh` ищет по типовым корням, не полагаться на `PATH` |
| Два FPC | 3.2.2 (i386) и 3.3.1 (x64); разные `fpc.cfg`, несовместимые `.ppu` | не смешивать каталоги вывода; `build.sh` печатает выбранный компилятор |
| `PP` мёртв | `PP=…/3.2.2/bin/x86_64-win64/ppcx64.exe` — файла нет | `probe.sh` печатает `ENV|PP|stale`; не использовать `$PP` как истину |
| `LAZARUSDIR` ≠ установка FPC | lazbuild из `fpcdelux`, i386-FPC из `lazarus` | `WARN|mixed-toolchain`; для `.lpi` доверять lazbuild, для прямого FPC — явному пути |
| FPC и git-bash пути | `-FuC:/dev/...` даёт `C:C:\Program Files\Git\dev\...` | передавать `cygpath -w` (`C:\dev\...`); в `build.sh` это делает `wpath` |
| `-FU` без `-FE` | `.exe` падает рядом с `.lpr` | `build.sh` задаёт `-FE out/probe/bin-<target>` |
| Тест-проект без пакетов | lazbuild не находит `GlvTestCross` | пакет `glvtestcross.lpk` должен быть установлен в Lazarus; `probe.sh` проверяет `.lpk` и собранные `.ppu` |
| Delphi | `dcc32`/`dcc64` отсутствуют, `demo.inc` отсутствует | ветка Delphi **не проверена**; не выдавать её за рабочую |

## 5. Формат вывода и трактовка

- `TOOL|…|ok` — файл существует, запускается и вернул версию.
- `ENV|PP|stale` — переменная задана, но указывает в никуда; это не «тулчейна
  нет», а конкретная поломка окружения.
- `RESULT|<target>|ok` — процесс компилятора завершился с кодом 0. В логе
  должны быть `lines compiled`/`Linking`; если лог пуст — это `fail`.
- `RESULT|…|skipped` — не проверяли (нет инструмента/цель недоступна).
  **Никогда** не пересказывать `skipped` как «собралось».
- `SUMMARY|…` — счётчики; код выхода `build.sh`: `0` все ok, `1` есть fail,
  `2` всё skipped, `64` ошибка аргументов.
