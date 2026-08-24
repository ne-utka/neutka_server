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
  default_dialog_range: 6
  dialog_distance_check_rate: 5t
  dialog_distance_grace: 10t

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

# Public command used only by the clickable answer components. The random
# session key and current-node check make copied or stale buttons harmless.
marallyzen_story_choice_command:
  type: command
  debug: false
  name: storychoice
  description: Выбор ответа в сюжетном диалоге
  usage: /storychoice
  permission: marallyzen.story.use
  permission message: <red>Недостаточно прав.
  tab complete:
  - determine <list[]>
  script:
  - if <context.server>:
    - stop
  - run marallyzen_story_choice_select def:<player>|<context.args.get[1]||null>|<context.args.get[2].to_lowercase||null>

marallyzen_story_choice_select:
  type: task
  debug: false
  definitions: viewer|session_key|choice_id
  script:
  - if !<[viewer].is_online||false>:
    - stop
  - define session <[viewer].flag[marallyzen_story_session]||null>
  - if <[session]> == null || <[session].get[key]> != <[session_key]> || <[session].get[awaiting_choice]||false> != true:
    - stop
  - define dialog_id <[session].get[dialog]>
  - define node_id <[session].get[node]>
  - define choice <server.flag[marallyzen_story_runtime.dialogs.<[dialog_id]>.nodes.<[node_id]>.choices.<[choice_id]>]||null>
  - if <[choice]> == null:
    - stop
  - ratelimit <[viewer]> 3t
  - flag <[viewer]> marallyzen_story_session.awaiting_choice:false
  - flag <[viewer]> marallyzen_story_session.available_choices:!
  - run marallyzen_story_choice_ui_clear def:<[viewer]>
  - actionbar "<gray>Вы<&co> <white><[choice].get[text].parse_color>" targets:<[viewer]>
  - wait 10t
  - if <[viewer].flag[marallyzen_story_session.key]||null> != <[session_key]>:
    - stop
  - define next <[choice].get[next]||end>
  - if <[next]> == end:
    - actionbar "" targets:<[viewer]>
    - flag <[viewer]> marallyzen_story_session:!
    - stop
  - run marallyzen_story_dialog_play_node def:<[viewer]>|<[session_key]>|<[dialog_id]>|<[next]>|<[session].get[default_speaker]||Персонаж>

marallyzen_story_events:
  type: world
  debug: false
  events:
    on server start:
    - run marallyzen_story_choice_ui_cleanup_all
    - run marallyzen_story_load def:null|true delay:2s

    on reload scripts:
    - foreach <server.online_players> as:viewer:
      - run marallyzen_story_session_stop def:<[viewer]>|false
    - run marallyzen_story_choice_ui_cleanup_all
    - run marallyzen_story_load def:null|true delay:2t

    on player right clicks interaction:
    - if <context.hand> != mainhand:
      - stop
    - define target <context.entity>
    - define owner <[target].flag[marallyzen_story_choice_owner]||null>
    - if <[owner]> != <player.uuid>:
      - stop
    - determine passively cancelled
    - run marallyzen_story_choice_ui_select def:<player>|<[target].flag[marallyzen_story_choice_index]||1>
    - run marallyzen_story_choice_select def:<player>|<[target].flag[marallyzen_story_choice_session]||null>|<[target].flag[marallyzen_story_choice_id]||null>

    on player scrolls their hotbar:
    - if <player.flag[marallyzen_story_session.awaiting_choice]||false> != true:
      - stop
    - determine passively cancelled
    - ratelimit <player> 1t
    - define delta <context.new_slot.sub[<context.previous_slot>]>
    - if <[delta]> == 1 || <[delta]> == -8:
      - define step 1
    - else:
      - define step -1
    - define selected <player.flag[marallyzen_story_session.selected_index]||1>
    - run marallyzen_story_choice_ui_select def:<player>|<[selected].add[<[step]>]>

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
    - define active_session <player.flag[marallyzen_story_session]||null>
    - if <[active_session]> != null && <[active_session].get[awaiting_choice]||false> == true && <[active_session].get[npc]||null> == <[target]>:
      - define selected_choice <[active_session].get[selected_choice]||null>
      - if <[selected_choice]> != null:
        - run marallyzen_story_choice_select def:<player>|<[active_session].get[key]>|<[selected_choice]>
      - stop
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
    - if <[file_id]> != <[dialog_id]>:
      - define errors:->:<element[Диалог <[dialog_id]>: поле id равно '<[file_id]>'.]>
    - define node_keys <yaml[<[yaml_id]>].list_keys[nodes]||<list[]>>
    - define nodes <map[]>
    # Legacy linear files remain valid and become a single "start" node.
    - if <[node_keys].is_empty>:
      - define legacy_lines <yaml[<[yaml_id]>].read[lines]||<list[]>>
      - define node_keys <list[start]>
      - define legacy_node <map[]>
      - define legacy_node.lines:<[legacy_lines]>
      - define legacy_node.choices:<map[]>
      - define nodes.start:<[legacy_node]>
      - define start_node start
    - else:
      - define start_node <yaml[<[yaml_id]>].read[start]||<[node_keys].first>>
      - foreach <[node_keys]> as:node_id:
        - if !<[node_id].regex_matches[^[a-z0-9_-]+$]>:
          - define errors:->:<element[Диалог <[dialog_id]>: некорректный ID узла <[node_id]>.]>
        - define node_lines <yaml[<[yaml_id]>].read[nodes.<[node_id]>.lines]||<list[]>>
        - define node_next <yaml[<[yaml_id]>].read[nodes.<[node_id]>.next]||null>
        - define choices <map[]>
        - foreach <yaml[<[yaml_id]>].list_keys[nodes.<[node_id]>.choices]||<list[]>> as:choice_id:
          - define choice_text <yaml[<[yaml_id]>].read[nodes.<[node_id]>.choices.<[choice_id]>.text]||null>
          - define choice_next <yaml[<[yaml_id]>].read[nodes.<[node_id]>.choices.<[choice_id]>.next]||null>
          - if !<[choice_id].regex_matches[^[a-z0-9_-]+$]>:
            - define errors:->:<element[Диалог <[dialog_id]>, узел <[node_id]>: некорректный выбор <[choice_id]>.]>
          - if <[choice_text]> == null || <[choice_next]> == null:
            - define errors:->:<element[Диалог <[dialog_id]>, выбор <[choice_id]>: нужны text и next.]>
          - if <[choice_next]> != end && !<[node_keys].contains[<[choice_next]>]>:
            - define errors:->:<element[Диалог <[dialog_id]>, выбор <[choice_id]>: неизвестный узел <[choice_next]>.]>
          - define choice <map[]>
          - define choice.text:<[choice_text]>
          - define choice.next:<[choice_next]>
          - define choices.<[choice_id]>:<[choice]>
        - if <[node_next]> != null && <[node_next]> != end && !<[node_keys].contains[<[node_next]>]>:
          - define errors:->:<element[Диалог <[dialog_id]>, узел <[node_id]>: неизвестный next <[node_next]>.]>
        - define node <map[]>
        - define node.lines:<[node_lines]>
        - define node.next:<[node_next]>
        - define node.choices:<[choices]>
        - define nodes.<[node_id]>:<[node]>
    - if !<[node_keys].contains[<[start_node]>]>:
      - define errors:->:<element[Диалог <[dialog_id]>: неизвестный стартовый узел <[start_node]>.]>
    - foreach <[nodes]> key:node_id as:node:
      - define node_lines <[node].get[lines]||<list[]>>
      - if <[node_lines].is_empty> && <[node].get[choices].is_empty||true>:
        - define errors:->:<element[Диалог <[dialog_id]>, узел <[node_id]>: нет реплик или вариантов ответа.]>
      - foreach <[node_lines]> as:line_data:
        - if <[line_data].get[pause]||null> != null:
          - foreach next
        - define node_audio <[line_data].get[audio]||null>
        - define node_text <[line_data].get[text]||null>
        - if <[node_audio]> == null && <[node_text]> == null:
          - define errors:->:<element[Диалог <[dialog_id]>, узел <[node_id]>, строка <[loop_index]>: нужны audio, text или pause.]>
        - if <[node_audio]> != null && !<[audio].contains[<[node_audio]>]>:
          - define errors:->:<element[Диалог <[dialog_id]>, узел <[node_id]>: неизвестное аудио <[node_audio]>.]>
    - define entry <map[]>
    - define entry.id:<[dialog_id]>
    - define entry.start:<[start_node]>
    - define entry.nodes:<[nodes]>
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
    - define entity_type <yaml[<[yaml_id]>].read[entity_type]||player>
    - define skin_type <yaml[<[yaml_id]>].read[skin.type]||none>
    - define skin_value <yaml[<[yaml_id]>].read[skin.value]||null>
    - define skin_model <yaml[<[yaml_id]>].read[skin.model]||classic>
    - define dialog_range <yaml[<[yaml_id]>].read[dialog_range]||<script[marallyzen_story_config].data_key[default_dialog_range]>>
    - if <[file_id]> != <[story_id]>:
      - define errors:->:<element[NPC <[story_id]>: поле id равно '<[file_id]>'.]>
    - if <[name]> == null:
      - define errors:->:<element[NPC <[story_id]>: отсутствует name.]>
    - if <[dialog_id]> == null || !<[dialogs].contains[<[dialog_id]>]>:
      - define errors:->:<element[NPC <[story_id]>: неизвестный dialog '<[dialog_id]>'.]>
    - if !<list[player|villager].contains[<[entity_type]>]>:
      - define errors:->:<element[NPC <[story_id]>: entity_type должен быть player или villager.]>
    - if <[entity_type]> != player && <[skin_type]> != none:
      - define errors:->:<element[NPC <[story_id]>: скин доступен только при entity_type player.]>
    - if !<list[none|player|file|blob].contains[<[skin_type]>]>:
      - define errors:->:<element[NPC <[story_id]>: skin.type должен быть none, player, file или blob.]>
    - if <[skin_type]> != none && <[skin_value]> == null:
      - define errors:->:<element[NPC <[story_id]>: отсутствует skin.value.]>
    - if !<list[classic|slim|auto].contains[<[skin_model]>]>:
      - define errors:->:<element[NPC <[story_id]>: skin.model должен быть classic, slim или auto.]>
    - if !<[dialog_range].regex_matches[^[0-9]+([.][0-9]+)?$]> || <[dialog_range]> <= 0:
      - define errors:->:<element[NPC <[story_id]>: dialog_range должен быть числом больше нуля.]>
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
    - define entry.entity_type:<[entity_type]>
    - define entry.skin:<[skin]>
    - define entry.name_visible:<yaml[<[yaml_id]>].read[name_visible]||false>
    - define entry.look_at_player:<yaml[<[yaml_id]>].read[look_at_player]||true>
    - define entry.look_range:<yaml[<[yaml_id]>].read[look_range]||<script[marallyzen_story_config].data_key[default_look_range]>>
    - define entry.dialog_range:<[dialog_range]>
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
  - define entity_type <[npc_data].get[entity_type]||player>
  - create <[entity_type]> <[npc_data].get[name]> <[location]> save:story_created
  - define created <entry[story_created].created_npc>
  - flag <[created]> marallyzen_story_id:<[story_id]>
  - flag <[created]> marallyzen_story_dialog:<[npc_data].get[dialog]>
  - adjust <[created]> name_visible:<[npc_data].get[name_visible]||false>
  - define skin <[npc_data].get[skin]>
  - define skin_type <[skin].get[type]||none>
  - if <[entity_type]> == player && <[skin_type]> == player:
    - adjust <[created]> skin:<[skin].get[value]>
  - else if <[entity_type]> == player && <[skin_type]> == blob:
    - adjust <[created]> skin_blob:<[skin].get[value]>
  - else if <[entity_type]> == player && <[skin_type]> == file:
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
  - narrate "<gold>Тип сущности<&co> <white><[npc_data].get[entity_type]||player>" targets:<[actor]>
  - narrate "<gold>Диалог<&co> <white><[npc_data].get[dialog]>" targets:<[actor]>
  - narrate "<gold>Скин<&co> <white><[npc_data].get[skin].get[type]> / <[npc_data].get[skin].get[model]>" targets:<[actor]>
  - if <[created]> != null && <server.npcs.contains[<[created]>]>:
    - narrate "<gold>Citizens ID<&co> <white><[created].id>" targets:<[actor]>
  - else:
    - narrate "<gray>NPC ещё не создан в мире." targets:<[actor]>

marallyzen_story_choice_ui_show:
  type: task
  debug: false
  definitions: viewer|session_key|choices
  script:
  - if !<[viewer].is_online||false> || <[viewer].flag[marallyzen_story_session.key]||null> != <[session_key]>:
    - stop
  - run marallyzen_story_choice_ui_clear def:<[viewer]>
  - define session <[viewer].flag[marallyzen_story_session]>
  - define npc_entity <[session].get[npc]||null>
  - if <[npc_entity]> != null && <[npc_entity].is_spawned||false>:
    - define anchor <[npc_entity].location.add[0,1.85,0]>
    - define facing <[anchor].face[<[viewer].eye_location>]>
    - define side_point <[facing].with_yaw[<[facing].yaw.sub[90]>].forward_flat[1]>
    - define side_vector <[side_point].sub[<[anchor]>]>
    - define base <[anchor].add[<[side_vector].mul[1.65]>]>
  - else:
    - define base <[viewer].eye_location.forward[3].add[0,0.5,0]>
    - define facing <[base].face[<[viewer].eye_location>]>
    - define side_point <[facing].with_yaw[<[facing].yaw.sub[90]>].forward_flat[1]>
    - define side_vector <[side_point].sub[<[base]>]>
  # A TextDisplay's alignment does not move its centered transform origin.
  # Keep the group centered, then offset every line by half its pixel width so
  # all visible left edges share the same world-space anchor.
  - define half_pixel_scale 0.009
  - define max_text_width 0
  - foreach <[choices]> as:choice:
    - define measure_label <[choice].get[text].parse_color.strip_color>
    - define measure_text <element[<[loop_index]>. <[measure_label]>]>
    - define measure_width <[measure_text].text_width>
    - if <[measure_width]> > <[max_text_width]>:
      - define max_text_width <[measure_width]>
  - define left_origin <[base].add[<[side_vector].mul[<[max_text_width].mul[<[half_pixel_scale]>].mul[-1]>]>]>
  - define ui_entities <list[]>
  - define interactions <list[]>
  - foreach <[choices]> key:choice_id as:choice:
    - define index <[loop_index]>
    - define label <[choice].get[text].parse_color.strip_color>
    - define y_offset <[index].sub[1].mul[-0.34]>
    - define line_origin <[left_origin].add[0,<[y_offset]>,0]>
    - define normal_text <element[<[index]>. <[label]>]>
    - define center_offset <[normal_text].text_width.mul[<[half_pixel_scale]>]>
    - define display_location <[line_origin].add[<[side_vector].mul[<[center_offset]>]>]>
    - spawn text_display <[display_location]> save:story_choice_text
    - define display <entry[story_choice_text].spawned_entity>
    - adjust <[display]> text:<[normal_text].color[white]>
    - adjust <[display]> pivot:center
    - adjust <[display]> display:left
    - adjust <[display]> line_width:1000
    - adjust <[display]> default_background:false
    - adjust <[display]> background_color:<color[transparent]>
    - adjust <[display]> text_shadowed:true
    - adjust <[display]> opacity:255
    - adjust <[display]> see_through:false
    - adjust <[display]> scale:<location[0.72,0.72,0.72]>
    - spawn interaction[width=3.4;height=0.34;is_aware=true] <[base].add[0,<[y_offset].sub[0.17]>,0]> save:story_choice_hitbox
    - define hitbox <entry[story_choice_hitbox].spawned_entity>
    - flag <[display]> marallyzen_story_choice_ui:true
    - flag <[hitbox]> marallyzen_story_choice_ui:true
    - flag <[hitbox]> marallyzen_story_choice_owner:<[viewer].uuid>
    - flag <[hitbox]> marallyzen_story_choice_session:<[session_key]>
    - flag <[hitbox]> marallyzen_story_choice_id:<[choice_id]>
    - flag <[hitbox]> marallyzen_story_choice_index:<[index]>
    - flag <[hitbox]> marallyzen_story_choice_label:<[label]>
    - flag <[hitbox]> marallyzen_story_choice_display:<[display]>
    - flag <[hitbox]> marallyzen_story_choice_origin:<[line_origin]>
    - flag <[hitbox]> marallyzen_story_choice_side:<[side_vector]>
    - adjust <[display]> hide_from_players
    - adjust <[hitbox]> hide_from_players
    - adjust <[viewer]> show_entity:<[display]>
    - adjust <[viewer]> show_entity:<[hitbox]>
    - define ui_entities:->:<[display]>
    - define ui_entities:->:<[hitbox]>
    - define interactions:->:<[hitbox]>
    - flag server marallyzen_story_choice_ui_entities:->:<[display]>
    - flag server marallyzen_story_choice_ui_entities:->:<[hitbox]>
  - flag <[viewer]> marallyzen_story_session.choice_ui:<[ui_entities]>
  - flag <[viewer]> marallyzen_story_session.choice_interactions:<[interactions]>
  - flag <[viewer]> marallyzen_story_session.selected_index:1
  - run marallyzen_story_choice_ui_select def:<[viewer]>|1

marallyzen_story_choice_ui_select:
  type: task
  debug: false
  definitions: viewer|requested_index
  script:
  - if !<[viewer].is_online||false> || <[viewer].flag[marallyzen_story_session.awaiting_choice]||false> != true:
    - stop
  - define interactions <[viewer].flag[marallyzen_story_session.choice_interactions]||<list[]>>
  - if <[interactions].is_empty>:
    - stop
  - define selected_index <[requested_index]>
  - if <[selected_index]> < 1:
    - define selected_index <[interactions].size>
  - else if <[selected_index]> > <[interactions].size>:
    - define selected_index 1
  - define previous_index <[viewer].flag[marallyzen_story_session.selected_index]||null>
  - if <[previous_index]> != null:
    - define previous <[interactions].get[<[previous_index]>]||null>
    - if <[previous]> != null && <[previous].is_spawned||false>:
      - define old_display <[previous].flag[marallyzen_story_choice_display]||null>
      - if <[old_display]> != null && <[old_display].is_spawned||false>:
        - define old_text <element[<[previous].flag[marallyzen_story_choice_index]>. <[previous].flag[marallyzen_story_choice_label]>]>
        - define old_offset <[old_text].text_width.mul[0.009]>
        - define old_location <[previous].flag[marallyzen_story_choice_origin].add[<[previous].flag[marallyzen_story_choice_side].mul[<[old_offset]>]>]>
        - teleport <[old_display]> <[old_location]>
        - adjust <[old_display]> text:<[old_text].color[white]>
        - adjust <[old_display]> background_color:<color[transparent]>
        - adjust <[old_display]> text_shadowed:true
  - define selected <[interactions].get[<[selected_index]>]>
  - if <[selected]> == null || !<[selected].is_spawned||false>:
    - stop
  - define new_display <[selected].flag[marallyzen_story_choice_display]||null>
  - if <[new_display]> == null || !<[new_display].is_spawned||false>:
    - stop
  - define selected_label <[selected].flag[marallyzen_story_choice_label].strip_color>
  - define selected_text <element[◀ <[selected_label]>]>
  - define selected_offset <[selected_text].text_width.mul[0.009]>
  - define selected_location <[selected].flag[marallyzen_story_choice_origin].add[<[selected].flag[marallyzen_story_choice_side].mul[<[selected_offset]>]>]>
  - teleport <[new_display]> <[selected_location]>
  - adjust <[new_display]> text:<[selected_text].color[#3A3A3A]>
  - adjust <[new_display]> background_color:<color[#F2B63DFF]>
  - adjust <[new_display]> text_shadowed:false
  - flag <[viewer]> marallyzen_story_session.selected_index:<[selected_index]>
  - flag <[viewer]> marallyzen_story_session.selected_choice:<[selected].flag[marallyzen_story_choice_id]>

marallyzen_story_choice_ui_clear:
  type: task
  debug: false
  definitions: viewer
  script:
  - define ui_entities <[viewer].flag[marallyzen_story_session.choice_ui]||<list[]>>
  - foreach <[ui_entities]> as:ui_entity:
    - if <[ui_entity].is_spawned||false>:
      - remove <[ui_entity]>
    - flag server marallyzen_story_choice_ui_entities:<-:<[ui_entity]>
  - flag <[viewer]> marallyzen_story_session.choice_ui:!
  - flag <[viewer]> marallyzen_story_session.choice_interactions:!
  - flag <[viewer]> marallyzen_story_session.selected_index:!
  - flag <[viewer]> marallyzen_story_session.selected_choice:!

marallyzen_story_choice_ui_cleanup_all:
  type: task
  debug: false
  script:
  - foreach <server.flag[marallyzen_story_choice_ui_entities]||<list[]>> as:ui_entity:
    - if <[ui_entity].is_spawned||false>:
      - remove <[ui_entity]>
  - flag server marallyzen_story_choice_ui_entities:!

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
  - define dialog_range 0
  - if <[npc_entity]> != null:
    - define npc_story_id <[npc_entity].flag[marallyzen_story_id]||null>
    - define npc_name <server.flag[marallyzen_story_runtime.npcs.<[npc_story_id]>.name]||Персонаж>
    - define dialog_range <server.flag[marallyzen_story_runtime.npcs.<[npc_story_id]>.dialog_range]||<script[marallyzen_story_config].data_key[default_dialog_range]>>
  - define start_node <[dialog].get[start]||start>
  - flag <[viewer]> marallyzen_story_session:map@[key=<[session_key]>;dialog=<[dialog_id]>;node=<[start_node]>;npc=<[npc_entity]>;default_speaker=<[npc_name]>;active_sound=null;awaiting_choice=false;transitions=0;max_distance=<[dialog_range]>]
  - if <[npc_entity]> != null:
    - run marallyzen_story_dialog_distance_watch def:<[viewer]>|<[session_key]>|<[npc_entity]>|<[dialog_range]>
  - run marallyzen_story_dialog_play_node def:<[viewer]>|<[session_key]>|<[dialog_id]>|<[start_node]>|<[npc_name]>

marallyzen_story_dialog_distance_watch:
  type: task
  debug: false
  definitions: viewer|session_key|npc_entity|max_distance
  script:
  - define check_rate <script[marallyzen_story_config].data_key[dialog_distance_check_rate]>
  - define check_ticks <[check_rate].as[duration].in_ticks>
  - define grace_ticks <script[marallyzen_story_config].data_key[dialog_distance_grace].as[duration].in_ticks>
  - define outside_ticks 0
  - while <[viewer].is_online||false> && <[viewer].flag[marallyzen_story_session.key]||null> == <[session_key]>:
    - if !<[npc_entity].is_spawned||false>:
      - run marallyzen_story_session_stop def:<[viewer]>|false|<element[<gray>Собеседник исчез. Диалог завершён.]>
      - stop
    - if <[viewer].world> != <[npc_entity].world>:
      - run marallyzen_story_session_stop def:<[viewer]>|false|<element[<gray>Вы отошли слишком далеко. Диалог завершён.]>
      - stop
    - define distance <[viewer].location.distance[<[npc_entity].location>]>
    - if <[distance]> > <[max_distance]>:
      - if <[outside_ticks]> == 0:
        - actionbar "<yellow>Вы отходите слишком далеко от собеседника..." targets:<[viewer]>
      - define outside_ticks <[outside_ticks].add[<[check_ticks]>]>
      - if <[outside_ticks]> >= <[grace_ticks]>:
        - run marallyzen_story_session_stop def:<[viewer]>|false|<element[<gray>Вы отошли дальше чем на <white><[max_distance]> <gray>блоков. Диалог завершён.]>
        - stop
    - else:
      - if <[outside_ticks]> > 0:
        - actionbar "" targets:<[viewer]>
      - define outside_ticks 0
    - wait <[check_rate]>

marallyzen_story_dialog_play_node:
  type: task
  debug: false
  definitions: viewer|session_key|dialog_id|node_id|default_speaker
  script:
  - if <[viewer].flag[marallyzen_story_session.key]||null> != <[session_key]>:
    - stop
  - define node <server.flag[marallyzen_story_runtime.dialogs.<[dialog_id]>.nodes.<[node_id]>]||null>
  - if <[node]> == null:
    - actionbar "<red>Ветка диалога повреждена." targets:<[viewer]>
    - run marallyzen_story_choice_ui_clear def:<[viewer]>
    - flag <[viewer]> marallyzen_story_session:!
    - stop
  - define transitions <[viewer].flag[marallyzen_story_session.transitions]||0>
  - define transitions <[transitions].add[1]>
  - if <[transitions]> > 64:
    - actionbar "<red>Диалог остановлен: слишком много автоматических переходов." targets:<[viewer]>
    - run marallyzen_story_choice_ui_clear def:<[viewer]>
    - flag <[viewer]> marallyzen_story_session:!
    - stop
  - flag <[viewer]> marallyzen_story_session.node:<[node_id]>
  - flag <[viewer]> marallyzen_story_session.transitions:<[transitions]>
  - flag <[viewer]> marallyzen_story_session.awaiting_choice:false
  - define lines <[node].get[lines]||<list[]>>
  - foreach <[lines]> as:line_data:
    - if <[viewer].flag[marallyzen_story_session.key]||null> != <[session_key]>:
      - stop
    - define pause <[line_data].get[pause]||null>
    - if <[pause]> != null:
      - wait <[pause].as[duration]>
      - foreach next
    - define audio_id <[line_data].get[audio]||null>
    - define text <[line_data].get[text]||null>
    - define speaker <[line_data].get[speaker]||<[default_speaker]>>
    - define duration <[line_data].get[duration]||40t>
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
  - if <[viewer].flag[marallyzen_story_session.key]||null> != <[session_key]>:
    - stop
  - define choices <[node].get[choices]||<map[]>>
  - if !<[choices].is_empty>:
    - flag <[viewer]> marallyzen_story_session.awaiting_choice:true
    - flag <[viewer]> marallyzen_story_session.available_choices:<[choices].keys>
    - actionbar "" targets:<[viewer]>
    - run marallyzen_story_choice_ui_show def:<[viewer]>|<[session_key]>|<[choices]>
    - stop
  - define next <[node].get[next]||end>
  - if <[next]> != end:
    - run marallyzen_story_dialog_play_node def:<[viewer]>|<[session_key]>|<[dialog_id]>|<[next]>|<[default_speaker]>
    - stop
  - actionbar "" targets:<[viewer]>
  - run marallyzen_story_choice_ui_clear def:<[viewer]>
  - flag <[viewer]> marallyzen_story_session:!

marallyzen_story_session_stop:
  type: task
  debug: false
  definitions: viewer|notify|reason
  script:
  - define session <[viewer].flag[marallyzen_story_session]||null>
  - if <[session]> == null:
    - if <[notify]> == true:
      - actionbar "<gray>Активного диалога нет." targets:<[viewer]>
    - stop
  - run marallyzen_story_choice_ui_clear def:<[viewer]>
  - define sound_id <[session].get[active_sound]||null>
  - if <[sound_id]> != null:
    - execute as_server "minecraft:stopsound <[viewer].name> voice <[sound_id].parsed>" silent
  - flag <[viewer]> marallyzen_story_session:!
  - actionbar "" targets:<[viewer]>
  - if <[reason]||null> != null:
    - actionbar <[reason]> targets:<[viewer]>
  - else if <[notify]> == true:
    - actionbar "<gray>Диалог остановлен." targets:<[viewer]>
