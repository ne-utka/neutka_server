# Marallyzen camera cutscenes.
#
# Recording samples the administrator's eye location into queue memory and
# writes the complete path to server flags only once. Playback uses a transient
# item display as a camera and stores persistent recovery data before touching
# the viewer, so reloads, restarts and reconnects cannot strand a player.

marallyzen_cutscene_config:
  type: data
  debug: false
  admin_permission: marallyzen.cutscene.admin
  default_record_seconds: 30
  max_record_seconds: 300
  max_loaded_chunks: 48
  sample_interval: 1t
  camera_interpolation: 2t
  actor_record_radius: 48
  max_recorded_actors: 8

marallyzen_cutscene_events:
  type: world
  debug: false
  events:
    on reload scripts:
    - run marallyzen_cutscene_cleanup_orphan_actors
    - foreach <server.online_players> as:viewer:
      - flag <[viewer]> marallyzen_cutscene_recording:!
      - if <[viewer].has_flag[marallyzen_cutscene_recovery]>:
        - run marallyzen_cutscene_restore def:<[viewer]>|<[viewer].flag[marallyzen_cutscene_recovery.id]||null>|recovery delay:1t

    on player joins:
    - flag player marallyzen_cutscene_recording:!
    - if <player.has_flag[marallyzen_cutscene_recovery]>:
      - run marallyzen_cutscene_restore def:<player>|<player.flag[marallyzen_cutscene_recovery.id]||null>|recovery delay:3t

    on player quits:
    - flag player marallyzen_cutscene_recording:!
    - if <player.has_flag[marallyzen_cutscene_recovery]>:
      - define camera <player.flag[marallyzen_cutscene_recovery.camera]||null>
      - if <[camera]> != null:
        - if <[camera].is_spawned||false>:
          - remove <[camera]>
      - foreach <player.flag[marallyzen_cutscene_recovery.actors]||<list[]>> as:actor_npc:
        - if <server.npcs.contains[<[actor_npc]>]>:
          - remove <[actor_npc]>
      # Keep recovery persistent. The join event restores location and mode.
      - flag player marallyzen_cutscene_session:!

    # A short-lived marker lets the recorder sample discrete arm animations
    # without installing packet listeners or writing any per-tick server flags.
    on player animates:
    - flag player marallyzen_cutscene_last_animation:<context.animation> expire:2t

    # Shift is the universal, discoverable skip input. Cancelling the sneak
    # event also prevents vanilla from dismounting the camera before cleanup.
    on player starts sneaking:
    - if !<player.has_flag[marallyzen_cutscene_session]>:
      - stop
    - determine passively cancelled
    - flag player marallyzen_cutscene_session.cancel_requested:true
    - actionbar "<gray>Завершаем кат-сцену..." targets:<player>

marallyzen_cutscene_command:
  type: command
  debug: false
  name: cutscene
  aliases:
  - cuts
  description: Записывает и воспроизводит кат-сцены Marallyzen.
  usage: /cutscene record [name] [seconds] | stop | play [name] [player] | cancel [player] | list | info [name] | delete [name]
  permission: marallyzen.cutscene.admin
  tab completions:
    1: record|stop|play|cancel|list|info|delete
    2: <proc[marallyzen_cutscene_tab_second].context[<context.args.get[1]||null>]>
    3: <proc[marallyzen_cutscene_tab_third].context[<context.args.get[1]||null>]>
  script:
  - define action <context.args.get[1].to_lowercase||help>
  - choose <[action]>:
    - case record:
      - if <context.server>:
        - narrate "<red>Запись можно начать только от имени игрока."
        - stop
      - if <player.has_flag[marallyzen_cutscene_recording]> || <player.has_flag[marallyzen_cutscene_recovery]>:
        - narrate "<red>Вы уже записываете или смотрите кат-сцену."
        - stop
      - define name <context.args.get[2].to_lowercase||null>
      - if <[name]> == null || !<[name].regex_matches[^[a-z0-9_-]{1,32}$]>:
        - narrate "<red>Название: 1–32 латинских символа, цифры, _ или -."
        - stop
      - if <server.has_flag[marallyzen_cutscenes.<[name]>]>:
        - narrate "<red>Запись <white><[name]><red> уже существует. Сначала удалите её."
        - stop
      - define seconds <context.args.get[3]||<script[marallyzen_cutscene_config].data_key[default_record_seconds]>>
      - if !<[seconds].regex_matches[^[0-9]+$]>:
        - narrate "<red>Продолжительность должна быть целым числом секунд."
        - stop
      - define max_seconds <script[marallyzen_cutscene_config].data_key[max_record_seconds]>
      - if <[seconds]> < 1 || <[seconds]> > <[max_seconds]>:
        - narrate "<red>Допустимая продолжительность: от 1 до <[max_seconds]> секунд."
        - stop
      - define session <util.random_uuid>
      - flag player marallyzen_cutscene_recording:map@[id=<[session]>;name=<[name]>;action=active]
      - run marallyzen_cutscene_record def:<player>|<[name]>|<[seconds].mul[20]>|<[session]> player:<player>
      - narrate "<gray>Подготовка записи <white><[name]><gray>. Для остановки: <white>/cutscene stop<gray>."

    - case stop:
      - if <context.server>:
        - narrate "<red>Команда доступна только игроку, который ведёт запись."
        - stop
      - if !<player.has_flag[marallyzen_cutscene_recording]>:
        - narrate "<yellow>Вы ничего не записываете."
        - stop
      - flag player marallyzen_cutscene_recording.action:save
      - narrate "<gray>Останавливаем и сохраняем запись..."

    - case play:
      - define name <context.args.get[2].to_lowercase||null>
      - if <[name]> == null || !<server.has_flag[marallyzen_cutscenes.<[name]>]>:
        - narrate "<red>Такой кат-сцены не существует."
        - stop
      - define target_name <context.args.get[3]||null>
      - if <[target_name]> == null:
        - if <context.server>:
          - narrate "<red>Из консоли обязательно укажите игрока."
          - stop
        - define viewer <player>
      - else:
        - define viewer <server.match_player[<[target_name]>]||null>
      - if <[viewer]> == null:
        - narrate "<red>Игрок не найден или не в сети."
        - stop
      - if !<[viewer].is_online||false>:
        - narrate "<red>Игрок не найден или не в сети."
        - stop
      - if <[viewer].has_flag[marallyzen_cutscene_recording]> || <[viewer].has_flag[marallyzen_cutscene_recovery]>:
        - narrate "<red>Этот игрок уже записывает или смотрит кат-сцену."
        - stop
      - run marallyzen_cutscene_play def:<[viewer]>|<[name]>|<player||null> player:<[viewer]>
      - narrate "<green>Запущена кат-сцена <white><[name]><green> для <white><[viewer].name><green>."

    - case cancel:
      - define target_name <context.args.get[2]||null>
      - if <[target_name]> == null:
        - if <context.server>:
          - narrate "<red>Из консоли обязательно укажите игрока."
          - stop
        - define viewer <player>
      - else:
        - define viewer <server.match_player[<[target_name]>]||null>
      - if <[viewer]> == null:
        - narrate "<red>Игрок не найден или не в сети."
        - stop
      - if !<[viewer].is_online||false>:
        - narrate "<red>Игрок не найден или не в сети."
        - stop
      - if <[viewer].has_flag[marallyzen_cutscene_recording]>:
        - flag <[viewer]> marallyzen_cutscene_recording.action:discard
        - narrate "<yellow>Запись игрока <white><[viewer].name><yellow> отменена без сохранения."
        - stop
      - if <[viewer].has_flag[marallyzen_cutscene_session]>:
        - flag <[viewer]> marallyzen_cutscene_session.cancel_requested:true
        - narrate "<yellow>Воспроизведение для <white><[viewer].name><yellow> отменяется."
        - stop
      - narrate "<yellow>У игрока нет активной кат-сцены."

    - case list:
      - define records <server.flag[marallyzen_cutscenes]||<map[]>>
      - if <[records].is_empty>:
        - narrate "<yellow>Сохранённых кат-сцен пока нет."
        - stop
      - narrate "<gold>Кат-сцены Marallyzen:"
      - foreach <[records].keys.alphabetical> as:name:
        - define frames <[records].get[<[name]>].get[frame_count]||0>
        - define seconds <[frames].div[20].round_to[1]>
        - define play_button <element[▶].on_hover[<&gray>Воспроизвести себе].on_click[/cutscene play <[name]>]>
        - define info_button <element[ⓘ].on_hover[<&gray>Информация].on_click[/cutscene info <[name]>]>
        - narrate "<gray>• <white><[name]> <dark_gray>— <gray><[seconds]> с. <green><[play_button]> <aqua><[info_button]>"

    - case info:
      - define name <context.args.get[2].to_lowercase||null>
      - define record <server.flag[marallyzen_cutscenes.<[name]>]||null>
      - if <[record]> == null:
        - narrate "<red>Такой кат-сцены не существует."
        - stop
      - define frames <[record].get[frame_count]||<[record].get[frames].size||0>>
      - define actors <[record].get[actor_profiles].size||0>
      - narrate "<gold>Кат-сцена: <white><[name]>"
      - narrate "<gray>Длительность: <white><[frames].div[20].round_to[2]> с. <dark_gray>(<[frames]> кадров)"
      - narrate "<gray>Записано актёров: <white><[actors]>"
      - narrate "<gray>Мир: <white><[record].get[world]||неизвестно>"
      - narrate "<gray>Создатель UUID: <white><[record].get[creator]||неизвестно>"

    - case delete:
      - define name <context.args.get[2].to_lowercase||null>
      - if <[name]> == null || !<server.has_flag[marallyzen_cutscenes.<[name]>]>:
        - narrate "<red>Такой кат-сцены не существует."
        - stop
      - flag server marallyzen_cutscenes.<[name]>:!
      - narrate "<green>Кат-сцена <white><[name]><green> удалена."

    - default:
      - narrate "<gold>/cutscene record [name] [seconds] <gray>— начать запись"
      - narrate "<gold>/cutscene stop <gray>— сохранить текущую запись"
      - narrate "<gold>/cutscene play [name] [player] <gray>— воспроизвести"
      - narrate "<gold>/cutscene cancel [player] <gray>— отменить запись или просмотр"
      - narrate "<gold>/cutscene list <gray>— список записей"
      - narrate "<gold>/cutscene info [name] <gray>— информация"
      - narrate "<gold>/cutscene delete [name] <gray>— удалить"

marallyzen_cutscene_tab_second:
  type: procedure
  debug: false
  definitions: action
  script:
  - define action <[action].to_lowercase||null>
  - if <list[play|info|delete].contains[<[action]>]>:
    - determine <server.flag[marallyzen_cutscenes].keys||<list[]>>
  - if <[action]> == cancel:
    - determine <server.online_players.parse[name]>
  - if <[action]> == record:
    - determine название
  - determine <list[]>

marallyzen_cutscene_tab_third:
  type: procedure
  debug: false
  definitions: action
  script:
  - define action <[action].to_lowercase||null>
  - if <[action]> == play:
    - determine <server.online_players.parse[name]>
  - if <[action]> == record:
    - determine 10|30|60|120
  - determine <list[]>

marallyzen_cutscene_record:
  type: task
  debug: false
  definitions: recorder|name|max_frames|session
  script:
  - repeat 3 as:countdown:
    - if <[recorder].flag[marallyzen_cutscene_recording.id]||null> != <[session]>:
      - stop
    - define remaining <element[4].sub[<[countdown]>]>
    - actionbar "<gray>Запись начнётся через <white><[remaining]>..." targets:<[recorder]>
    - wait 1s
  - if <[recorder].flag[marallyzen_cutscene_recording.id]||null> != <[session]>:
    - stop
  - actionbar "<green>Запись началась! <gray>/cutscene stop — сохранить" targets:<[recorder]>
  - define frames <list[]>
  - define actor_frames <list[]>
  - define actor_profiles <map[]>
  - define record_world <[recorder].location.world.name>
  - define world_changed false
  - define actor_radius <script[marallyzen_cutscene_config].data_key[actor_record_radius]>
  - define max_actors <script[marallyzen_cutscene_config].data_key[max_recorded_actors]>
  - repeat <[max_frames]> as:frame_index:
    - define state <[recorder].flag[marallyzen_cutscene_recording]||null>
    - if <[state]> == null:
      - repeat stop
    - if <[state].get[id]||null> != <[session]>:
      - repeat stop
    - if <[state].get[action]||active> != active:
      - repeat stop
    - if !<[recorder].is_online||false>:
      - repeat stop
    - if <[recorder].location.world.name> != <[record_world]>:
      - define world_changed true
      - repeat stop
    - define frames:->:<[recorder].eye_location>
    - define actor_frame <map[]>
    - foreach <[recorder].location.find_players_within[<[actor_radius]>]> as:actor:
      - if <[actor]> == <[recorder]>:
        - foreach next
      - define actor_id <[actor].uuid>
      - if !<[actor_profiles].contains[<[actor_id]>]>:
        - if <[actor_profiles].size> >= <[max_actors]>:
          - foreach next
        - definemap actor_profile:
            name: <[actor].name>
            skin_blob: <[actor].skin_blob>
            equipment: <[actor].equipment_map>
            hand: <[actor].item_in_hand>
            offhand: <[actor].item_in_offhand>
        - define actor_profiles <[actor_profiles].with[<[actor_id]>].as[<[actor_profile]>]>
      - definemap actor_state:
          location: <[actor].location>
          pose: <[actor].visual_pose>
          animation: <[actor].flag[marallyzen_cutscene_last_animation]||none>
      - define actor_frame <[actor_frame].with[<[actor_id]>].as[<[actor_state]>]>
    - define actor_frames:->:<[actor_frame]>
    - if <[frame_index].mod[10]> == 0:
      - actionbar "<gray>● Запись <white><[name]> <dark_gray>— <gray><[frame_index].div[20].round_to[1]> с. <dark_gray>• <gray>актёров: <white><[actor_profiles].size>" targets:<[recorder]>
    - wait <script[marallyzen_cutscene_config].data_key[sample_interval]>

  - define state <[recorder].flag[marallyzen_cutscene_recording]||null>
  - define final_action discard
  - if <[state]> != null:
    - if <[state].get[id]||null> == <[session]>:
      - define final_action <[state].get[action]||active>
      - flag <[recorder]> marallyzen_cutscene_recording:!
  - if <[final_action]> == discard:
    - if <[recorder].is_online||false>:
      - actionbar "<yellow>Запись отменена без сохранения." targets:<[recorder]>
    - stop
  - if <[frames].is_empty>:
    - if <[recorder].is_online||false>:
      - actionbar "<red>Не записано ни одного кадра." targets:<[recorder]>
    - stop
  - flag server marallyzen_cutscenes.<[name]>:map@[format_version=2;creator=<[recorder].uuid>;world=<[record_world]>;frame_count=<[frames].size>;frames=<[frames]>;actor_profiles=<[actor_profiles]>;actor_frames=<[actor_frames]>]
  - if <[recorder].is_online||false>:
    - actionbar "<green>Кат-сцена <white><[name]><green> сохранена: <white><[frames].size><green> кадров, <white><[actor_profiles].size><green> актёров." targets:<[recorder]>
    - if <[world_changed]>:
      - narrate "<yellow>Запись остановлена перед переходом в другой мир." targets:<[recorder]>

marallyzen_cutscene_play:
  type: task
  debug: false
  definitions: viewer|name|initiator
  script:
  - if !<[viewer].is_online||false> || <[viewer].has_flag[marallyzen_cutscene_recovery]>:
    - stop
  - define record <server.flag[marallyzen_cutscenes.<[name]>]||null>
  - if <[record]> == null:
    - actionbar "<red>Кат-сцена не найдена." targets:<[viewer]>
    - stop
  - define frames <[record].get[frames]||<list[]>>
  - define actor_profiles <[record].get[actor_profiles]||<map[]>>
  - define actor_frames <[record].get[actor_frames]||<list[]>>
  - if <[frames].is_empty>:
    - actionbar "<red>В кат-сцене нет кадров." targets:<[viewer]>
    - stop
  - define worlds <[frames].parse[world.name].deduplicate>
  - if <[worlds].size> != 1:
    - actionbar "<red>Кат-сцена содержит переход между мирами и не может быть проиграна." targets:<[viewer]>
    - stop
  - define chunks <[frames].parse[chunk].deduplicate>
  - define max_chunks <script[marallyzen_cutscene_config].data_key[max_loaded_chunks]>
  - if <[chunks].size> > <[max_chunks]>:
    - actionbar "<red>Маршрут слишком большой: <[chunks].size>/<[max_chunks]> чанков." targets:<[viewer]>
    - stop
  - chunkload <[chunks]> duration:<[frames].size.add[100]>t

  - define session <util.random_uuid>
  - define return_location <[viewer].location>
  - define return_gamemode <[viewer].gamemode>
  - define return_can_fly <[viewer].can_fly>
  - define return_flying <[viewer].is_flying>
  - flag <[viewer]> marallyzen_cutscene_recovery:map@[id=<[session]>;location=<[return_location]>;gamemode=<[return_gamemode]>;can_fly=<[return_can_fly]>;flying=<[return_flying]>;camera=null;actors=<list[]>;hidden_players=<list[]>]
  - flag <[viewer]> marallyzen_cutscene_session:map@[id=<[session]>;name=<[name]>;camera=null;cancel_requested=false;actors=<list[]>]

  # Poses use their own mounts. Clear them before attaching the camera so the
  # two systems cannot fight over the player's vehicle or visual metadata.
  - if <[viewer].has_flag[marallyzen_pose]>:
    - run marallyzen_pose_clear player:<[viewer]>
    - wait 2t
  - define first_frame <[frames].first>
  - spawn item_display[item=stone;display=fixed;pivot=center;scale=0,0,0;teleport_duration=<script[marallyzen_cutscene_config].data_key[camera_interpolation]>;interpolation_duration=<script[marallyzen_cutscene_config].data_key[camera_interpolation]>;view_range=32;shadow_radius=0] <[first_frame]> save:cutscene_camera
  - define camera <entry[cutscene_camera].spawned_entity||null>
  - if <[camera]> == null:
    - run marallyzen_cutscene_restore def:<[viewer]>|<[session]>|error
    - stop
  - if !<[camera].is_spawned||false>:
    - run marallyzen_cutscene_restore def:<[viewer]>|<[session]>|error
    - stop
  - adjust <[camera]> force_no_persist:true
  - adjust <[camera]> hide_from_players
  - adjust <[viewer]> show_entity:<[camera]>
  - flag <[camera]> marallyzen_cutscene_camera:<[session]>
  - flag <[viewer]> marallyzen_cutscene_session.camera:<[camera]>
  - flag <[viewer]> marallyzen_cutscene_recovery.camera:<[camera]>

  - adjust <[viewer]> hide_from_players
  - adjust <[viewer]> gamemode:spectator
  - mount <[viewer]>|<[camera]>
  - wait 1t
  - if <[viewer].flag[marallyzen_cutscene_session.id]||null> != <[session]>:
    - run marallyzen_cutscene_restore def:<[viewer]>|<[session]>|cancelled
    - stop
  - adjust <[viewer]> spectate:<[camera]>
  - actionbar "<gray>Кат-сцена <white><[name]> <dark_gray>• <gray>Shift — пропустить" targets:<[viewer]>

  - define cancelled false
  - define actor_npcs <map[]>
  - define actor_visibility <map[]>
  - define actor_last_animation <map[]>
  - foreach <[frames]> as:frame:
    - if !<[viewer].is_online||false>:
      - if <[camera].is_spawned||false>:
        - remove <[camera]>
      - flag <[viewer]> marallyzen_cutscene_session:!
      - stop
    - if <[viewer].flag[marallyzen_cutscene_session.id]||null> != <[session]>:
      - stop
    - if <[viewer].flag[marallyzen_cutscene_session.cancel_requested]||false>:
      - define cancelled true
      - foreach stop
    - teleport <[camera]> <[frame]>
    - define actor_frame <[actor_frames].get[<[loop_index]>]||<map[]>>

    # Hide clones that left the recorded radius at this exact frame.
    - foreach <[actor_npcs].keys> as:actor_id:
      - if !<[actor_frame].contains[<[actor_id]>]> && <[actor_visibility].get[<[actor_id]>]||false>:
        - adjust <[viewer]> hide_entity:<[actor_npcs].get[<[actor_id]>]>
        - define actor_visibility <[actor_visibility].with[<[actor_id]>].as[false]>

    # Create each clone lazily on its first recorded frame. The clone and the
    # hidden live original are both viewer-specific, so parallel viewings do
    # not leak actors into the normal world or interfere with one another.
    - foreach <[actor_frame].keys> as:actor_id:
      - define actor_state <[actor_frame].get[<[actor_id]>]>
      - define actor_npc <[actor_npcs].get[<[actor_id]>]||null>
      - if <[actor_npc]> == null:
        - define actor_profile <[actor_profiles].get[<[actor_id]>]||null>
        - if <[actor_profile]> == null:
          - foreach next
        - define actor_name <[actor_profile].get[name]||Actor>
        - create player <[actor_name]> <[actor_state].get[location]> save:cutscene_actor
        - define actor_npc <entry[cutscene_actor].created_npc||null>
        - if <[actor_npc]> == null:
          - foreach next
        - adjust <[actor_npc]> skin_blob:<[actor_profile].get[skin_blob].append[;<[actor_name]>]>
        - adjust <[actor_npc]> name_visible:false
        - adjust <[actor_npc]> set_protected:true
        - adjust <[actor_npc]> targetable:false
        - adjust <[actor_npc]> hide_from_players
        - adjust <[viewer]> show_entity:<[actor_npc]>
        - define equipment <[actor_profile].get[equipment]||<map[]>>
        - equip <[actor_npc]> hand:<[actor_profile].get[hand]||air> offhand:<[actor_profile].get[offhand]||air> head:<[equipment].get[helmet]||air> chest:<[equipment].get[chestplate]||air> legs:<[equipment].get[leggings]||air> boots:<[equipment].get[boots]||air>
        - flag <[actor_npc]> marallyzen_cutscene_actor:<[session]>
        - flag <[viewer]> marallyzen_cutscene_recovery.actors:->:<[actor_npc]>
        - flag <[viewer]> marallyzen_cutscene_session.actors:->:<[actor_npc]>
        - define actor_npcs <[actor_npcs].with[<[actor_id]>].as[<[actor_npc]>]>
        - define actor_visibility <[actor_visibility].with[<[actor_id]>].as[true]>
        - define real_actor <player[<[actor_id]>]>
        - if <[real_actor].is_online||false> && <[real_actor]> != <[viewer]>:
          - adjust <[viewer]> hide_entity:<[real_actor]>
          - flag <[viewer]> marallyzen_cutscene_recovery.hidden_players:->:<[real_actor]>
      - else if !<[actor_visibility].get[<[actor_id]>]||false>:
        - adjust <[viewer]> show_entity:<[actor_npc]>
        - define actor_visibility <[actor_visibility].with[<[actor_id]>].as[true]>
      - teleport <[actor_npc]> <[actor_state].get[location]>
      - adjust <[actor_npc]> visual_pose:<[actor_state].get[pose]||standing>
      - define animation <[actor_state].get[animation]||none>
      - define previous_animation <[actor_last_animation].get[<[actor_id]>]||none>
      - if <[animation]> != none && <[animation]> != <[previous_animation]>:
        - animate <[actor_npc]> animation:<[animation]> for:<[viewer]>
      - define actor_last_animation <[actor_last_animation].with[<[actor_id]>].as[<[animation]>]>
    - if <[loop_index].mod[20]> == 0:
      - actionbar "<gray>Кат-сцена <white><[name]> <dark_gray>• <gray>Shift — пропустить" targets:<[viewer]>
    - wait <script[marallyzen_cutscene_config].data_key[sample_interval]>
  - if <[cancelled]>:
    - run marallyzen_cutscene_restore def:<[viewer]>|<[session]>|cancelled
  - else:
    - run marallyzen_cutscene_restore def:<[viewer]>|<[session]>|completed

marallyzen_cutscene_restore:
  type: task
  debug: false
  definitions: viewer|session|reason
  script:
  - define recovery <[viewer].flag[marallyzen_cutscene_recovery]||null>
  - if <[recovery]> == null:
    - stop
  - if <[session]> != null && <[recovery].get[id]||null> != <[session]>:
    - stop
  - define camera <[recovery].get[camera]||<[viewer].flag[marallyzen_cutscene_session.camera]||null>>
  - define actors <[recovery].get[actors]||<list[]>>
  - define hidden_players <[recovery].get[hidden_players]||<list[]>>
  - if !<[viewer].is_online||false>:
    - if <[camera]> != null:
      - if <[camera].is_spawned||false>:
        - remove <[camera]>
    - foreach <[actors]> as:actor_npc:
      - if <server.npcs.contains[<[actor_npc]>]>:
        - remove <[actor_npc]>
    - flag <[viewer]> marallyzen_cutscene_session:!
    - stop

  # Detach the packet camera before restoring server state. The explicit mount
  # cancel prevents a lingering passenger relation if the camera still exists.
  - adjust <[viewer]> spectate:<[viewer]>
  - mount cancel <[viewer]>
  - adjust <[viewer]> gamemode:<[recovery].get[gamemode]||survival>
  - teleport <[viewer]> <[recovery].get[location]>
  - adjust <[viewer]> can_fly:<[recovery].get[can_fly]||false>
  - if <[recovery].get[flying]||false> && <[recovery].get[can_fly]||false>:
    - adjust <[viewer]> flying:true
  - else:
    - adjust <[viewer]> flying:false
  - adjust <[viewer]> show_to_players
  - foreach <[hidden_players]> as:hidden_player:
    - if <[hidden_player].is_online||false>:
      - adjust <[viewer]> show_entity:<[hidden_player]>
  - foreach <[actors]> as:actor_npc:
    - if <server.npcs.contains[<[actor_npc]>]>:
      - remove <[actor_npc]>
  - if <[camera]> != null:
    - if <[camera].is_spawned||false>:
      - remove <[camera]>
  - flag <[viewer]> marallyzen_cutscene_session:!
  - flag <[viewer]> marallyzen_cutscene_recovery:!
  - choose <[reason]>:
    - case completed:
      - actionbar "<gray>Кат-сцена завершена." targets:<[viewer]>
    - case cancelled:
      - actionbar "<yellow>Кат-сцена пропущена." targets:<[viewer]>
    - case error:
      - actionbar "<red>Кат-сцена остановлена из-за ошибки камеры." targets:<[viewer]>
    - default:
      - actionbar "<gray>Состояние после кат-сцены восстановлено." targets:<[viewer]>

marallyzen_cutscene_cleanup_orphan_actors:
  type: task
  debug: false
  script:
  - foreach <server.npcs> as:actor_npc:
    - if <[actor_npc].has_flag[marallyzen_cutscene_actor]>:
      - remove <[actor_npc]>
