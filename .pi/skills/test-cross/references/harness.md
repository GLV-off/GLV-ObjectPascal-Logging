# Харнесс Glv.Testing: что видно в коде

Источник — внешний репозиторий `../pas_TestingWrapper` (только чтение).
Ниже утверждения с путём и строкой; всё, что не видно в коде, помечено
`[гипотеза]`. `[наблюдение]` — результат фактического прогона, он тоже
требует проверки на другой машине.

## 1. Что подключают тест-проекты

- `test/pkg/lz/Test.lpi:62-72` требует пакеты `glv_log_def_engine`,
  `glv_log_contract`, `GlvTestCross`; `TestInt.lpi:61-68` — `glv_log_def_engine` и `GlvTestCross`
  (без `glv_log_contract`).
- Пакет `../pas_TestingWrapper/Pkg/LZ/glvtestcross.lpk:4` называется
  `GlvTestCross`; его юниты — `Glv.Testing.Cross`, `.App`, `.AppWrapper`,
  `.FPUnitAppWrapper`, `.Assertion`, `.TestCase` (`lpk:33-57`).
- Пакет компилируется с `-dFPUNIT` (`lpk:28-30`) и требует
  `fpcunittestrunner` (`lpk:60-63`).
- В `Glv.Testing.Cross` для FPC: `TCrossTestCase = TTestCase` и
  `TCrossTestCaseClass = class of TTestCase` (`Cross.pas:53-56`),
  `Assert = Glv.Testing.Assertion.TAssertWrapper` (`Cross.pas:40-42`).
- Отдельного `[Test]`-атрибута для FPC-ветки не требуется: обёртки
  атрибутов подключаются и для FPC (`Cross.pas:16`), но существующие тесты
  их не используют; в этом репо нет DUnitX-проекта (`[гипотеза]` для
  Delphi-ветки).

- `Glv.Testing.TestCase` — только пустой `TSafeTestCase` (`../pas_TestingWrapper/Src/Glv.Testing.TestCase.pas:10-17`);
  тесты его не используют, `TCrossTestCase` приходит из `FpcUnit` (`Cross.pas:55`).

## 2. Регистрация

- `CrossRegTest(ClassOfTest, Subpath)` объявлена в `Cross.pas:83`.
- На FPC она вызывает `RegisterTest(Subpath, ClassOfTest)`
  (`Cross.pas:87-90`); `Subpath` — имя suite, в тестах это `'Unit'` или
  `'Int'`.
- Регистрация выполняется в `initialization` тест-юнита:
  `test/src/LogTestUnit.pas:112-116`, `test/src/LogTestInt.pas:170-173`.
- Вызов `Run('...')` — в `Test.lpr:11-15` и `TestInt.lpr:11-16`.

## 3. Что запускается

- `Glv.Testing.App.Run` при определённом `FPUNIT` выбирает
  `TFPUnitTestApp` (`App.pas:27-40`); иначе — заглушку
  `TUnimplementedTestApp`, которая только печатает текст (`App.pas:62-65`).
- `TFPUnitTestApp.Run` ставит `SetConsoleCP(CP_UTF8)` и
  `SetConsoleOutputCP(CP_UTF8)` на Windows (`FPUnitAppWrapper.pas:56-59`),
  включает `DefaultRunAllTests := True` и `DefaultFormat := fPlain`
  (`:60-61`), создаёт `TTestRunner`, вызывает `Application.Run()` (`:62-69`)
  и затем `ReadLn()` (`:73`).
- `ReadLn()` в конце означает: при автоматическом запуске stdin должен быть
  закрыт (`< /dev/null`), иначе процесс ждёт ввода. То же — `ReadLn` под
  `{$IFDEF DEBUG}` в `Test.lpr:13-15` / `TestInt.lpr:14-16`.
- `[гипотеза]` Набор тестов класса строит FPC `TTestCase.Suite` по
  published-методам; `CrossRegTest` лишь регистрирует класс, а имена методов
  в коде обёртки не перечисляются. Поэтому методы должны быть `published`
  и без параметров.

## 4. Жизненный цикл теста

- `SetUp`/`TearDown` объявлены в тест-классах как `protected ... override`
  (`LogTestUnit.pas:21-23`, `LogTestInt.pas:15-17,26-28`).
- По коду тестов видно, что они работают на каждый тест: `SetUp` заполняет
  `FFilepath`/`FLastLvl`, `TearDown` очищает (`LogTestInt.pas:55-63,121-129`).
- `[гипотеза]` Порядок: `SetUp` → published-метод → `TearDown`;
  исключение в тесте даёт error, невыполненный `Assert` — failure. Это
  наблюдаемое поведение FPC-раннера, отдельного кода в обёртке нет.

## 5. Доступные проверки

`TAssertWrapper` (`../pas_TestingWrapper/Src/Glv.Testing.Assertion.pas:10-19`):

| Метод | Типы |
|---|---|
| `Assert.IsTrue` / `IsFalse` | `Boolean` |
| `Assert.AreEqual` | `Int64`, `UnicodeString` |
| `Assert.AreNotEqual` | `UnicodeString`, `LongInt` |
| `Assert.IsNull` / `IsNotNull` | `TObject` |

Нет `AreEqual(Boolean)` и нет `AreEqual(TDateTime)` — сравнивать через
`Ord`/`Int64` или строку. Сообщение (`AMsg`) необязательно.

## 6. Формат вывода и код возврата

`[гипотеза]` Раннер печатает дерево suite и итоги:

```text
Number of run tests: 4
Number of errors:    0
Number of failures:  0
```

`[гипотеза]` (по прогону): при одном failure (`TestInt`, 2026-10-28) процесс завершился
с кодом `1`; при успехе — `0`. Полагаться только на код нельзя: при
`ReadLn`/таймауте/отсутствии итогов код тоже может быть ненулевым. Считать
тесты нужно по трём строкам `Number of ...`.

## 7. Где лежат файлы интеграционных тестов

`TEnv.Root` = `ExtractFilePath(ParamStr(0))` (`TestEnv.pas:22-24`), поэтому
`test.log` и `async.log` создаются рядом с `.exe` — в
`test/out/<cpu>-<os>/<mode>/`, а не в `test/src`. Абсолютных путей в тестах
нет; это же означает, что два параллельных запуска одного exe будут делить
файлы.

## 8. Чего в этом репо нет

- Delphi-проекта тестов и DUnitX-ветки: `[гипотеза]` ветки
  `Cross.pas:21-26,43-50,61-79` не проверялись, Delphi в окружении нет.
- `TestReport.pas` — пустая заготовка (`test/src/TestReport.pas:1-18`);
  на тесты не влияет (`[гипотеза]`), но подключён в обоих `.lpi`.
- Отдельного API для таймаутов/повторов в обёртке нет (`[гипотеза]`):
  ждать завершения асинхронного логгера приходится тесту.
