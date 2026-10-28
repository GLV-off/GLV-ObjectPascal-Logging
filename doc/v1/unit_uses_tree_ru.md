# Дерево использования модулей

Ниже представлено полное дерево зависимостей в пределах 
всей библиотеки (не учитывается тестовое окружение).

Слои: `GLV.Log.Lvl` -> `GLV.Log.Engine` (контракт V2, пакет `glv_log_contract`);
`GlvLogBase` и реализации `TLog` (пакет `glv_log_def_engine`); поверх них —
`GLV.Log.Builder` / `GLV.Log.Holder` и V1-фасад `GlvLog`.

```
<library>
  GLV.Log.Lvl
  GLV.Log.Engine
    |- GLV.Log.Lvl
  GLV.Log
    |- GLV.Log.Lvl
    |- GLV.Log.Engine
    |    |- GLV.Log.Lvl
  GlvLogTypes
  GlvLogBase
    |- GLV.Log.Lvl
  GlvLogCustom
    |- GLV.Log.Lvl
    |- GlvLogBase
    |    |- GLV.Log.Lvl
  GlvLogGroup
    |- Generics.Collections
    |- GLV.Log.Lvl
    |- GlvLogBase
    |    |- GLV.Log.Lvl
  GlvLogFiles
    |- SysUtils, Classes, SyncObjs, Generics.Collections
    |- GLV.Log.Lvl
    |- GlvLogBase
    |    |- GLV.Log.Lvl
    |- GlvLogFileOps (impl)
  GlvLogFileOps
    |- Classes, SysUtils
  GlvLogDev
    |- SysUtils
    |- GlvLogTypes
  GLV.Log.ConsoleSink
    |- GLV.Log.Lvl
    |- Classes (impl)
  GLV.Log.Lock
    |- SyncObjs
    |- GLV.Log.Lvl
    |- GlvLogBase
    |    |- GLV.Log.Lvl
    |- SysUtils (impl)
  GLV.Log.Builder
    |- SysUtils, Generics.Collections, SyncObjs
    |- GLV.Log.Lvl
    |- GlvLogBase
    |    |- GLV.Log.Lvl
    |- GlvLogCustom
    |- GlvLogGroup
    |- GlvLogFiles
    |- GLV.Log.ConsoleSink
    |- GLV.Log.Lock
  GLV.Log.Holder
    |- SyncObjs, Generics.Collections
    |- GLV.Log.Lvl
    |- GLV.Log.Engine
    |    |- GLV.Log.Lvl
    |- GlvLogBase
    |    |- GLV.Log.Lvl
  GlvLog (V1-фасад)
    |- GLV.Log.Lvl
    |- GLV.Log.ConsoleSink
    |- GLV.Log.Lock
    |- GLV.Log.Builder
    |- GlvLogBase
    |- GlvLogCustom
    |- GlvLogGroup
    |- GlvLogFiles
    |- SysUtils (impl)
  GLV.Log.ConsoleEngine
    |- SysUtils, Classes, GLV.Log.Lvl, GLV.Log.Engine (impl)
  GLV.Log.SyncFileEngine
    |- GLV.Log.Engine, GlvLog (impl)
```

Замечания:

- `GlvLogTypes` — V1-копия `TLogLvl`; используется только `GlvLogDev`,
  новый код берёт `GLV.Log.Lvl`.
- `GlvLog` (фасад) зависит от `GLV.Log.Builder`/`GLV.Log.Lock` только ради
  алиасов типов; `GLV.Log.Builder` фасад не использует (иначе цикл).
- `GLV.Log.Holder` — единственный юнит, который регистрирует прокси в
  `TLogEngine` во время работы программы; `*Engine`-юниты делают это в
  `initialization`.
