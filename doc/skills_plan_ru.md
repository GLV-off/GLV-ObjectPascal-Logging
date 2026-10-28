# План работ: скиллы `.pi/skills` — 5 штук, по сессиям

Статус: S1–S5 выполнены.
Область записи: только `.pi/skills/**` (создаём) и `doc/` (этот файл, журнал).
`lib/`, `test/`, `demos/` в этих сессиях **не трогаем** — если сессия захочет
правку кода, это отдельная задача с отдельным тестом.

Уже существуют и **не переписываются**: `code-recon` (рекон + ревью находок),
`design-brainstorm` (варианты дизайна). Новые скиллы покрывают то, чего в них
нет: процедуру изменений, тулчейн, артефакты сборки/доки и работу с бэклогом.

---

## 0. Как пользоваться планом

### Протокол сессии

1. Прочитать: `AGENTS.md`, `CONTRIBUTING.md`, `README.md`, затем
   `.pi/skills/code-recon/SKILL.md` и `.pi/skills/design-brainstorm/SKILL.md`
   (чтобы не дублировать) и раздел нужного скилла ниже.
2. Прочитать «Снимок фактов» (раздел 1) — он заменяет разведку с нуля.
   Факты старше 2-3 недель или после смены окружения перепроверить командами
   из колонки «Как проверено».
3. Сделать один скилл по разделу сессии. Не начинать следующий, пока
   текущий не проходит DoD (раздел 0.3).
4. В конце: обновить таблицу статусов (раздел 2), дописать строку в журнал
   (раздел 10), проверить `git status --porcelain`.

Одна сессия = один скилл. Если сессия кончается раньше — фиксировать
частичное состояние в журнале, а не «дорисовывать» в спешке.

### 0.1. Общие правила новых скиллов

- Формат — как у существующих: каталог `.pi/skills/<name>/` с `SKILL.md`,
  `references/*.md`, `scripts/*.sh`. Имя каталога = `name` в frontmatter
  (lowercase, дефисы), `description` ≤ 1024 символов, содержит и «что делает»,
  и «когда применять».
- Язык `SKILL.md` и `references` — русский (как у существующих скиллов),
  служебные поля и команды — как есть.
- Объём: `SKILL.md` ≈ 100–150 строк, каждый reference ≈ 80–120 строк,
  скрипт ≈ 100–200 строк. Если не влезает — это два скилла, а не один.
- Скрипты: `bash`, POSIX-совместимо настолько, насколько позволяет Windows
  git-bash. **Нельзя** опираться на `jq` и `xmllint` — их в системе нет;
  есть `rg`, `grep`, `awk`, `sed`, `python`. Предпочтение: `rg` c фолбэком
  на `grep` (см. `code-recon/scripts/recon.sh`).
- Скрипты печатают машинночитаемые строки (`TOOL|…`, `RESULT|…`, `DEP|…`),
  чтобы результат можно было сравнивать между сессиями, и всегда
  возвращают осмысленный код выхода.
- Никаких новых зависимостей, установок, скачиваний и правок внешних
  репозиториев (включая `../pas_TestingWrapper` — только чтение).
- Каждый скилл содержит раздел «Не дублировать»: что уже делают `code-recon`
  и `design-brainstorm`, и что делать не нужно.
- Файлы скиллов — LF (как существующие), файлы в `doc/` — CRLF (как `doc/units.md`).
- Скилл не «улучшает» проект: находки он **описывает**, правки — только по
  отдельному явному запросу пользователя.

### 0.2. Анти-список (не делать в этих сессиях)

- скиллы «SOLID-ревью», «code-review», «найди баги» — есть;
- генераторы кода логгеров без тестов/пакетов/доков;
- любые предложения зависимостей, DI, фабрик, плагинов — прямое нарушение
  `CONTRIBUTING.md` («simple and lightweight»);
- «зелёная» сборка без запуска компилятора;
- правка автоген-юнитов `lib/pkg/lz/*.pas`, `lib/pkg/ct/*.pas` руками;
- удаление `backup/`, `out/`, `*.lps` «для чистоты» в рамках этих сессий.

### 0.3. DoD скилла (проверяется в конце каждой сессии)

- [ ] `SKILL.md` с валидным frontmatter (`name` = имя каталога, `description`
      с «что/когда»), жёсткие правила, фазы/шаги, раздел «Не дублировать».
- [ ] Все скрипты запущены на этом репозитории; фактический вывод записан
      в журнал (раздел 10). Не запускался — так и написано.
- [ ] Ни один скрипт не требует `jq`/`xmllint`, не лезет в сеть, не пишет
      вне временного каталога.
- [ ] `git status --porcelain` содержит только новые файлы скилла (и этот план).
- [ ] Скилл отвечает на вопрос «что делать», а не только «что не так».
- [ ] Обновлены: таблица статусов (раздел 2), журнал (раздел 10).

---

## 1. Снимок фактов (проверено в этой сессии)

Всё ниже — проверено командами, вывод которых приводится. Это база для всех
сессий; перепроверять только при сомнении.

| # | Факт | Как проверено | Зачем важно |
|---|---|---|---|
| F1 | Компилятор **есть**, но не в `PATH`: `C:\dev\tools\lazarus\fpc\3.2.2\bin\i386-win32\fpc.exe` (версия 3.2.2, работает) | `ls`, `ppc386.exe -iV` → `3.2.2` | AGENTS.md утверждает «FPC в PATH отсутствует», из-за чего агенты не пытаются собирать |
| F2 | Второй тулчейн: `C:\dev\tools\fpcdelux\fpc\bin\x86_64-win64\fpc.exe` + `ppcx64.exe` | `find /c/dev/tools -maxdepth 6 -iname ppcx64.exe` | Объясняет `out/x86_64-win64`; два FPC = два `fpc.cfg` и несовместимые `.ppu` |
| F3 | `LAZARUSDIR=C:\dev\tools\fpcdelux\lazarus`, там есть `lazbuild.exe` | `env`, `ls` | Сборка через `.lpi`/`.lpk` возможна |
| F4 | `PP=C:\dev\tools\lazarus\fpc\3.2.2\bin\x86_64-win64\ppcx64.exe` — **файла нет** (мёртвая переменная) | `env` + `ls` пути | Типовая ловушка: сборка «падает» из-за устаревшей переменной |
| F5 | Зависимость тестов на месте: `../pas_TestingWrapper/Pkg/LZ/glvtestcross.lpk`, собранные `.ppu` в `Out/i386-win32/Debug/` | `ls` | `test-cross` может ссылаться на реальный API, а не на догадки |
| F6 | Следы сборки: `demos/simple/out/x86_64-win64/Debug/Demo.exe` (28.10), `lib/out/{i386-win32,x86_64-win64}`, `test/out/{i386-win32,x86_64-win64}` | `ls -la` | На машине уже что-то собирали — «не проверено» не должно быть дефолтом |
| F7 | Пакеты **асимметричны**: Lazarus-пакеты = только v2 (`glv_log_contract`: 3 юнита, `glv_log_def_engine`: 2 юнита); CodeTyphon `.ctpkg` = только v1 (8 юнитов) | `grep` по `.lpk`/`.ctpkg` | v1 не собирается через Lazarus-пакет, v2 — через CodeTyphon |
| F8 | В `lib/src` 16 `.pas`; вне всех пакетов: `GlvLogConsole.pas`, `GlvLogContract.pas`, `GlvLogEngine.pas` | сверка списков | Готовая проверка для `pascal-package-sync` |
| F9 | `Test.lpi` требует **оба** пакета (`glv_log_def_engine` + `glv_log_contract`) + `GlvTestCross`; `TestInt.lpi` — только `glv_log_def_engine` + `GlvTestCross` | `grep PackageName test/pkg/lz/*.lpi` | AGENTS.md описывает иначе (`DOC`) |
| F10 | Оба тест-проекта дополнительно берут юниты из `OtherUnitFiles=..\..\src` | `grep SearchPaths` | Риск двойной компиляции: юнит и из пакета, и из исходников |
| F11 | Тест-юниты: `Test.lpi` → `LogTestUnit/TestEnv/TestFileUtils/TestReport`; `TestInt.lpi` → `LogTestInt/TestEnv/TestFileUtils/TestReport` | `grep src\\.*\.pas` | Карта тестов для `test-cross` |
| F12 | Регистрация тестов: `CrossRegTest(TXxxTest, 'Unit')` в `LogTestUnit.pas:114-116`, `'Int'` — в `LogTestInt.pas:172-173` | `grep -n initialization -A8` | Фиксирует конвенцию харнесса |
| F13 | `LogTestUnit.pas:3` — `{$I 'glv_log_test'}` без `.inc` (в остальных файлах — с `.inc`) | `head` | Портабельность FPC/Delphi, кандидат в finding |
| F14 | `TestReport.pas` — заготовка: `TTestReport = record end;`, включена в оба `.lpi` | `cat` | Мёртвый код, кандидат в бэклог |
| F15 | `git ls-files` = **57** файлов, AGENTS.md говорит «39» | `git ls-files \| wc -l` | Готовый `DOC`-дрифт для `doc-sync-ru` |
| F16 | `doc/units.md` обещает `GLV.Log.AsyncFileEngine`, такого юнита нет (v2 = `Lvl`, `Engine`, `Contract`, `GLV.Log`, `ConsoleEngine`, `SyncFileEngine`) | `ls lib/src` | Расхождение плана v2 с кодом |
| F17 | `demos/simple/src/DemoApp.pas` и `pkg/delphi/Demo.dpr` ссылаются на отсутствующий `demo.inc`; Delphi на машине нет | `find demos`, `where` | Проверить нельзя — только зафиксировать |
| F18 | В рабочем дереве есть игнорируемые артефакты: `test/pkg/lz/TestInt.lps`, `demos/simple/pkg/lz/Demo.lps`, `*/backup/` | `git ls-files`, `.gitignore` | Не считать их находками |

**Проверено в S1 (2026-10-28):** сборка всех целей запускалась, результат —
в журнале (раздел 10). Прогон тестов (не только компиляция) по-прежнему
не выполнялся; Delphi и CodeTyphon недоступны.

---

## 2. Обзор сессий

| # | Скилл | Боль, которую снимает | Зависит от | Оценка | Статус |
|---|---|---|---|---|---|
| S1 | `pascal-build-probe` | «можно ли проверить сборку» — сейчас отвечают угадыванием | — | 1 сессия | [x] |
| S2 | `pascal-package-sync` | пакеты/проекты правятся вслепую, без IDE; юниты выпадают из сборки | S1 (для проверки) | 1 сессия | [x] |
| S3 | `test-cross` | тесты пишутся копированием соседнего файла; харнесс снаружи репо | S1 | 1 сессия | [x] |
| S4 | `doc-sync-ru` | доки расходятся с кодом, агенты верят тексту | S1, S2 | 1 сессия | [x] |
| S5 | `backlog-from-review` | находки `code-recon` теряются, долги не закрываются | S1–S4 | 1 сессия | [x] |

Порядок обязателен: S1 делает остальные проверяемыми, S5 собирает результаты
предыдущих. S2 ⇄ S4 можно менять местами, если приоритет — доки.

---

## S1. `pascal-build-probe`

**Зачем.** Сейчас ответ на «собирается ли» зависит от того, догадался ли агент
посмотреть `env`. F1–F4 показывают: компилятор есть, но `PATH` и `PP` врут.
Скилл должен детектировать тулчейн и либо собрать, либо честно сказать,
чего не хватает (и не выдумывать результат).

**Артефакты**
- `.pi/skills/pascal-build-probe/SKILL.md`
- `scripts/probe.sh` — детект тулчейна, ничего не собирает
- `scripts/build.sh` — сборка выбранных целей через `lazbuild`, фолбэк на `fpc`
- `references/build-matrix.md` — таблица точек сборки + правила установки/путей

**Шаги**
1. Перенести в `SKILL.md` раздел 1 (F1–F6) как «типовые ловушки окружения»:
   две установки FPC, мёртвый `PP`, `LAZARUSDIR` вместо `PATH`, фолбэк на
   `ppc386`, разные `out/<cpu>-<os>/{Debug,debug,release}`.
2. `probe.sh` ищет в таком порядке: `command -v fpc lazbuild`; `$PP`,
   `$FPCDIR`, `$LAZARUSDIR`; типовые корни `C:/dev/tools/{lazarus,fpcdelux}`,
   `C:/lazarus`, `/usr/lib/lazarus`, `/usr/bin/fpc`; Delphi — `dcc32/dcc64`
   в `%ProgramFiles(x86)%\Embarcadero\Studio`.
   Для найденного — `-iV`/`--version`, проверка, что файл существует.
   Отдельно проверяется зависимость тестов: `../pas_TestingWrapper/Pkg/LZ/glvtestcross.lpk`.
3. Формат вывода (стабильный, сравнивается между сессиями):
   ```text
   TOOL|fpc-i386|ok|C:\dev\tools\lazarus\fpc\3.2.2\bin\i386-win32\fpc.exe|3.2.2
   TOOL|fpc-x64|ok|C:\dev\tools\fpcdelux\fpc\bin\x86_64-win64\fpc.exe|<ver>
   TOOL|lazbuild|ok|C:\dev\tools\fpcdelux\lazarus\lazbuild.exe|<ver>
   ENV|PP|stale|C:\dev\tools\lazarus\fpc\3.2.2\bin\x86_64-win64\ppcx64.exe
   DEP|GlvTestCross|ok|../pas_TestingWrapper/Pkg/LZ/glvtestcross.lpk
   TOOL|delphi|absent|
   SUMMARY|fpc=2|lazbuild=1|delphi=0|tests-dep=1
   ```
   Код выхода: `0` — тулчейн полный, `2` — частичный, `3` — нет ничего.
   Скрипт **не падает** на отсутствии тулчейна: отсутствие — это результат.
4. `build.sh <target>`: `lib-v2`, `lib-v1-ct`, `tests`, `tests-int`, `demo`,
   `all`. Через `lazbuild --build-mode=…` при наличии; фолбэк —
   `fpc -Mdelphi -Fu<repo>/lib/src -Fi<repo>/lib/src -Fu<wrapper>/Src -FU<tmp>`.
   Всё пишется в `out/probe/<target>-<timestamp>.log`, последняя строка —
   `RESULT|<target>|ok|fail|skipped|<причина>`. Перед сборкой вызывается
   `probe.sh` и результат печатается рядом — чтобы отчёт не терял контекст.
5. `references/build-matrix.md` — таблица точек сборки (проверить по файлам):

   | Точка | Файл | Юниты | Требует | Выход |
   |---|---|---|---|---|
   | lib v2 contract | `lib/pkg/lz/glv_log_contract.lpk` | `GLV.Log`, `GLV.Log.Engine`, `GLV.Log.Lvl` | FCL | `lib/out/<cpu>-<os>/$(BuildMode)` |
   | lib v2 engines | `lib/pkg/lz/glv_log_def_engine.lpk` | `GLV.Log.ConsoleEngine`, `GLV.Log.SyncFileEngine` | FCL, `glv_log_contract` | там же |
   | lib v1 (CodeTyphon) | `lib/pkg/ct/glv_log_def_engine.ctpkg` | 8 юнитов `GlvLog*` | `adFCL` | там же |
   | тесты (unit) | `test/pkg/lz/Test.lpi` | `LogTestUnit`, `TestEnv`, `TestFileUtils`, `TestReport` | `glv_log_def_engine`, `glv_log_contract`, `GlvTestCross` | `test/out/<cpu>-<os>/{release,debug}` |
   | тесты (int) | `test/pkg/lz/TestInt.lpi` | `LogTestInt`, `TestEnv`, `TestFileUtils`, `TestReport` | `glv_log_def_engine`, `GlvTestCross` | там же |
   | демо (Lazarus) | `demos/simple/pkg/lz/Demo.lpi` | `DemoApp` | пакеты lib | `demos/simple/out/<cpu>-<os>/Debug` |
   | демо (CodeTyphon) | `demos/simple/pkg/ct/Demo.ctpr` | то же | — | — |
   | демо (Delphi) | `demos/simple/pkg/delphi/Demo.dproj` | то же | `demo.inc` (отсутствует) | — |

   Плюс раздел «Как ставить/включать»: `lazbuild --build-mode=Debug <lpi>`,
   почему нельзя полагаться на `PATH`, что делать при двух FPC (явно
   указывать каталог бинарей и `-Fu` от одного из них).
6. Прогнать `probe.sh` и **первую реальную сборку** (`build.sh tests`, если
   тулчейн полный). Результат — в журнал, дословно. Если сборка падает —
   это факт для бэклога, а не повод «поправить код» в этой сессии.

**DoD дополнительно**
- `probe.sh` на этой машине печатает `TOOL|fpc-i386|ok…`, `TOOL|lazbuild|ok…`,
  `ENV|PP|stale…`, `TOOL|delphi|absent`, `SUMMARY|…`, код выхода `0`.
- `build.sh` без аргументов печатает список целей и код `64`; с неизвестной
  целью — ошибку, а не молчаливый `ok`.
- В `SKILL.md` явно: «сборка не запускалась ⇒ писать `не проверено`,
  запрещено выводить `ok` из наличия исходников».

---

## S2. `pascal-package-sync`

**Зачем.** AGENTS.md отправляет добавлять юнит в `.lpk`/`.ctpkg` «через IDE»,
но IDE у агента нет, а формат — XML. Итог виден в F7–F10: пакеты асимметричны,
три юнита не входят ни в один пакет, а оба тест-проекта берут юниты из
исходников параллельно пакетам.

**Артефакты**
- `.pi/skills/pascal-package-sync/SKILL.md`
- `scripts/pkg-inventory.sh` — инвентаризация пакетов и покрытия
- `scripts/pkg-add-unit.sh <pkg> <unit.pas>` — добавить юнит (с `--check`)
- `references/pkg-formats.md` — анатомия `.lpk`, `.ctpkg`, `.lpi`, `.dproj`

**Шаги**
1. `pkg-inventory.sh` (без `xmllint` — `grep`/`awk` по строкам `<Filename Value>`,
   `<UnitName Value>`, `<PackageName Value>`, `<Name Value>`):
   - таблица «пакет → юниты», «юнит → пакеты»;
   - покрытие `lib/src/*.pas` (сейчас ожидаемо: 13/16 покрыты, 3 — нет);
   - асимметрия v1/v2 (Lazarus vs CodeTyphon);
   - десинк автоген-юнита: `uses` в `lib/pkg/lz/glv_log_def_engine.pas`
     против списка `Files` в `.lpk`;
   - потребители, у которых юнит одновременно в пакете и в `OtherUnitFiles`;
   - `RequiredPkgs` (обратить внимание: `FCL` в Lazarus, `adFCL` в CodeTyphon).
2. `pkg-add-unit.sh`: вставляет `<Item><Filename Value="..\..\src\X.pas"/>
   <UnitName Value="X"/></Item>` в `<Files>` с сохранением отступов и CRLF;
   `--check` печатает unified diff и ничего не пишет; отказывается работать,
   если файл начинается с `{ This file was automatically created`;
   не трогает `.pas`-список автогена — по нему печатает предупреждение
   «пересобрать/установить пакет в IDE или добавить вручную».
3. `references/pkg-formats.md`: `Package Version="6"`, `PathDelim="\"`,
   `SearchPaths.{IncludeFiles,OtherUnitFiles,UnitOutputDirectory}`,
   `Files/Item`, `RequiredPkgs/Item`, `UsageOptions/UnitPath`; отличия
   `.ctpkg` (`Type=RunAndDesignTime`, `adFCL`, `dsDwarf3`) и `.lpi`
   (`BuildModes` с `release`/`debug`, `OtherUnitFiles=..\..\src`);
   правило «имя юнита в `UnitName` — с точками, как в `unit`-строке»;
   почему ручная правка допустима (XML стабилен), а автоген — нет.
4. Прогнать `pkg-inventory.sh`, сверить с F7/F8/F10; расхождения — в журнал
   как вход для S5 (не исправлять здесь).

**DoD дополнительно**
- Инвентаризация воспроизводит F7, F8, F10 дословно (13/16, списки пакетов,
  дубли из `OtherUnitFiles`).
- `pkg-add-unit.sh --check` на копии `.lpk` во временном каталоге даёт
  минимальный diff (только вставленный `<Item>`), оригинал не изменён.
- `SKILL.md` содержит ≤ 10 проверок, у каждой — готовая команда.

---

## S3. `test-cross`

**Зачем.** Тесты есть (F11–F13), но конвенция харнесса живёт во внешнем
репозитории и в голове автора. Без скилла новый тест пишется копипастой,
а флаки (тайминги, файловая система) воспроизводятся по наследству.

**Артефакты**
- `.pi/skills/test-cross/SKILL.md`
- `references/harness.md` — API `Glv.Testing.Cross` по факту чтения
  `../pas_TestingWrapper/Src/Glv.Testing.Cross.pas` (+ `TestCase`, `Assertion`)
- `references/contracts-ru.md` — 4 контракта формата строк + ловушка Unicode
- `references/flakiness.md` — почему `Sleep(500)` и ФС делают тесты хрупкими
- `scripts/test-skeleton.sh <Unit|Int> <TName>` — печатает скелет класса и
  строку `CrossRegTest` **в stdout**, файлы не меняет

**Шаги**
1. Прочитать внешний харнесс (только чтение): `TCrossTestCase`, `CrossRegTest`,
   как выбирается `'Unit'`/`'Int'`, какие методы вызываются (`published`,
   `SetUp`/`TearDown`), что делает раннер (`Glv.Testing.App`).
   В `harness.md` — только то, что видно в коде, остальное помечать `[гипотеза]`.
2. Зафиксировать конвенцию этого репозитория: `{$I 'glv_log_test.inc'}` первой
   строкой, `uses Glv.Testing.Cross`, регистрация в `initialization`,
   интеграционные тесты — только `'Int'` и только через `TEnv` (пути от
   `ParamStr(0)`, т.е. файлы ложатся в `out/<cpu>-<os>/<mode>/`), никаких
   абсолютных путей.
3. `contracts-ru.md`: таблица из AGENTS.md (4 формата) + `TLogLvl.AsStr`,
   с указанием, где именно это закреплено (`LogTestInt.pas`,
   `LogTestUnit.pas:TLogLvlTest.TestAsStr`), и ловушка `Format` + `UnicodeString`
   (тест `TestUnicodeText`, константа `#$4E2D#$1F600`).
4. `flakiness.md`: `Sleep(500)` в `TAsyncFileLogTest`, зависимость от ФС и
   антивируса, очистка файлов между прогонами, почему нельзя проверять
   «файл появился» без ожидания с таймаутом; правило «новый async-тест
   обязан иметь таймаут, а не фиксированный Sleep».
5. `test-skeleton.sh`: на входе `Unit|Int` и имя класса, на выходе — блок
   `TXxxTest = class(TCrossTestCase) … published … end;` + строка регистрации
   с комментарием «вставить в implementation/initialization файла …».
   Никакой записи в `test/src` — скелет вставляет человек/агент осознанно.

**DoD дополнительно**
- `harness.md` не содержит ни одного утверждения о харнессе без ссылки на
  файл внешнего репо (путь:строка) или пометки `[гипотеза]`.
- `test-skeleton.sh Unit TFooTest` и `… Int TFooTest` дают разный вывод
  (разный `'Unit'`/`'Int'` и разные целевые файлы).
- В `SKILL.md` явно: тесты без компилятора не «проходят»; прогон — через
  S1 (`build.sh tests` / `tests-int`).

---

## S4. `doc-sync-ru`

**Зачем.** Доки — заявка, а не истина, и в этом репо они уже разошлись
(F9, F15, F16 + утверждение AGENTS.md про отсутствие FPC). Проверять это
руками каждый раз дорого, а верить тексту — единственный способ ошибиться
в проекте, где контракты продублированы в трёх местах.

**Артефакты**
- `.pi/skills/doc-sync-ru/SKILL.md`
- `scripts/doc-facts.sh` — извлечение проверяемых утверждений из доков и сверка
- `references/doc-map.md` — какой документ за какие утверждения отвечает

**Шаги**
1. `doc-map.md`: `AGENTS.md` (контракты, карта репо, сборка, известные
   дефекты) · `README.md` (пользовательские фичи, примеры, форматы) ·
   `doc/v1/*` (карта зависимостей и чек-лист v1) · `doc/v2/*` (замысел v2) ·
   `doc/units.md` (плановая структура) · `CONTRIBUTING.md` (инварианты).
   Для каждого — «что здесь можно проверить машинно».
2. `doc-facts.sh` проверяет:
   - количества («N отслеживаемых файлов», «~1400 строк», «8 модулей») против
     `git ls-files`, `wc -l`, `ls`;
   - все упомянутые пути (`lib/…`, `test/…`, `doc/…`, `demos/…`) существуют;
   - все упомянутые имена юнитов есть в `lib/src` (ловит `AsyncFileEngine`);
   - имена пакетов из `RequiredPkgs` и таблиц совпадают с `.lpi`/`.lpk`;
   - строки форматов из AGENTS.md/README встречаются в тестах;
   - утверждения про окружение (`FPC в PATH отсутствует`) — против `probe.sh`
     из S1 (если скилл S1 есть) или против простого детекта.
   Вывод — `DOC|<файл>:<строка>|<тип>|<утверждение>|<факт>`, код выхода `0`,
   если дрифтов нет, и `2`, если есть.
3. `SKILL.md`: правила «док — заявка», «расхождение — отдельная находка
   класса `DOC` (совместимо с `code-recon`)», «правка кода под текст и правка
   текста под код — два разных решения, по умолчанию только второе и только
   по запросу», RU, обновление доков в том же изменении, что и код.
4. Прогнать `doc-facts.sh`, зафиксировать фактические дрифты в журнале
   (минимум: 39/57, `AsyncFileEngine`, `Test.lpi` requires, FPC в PATH).

**DoD дополнительно**
- Скрипт ловит все четыре известных дрифта и **не** даёт ложных срабатываний
  на `backup/`, `out/`, `*.lps` (они игнорируются git).
- Каждая проверка в скрипте — одна короткая функция с комментарием
  «утверждение → факт».
- В `SKILL.md` нет советов «привести код в соответствие с докой» без
  отдельного решения.

---

## S5. `backlog-from-review`

**Зачем.** `code-recon` выдаёт отчёт с severity, но отчёт живёт один сеанс.
Долги из AGENTS.md («известные дефекты») и находки ревью не превращаются
в проверяемый список, поэтому одни и те же проблемы находятся заново.

**Артефакты**
- `.pi/skills/backlog-from-review/SKILL.md`
- `scripts/findings-to-backlog.sh <report.md>` — markdown-отчёт → строки бэклога
- `references/item-template.md` — шаблон пункта и правила статусов
- сам бэклог: `doc/backlog_ru.md` (создаётся в этой сессии, наполняется seed-ом)

**Шаги**
1. `item-template.md`: поля `ID` (`BL-001`…), заголовок, класс
   (`BLOCKER/BUG/RISK/SMELL/DOC` — как в `code-recon`), доказательство
   `путь:строка`, последствие, минимальная правка, тест, который закрепит
   поведение, размер (`S/M/L`), риск правки (API/второй компилятор/доки),
   зависимости, статус (`new/in-progress/done/wontfix` + причина).
   Правила: один пункт = одно осмысленное изменение + один тест; `wontfix`
   без причины запрещён; закрытие — только по тесту или по явному решению.
2. `findings-to-backlog.sh`: читает markdown, ищет блоки находок по меткам
   severity и `путь:строка`, печатает готовые строки таблицы; дедуплицирует
   по `путь:строка`; при совпадении с `doc/backlog_ru.md` — помечает
   `dup` и не создаёт новый ID; ничего не дописывает в бэклог без `--write`.
3. Наполнить `doc/backlog_ru.md` seed-ом (минимум 8 пунктов):
   - известные дефекты из AGENTS.md: спин `TAsyncLogThread`, `WriteLines`
     без усечения и BOM, `WriteBom`, потеря `FQueue` при `Destroy`,
     перезапись файла целиком в `TPrimitiveFileLog`;
   - F8 (3 юнита вне пакетов), F9 (`Test.lpi` requires ≠ доки),
     F13 (`{$I}` без `.inc`), F14 (`TestReport`), F15 (39/57),
     F16 (`AsyncFileEngine`), F17 (`demo.inc`) — из сессий S2/S4;
   - любые падения первой реальной сборки из S1 — как `BLOCKER`/`BUG`
     с дословным логом.
4. Приоритизация: 3–5 пунктов в «next», остальное — в «later»; в «next»
   не больше одного пункта, который ломает публичный API.

**DoD дополнительно**
- `findings-to-backlog.sh` на тестовом фрагменте (2 находки, одна из них
  дубль существующей) даёт 1 новый ID и 1 `dup`.
- `doc/backlog_ru.md` содержит ≥ 8 пунктов, у каждого — `путь:строка` и
  критерий приёмки; ни один пункт не является «улучшить всё».
- `SKILL.md` не подменяет `code-recon`: ревью не проводится, только
  преобразование уже найденного.

---

## 9. Риски и ограничения

| Риск | Как снижаем |
|---|---|
| Скилл превращается в дубль `code-recon` | обязательный раздел «Не дублировать» + DoD-проверка |
| Скрипты не работают на Windows/git-bash | все скрипты гоняются на этой машине в сессии; запрет `jq`/`xmllint` |
| Два FPC дают разные `.ppu` и «странные» ошибки | `build.sh` всегда печатает, каким компилятором собирал, и не смешивает каталоги вывода |
| Сессия «заодно» правит код библиотеки | область записи зафиксирована в шапке плана; правки кода — отдельная задача |
| Отчёт сессии выдумывает «собралось» | DoD: только дословный вывод, «не проверено» — валидный результат |
| План устаревает | раздел 1 перепроверяется командами при старте сессии; журнал фиксирует дату |

## 10. Журнал сессий

| Дата | Сессия | Что сделано | Скрипты запускались (факт) | Осталось |
|---|---|---|---|---|
| 2026-10-28 | S1 `pascal-build-probe` | SKILL.md; probe.sh (161 стр.); build.sh (180 стр.); references/build-matrix.md; детект тулчейна и сборка всех целей | `probe.sh` → `TOOL\|fpc-i386\|ok`, `TOOL\|lazbuild\|ok`, `ENV\|PP\|stale`, `TOOL\|delphi\|absent`, `SUMMARY\|fpc=2\|lazbuild=1\|delphi=0\|tests-dep=1`, exit 0. `build.sh all` (lazbuild) → `ok=5\|fail=0\|skipped=0`, exit 0. `LAZBUILD=off build.sh all` (fpc-фолбэк) → `ok=5`, exit 0. Без аргументов и неизвестная цель → exit 64 | S2–S5; прогон тестов (не только сборка); Delphi/CodeTyphon не проверены |
| 2026-10-28 | S2 `pascal-package-sync` | SKILL.md (152); references/pkg-formats.md (128); pkg-inventory.sh (162); pkg-add-unit.sh (98); инвентаризация, --check, отказы | `pkg-inventory.sh` → `PKG` ×3 (units=8/3/2), `COVER\|src=16\|covered=13\|uncovered=3\|missing=GlvLogConsole,GlvLogContract,GlvLogEngine`, `ASYM\|v1=8\|v2=5\|both=no`, `AUTOGEN` ×3 ok, `DUP` 8 (`search=..\..\src`), `OVL\|none`, `SUMMARY\|packages=3\|units=13\|src=16\|covered=13\|uncovered=3\|dups=8\|ovl=0\|autogen_desync=0\|projects=3`. `pkg-add-unit.sh --check` на temp-копии → diff +4 строки, md5 оригинала не изменился, exit 0; apply → CRLF сохранён; повтор `GLV.Log` → exit 3; автоген-файл → exit 2 | S3–S5; в S5: 3 юнита вне пакетов; F10 уточнён: 8 DUP — тест-юниты в `<Units>` и `OtherUnitFiles=test/src`, а не `lib/src` |
| 2026-10-28 | S3 `test-cross` | SKILL.md (152); harness.md (111); contracts-ru.md (90); flakiness.md (119); test-skeleton.sh (105); run-tests.sh (147), дополнительно для фактического прогона | `test-skeleton.sh Unit TFooTest` и `Int TFooTest` → exit 0, вывод различается (LogTestUnit/`'Unit'` против LogTestInt/`'Int'`/TEnv); неверный режим → exit 2, без аргументов → exit 64. `run-tests.sh Unit --no-build` → `TEST\|unit\|run=4\|errors=0\|failures=0\|exit=0`, `RESULT\|test-unit\|pass`, exit 0. `run-tests.sh all` → unit pass (4), int `run=3\|errors=0\|failures=1\|exit=1`, `TestPrimitiveFileLogUnicode` (детерминированный fail), exit 1. `FPC=/nonexistent LAZBUILD=off run-tests.sh Unit` → `skipped\|build-not-ok`, exit 2. `bash -n` оба скрипта — ok | S4–S5; в S5: Unicode-файл, `AsStr`/UNKNOWN без else, отсутствие теста `TConsole`, `Sleep(500)`, устаревший i386-exe. `run-tests.sh` добавлен к артефактам плана, чтобы прогон через S1 был проверяемым |
| 2026-10-28 | S4 `doc-sync-ru` | SKILL.md (149); references/doc-map.md (86); scripts/doc-facts.sh (189); 10 проверок; 4 известных дрифта + 7 дополнительных | `bash .pi/skills/doc-sync-ru/scripts/doc-facts.sh .` → `SUMMARY\|checks=10\|drifts=11`, exit 2: `AGENTS.md:54` 39→76, `AGENTS.md:53` нет `*.o`, path ×5 (`doc/v1`), `doc/units.md:11` AsyncFileEngine, `AGENTS.md:83` UNKNOWN, `AGENTS.md:48` Test.lpi, `AGENTS.md:40` fpc=2 вне PATH. `--help` exit 0; bad root/args exit 64; `bash -n` ok; path-выхлоп без out/backup/lps | S5; правки lib/src и test/src — параллельная сессия, не наши; S4 только читает; 4 известных дрифта пойманы |
| 2026-10-28 | S5 `backlog-from-review` | SKILL.md (150); references/item-template.md (99); scripts/findings-to-backlog.sh (197); doc/backlog_ru.md (57 строк, 16 пунктов, next=5) | `findings-to-backlog.sh /tmp/findings.md` → `\| BL-001 \| BUG \| ... \| dup \|`, `\| BL-017 \| BUG \| ... \| new \|`, `RESULT\|new=1\|dup=1`, exit 0. `--write` в копию → `WROTE\|...\|new=1`, оригинал не изменён; без `--write` файл не писан; no args/badopt=64, missing=66, `--write` без маркера=3, `--help`=0; `bash -n` ok; 16/16 evidence `путь:строка` валидны, next=5, `API: breaking`=0, дублей=0; F8 закрыт (`covered=17\|uncovered=0`); текущий `doc-facts`=6 (снимок S4=11 исторический) | S5 закрывает план; правок `lib/`, `test/`, `demos/` нет; в дереве остаются чужие параллельные изменения |
