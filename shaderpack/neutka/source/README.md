# neutka

Shader pack для Fabric + Iris + Sodium с CazToon-style depth-based обводкой блоков и энтити.

## Установка

1. Скопировать папку `neutka` или архив `neutka.zip` в `.minecraft/shaderpacks/`.
2. Открыть настройки графики Iris и выбрать `neutka`.
3. Параметры контура находятся в Shader Pack Settings.

## Реализация

- Непрозрачные terrain, block entity и entity passes записывают маску в `colortex1.r`.
- `colortex1` хранит outline mask, emissive mask, skylight и класс геометрии.
- `colortex2` хранит маски облаков, воды/стекла и погодного тумана.
- `colortex3` хранит emissive-цвет для совместимости с последующим bloom-проходом.
- `final.fsh` объединяет `depthtex0` с `dhDepthTex` и ищет перепады по четырём диагональным точкам.
- Standard использует положительный лапласиан глубины.
- Dungeons Style использует относительную линеаризованную глубину и проверку диагонального контраста.
- На стыке native chunks и Distant Horizons контур подавляется.
- Для Voxy LOD предусмотрен отдельный выключатель, по умолчанию LOD-контуры отключены.
- Видимость контура подавляется туманом, водой, погодой и облаками; в тёмных областях действует диапазон 10–40 блоков.
- DH-растительность фильтруется по HSV-профилю зелёного цвета.
- `MAGICAL_TOUCH` исключает листву и анимированную растительность.
- Emissive block/item/entity branches записывают отдельную маску и glow payload.

Пак ориентирован на Iris ветки 26.1 и использует стандартный GLSL 330 compatibility pipeline.
