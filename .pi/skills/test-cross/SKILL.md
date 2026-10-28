---
name: test-cross
description: Кросс-тесты GLV Log на FPC/Lazarus через внешний Glv.Testing — выбор Unit/Int, скелет TCrossTestCase и CrossRegTest, прогон через build.sh S1 с таймаутом и разбором Number of run tests/errors/failures, контракты форматов и Unicode, защита от Sleep-флаков и устаревшего .exe. Использовать при добавлении/правке теста в test/src, проверке «проходят ли тесты», разборе падений Test/TestInt и переносе теста между Unit и Int.
---

# Кросс-тесты: Unit / Int

Тесты живут в `test/src`, харнесс — во внешнем
`../pas_TestingWrapper` (только чтение, не править). Скилл фиксирует
конвенцию и даёт воспроизводимый прогон: **сборка → запуск → счётчики →
честный статус**. Он не «чинит» библиотеку под зелёный тест.

## Жёсткие правила

1. **Сначала харнесс, потом тест.** API брать из
   `references/harness.md` (там путь:строка), а не из догадок.
2. **Unit ≠ Int.** `Unit` — чистые функции/память, `Int` — файлы, потоки,
   кодировки. Int-тесты используют `TEnv`, а не абсолютные пути.
3. **Первая строка юнита — include.** `{$I 'glv_log_test.inc'}` сразу после
   `unit ...;` (в существующем `LogTestUnit.pas` — без `.inc`, но новый юнит
   оформляйте с `.inc`).
4. **Регистрация — в `initialization`.** `CrossRegTest(TMyTest, 'Unit')`
   или `'Int'`; метод должен быть `published` и без параметров.
5. **`SetUp`/`TearDown` — на каждый тест.** Не хранить состояние между
   методами; файлы чистить в `finally`/`TearDown`.
6. **Нет компилятора — нет «прошло».** Сборка тестов — только через S1
   (`build.sh tests` / `tests-int`); `skipped` или отсутствие `.exe` — это
   «не проверено», а не pass.
7. **Устаревший `.exe` — не доказательство.** Перед прогоном собрать;
   `run-tests.sh` отказывается запускать бинарник старше исходников.
8. **Async ждёт условие с таймаутом.** Фиксированный `Sleep(500)` —
   известный флак; новый тест обязан иметь дедлайн, а не «подождать».
9. **Не судить по консоли.** `???` в выводе не доказывает порчу файла;
   сравнивайте `UnicodeString`/`Ord`/байты и счётчики раннера.

## Шаг 1 — что именно запускается

Прочитайте `references/harness.md` (TCrossTestCase, `CrossRegTest`,
`SetUp/TearDown`, `TFPUnitTestApp`, `ReadLn`) и
`references/contracts-ru.md` (4 формата + Unicode) перед правкой теста.
Ключевое: `TCrossTestCase = TTestCase`, `Assert = TAssertWrapper`
(`../pas_TestingWrapper/Src/Glv.Testing.Cross.pas:40-56`), а `Run` выбирает
FPUnit-раннер при `-dFPUNIT` (пакет `glvtestcross.lpk:28-30`).

## Шаг 2 — выбрать режим

| Что тестируете | Режим | Файл | `CrossRegTest` | Пакет/проект |
|---|---|---|---|---|
| логика, callback, `AsStr` | `Unit` | `test/src/LogTestUnit.pas` | `'Unit'` | `test/pkg/lz/Test.lpi` |
| файл, поток, UTF-8, тайминги | `Int` | `test/src/LogTestInt.pas` | `'Int'` | `test/pkg/lz/TestInt.lpi` |

Сомневаетесь — начинайте с `Unit`: он быстрее и не зависит от ФС. Если
нужен новый файл-юнит, после создания добавьте его в `<Units>` нужного
`.lpi` (см. скилл S2 `pascal-package-sync`).

## Шаг 3 — скелет (в stdout, без записи)

```bash
bash .pi/skills/test-cross/scripts/test-skeleton.sh Unit TMyTest
bash .pi/skills/test-cross/scripts/test-skeleton.sh Int TMyTest
```

Вывод — блок `TMyTest = class(TCrossTestCase)` + `initialization` с
`CrossRegTest`. Разница: `Unit` → `test/src/LogTestUnit.pas`/`'Unit'`;
`Int` → `test/src/LogTestInt.pas`/`'Int'`, поле `FFilepath`, `TEnv.TestFile`
и удаление файла в `TearDown`. Скрипт ничего не пишет на диск; вставьте
блок в целевой файл осознанно.

## Шаг 4 — прогон

Основной путь (собирает через S1 и запускает свежий `.exe`):

```bash
bash .pi/skills/test-cross/scripts/run-tests.sh Unit
bash .pi/skills/test-cross/scripts/run-tests.sh Int
bash .pi/skills/test-cross/scripts/run-tests.sh all
```

Полезные флаги: `--no-build` (только запуск), `--allow-stale` (разрешить
старый `.exe`), `TEST_TIMEOUT=60`. Явная сборка + запуск:

```bash
bash .pi/skills/pascal-build-probe/scripts/build.sh tests tests-int
bash .pi/skills/test-cross/scripts/run-tests.sh Unit --no-build
```

`run-tests.sh` печатает `BUILD|...`, затем
`TEST|unit|run=N|errors=N|failures=N|exit=N|exe=...|log=...`,
`RESULT|test-unit|pass|fail|skipped|...`, `SUMMARY|...`. Лог — в
`out/probe/test-<label>-<stamp>.log`; он и есть доказательство.

## Шаг 5 — как читать результат

| Строка | Значит |
|---|---|
| `RESULT|test-unit|pass|run=4` | запущено 4, errors=0, failures=0, exit=0 |
| `fail|...failures=1...` | тест упал; смотреть `Failed:` и лог |
| `skipped|build-not-ok` | S1 не собрал: нет компилятора/пакета — **не pass** |
| `skipped|stale-exe` | `.exe` старше исходников: пересобрать |
| `skipped|no-exe` | бинарника нет: сборка не выполнялась/не удалась |
| `fail|timeout=...` | раннер завис (часто `ReadLn` без stdin) |
| `fail|no-summary` | раннер упал до итогов: смотреть хвост лога |
| `fail|no-tests-run` | 0 тестов: забыт `CrossRegTest`/`published` |

Текущий снимок (2026-10-28, x86_64 Debug): `Unit` — 4 теста, pass;
`Int` — 3 теста, 1 failure: `TestPrimitiveFileLogUnicode` (см.
`contracts-ru.md`). Это не «всё зелёное»; не пересказывайте иначе.

## Шаг 6 — если тест флакует

Прочитайте `references/flakiness.md`. Коротко: файл — уникальное имя через
`TEnv`, удаление до и после, `FileExists` до чтения, async — цикл ожидания
до дедлайна, не `Sleep`; не запускать `Test`/`TestInt` параллельно; не
перезапускать детерминированный fail «до зелёного».

## Шаг 7 — отчёт

Укажите: режим, файл/класс, команду сборки и прогона, строки
`TEST|...`/`RESULT|...`, путь к логу, число тестов. Если сборка не
запускалась — пишите «не проверено» и чего не хватает (FPC/lazbuild/
`GlvTestCross`/пакеты). Delphi/DUnitX-ветка в этом репо не проверена.

## 10 проверок (каждая — готовая команда)

1. **Unit-скелет:** `bash .pi/skills/test-cross/scripts/test-skeleton.sh Unit TFooTest` — exit 0, в выводе `test/src/LogTestUnit.pas` и `CrossRegTest(TFooTest, 'Unit')`.
2. **Int-скелет:** `bash .pi/skills/test-cross/scripts/test-skeleton.sh Int TFooTest` — exit 0, в выводе `test/src/LogTestInt.pas`, `TEnv.TestFile` и `'Int'`; вывод отличается от Unit.
3. **Отказы скелета:** `bash .pi/skills/test-cross/scripts/test-skeleton.sh Foo TFooTest` → exit 2; `bash .pi/skills/test-cross/scripts/test-skeleton.sh` → exit 64.
4. **Синтаксис скриптов:** `bash -n .pi/skills/test-cross/scripts/*.sh` — без ошибок.
5. **Сборка тестов через S1:** `bash .pi/skills/pascal-build-probe/scripts/build.sh tests tests-int` — `RESULT|tests|ok` и `RESULT|tests-int|ok`, exit 0.
6. **Unit-прогон:** `bash .pi/skills/test-cross/scripts/run-tests.sh Unit` — `RESULT|test-unit|pass|run=4`, exit 0.
7. **Int-прогон:** `bash .pi/skills/test-cross/scripts/run-tests.sh Int` — на текущем коде `RESULT|test-int|fail|...failures=1`, в логе `TestPrimitiveFileLogUnicode`; это воспроизводимый известный fail, не pass.
8. **Старый exe:** `bash .pi/skills/test-cross/scripts/run-tests.sh Unit --no-build` после правки `.pas` — `WARN|stale-exe`/`skipped`, а не зелёный прогон.
9. **Регистрация:** `grep -RIn "CrossRegTest" test/src` — три `'Unit'` в `LogTestUnit.pas:114-116` и два `'Int'` в `LogTestInt.pas:172-173`.
10. **Без компилятора:** `FPC=/nonexistent LAZBUILD=off bash .pi/skills/test-cross/scripts/run-tests.sh Unit` — `skipped|build-not-ok`, exit не 0; трактовать как «не проверено», не как pass.

## Не дублировать

- `pascal-build-probe` (S1) — детект тулчейна и компиляция; здесь только
  вызываем `build.sh` и не дублируем его проверки.
- `pascal-package-sync` (S2) — добавление юнита в `.lpi`/`.lpk`; здесь
  тест-файл только упоминается.
- `doc-sync-ru` (S4) — сверка AGENTS/README с кодом; найденные расхождения
  (например, `UNKNOWN`) фиксируем, но не правим доки здесь.
- `backlog-from-review` (S5) — дефекты `Sleep`/ФС/Unicode — вход туда.
- `code-recon`/`design-brainstorm` — не про запуск тестов.

## Если окружение недоступно

Сообщите: «тесты не запускались»; перечислите, что проверяли
(`build.sh`/`run-tests.sh`), чего нет (FPC/lazbuild/`GlvTestCross`/
пакеты), и какие строки получены (`skipped|...`). Не выдавайте сборку за
прогон и `skipped` за успех.
