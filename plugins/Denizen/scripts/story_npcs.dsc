# Data-driven story NPCs for Paper 26.1.2 + Citizens + Denizen + Depenizen.
# YAML files are the source of truth. A validated snapshot is copied to the
# persistent runtime flag, so a broken reload never replaces working content.

marallyzen_story_config:
  type: data
  debug: false
  manifest: story/manifest.yml
  admin_permission: marallyzen.story.admin
  use_permission: marallyzen.story.use
  click_cooldown: 10t
  default_look_range: 6

marallyzen_story_command:
  type: command
  debug: false
  name: story
  aliases:
  - storynpc
  description: Управление сюжетными NPC и диалогами Marallyzen
  usage: /story validate | reload | npc [spawn|remove|info|list] | dialog play | stop
  permission: marallyzen.story.admin
  permission message: <red>Недостаточно прав.
  tab complete:
  - define root <context.args.get[1].to_lowercase||null>
  - if <context.args.size> <= 1:
    - determine validate|reload|npc|dialog|stop
  - if <context.args.size> == 2 && <[root]> == npc:
    - determine spawn|remove|info|list
  - if <context.args.size> == 2 && <[root]> == dialog:
    - determine play
  - if <context.args.size> == 3 && <[root]> == npc && <list[spawn|remove|info].contains[<context.args.get[2].to_lowercase||null>]>:
    - determine <server.flag[marallyzen_story_runtime.npcs].keys||<list[]>>
  - if <context.args.size> == 3 && <[root]> == dialog && <context.args.get[2].to_lowercase||null> == play:
    - determine <server.flag[marallyzen_story_runtime.dialogs].keys||<list[]>>
  - if <context.args.size> == 4 && <[root]> == dialog && <context.args.get[2].to_lowercase||null> == play:
    - determine <server.online_players.parse[name]>
  - if <context.args.size> == 2 && <[root]> == stop:
    - determine <server.online_players.parse[name]>
  - determine <list[]>
  script:
  - define root <context.args.get[1].to_lowercase||help>
  - choose <[root]>:
    - case validate:
      - run marallyzen_story_load def:<player>|false
    - case reload:
      - run marallyzen_story_load def:<player>|true
    - case npc:
      - define action <context.args.get[2].to_lowercase||help>
      - choose <[action]>:
        - case spawn:
          - if <context.server>:
            - narrate "<red>Создавать NPC нужно от имени игрока."
            - stop
          - define story_id <context.args.get[3].to_lowercase||null>
          - run marallyzen_story_npc_spawn def:<[story_id]>|<player>
        - case remove:
          - define story_id <context.args.get[3].to_lowercase||null>
          - run marallyzen_story_npc_remove def:<[story_id]>|<player>
        - case info:
          - define story_id <context.args.get[3].to_lowercase||null>
          - run marallyzen_story_npc_info def:<[story_id]>|<player>
        - case list:
          - define configured <server.flag[marallyzen_story_runtime.npcs].keys||<list[]>>
          - if <[configured].is_empty>:
            - narrate "<yellow>В рабочем реестре нет NPC. Выполните /story reload."
            - stop
          - narrate "<gold>Сюжетные NPC <gray>(<white><[configured].size><gray>)<&co>"
          - foreach <[configured]> as:story_id:
            - define instance <server.flag[marallyzen_story_instances.<[story_id]>.npc]||null>
            - define spawned false
            - if <[instance]> != null && <server.npcs.contains[<[instance]>]>:
              - define spawned true
            - define state <tern[<[spawned]>].pass[<green>создан].fail[<gray>не создан]>
            - narrate "<white><[story_id]> <gray>— <[state]>"
        - default:
          - narrate "<gold>/story npc spawn <white>[id]"
          - narrate "<gold>/story npc remove <white>[id]"
          - narrate "<gold>/story npc info <white>[id]"
          - narrate "<gold>/story npc list"
    - case dialog:
      - define action <context.args.get[2].to_lowercase||help>
      - if <[action]> != play:
        - narrate "<gold>/story dialog play <white>[dialog_id] [player]"
        - stop
      - define dialog_id <context.args.get[3].to_lowercase||null>
      - define viewer null
      - if !<context.server>:
        - define viewer <player>
      - if <context.args.size> >= 4:
        - define viewer <server.match_player[<context.args.get[4]>]||null>
      - if <[viewer]> == null:
        - narrate "<red>Игрок не найден."
        - stop
      - run marallyzen_story_dialog_start def:<[viewer]>|<[dialog_id]>|null
      - narrate "<green>Диалог <white><[dialog_id]> <green>запущен для <white><[viewer].name><green>."
    - case stop:
      - define viewer null
      - if !<context.server>:
        - define viewer <player>
      - if <context.args.size> >= 2:
        - define viewer <server.match_player[<context.args.get[2]>]||null>
      - if <[viewer]> == null:
        - narrate "<red>Игрок не найден."
        - stop
      - run marallyzen_story_session_stop def:<[viewer]>|true
    - default:
      - narrate "<gold>/story validate <gray>— проверить YAML без применения"
      - narrate "<gold>/story reload <gray>— проверить и применить YAML"
      - narrate "<gold>/story npc <white>[spawn|remove|info|list]"
      - narrate "<gold>/story dialog play <white>[dialog_id] [player]"
      - narrate "<gold>/story stop <white>[player]"

marallyzen_story_events:
  type: world
  debug: false
  events:
    on server start:
    - run marallyzen_story_load def:null|true delay:2s

    on reload scripts:
    - foreach <server.online_players> as:viewer:
      - run marallyzen_story_session_stop def:<[viewer]>|false
    - run marallyzen_story_load def:null|true delay:2t

    on player right clicks entity:
    - if <context.hand> != mainhand:
      - stop
    - define target <context.entity>
    - if !<[target].is_spawned||false> || !<[target].is_npc||false>:
      - stop
    - define story_id <[target].flag[marallyzen_story_id]||null>
    - if <[story_id]> == null:
      - stop
    - determine passively cancelled
    - ratelimit <player> 2t
    - if !<player.is_op> && !<player.has_permission[marallyzen.story.use]>:
      - actionbar "<gray>Вы пока не можете поговорить с этим персонажем." targets:<player>
      - stop
    - define dialog_id <server.flag[marallyzen_story_runtime.npcs.<[story_id]>.dialog]||null>
    - if <[dialog_id]> == null:
      - actionbar "<gray>Персонажу пока нечего сказать." targets:<player>
      - stop
    - run marallyzen_story_dialog_start def:<player>|<[dialog_id]>|<[target]>

    on player quits:
    - run marallyzen_story_session_stop def:<player>|false
    on player dies:
    - run marallyzen_story_session_stop def:<player>|false
    on player changes world:
    - run marallyzen_story_session_stop def:<player>|false

marallyzen_story_load:
  type: task
  debug: false
  definitions: actor|apply
  script:
  - define errors <list[]>
  - define loaded_yaml <list[]>
  - define npcs <map[]>
  - define dialogs <map[]>
  - define audio <map[]>
  - define manifest_path <script[marallyzen_story_config].data_key[manifest]>
  - if !<util.has_file[<[manifest_path]>]>:
    - define errors:->:<element[Не найден plugins/Denizen/<[manifest_path]>]>
    - inject marallyzen_story_load_finish
    - stop

  - ~yaml load:<[manifest_path]> id:mlz_story_stage_manifest
  - define loaded_yaml:->:mlz_story_stage_manifest
  - define version <yaml[mlz_story_stage_manifest].read[version]||1>
  - define audio_path <yaml[mlz_story_stage_manifest].read[audio]||null>
  - if <[audio_path]> == null || !<util.has_file[story/<[audio_path]>]>:
    - define errors:->:<element[Не найден аудиоманифест story/<[audio_path]>.]>
  - else:
    - ~yaml load:story/<[audio_path]> id:mlz_story_stage_audio
    - define loaded_yaml:->:mlz_story_stage_audio
    - foreach <yaml[mlz_story_stage_audio].list_keys[audio]||<list[]>> as:audio_id:
      - define sound_id <yaml[mlz_story_stage_audio].read[audio.<[audio_id]>.sound_id]||null>
      - define duration <yaml[mlz_story_stage_audio].read[audio.<[audio_id]>.duration]||null>
      - if <[sound_id]> == null:
        - define errors:->:<element[Аудио <[audio_id]>: отсутствует sound_id.]>
        - foreach next
      - if <[duration]> == null:
        - define errors:->:<element[Аудио <[audio_id]>: отсутствует duration.]>
        - foreach next
      - define entry <map[]>
      - define entry.sound_id:<[sound_id]>
      - define entry.duration:<[duration]>
      - define audio.<[audio_id]>:<[entry]>

  - foreach <yaml[mlz_story_stage_manifest].list_keys[dialogs]||<list[]>> as:dialog_id:
    - if !<[dialog_id].regex_matches[^[a-z0-9_-]+$]>:
      - define errors:->:<element[Некорректный ID диалога: <[dialog_id]>.]>
      - foreach next
    - define path <yaml[mlz_story_stage_manifest].read[dialogs.<[dialog_id]>]||null>
    - if <[path]> == null || !<util.has_file[story/<[path]>]>:
      - define errors:->:<element[Диалог <[dialog_id]>: не найден story/<[path]>.]>
      - foreach next
    - define yaml_id mlz_story_stage_dialog_<[dialog_id]>
    - ~yaml load:story/<[path]> id:<[yaml_id]>
    - define loaded_yaml:->:<[yaml_id]>
    - define file_id <yaml[<[yaml_id]>].read[id]||null>
    - define lines <yaml[<[yaml_id]>].read[lines]||<list[]>>
    - if <[file_id]> != <[dialog_id]>:
      - define errors:->:<element[Диалог <[dialog_id]>: поле id равно '<[file_id]>'.]>
    - if <[lines].is_empty>:
      - define errors:->:<element[Диалог <[dialog_id]>: список lines пуст.]>
    - foreach <[lines]> as:node:
      - if <[node].get[pause]||null> != null:
        - foreach next
      - define node_audio <[node].get[audio]||null>
      - define node_text <[node].get[text]||null>
      - if <[node_audio]> == null && <[node_text]> == null:
        - define errors:->:<element[Диалог <[dialog_id]>, строка <[loop_index]>: нужны audio, text или pause.]>
      - if <[node_audio]> != null && !<[audio].contains[<[node_audio]>]>:
        - define errors:->:<element[Диалог <[dialog_id]>, строка <[loop_index]>: неизвестное аудио <[node_audio]>.]>
    - define entry <map[]>
    - define entry.id:<[dialog_id]>
    - define entry.lines:<[lines]>
    - define dialogs.<[dialog_id]>:<[entry]>

  - foreach <yaml[mlz_story_stage_manifest].list_keys[npcs]||<list[]>> as:story_id:
    - if !<[story_id].regex_matches[^[a-z0-9_-]+$]>:
      - define errors:->:<element[Некорректный ID NPC: <[story_id]>.]>
      - foreach next
    - define path <yaml[mlz_story_stage_manifest].read[npcs.<[story_id]>]||null>
    - if <[path]> == null || !<util.has_file[story/<[path]>]>:
      - define errors:->:<element[NPC <[story_id]>: не найден story/<[path]>.]>
      - foreach next
    - define yaml_id mlz_story_stage_npc_<[story_id]>
    - ~yaml load:story/<[path]> id:<[yaml_id]>
    - define loaded_yaml:->:<[yaml_id]>
    - define file_id <yaml[<[yaml_id]>].read[id]||null>
    - define name <yaml[<[yaml_id]>].read[name]||null>
    - define dialog_id <yaml[<[yaml_id]>].read[dialog]||null>
    - define skin_type <yaml[<[yaml_id]>].read[skin.type]||none>
    - define skin_value <yaml[<[yaml_id]>].read[skin.value]||null>
    - define skin_model <yaml[<[yaml_id]>].read[skin.model]||classic>
    - if <[file_id]> != <[story_id]>:
      - define errors:->:<element[NPC <[story_id]>: поле id равно '<[file_id]>'.]>
    - if <[name]> == null:
      - define errors:->:<element[NPC <[story_id]>: отсутствует name.]>
    - if <[dialog_id]> == null || !<[dialogs].contains[<[dialog_id]>]>:
      - define errors:->:<element[NPC <[story_id]>: неизвестный dialog '<[dialog_id]>'.]>
    - if !<list[none|player|file|blob].contains[<[skin_type]>]>:
      - define errors:->:<element[NPC <[story_id]>: skin.type должен быть none, player, file или blob.]>
    - if <[skin_type]> != none && <[skin_value]> == null:
      - define errors:->:<element[NPC <[story_id]>: отсутствует skin.value.]>
    - if !<list[classic|slim|auto].contains[<[skin_model]>]>:
      - define errors:->:<element[NPC <[story_id]>: skin.model должен быть classic, slim или auto.]>
    - if <[skin_type]> == file:
      - if !<[skin_value].regex_matches[^[A-Za-z0-9_.-]+$]>:
        - define errors:->:<element[NPC <[story_id]>: небезопасное имя файла скина.]>
      - else if !<util.has_file[story/skins/<[skin_value]>]>:
        - define errors:->:<element[NPC <[story_id]>: не найден story/skins/<[skin_value]>.]>
    - define skin <map[]>
    - define skin.type:<[skin_type]>
    - define skin.value:<[skin_value]>
    - define skin.model:<[skin_model]>
    - define entry <map[]>
    - define entry.id:<[story_id]>
    - define entry.name:<[name]>
    - define entry.dialog:<[dialog_id]>
    - define entry.skin:<[skin]>
    - define entry.name_visible:<yaml[<[yaml_id]>].read[name_visible]||false>
    - define entry.look_at_player:<yaml[<[yaml_id]>].read[look_at_player]||true>
    - define entry.look_range:<yaml[<[yaml_id]>].read[look_range]||<script[marallyzen_story_config].data_key[default_look_range]>>
    - define npcs.<[story_id]>:<[entry]>

  - inject marallyzen_story_load_finish

marallyzen_story_load_finish:
  type: task
  debug: false
  script:
  - foreach <[loaded_yaml]||<list[]>> as:yaml_id:
    - yaml unload id:<[yaml_id]>
  - if !<[errors].is_empty>:
    - if <[actor]||null> != null:
      - narrate "<red>Конфигурация не применена. Ошибок: <[errors].size>" targets:<[actor]>
      - foreach <[errors]> as:error:
        - narrate "<gray>• <white><[error]>" targets:<[actor]>
    - stop
  - if <[apply]> == true:
    - define runtime <map[]>
    - define runtime.version:<[version]>
    - define runtime.loaded_at:<util.time_now>
    - define runtime.npcs:<[npcs]>
    - define runtime.dialogs:<[dialogs]>
    - define runtime.audio:<[audio]>
    - flag server marallyzen_story_runtime:<[runtime]>
  - if <[actor]||null> != null:
    - define verb <tern[<[apply]> == true].pass[применена].fail[проверена]>
    - narrate "<green>Конфигурация <[verb]>. <gray>NPC: <white><[npcs].size><gray>, диалогов: <white><[dialogs].size><gray>, аудио: <white><[audio].size><gray>." targets:<[actor]>

marallyzen_story_npc_spawn:
  type: task
  debug: false
  definitions: story_id|actor
  script:
  - define npc_data <server.flag[marallyzen_story_runtime.npcs.<[story_id]>]||null>
  - if <[npc_data]> == null:
    - narrate "<red>NPC '<[story_id]>' отсутствует в рабочем реестре." targets:<[actor]>
    - stop
  - define old <server.flag[marallyzen_story_instances.<[story_id]>.npc]||null>
  - if <[old]> != null && <server.npcs.contains[<[old]>]>:
    - narrate "<yellow>NPC <[story_id]> уже создан. Сначала используйте remove." targets:<[actor]>
    - stop
  - define location <[actor].location.forward_flat[2].with_yaw[<[actor].location.yaw.add[180]>]>
  - create player <[npc_data].get[name]> <[location]> save:story_created
  - define created <entry[story_created].created_npc>
  - flag <[created]> marallyzen_story_id:<[story_id]>
  - flag <[created]> marallyzen_story_dialog:<[npc_data].get[dialog]>
  - adjust <[created]> name_visible:<[npc_data].get[name_visible]||false>
  - define skin <[npc_data].get[skin]>
  - define skin_type <[skin].get[type]||none>
  - if <[skin_type]> == player:
    - adjust <[created]> skin:<[skin].get[value]>
  - else if <[skin_type]> == blob:
    - adjust <[created]> skin_blob:<[skin].get[value]>
  - else if <[skin_type]> == file:
    - execute as_server "npc select <[created].id>" silent
    - define slim_flag ""
    - if <[skin].get[model]||classic> == slim:
      - define slim_flag -s
    - execute as_server "npc skin --file plugins/Denizen/story/skins/<[skin].get[value]> <[slim_flag]>" silent
  - if <[npc_data].get[look_at_player]||true>:
    - execute as_server "npc select <[created].id>" silent
    - execute as_server "npc lookclose --range <[npc_data].get[look_range]||6>" silent
  - flag server marallyzen_story_instances.<[story_id]>:map@[npc=<[created]>;location=<[location]>;created_by=<[actor].uuid>]
  - narrate "<green>NPC <white><[story_id]> <green>создан. Citizens ID: <white><[created].id><green>." targets:<[actor]>

marallyzen_story_npc_remove:
  type: task
  debug: false
  definitions: story_id|actor
  script:
  - define created <server.flag[marallyzen_story_instances.<[story_id]>.npc]||null>
  - if <[created]> == null || !<server.npcs.contains[<[created]>]>:
    - flag server marallyzen_story_instances.<[story_id]>:!
    - narrate "<yellow>Созданный NPC <[story_id]> не найден." targets:<[actor]>
    - stop
  - remove <[created]>
  - flag server marallyzen_story_instances.<[story_id]>:!
  - narrate "<green>NPC <white><[story_id]> <green>удалён." targets:<[actor]>

marallyzen_story_npc_info:
  type: task
  debug: false
  definitions: story_id|actor
  script:
  - define npc_data <server.flag[marallyzen_story_runtime.npcs.<[story_id]>]||null>
  - if <[npc_data]> == null:
    - narrate "<red>NPC '<[story_id]>' отсутствует в рабочем реестре." targets:<[actor]>
    - stop
  - define created <server.flag[marallyzen_story_instances.<[story_id]>.npc]||null>
  - narrate "<gold>ID<&co> <white><[story_id]>" targets:<[actor]>
  - narrate "<gold>Имя<&co> <white><[npc_data].get[name]>" targets:<[actor]>
  - narrate "<gold>Диалог<&co> <white><[npc_data].get[dialog]>" targets:<[actor]>
  - narrate "<gold>Скин<&co> <white><[npc_data].get[skin].get[type]> / <[npc_data].get[skin].get[model]>" targets:<[actor]>
  - if <[created]> != null && <server.npcs.contains[<[created]>]>:
    - narrate "<gold>Citizens ID<&co> <white><[created].id>" targets:<[actor]>
  - else:
    - narrate "<gray>NPC ещё не создан в мире." targets:<[actor]>

marallyzen_story_dialog_start:
  type: task
  debug: false
  definitions: viewer|dialog_id|npc_entity
  script:
  - if !<[viewer].is_online||false>:
    - stop
  - define dialog <server.flag[marallyzen_story_runtime.dialogs.<[dialog_id]>]||null>
  - if <[dialog]> == null:
    - actionbar "<gray>Этот диалог пока недоступен." targets:<[viewer]>
    - stop
  - if <[viewer].has_flag[marallyzen_story_session]>:
    - actionbar "<gray>Сначала дослушайте текущую реплику." targets:<[viewer]>
    - stop
  - ratelimit <[viewer]> <script[marallyzen_story_config].data_key[click_cooldown]>
  - define session_key <util.random_uuid>
  - define npc_name Персонаж
  - if <[npc_entity]> != null:
    - define npc_story_id <[npc_entity].flag[marallyzen_story_id]||null>
    - define npc_name <server.flag[marallyzen_story_runtime.npcs.<[npc_story_id]>.name]||Персонаж>
  - flag <[viewer]> marallyzen_story_session:map@[key=<[session_key]>;dialog=<[dialog_id]>;npc=<[npc_entity]>;active_sound=null]
  - run marallyzen_story_dialog_play def:<[viewer]>|<[session_key]>|<[dialog_id]>|<[npc_name]>

marallyzen_story_dialog_play:
  type: task
  debug: false
  definitions: viewer|session_key|dialog_id|default_speaker
  script:
  - define lines <server.flag[marallyzen_story_runtime.dialogs.<[dialog_id]>.lines]||<list[]>>
  - foreach <[lines]> as:node:
    - if <[viewer].flag[marallyzen_story_session.key]||null> != <[session_key]>:
      - stop
    - define pause <[node].get[pause]||null>
    - if <[pause]> != null:
      - wait <[pause].as[duration]>
      - foreach next
    - define audio_id <[node].get[audio]||null>
    - define text <[node].get[text]||null>
    - define speaker <[node].get[speaker]||<[default_speaker]>>
    - define duration <[node].get[duration]||40t>
    - if <[audio_id]> != null:
      - define audio <server.flag[marallyzen_story_runtime.audio.<[audio_id]>]>
      - define sound_id <[audio].get[sound_id]>
      - define duration <[audio].get[duration]>
      - flag <[viewer]> marallyzen_story_session.active_sound:<[sound_id]>
      - execute as_server "execute at <[viewer].name> run minecraft:playsound <[sound_id].parsed> voice <[viewer].name> ~ ~ ~ 1 1 0" silent
    - define remaining <[duration].as[duration].in_ticks>
    - while <[remaining]> > 0:
      - if <[viewer].flag[marallyzen_story_session.key]||null> != <[session_key]>:
        - stop
      - if <[text]> != null:
        - actionbar "<white><[speaker].parse_color> <gray>>> <[text].parse_color>" targets:<[viewer]>
      - define step 40
      - if <[remaining]> < <[step]>:
        - define step <[remaining]>
      - wait <[step]>t
      - define remaining <[remaining].sub[<[step]>]>
    - flag <[viewer]> marallyzen_story_session.active_sound:null
  - if <[viewer].flag[marallyzen_story_session.key]||null> == <[session_key]>:
    - actionbar "" targets:<[viewer]>
    - flag <[viewer]> marallyzen_story_session:!

marallyzen_story_session_stop:
  type: task
  debug: false
  definitions: viewer|notify
  script:
  - define session <[viewer].flag[marallyzen_story_session]||null>
  - if <[session]> == null:
    - if <[notify]> == true:
      - actionbar "<gray>Активного диалога нет." targets:<[viewer]>
    - stop
  - define sound_id <[session].get[active_sound]||null>
  - if <[sound_id]> != null:
    - execute as_server "minecraft:stopsound <[viewer].name> voice <[sound_id].parsed>" silent
  - flag <[viewer]> marallyzen_story_session:!
  - actionbar "" targets:<[viewer]>
  - if <[notify]> == true:
    - actionbar "<gray>Диалог остановлен." targets:<[viewer]>
