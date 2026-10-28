# Анатомия пакетов и проектов GLV Log

Файлы читаются как обычный XML, но `xmllint` в окружении нет — только
`grep`/`awk`/`sed`. Все пути внутри файлов — относительные, с `\`
(`PathDelim Value="\"`), файлы — CRLF.

## 1. Кто за что отвечает

| Формат | Кто создаёт | Что описывает | Версия в репо |
|---|---|---|---|
| `.lpk` | Lazarus | пакет: список юнитов, зависимости, пути | `Package Version="6"` |
| `.ctpkg` | CodeTyphon/Typhon | то же для Typhon | `Package Version="5"` |
| `.lpi` | Lazarus | проект: `BuildModes`, `Units`, `RequiredPackages` | `ProjectOptions Version="13"` |
| `.dproj` | Delphi | проект: `DCC_UnitSearchPath`, `DCCReference` | MSBuild XML |

Рядом с `.lpk`/`.ctpkg` лежит одноимённый `.pas` — **автоген-юнит**,
который IDE пересоздаёт при сохранении/установке пакета. Его не правят
руками; наличие маркера проверяется в `pkg-add-unit.sh`.

## 2. `.lpk` (Lazarus)

```xml
<CONFIG>
  <Package Version="6">
    <PathDelim Value="\"/>
    <Name Value="glv_log_contract"/>
    <Type Value="RunTimeOnly"/>            <!-- может отсутствовать -->
    <CompilerOptions>
      <Version Value="11"/>
      <PathDelim Value="\"/>
      <SearchPaths>
        <IncludeFiles Value="..\..\src"/>
        <OtherUnitFiles Value="..\..\src"/>
        <UnitOutputDirectory Value="..\..\out\$(TargetCPU)-$(TargetOS)\$(BuildMode)"/>
      </SearchPaths>
    </CompilerOptions>
    <Files>
      <Item>
        <Filename Value="..\..\src\GLV.Log.pas"/>
        <UnitName Value="GLV.Log"/>
      </Item>
    </Files>
    <RequiredPkgs>
      <Item><PackageName Value="FCL"/></Item>
    </RequiredPkgs>
    <UsageOptions><UnitPath Value="$(PkgOutDir)"/></UsageOptions>
  </Package>
</CONFIG>
```

- `Files/Item` — единственный список, который реально компилируется в пакет.
- `UnitName` — имя из строки `unit ...;`, **с точками** (`GLV.Log`, не
  `GLV_Log` и не имя файла без расширения).
- `Filename` — путь от каталога `.lpk` (у `lib/pkg/lz/*.lpk` это
  `..\..\src\...`).
- `RequiredPkgs` — имена пакетов Lazarus (`FCL`, `glv_log_contract`), не
  файлы и не модули.
- `OtherUnitFiles` — путь поиска. Юнит, которого нет в `Files`, но который
  лежит здесь и используется другим юнитом пакета, всё равно скомпилируется
  неявно (так `glv_log_def_engine` подтягивает v1-юниты через
  `GLV.Log.SyncFileEngine.pas`).
- `$(PkgOutDir)`, `$(TargetCPU)`, `$(BuildMode)` — переменные IDE; в путях
  не раскрывать вручную.

## 3. `.ctpkg` (CodeTyphon)

Отличия от `.lpk`:

- `Package Version="5"`, `Type Value="RunAndDesignTime"`;
- `RequiredPkgs` — `adFCL` (а не `FCL`);
- `Linking/Debugging/DebugInfoType = dsDwarf3`;
- автоген-юнит содержит `TyphonPackageIntf` и
  `RegisterPackage('glv_log_def_engine', @Register)`;
- рядом лежит `ctinfo.txt` (версия/дата, генерируется IDE).

`lazbuild` не собирает `.ctpkg`; проверка — только компиляция юнитов через
FPC (`build.sh lib-v1-ct`) или CodeTyphon IDE.

## 4. `.lpi` (Lazarus-проект)

- `BuildModes`: `Debug` (обычно `Default="True"`) и `Release`; у каждого
  свои `SearchPaths` и выходной каталог.
- `Units/Unit/Filename` — исходники проекта; `IsPartOfProject`.
- `RequiredPackages/Item/PackageName` — подключённые пакеты.
- `SearchPaths/OtherUnitFiles` — дополнительные каталоги поиска; у
  `test/pkg/lz/*.lpi` это `..\..\src` = `test/src`, у
  `demos/simple/pkg/lz/Demo.lpi` — `demos/simple/src`.
- Выход: `test/out/<cpu>-<os>/debug|release` (строчные — заданы явно),
  демо — `$(BuildMode)` (`Debug`).

Юнит, который одновременно есть в `Units` и попадает в `OtherUnitFiles`,
описан дважды. Это не ошибка XML, но источник неоднозначности: проект может
собрать его из другого каталога. `pkg-inventory.sh` печатает такие пары как
`DUP|…`.

## 5. `.dproj` (Delphi)

- `DCC_UnitSearchPath` (например `..\..\src`) — аналог `OtherUnitFiles`;
- `DCCReference Include="..\..\src\DemoApp.pas"` — файлы проекта;
- `DCC_DcuOutput`/`DCC_ExeOutput` — каталоги вывода;
- ветка в этом репо не проверена: Delphi нет, `demo.inc` отсутствует.

## 6. Правила правки

1. Менять только `<Files>` (добавить/удалить `<Item>`), не переставлять
   остальные секции.
2. Сохранять CRLF и отступы (4/6/8 пробелов, как в соседних `<Item>`).
3. Сортировать юниты по `UnitName` без учёта регистра — так делает IDE;
   `pkg-add-unit.sh` вставляет в нужное место.
4. `UnitName` = ровно имя из `unit`-строки, с точками и регистром.
5. Автоген-юнит (`lib/pkg/*/*.pas`) не редактировать. После правки `.lpk`
   пересобрать пакет (S1: `build.sh lib-v2`) и, если нужно, переустановить
   его в IDE — тогда автоген перегенерируется.
6. Не «чинить» симметрию v1/v2 механически: разные API, разные пакеты.
   Решение — отдельная задача.
7. Правка `.lpi`/`.dproj` — вручную по той же схеме; скрипт их не трогает.

## 7. Ловушки

| Ловушка | Проявление |
|---|---|
| Одинаковое имя пакета в двух экосистемах | `glv_log_def_engine.lpk` и `.ctpkg` — разные наборы юнитов; в отчётах нужен путь, а не только имя |
| `OtherUnitFiles` = весь `lib/src` | юниты вне `Files` компилируются неявно и не попадают в пакет; покрытие считать по `Files` |
| `UnitName` без точек | пакет собирается, но `uses GLV.Log` не находит юнит |
| Потеря CRLF | diff показывает весь файл изменённым; IDE/`lazbuild` это переживут, git — нет |
| `$(BuildMode)` vs `debug` | пакеты пишут в `default`, тесты — в `debug`/`release`; это не ошибка |
| Автоген не обновлён | `.lpk` содержит юнит, а установочный `.pas` — нет; пакет «собирается», но юнит не устанавливается |
| Ручная правка XML без проверки | забыт `</Item>`/`<UnitName>` → `lazbuild` падает с невнятной ошибкой; после правки всегда собирать |
