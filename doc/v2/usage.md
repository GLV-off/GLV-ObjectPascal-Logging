# Как использовать

Предполагается что клиент\разработчик в местах использования лога включает только 
Glv.Log модуль. В корневом проектном файле, он включает Glv.Log.<EngineName>Engine модуль. (Для примера, Glv.Log.ConsoleEngine)

Каждый движок обязан реализовать либо процедуру либо метод по сигнатуре:
``` pascal
procedure(const InLvl: TLogLvl; const Intxt: UnicodeString); 
// or
procedure(const InLvl: TLogLvl; const Intxt: UnicodeString) of object;
```

Потом обёртка-запись принимает нужный экземпляр и далее TLogEngine уже будет вызывать правильную реализацию.