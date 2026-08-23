# Команды администрации

Подсказки аргументов доступны через `Tab` и зависят от прав LuckPerms.

## Плакаты

```text
/poster spawn <asset_name>
/poster give <type> [player]
/poster info
/poster remove
/poster variant <default|alive|dead|band>
/poster rebuild
/poster cancel
```

Права: `marallyzen.poster.use`, административные действия — `marallyzen.poster.admin`.

## Диктофоны

```text
/dictaphone spawn <audio_file>
/dictaphone remove
/dictaphone info
/dictaphone rebuild
/dictaphone cancel
```

Короткий алиас: `/dict`.

Наррации можно менять без редактирования скрипта:

```text
/dictaphone narration set <audio_file> <text>
/dictaphone narration add <audio_file> <text>
/dictaphone narration speaker <audio_file> <name>
/dictaphone narration list <audio_file>
/dictaphone narration clear <audio_file>
```

Права: `marallyzen.dictaphone.use`, административные действия — `marallyzen.dictaphone.admin`.

## Фантомные предметы

```text
/pitems spawn <id,id,...> <количество|each> [радиус]
/pitems remove [радиус]
/pitems list
/pitems purge
```

Пример декоративного круга из разных предметов:

```text
/pitems spawn bread,dried_kelp,rotten_flesh,carrot,apple,cooked_beef,beef,cooked_porkchop each 1.5
```

Полная команда также доступна как `/phantomitems`. Право: `marallyzen.phantomitems.admin`.

## Тест взаимодействий

```text
/slapdummy spawn [name]
/slapdummy remove
```

Право: `marallyzen.identity.admin`.

## Plasmo Voice

```text
/vreload
/vmute <player>
/vunmute <player>
/vreconnect
/vlist
```

Первые три административные команды выдаются только нужным ролям через LuckPerms.
