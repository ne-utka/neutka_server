# Сюжетные NPC и диалоги

Сюжетные NPC работают через Citizens и Denizen. Конфигурация хранится отдельно от движка в `plugins/Denizen/story`, поэтому добавление персонажей не требует редактирования `story_npcs.dsc`.

## Безопасный рабочий процесс

1. Добавьте или измените YAML-файлы.
2. Выполните `/story validate`.
3. Исправьте все показанные ошибки.
4. Выполните `/story reload`.
5. Создайте персонажа командой `/story npc spawn <id>`.

Загрузчик сначала строит временный реестр. Если найден хотя бы один отсутствующий файл, неизвестное аудио или неправильная связь, текущая рабочая версия остаётся активной.

## Манифест

Файл `story/manifest.yml` перечисляет все материалы:

```yaml
version: 1
npcs:
  bartender: npcs/bartender.yml
dialogs:
  bartender_intro: dialogs/bartender_intro.yml
audio: audio.yml
```

ID разрешено составлять из строчных латинских букв, цифр, `_` и `-`. После размещения NPC его ID менять не следует.

## Персонаж

```yaml
id: bartender
name: Бармен
dialog: bartender_intro
name_visible: false
look_at_player: true
look_range: 6

skin:
  type: file
  value: bartender.png
  model: slim
```

Варианты `skin.type`:

- `player` — актуальный или закэшированный скин аккаунта из `value`;
- `file` — PNG из `story/skins`, модель `classic` или `slim`;
- `blob` — сохранённый `texture;signature;name`, не требующий нового запроса к Mojang/Mineskin;
- `none` — стандартный скин Citizens.

Для большой постоянной библиотеки рекомендуется `blob`: сервер не зависит от лимитов внешнего сервиса при каждом создании NPC. Slim-модель кодируется вместе с профилем скина.

## Диалог

```yaml
id: bartender_intro

lines:
  - speaker: Бармен
    audio: bartender_01
    text: "Давно я здесь новых лиц не видел."
  - pause: 10t
  - speaker: Бармен
    audio: bartender_02
    text: "Чего налить?"
```

Звук слышит только начавший разговор игрок. Наррация показывается над хотбаром белым именем говорящего и серым текстом. Реплика автоматически держится столько же, сколько аудио.

Текстовая реплика без `audio` по умолчанию показывается `40t`; можно явно указать `duration`. Повторный ПКМ не перезапускает активный разговор.

## Реестр аудио

```yaml
audio:
  bartender_01:
    sound_id: marallyzen:quest/bar/bartender_01
    duration: 84t
```

Соответствующий `sound_id` должен присутствовать в `assets/marallyzen/sounds.json`, а `.ogg` — в ресурспаке. Для пересборки манифеста из файлов предусмотрен `tools/build_story_audio_manifest.ps1`.

## Тестирование

```text
/story dialog play bartender_intro
/story dialog play bartender_intro PlayerName
/story stop
/story npc info bartender
/story npc list
```

При выходе, смерти или смене мира активный звук и наррация останавливаются автоматически.
