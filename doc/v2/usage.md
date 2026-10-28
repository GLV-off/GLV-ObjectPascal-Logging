# Как использовать

Предполагается что клиент\разработчик в местах использования лога включает только 
GLV.Log модуль. В корневом проектном файле, он включает GLV.Log.<EngineName>Engine модуль. (Для примера, GLV.Log.ConsoleEngine)

Каждый движок обязан реализовать либо процедуру либо метод по сигнатуре:
``` pascal
procedure(const InLvl: TLogLvl; const Intxt: UnicodeString); 
// or
procedure(const InLvl: TLogLvl; const Intxt: UnicodeString) of object;
```

Потом обёртка-запись принимает нужный экземпляр и далее TLogEngine уже будет вызывать правильную реализацию.

## Граф логгеров вместо готового движка (Builder + Holder)

Альтернатива `*Engine`-модулям: граф собирается из готовых `TLog`-реализаций,
а в `TLogEngine` регистрируется один стабильный прокси `HolderLog`.

``` pascal
uses
  GLV.Log,           // LogInfo / LogWarn / LogError / LogDebug
  GLV.Log.Builder,   // TLogBuilder
  GLV.Log.Holder;    // TLogHolder

var
  B: TLogBuilder;
begin
  B := TLogBuilder.Create;
  try
    TLogHolder.Inst := B.Console.AsyncFile('app.log').WithLock().Build;
  finally
    B.Free;                        // владение sink'ами уже у графа
  end;

  LogInfo('Application started');
end;
```

Правила:

- `TLogHolder.Inst` владеет графом; builder после `Build` можно сразу освободить
  (он передал владение);
- первая установка регистрирует callback в `TLogEngine` и должна произойти до
  старта рабочих потоков (перерегистрация callback не потокобезопасна);
- последующие `TLogHolder.Inst := ...` — hot-swap: старый граф не освобождается,
  а живёт до финализации holder'а, поэтому поток, уже вошедший в `Log`, не падает;
- `TLogHolder.Inst := nil` отключает логирование: `LogInfo` бросает
  `ELoggingEngineNotInitialized`;
- holder взаимоисключающий с `GLV.Log.ConsoleEngine` и
  `GLV.Log.SyncFileEngine`: они ставят свой callback в `initialization`;
- `TLockLog` (`.WithLock`) — единственная точка синхронизации: один `Acquire`
  на сообщение поверх всего графа.

## Рабочий пример

`demos/builder` — сборка графа через `TLogBuilder`, проверка владения,
`WithLock`, ошибки контракта и hot-swap через `TLogHolder`.
Проект Lazarus: `demos/builder/pkg/lz/BuilderDemo.lpi`; из консоли —
`bash .pi/skills/pascal-build-probe/scripts/build.sh demo-builder`.
Async-сценарий включается флагом `--async` из-за известных дефектов
`TAsyncLogThread` (BL-001, BL-002).
