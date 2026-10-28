# Контракты формата и Unicode

Таблица повторяет `AGENTS.md`, но с привязкой к коду и тестам. Если строка
не покрыта тестом, это отмечено явно: контракт без теста — заявка, а не
гарантия.

## 1. Четыре формата

| Логгер | Формат строки | Реализация | Тест |
|---|---|---|---|
| `TPrimitiveFileLog` | `yyyy-mm-dd hh:nn:ss [LEVEL] text` | `lib/src/GlvLogFiles.pas:279` | `test/src/LogTestInt.pas:85-92` |
| `TAsyncFileLog` | `[LEVEL]: text` | `lib/src/GlvLogFiles.pas:128` | `test/src/LogTestInt.pas:155-162` |
| `TConsole` | `LEVEL: t.id=<ThreadID>, m=text` | `lib/src/GlvLog.pas:147-149` | **теста нет** (см. §3) |
| `TLogLvl.AsStr` | `INFO/DEBUG/ERROR/WARN` | `lib/src/GlvLogTypes.pas:51-57` | `test/src/LogTestUnit.pas:104-110` |

Детали:

- Время в `TPrimitiveFileLog` подставляется через `TDateTimeFunc`
  (`GlvLogFiles.pas:266-284`); тест фиксирует его `StaticDateTime`
  (`LogTestInt.pas:50-53`), поэтому строка детерминирована:
  `2026-08-09 12:30:00 [DEBUG] debug text test write`.
- `TAsyncFileLog` формирует строку конкатенацией, без `Format`
  (`GlvLogFiles.pas:125-128`) — это осознанный обход потери Unicode.
- `TConsole.ConsoleLog` использует `WriteLn` и `TThread.CurrentThread.ThreadID`
  (`GlvLog.pas:147-149`); в `test/src` нет ни одного теста на `TConsole`
  (проверяется `grep`), формат закреплён только кодом.
- `TLogLvl.AsStr` возвращает четыре значения; ветки `else` в
  `GlvLogTypes.pas:51-57` **нет**, поэтому утверждение AGENTS про `UNKNOWN`
  для прочих значений кодом не подтверждено. `TestAsStr`
  (`LogTestUnit.pas:104-110`) проверяет только четыре легальных уровня;
  поведение `TLogLvl(99)` не тестируется. Это вход для S4/S5, не правка
  здесь.

## 2. Unicode: где ломается

В тестах две разные точки:

1. **Callback (память).** `TCustomLogTest.TestUnicodeText`
   (`LogTestUnit.pas:91-102`) передаёт `#$4E2D#$1F600` через
   `TCustomLog` и проверяет, что callback получил тот же `UnicodeString`.
   Тест проходит; константа описана в `LogTestUnit.pas:42-45`.
2. **Файл (UTF-8).** `TFileLogTest.TestPrimitiveFileLogUnicode`
   (`LogTestInt.pas:100-119`) пишет ту же строку через
   `TPrimitiveFileLog` и читает `TstReadLines`
   (`TestFileUtils.pas:21-47`). На прогоне 2026-10-28 (x86_64, Debug)
   тест **падает**:

   ```text
   TestPrimitiveFileLogUnicode  Failed: "unicode text written to file is not UTF-8 or corrupted"
   expected: <2026-08-09 12:30:00 [INFO] ???> but was: <2026-08-09 12:30:00 [INFO] ???>
   Number of failures:  1
   ```

   Оба значения в консоли отображаются как `???` (кодировка консоли), но
   сравнение `UnicodeString` не равно. Это не флак: тест детерминированно
   воспроизводится. Причина не локализована: под подозрением и запись
   `TPrimitiveFileLog` (`Items.Add(UTF8Encode(...))` + `SaveToFile`,
   `GlvLogFiles.pas:274-280`), и двойное декодирование в
   `TstReadLines` (`LoadFromFile(..., TEncoding.Utf8)` + `UTF8Decode`,
   `TestFileUtils.pas:30,40`) — `[гипотеза]`, нужен разбор байтов файла.

## 3. Ловушка `Format` + `UnicodeString`

`InfoFmt/WarnFmt/ErrorFmt/DebugFmt` вызывают `Format`
(`lib/src/GlvLog.pas:102-120`). В FPC `Format` работает через
`AnsiString`, поэтому `Format('%s', [UnicodeString])` на не-UTF-8 системной
кодировке может потерять не-ASCII (`???`). Тестов на `*Fmt` в `test/src`
нет; `TestAsStr` и файловые тесты используют конкатенацию/литералы, а не
`Format`. Поэтому:

- `Info/Warn/Error/Debug` (прямой `Log`) — Unicode-safe по пути;
- `*Fmt` — **не гарантированы**, пока нет теста `TestUnicodeFmt`;
- `FormatDateTime` в файловом логгере возвращает `string` из даты и не
  содержит пользовательского Unicode.

Если добавляете тест на Unicode, проверяйте именно байты/`Ord` символов,
а не вывод в консоль: `SetConsoleOutputCP(CP_UTF8)`
(`../pas_TestingWrapper/Src/Glv.Testing.FPUnitAppWrapper.pas:56-58`) не
спасает перенаправленный вывод от `?`.

## 4. Как менять формат

1. Сначала править ожидания в `LogTestInt.pas` / `LogTestUnit.pas` — они
   сравнивают строки посимвольно.
2. Затем код логгера.
3. Прогнать `test-cross/scripts/run-tests.sh Int` (и `Unit`).
4. Обновить README/AGENTS, если формат продублирован в примерах.

Не «подгонять» тест под текущий вывод без решения о контракте: это скрывает
регрессию.
