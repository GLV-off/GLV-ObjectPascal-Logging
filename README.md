# GLV Log - Pascal logging library

Lightweight logging library for Object Pascal (Free Pascal / Lazarus).
Minimal object-based API: assign log levels, write to console, to files
(synchronously or in a background thread) or to any custom sink via a callback.

## Features

- Object-oriented API based on a single abstract `TLog` with a `Log(ALvl, ATxt)` method
- Built-in log levels: `llInfo`, `llDebug`, `llError`, `llWarn`
- Loggers:
  - console output (`TCustomLog` + `TConsole`)
  - synchronous file logger (`TPrimitiveFileLog`)
  - asynchronous file logger with a dedicated background thread (`TAsyncFileLog` / `TAsyncLogThread`)
  - custom sink via method callback (`TCustomLog`)
- Group multiple loggers into one (`TGroupLog`) - fan-out to all children
- Ready-to-use singleton `TLogging.Inst` (console + async `log.log` by default)
- UTF-8 (BOM) file output
- No dependencies beyond the Free Pascal FCL
- MIT license

## Requirements

- Free Pascal 3.x or newer (units require Delphi mode: `{$MODE DELPHI}`, `{$H+}`)
- Lazarus IDE (for building via the `.lpk` package and `.lpi` test projects)
- FCL (`SysUtils`, `Classes`, `Generics.Collections`, `SyncObjs`)

## Installation

Option 1 - via Lazarus package:

1. Open `lib/pkg/lz/glv_log_lib.lpk` with the Lazarus IDE
2. Compile/install the package or add it to your project's required packages

Option 2 - without an IDE: add `lib/src` to your project's unit search path
and compile with FPC directly.

## Quick Start

### Single default logger (singleton)

`TLogging` installs a group with console output and an async `log.log` file.
No initialization code needed:

```pascal
uses
  GlvLog;

begin
  TLogging.Inst.Log(llInfo, 'Application started');
  TLogging.Inst.Log(llError, 'Something went wrong');
end;
```

### Manual composition

Build your own logging pipeline from any combination of logger objects:

```pascal
uses
  GlvLog;

var
  L: TLog;
begin
  L := TGroupLog.Create([
    TCustomLog.Create(TConsole.ConsoleLog),        { console }
    TAsyncFileLog.Create(TAsyncLogThread.Create('app.log')) { async file }
  ]);
  try
    L.Log(llDebug, 'debug message');
    L.Log(llWarn, 'warning message');
  finally
    FreeAndNil(L);
  end;
end;
```

## Concepts

### Levels

`TLogLvl` supports `llInfo`, `llDebug`, `llError`, `llWarn`.
Use the helper `AsStr` or the standalone `LogLvlAsStr` to get an uppercase string:

```pascal
llInfo.AsStr   { returns 'INFO' }
LogLvlAsStr(llWarn) { returns 'WARN' }
```

### Logger classes

| Class | Description |
|---|---|
| `TLog` | Abstract base - the single logging interface (`Log(ALvl, ATxt)`) |
| `TCustomLog` | Redirects logging to a user-provided callback (`TLogCb`) |
| `TGroupLog` | Fan-out: forwards each message to all nested loggers |
| `TPrimitiveFileLog` | Simple sync file logger (rewrites the file on each message) |
| `TAsyncFileLog` | Async file logger backed by `TAsyncLogThread` |
| `TLogging` | Singleton; `Inst` returns a ready-to-use `TLog` group |

## Snippets

### Custom callback logger

Good for injecting your own logic (network sink, GUI list box, log rotation...):

```pascal
type
  TMyForm = class
  private
    procedure MyLog(const ALvl: TLogLvl; const ATxt: UnicodeString);
  end;

procedure TMyForm.MyLog(const ALvl: TLogLvl; const ATxt: UnicodeString);
begin
  Memo.Lines.Add(Format('%s: %s', [ALvl.AsStr, ATxt]));
end;

var
  L: TCustomLog;
begin
  L := TCustomLog.Create(Self.MyLog);
  L.Log(llDebug, 'custom log message');
end;
```

### File logger

Synchronous file logging with a timestamp prefix:

```pascal
var
  F: TPrimitiveFileLog;
begin
  F := TPrimitiveFileLog.Create('app.log');   { or Create(Filename, @DateTimeFunc) }
  F.Log(llInfo, 'saved');
end;
```

### Grouping multiple loggers

```pascal
var
  L: TLog;
begin
  L := TGroupLog.Create([
    TCustomLog.Create(TConsole.ConsoleLog),
    TAsyncFileLog.Create(TAsyncLogThread.Create('app.log')),
    TCustomLog.Create(TelegramBot.SendLog)
  ]);
end;
```

Note: `TGroupLog` owns the objects passed to it and frees them on destruction.

## Units overview

| Unit | Purpose |
|---|---|
| `GlvLog` | Facade - includes all common types/classes and the `TLogging` singleton |
| `GlvLogTypes` | `TLogLvl` and helpers |
| `GlvLogBase` | Abstract `TLog` base class |
| `GlvLogCustom` | `TCustomLog`, `TLogCb` callback |
| `GlvLogGroup` | `TGroupLog` fan-out logger |
| `GlvLogFiles` | `TPrimitiveFileLog`, `TAsyncFileLog`, `TAsyncLogThread` |
| `GlvLogFileOps` | Internal IO utilities (not for public usage) |
| `GlvLogDev` | Developer-level routines `DevLog*` (not stable for public usage) |

## Known limitations

- `TPrimitiveFileLog` reads the whole file into memory and rewrites it - not
  suitable for large/long-running logs; not thread-safe (comment in unit).
- Async file logger flushes to disk in batches (every 8 records queued).
- `GlvLogDev` is a developer tool - API is not stable.

## Tests

Unit and integration testing uses wrapper library [](https://github.com/GLV-off/GLV_Pascal_TestingWrapper). You should clone this package before open autotesting project.

Build and run `test/pkg/lz/Test.lpr` (uses the `Glv.Testing` runner):

```sh
fpc -Mdelphi -FUtest/out/i386-win32/debug test/pkg/lz/Test.lpr
```

or open it in Lazarus and press Run. Test sources are in `test/src`.

## Documentation

- `doc/unit_uses_tree_ru.md` - unit dependency tree (RU)
- `doc/undocumented_units_checklist_ru.md` - documentation checklist (RU)
- `CONTRIBUTING.md` - contribution guidelines

## License

[MIT](LICENSE)
