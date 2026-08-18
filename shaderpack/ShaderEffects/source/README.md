# ShaderEffects

Shader pack для Fabric + Iris + Sodium с CazToon-style depth-based обводкой блоков и энтити и полноэкранным TAA.

## Установка

1. Скопировать архив `ShaderEffects.zip` в `.minecraft/shaderpacks/`.
2. Открыть настройки графики Iris и выбрать `ShaderEffects.zip`.
3. Параметры bloom, цветокоррекции, виньетки, TAA и контура находятся в Shader Pack Settings.

## Реализация

- Непрозрачные terrain, block entity и entity passes записывают маску в `colortex1.r`.
- `colortex1` хранит outline mask, emissive mask, skylight и класс геометрии.
- `colortex2` хранит маски облаков, воды/стекла и погодного тумана.
- `composite.fsh` объединяет `depthtex0` с `dhDepthTex` и ищет перепады по четырём диагональным точкам.
- `composite1.fsh` выполняет TAA: перепроекцию истории, ограничение по окрестности и подавление шлейфов при движении.
- Восьмикадровый субпиксельный jitter применяется к обычной геометрии и Distant Horizons; Voxy обрабатывается отдельной стабильной веткой.
- История TAA хранится в persistent `colortex4`.
- Standard использует положительный лапласиан глубины.
- Dungeons Style использует относительную линеаризованную глубину и проверку диагонального контраста.
- На стыке native chunks и Distant Horizons контур подавляется.
- Для Voxy LOD предусмотрен отдельный выключатель, по умолчанию LOD-контуры отключены.
- Видимость контура подавляется туманом, водой, погодой и облаками; в тёмных областях действует диапазон 10–40 блоков.
- DH-растительность фильтруется по HSV-профилю зелёного цвета.
- `MAGICAL_TOUCH` исключает листву и анимированную растительность.
- Emissive block/item/entity branches записывают отдельную маску и glow payload.

Пак ориентирован на Iris ветки 26.1 и использует стандартный GLSL 330 compatibility pipeline.
