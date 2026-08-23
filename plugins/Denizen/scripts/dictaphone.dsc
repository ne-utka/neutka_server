# Marallyzen server-side dictaphones for Paper 26.1.2 + Denizen 1.3.2-b7286M-DEV.
# No Citizens, Depenizen or client mod is required.
# Persistent records are stored under server flag "marallyzen_dictaphones".
#
# Every placed dictaphone stores its own resource-pack sound and exact playback
# duration. Sound is sent only to the player who activated the dictaphone.

marallyzen_dictaphone_config:
  type: data
  debug: false
  use_permission: marallyzen.dictaphone.use
  admin_permission: marallyzen.dictaphone.admin
  view_distance: 1.5
  start_sound: marallyzen:dictophone_start
  start_duration: 10t
  stop_sound: marallyzen:dictophone_stop
  stop_duration: 19t
  # Add future recordings here. The key is what admins type after "spawn".
  # Duration is rounded up to a whole server tick so sounds never overlap.
  audio_files:
    05_dictaphone_prompt:
      sound_id: marallyzen:quest/test_world_quest/05_dictaphone_prompt
      duration: 75t
    06_dictaphone_done_1:
      sound_id: marallyzen:quest/test_world_quest/06_dictaphone_done_1
      duration: 32t
    07_dictaphone_done_2:
      sound_id: marallyzen:quest/test_world_quest/07_dictaphone_done_2
      duration: 27t
  # Five three-tick client-interpolated beats: 0.75 seconds total. This keeps
  # the motion responsive while still leaving enough frames for a cinematic
  # launch, controlled overshoot and settle.
  animation_step: 3t
  # X and Y wind angles in degrees, followed by client interpolation time.
  sway_frames:
  - "0.000,3.600,12t"
  - "1.650,3.050,11t"
  - "2.450,1.150,13t"
  - "2.100,-0.750,12t"
  - "1.050,-2.400,11t"
  - "0.000,-3.600,12t"
  - "-1.750,-2.950,13t"
  - "-2.550,-1.000,11t"
  - "-2.050,0.850,12t"
  - "-1.000,2.550,13t"

marallyzen_dictaphone_command:
  type: command
  debug: false
  name: dictaphone
  aliases:
  - dict
  description: Управление серверными диктофонами Marallyzen
  usage: /dictaphone spawn [audio_file] | narration [set|add|speaker|list|clear] [audio_file] [text] | remove | info | rebuild | cancel
  permission: marallyzen.dictaphone.use
  permission message: <red>Недостаточно прав.
  tab complete:
  - define admin <context.server>
  - if !<[admin]>:
    - define admin <player.is_op.or[<player.has_permission[marallyzen.dictaphone.admin]>]>
  - if <context.args.size> <= 1:
    - if <[admin]>:
      - determine spawn|narration|remove|info|rebuild|cancel
    - determine info|cancel
  - if <context.args.size> == 2 && <context.args.get[1].to_lowercase||null> == spawn && <[admin]>:
    - determine <script[marallyzen_dictaphone_config].data_key[audio_files].keys>
  - if <context.args.size> == 2 && <context.args.get[1].to_lowercase||null> == narration && <[admin]>:
    - determine set|add|speaker|list|clear
  - if <context.args.size> == 3 && <context.args.get[1].to_lowercase||null> == narration && <[admin]>:
    - determine <script[marallyzen_dictaphone_config].data_key[audio_files].keys>
  - determine <list[]>
  script:
  - define sub <context.args.get[1].to_lowercase||help>
  - if <[sub]> == cancel:
    - if <player.exists||false>:
      - run marallyzen_dictaphone_close def:<player>|true
    - stop
  - if <[sub]> == info:
    - if !<player.exists||false>:
      - narrate "Команда доступна только игроку."
      - stop
    - define target <player.eye_location.ray_trace_target[range=6;entities=item_display|interaction].hit_entity||null>
    - define id <[target].flag[dictaphone_id]||null>
    # A floor display is commonly occluded by its supporting block during ray
    # tracing. The support carries the same persistent ID, so use it as the
    # precise fallback for commands aimed at a stationary dictaphone.
    - if <[id]> == null:
      - define support <player.eye_location.ray_trace[range=6;return=block]||null>
      - define id <[support].flag[marallyzen_dictaphone_id]||null>
    - if <[id]> == null:
      - narrate "<yellow>Посмотрите на диктофон в пределах 6 блоков."
      - stop
    - define record <server.flag[marallyzen_dictaphones.<[id]>]||null>
    - if <[record]> == null:
      - narrate "<red>Запись диктофона не найдена."
      - stop
    - narrate "<gold>ID<&co> <white><[id]>"
    - narrate "<gold>Аудиофайл<&co> <white><[record].get[audio_file]||не назначен>"
    - narrate "<gold>Sound ID<&co> <white><[record].get[sound_id]||не назначен>"
    - narrate "<gold>Длительность<&co> <white><[record].get[sound_duration]||не назначена>"
    - narrate "<gold>Создатель<&co> <white><[record].get[creator]||неизвестен>"
    - stop
  - define admin true
  - if <player.exists||false>:
    - define admin <player.is_op.or[<player.has_permission[marallyzen.dictaphone.admin]>]>
  - if !<[admin]>:
    - narrate "<red>Нужно право marallyzen.dictaphone.admin или OP."
    - stop
  - choose <[sub]>:
    - case spawn:
      - if !<player.exists||false>:
        - narrate "Команда доступна только игроку."
        - stop
      - define audio_key <context.args.get[2]||null>
      - if <[audio_key]> == null:
        - narrate "<red>Укажите аудиофайл из подсказки команды."
        - narrate "<gray>Пример<&co> <white>/dictaphone spawn 05_dictaphone_prompt"
        - stop
      - define audio_key <[audio_key].to_lowercase.replace[.ogg].with[]>
      - define audio_catalog <script[marallyzen_dictaphone_config].data_key[audio_files]>
      - define audio_data <[audio_catalog].get[<[audio_key]>]||null>
      - if <[audio_data]> == null:
        - narrate "<red>Укажите аудиофайл из подсказки команды."
        - narrate "<gray>Пример<&co> <white>/dictaphone spawn 05_dictaphone_prompt"
        - stop
      - define support <player.eye_location.ray_trace[range=6;return=block]||null>
      - if <[support]> == null || !<[support].material.is_solid>:
        - narrate "<yellow>Посмотрите на верхнюю грань твёрдого блока в пределах 6 блоков."
        - stop
      - if <[support].has_flag[marallyzen_dictaphone_id]>:
        - narrate "<red>На этом блоке уже стоит диктофон."
        - stop
      - run marallyzen_dictaphone_create def:<[support]>|<player>|<[audio_key]>|<[audio_data].get[sound_id]>|<[audio_data].get[duration]>
    - case narration:
      - define action <context.args.get[2].to_lowercase||help>
      - define audio_key <context.args.get[3].to_lowercase.replace[.ogg].with[]||null>
      - define audio_catalog <script[marallyzen_dictaphone_config].data_key[audio_files]>
      - if !<list[set|add|speaker|list|clear].contains[<[action]>]> || <[audio_key]> == null || !<[audio_catalog].contains[<[audio_key]>]>:
        - narrate "<gray>Настройка нарраций для записи<&co>"
        - narrate "<white>/dictaphone narration set <audio_file> <text> <gray>— заменить все реплики одной"
        - narrate "<white>/dictaphone narration add <audio_file> <text> <gray>— добавить следующую реплику"
        - narrate "<white>/dictaphone narration speaker <audio_file> <name> <gray>— белая подпись говорящего; <white>- <gray>скрывает её"
        - narrate "<white>/dictaphone narration list <audio_file> <gray>— показать настройку"
        - narrate "<white>/dictaphone narration clear <audio_file> <gray>— удалить наррацию"
        - stop
      - if <[action]> == list:
        - define lines <server.flag[marallyzen_dictaphone_narrations.<[audio_key]>.lines]||<list[]>>
        - define speaker <server.flag[marallyzen_dictaphone_narrations.<[audio_key]>.speaker]||без подписи>
        - narrate "<gray>Запись<&co> <white><[audio_key]>.ogg"
        - narrate "<gray>Говорящий<&co> <white><[speaker]>"
        - if <[lines].is_empty>:
          - narrate "<gray>Реплик пока нет."
        - else:
          - foreach <[lines]> as:line:
            - narrate "<gray><[loop_index]>. <white><[line].parse_color>"
        - stop
      - if <[action]> == clear:
        - flag server marallyzen_dictaphone_narrations.<[audio_key]>:!
        - narrate "<green>Наррация для <white><[audio_key]>.ogg <green>удалена."
        - stop
      - if <context.args.size> < 4:
        - narrate "<red>После имени аудио укажите текст."
        - stop
      - define text <context.args.get[4].to[last].space_separated||null>
      - if <[text]> == null:
        - narrate "<red>После имени аудио укажите текст."
        - stop
      - choose <[action]>:
        - case set:
          - flag server marallyzen_dictaphone_narrations.<[audio_key]>.lines:<list[<[text]>]>
          - narrate "<green>Наррация <white><[audio_key]>.ogg <green>заменена одной репликой."
        - case add:
          - flag server marallyzen_dictaphone_narrations.<[audio_key]>.lines:->:<[text]>
          - narrate "<green>Реплика добавлена к <white><[audio_key]>.ogg<green>."
        - case speaker:
          - if <[text]> == -:
            - flag server marallyzen_dictaphone_narrations.<[audio_key]>.speaker:!
            - narrate "<green>Подпись говорящего скрыта."
          - else:
            - flag server marallyzen_dictaphone_narrations.<[audio_key]>.speaker:<[text]>
            - narrate "<green>Говорящий для <white><[audio_key]>.ogg<green><&co> <white><[text]>"
    - case remove:
      - if !<player.exists||false>:
        - narrate "Команда доступна только игроку."
        - stop
      - define target <player.eye_location.ray_trace_target[range=6;entities=item_display|interaction].hit_entity||null>
      - define id <[target].flag[dictaphone_id]||null>
      - if <[id]> == null:
        - define support <player.eye_location.ray_trace[range=6;return=block]||null>
        - define id <[support].flag[marallyzen_dictaphone_id]||null>
      - if <[id]> == null:
        - narrate "<yellow>Посмотрите на диктофон в пределах 6 блоков."
        - stop
      - run marallyzen_dictaphone_remove def:<[id]>|<player>
    - case rebuild:
      - run marallyzen_dictaphone_rebuild
      - narrate "<green>Проверка и восстановление диктофонов запущены."
    - default:
      - narrate "<gold>/dictaphone spawn <white>[audio_file] <gray>— поставить диктофон с выбранной записью"
      - narrate "<gold>/dictaphone narration <white>[set|add|speaker|list|clear] [audio_file] <gray>— настроить наррацию"
      - narrate "<gold>/dictaphone remove <gray>— удалить диктофон, на который вы смотрите"
      - narrate "<gold>/dictaphone info | rebuild | cancel"

marallyzen_dictaphone_events:
  type: world
  debug: false
  events:
    on player right clicks interaction:
    - define id <context.entity.flag[dictaphone_id]||null>
    - if <[id]> == null:
      - stop
    - determine passively cancelled
    - ratelimit <player> 2t
    - if <context.entity.flag[dictaphone_role]||null> == session_interaction:
      - if <context.entity.flag[dictaphone_session_owner]||null> != <player.uuid>:
        - stop
      # The airborne dictaphone is presentation/playback state, not a toggle.
      # Ignore repeat clicks during both flight and viewing so an accidental
      # click can never interrupt the animation or put it back on the floor.
      - stop
    - run marallyzen_dictaphone_open def:<[id]>|<player>

    on player tries to attack interaction:
    - define id <context.entity.flag[dictaphone_id]||null>
    - if <[id]> == null:
      - stop
    - determine passively cancelled

    on player damages item_display:
    - define id <context.entity.flag[dictaphone_id]||null>
    - if <[id]> == null:
      - stop
    - determine passively cancelled

    on player breaks block:
    - define id <context.location.flag[marallyzen_dictaphone_id]||null>
    - if <[id]> == null:
      - stop
    - if !<player.is_op> && !<player.has_permission[marallyzen.dictaphone.admin]>:
      - determine cancelled
      - stop
    - run marallyzen_dictaphone_remove def:<[id]>|<player>

    on player quits:
    - run marallyzen_dictaphone_close def:<player>|false
    on player dies:
    - run marallyzen_dictaphone_close def:<player>|false
    on player changes world:
    - run marallyzen_dictaphone_close def:<player>|false
    on reload scripts:
    - foreach <server.online_players> as:viewer:
      - run marallyzen_dictaphone_close def:<[viewer]>|false
    - run marallyzen_dictaphone_rebuild delay:2t
    on server start:
    - run marallyzen_dictaphone_rebuild delay:2s
    on chunk loads:
    - ratelimit <context.chunk> 2s
    - run marallyzen_dictaphone_rebuild_chunk def:<context.chunk> delay:2t

marallyzen_dictaphone_create:
  type: task
  debug: false
  definitions: support|admin|audio_file|sound_id|sound_duration
  script:
  - if !<[support].material.is_solid>:
    - narrate "<red>Диктофону нужна твёрдая опора." targets:<[admin]>
    - stop
  - define id <util.random_uuid>
  - define yaw <[admin].location.yaw>
  # Item models are centred around model-space Y=8. The model starts at Y=0,
  # so its display origin is placed half a block above the supporting surface.
  - define position <[support].center.add[0,1,0].with_yaw[<[yaw]>].with_pitch[0]>
  - flag server marallyzen_dictaphones.<[id]>:map@[position=<[position]>;support=<[support]>;yaw=<[yaw]>;creator=<[admin].uuid>;audio_file=<[audio_file]>;sound_mode=local;sound_id=<[sound_id]>;sound_duration=<[sound_duration]>]
  - flag <[support]> marallyzen_dictaphone_id:<[id]>
  - run marallyzen_dictaphone_spawn_stationary def:<[id]>
  - playsound <[position]> sound:block_wood_place volume:0.55 pitch:1.35
  - narrate "<green>Диктофон установлен. <gray>Запись<&co> <white><[audio_file]>.ogg" targets:<[admin]>

marallyzen_dictaphone_spawn_stationary:
  type: task
  debug: false
  definitions: id
  script:
  - define record <server.flag[marallyzen_dictaphones.<[id]>]||null>
  - if <[record]> == null:
    - stop
  - define support <[record].get[support]>
  - if !<[support].chunk.is_loaded>:
    - stop
  - if !<[support].material.is_solid>:
    - run marallyzen_dictaphone_remove def:<[id]>|null
    - stop
  - if <server.has_flag[marallyzen_dictaphone_spawning.<[id]>]>:
    - stop
  - flag server marallyzen_dictaphone_spawning.<[id]>:true expire:2s
  - foreach <list[<[record].get[display]||null>|<[record].get[interaction]||null>]> as:old_entity:
    - if <[old_entity]> != null && <[old_entity].is_spawned||false>:
      - remove <[old_entity]>
  - define position <[support].center.add[0,1,0].with_yaw[<[record].get[yaw]||0>].with_pitch[0]>
  - flag server marallyzen_dictaphones.<[id]>.position:<[position]>
  - spawn item_display[item=paper[item_model=marallyzen:dictaphone_simple];display=fixed;pivot=fixed;scale=1,1,1;interpolation_duration=0t;teleport_duration=0t;view_range=32;shadow_radius=0] <[position]> persistent save:dictaphone_display
  - define display <entry[dictaphone_display].spawned_entity>
  - flag <[display]> dictaphone_id:<[id]>
  - flag <[display]> dictaphone_role:stationary_model
  - define hitbox_location <[support].center.add[0,0.5,0]>
  - spawn interaction[width=0.72;height=0.32;is_aware=true] <[hitbox_location]> persistent save:dictaphone_interaction
  - define interaction <entry[dictaphone_interaction].spawned_entity>
  - flag <[interaction]> dictaphone_id:<[id]>
  - flag <[interaction]> dictaphone_role:stationary_interaction
  - flag server marallyzen_dictaphones.<[id]>.display:<[display]>
  - flag server marallyzen_dictaphones.<[id]>.interaction:<[interaction]>
  - flag <[support]> marallyzen_dictaphone_id:<[id]>
  - flag server marallyzen_dictaphone_spawning.<[id]>:!

marallyzen_dictaphone_remove:
  type: task
  debug: false
  definitions: id|actor
  script:
  - define record <server.flag[marallyzen_dictaphones.<[id]>]||null>
  - if <[record]> == null:
    - stop
  - foreach <server.online_players> as:viewer:
    - if <[viewer].flag[marallyzen_dictaphone_session.dictaphone_id]||null> == <[id]>:
      - run marallyzen_dictaphone_close def:<[viewer]>|false
  - foreach <list[<[record].get[display]||null>|<[record].get[interaction]||null>]> as:entity:
    - if <[entity]> != null && <[entity].is_spawned||false>:
      - remove <[entity]>
  - define support <[record].get[support]>
  - flag <[support]> marallyzen_dictaphone_id:!
  - flag server marallyzen_dictaphones.<[id]>:!
  - if <[actor]> != null:
    - narrate "<green>Диктофон удалён." targets:<[actor]>

marallyzen_dictaphone_rebuild:
  type: task
  debug: false
  script:
  - foreach <server.flag[marallyzen_dictaphones].keys||<list[]>> as:id:
    - define record <server.flag[marallyzen_dictaphones.<[id]>]>
    # Safe defaults for legacy dictaphones placed before per-device audio.
    - if <[record].get[sound_mode]||null> == null:
      - flag server marallyzen_dictaphones.<[id]>.sound_mode:none
      - flag server marallyzen_dictaphones.<[id]>.sound_id:null
      - flag server marallyzen_dictaphones.<[id]>.sound_duration:null
      - flag server marallyzen_dictaphones.<[id]>.audio_file:null
    - define support <[record].get[support]>
    - if !<[support].chunk.is_loaded>:
      - foreach next
    - if !<[support].material.is_solid>:
      - run marallyzen_dictaphone_remove def:<[id]>|null
    - else:
      - run marallyzen_dictaphone_spawn_stationary def:<[id]>

marallyzen_dictaphone_rebuild_chunk:
  type: task
  debug: false
  definitions: loaded_chunk
  script:
  - foreach <server.flag[marallyzen_dictaphones].keys||<list[]>> as:id:
    - define record <server.flag[marallyzen_dictaphones.<[id]>]>
    - if <[record].get[support].chunk> != <[loaded_chunk]>:
      - foreach next
    - if <server.has_flag[marallyzen_dictaphone_spawning.<[id]>]>:
      - foreach next
    - if !<[record].get[support].material.is_solid>:
      - run marallyzen_dictaphone_remove def:<[id]>|null
    - else if !<[record].get[display].is_spawned||false> || !<[record].get[interaction].is_spawned||false>:
      - run marallyzen_dictaphone_spawn_stationary def:<[id]>

marallyzen_dictaphone_open:
  type: task
  debug: false
  definitions: id|viewer
  script:
  - if <[viewer].has_flag[marallyzen_dictaphone_opening]>:
    - stop
  - flag <[viewer]> marallyzen_dictaphone_opening expire:3s
  - if <[viewer].has_flag[marallyzen_dictaphone_session]>:
    - run marallyzen_dictaphone_close def:<[viewer]>|false
    - wait 1t
  - define record <server.flag[marallyzen_dictaphones.<[id]>]||null>
  - if <[record]> == null:
    - flag <[viewer]> marallyzen_dictaphone_opening:!
    - stop
  - if <[record].get[sound_id]||null> == null || <[record].get[sound_duration]||null> == null:
    - actionbar "<gray>В этом диктофоне нет записи." targets:<[viewer]>
    - flag <[viewer]> marallyzen_dictaphone_opening:!
    - stop
  - define stationary <[record].get[display]||null>
  - if !<[stationary].is_spawned||false>:
    - run marallyzen_dictaphone_spawn_stationary def:<[id]>
    - define stationary <server.flag[marallyzen_dictaphones.<[id]>.display]>
  - adjust <[viewer]> hide_entity:<[stationary]>
  - define origin <[record].get[position]>
  - define direction <[viewer].eye_location.sub[<[origin]>].normalize>
  - define view_distance <script[marallyzen_dictaphone_config].data_key[view_distance]>
  - define target <[origin].add[<[direction].mul[<[view_distance]>]>].add[0,0.5,0].face[<[viewer].eye_location>].with_pitch[0]>
  - define view_yaw <[target].yaw>
  - define view_origin <[origin].with_yaw[<[view_yaw]>].with_pitch[0]>
  - spawn item_display[item=paper[item_model=marallyzen:dictaphone];display=fixed;pivot=center;scale=0.96,0.96,0.96;interpolation_duration=5t;teleport_duration=5t;view_range=32;shadow_radius=0] <[view_origin]> save:view_model
  - define model <entry[view_model].spawned_entity||null>
  - if <[model]> == null || !<[model].is_spawned||false>:
    - adjust <[viewer]> show_entity:<[stationary]>
    - flag <[viewer]> marallyzen_dictaphone_opening:!
    - stop
  - flag <[model]> dictaphone_id:<[id]>
  - flag <[model]> dictaphone_role:session_model
  - flag <[model]> dictaphone_session_owner:<[viewer].uuid>
  - adjust <[model]> hide_from_players
  - adjust <[viewer]> show_entity:<[model]>
  - define interaction_location <[target].sub[0,0.18,0]>
  - spawn interaction[width=0.82;height=0.58;is_aware=true] <[interaction_location]> save:view_interaction
  - define interaction <entry[view_interaction].spawned_entity>
  - flag <[interaction]> dictaphone_id:<[id]>
  - flag <[interaction]> dictaphone_role:session_interaction
  - flag <[interaction]> dictaphone_session_owner:<[viewer].uuid>
  - adjust <[interaction]> hide_from_players
  - adjust <[viewer]> show_entity:<[interaction]>
  - define entities <list[<[model]>|<[interaction]>]>
  - define moving <list[<[model]>]>
  - define session_key <util.random_uuid>
  - flag <[viewer]> marallyzen_dictaphone_session:map@[session_key=<[session_key]>;dictaphone_id=<[id]>;stationary=<[stationary]>;entities=<[entities]>;moving=<[moving]>;model=<[model]>;interaction=<[interaction]>;origin=<[view_origin]>;target=<[target]>;busy=true;sway_frame=1;audio_file=<[record].get[audio_file]||unknown>;sound_mode=local;sound_id=<[record].get[sound_id]>;sound_duration=<[record].get[sound_duration]>;playback_finished=false]
  - flag <[viewer]> marallyzen_dictaphone_opening:!
  - run marallyzen_dictaphone_animate_out def:<[viewer]>

marallyzen_dictaphone_animate_out:
  type: task
  debug: false
  definitions: viewer
  script:
  - define session <[viewer].flag[marallyzen_dictaphone_session]||null>
  - if <[session]> == null:
    - stop
  - define origin <[session].get[origin]>
  - define target <[session].get[target]>
  - define delta <[target].sub[<[origin]>]>
  - define model <[session].get[model]>
  - define step <script[marallyzen_dictaphone_config].data_key[animation_step]>
  - adjust <[model]> teleport_duration:<[step]>
  - adjust <[model]> interpolation_duration:<[step]>
  # Keep the spawn and first movement packets separate to prevent the client
  # from visually skipping the launch beat.
  - wait 1t
  - if !<[viewer].has_flag[marallyzen_dictaphone_session]>:
    - stop
  # easeOutCubic-inspired travel with a compact vertical arc. The fourth beat
  # passes the target by 4%, then settles back; rotation and scale share the
  # same rhythm so the device feels like one solid object with real inertia.
  # travel progress, vertical arc, X rotation degrees, uniform scale
  - define frames <list[0.488,0.16,18,0.975|0.784,0.31,48,1.012|0.936,0.25,76,1.032|1.04,0.07,94,1.014|1,0,90,1]>
  - foreach <[frames]> as:frame:
    - define values <[frame].split[,]>
    - define frame_location <[origin].add[<[delta].mul[<[values].get[1]>]>].add[0,<[values].get[2]>,0]>
    - teleport <[session].get[moving]> <[frame_location]>
    - adjust <[model]> interpolation_start:0t
    # Marallyzen turns the top panel toward the camera with X=90 degrees and
    # simultaneously rolls it by Z=180 degrees. Without the Z rotation the
    # recorder arrives upside down.
    - define z_angle <[values].get[3].mul[2].to_radians>
    - adjust <[model]> left_rotation:<location[0,0,1].to_axis_angle_quaternion[<[z_angle]>]>
    - adjust <[model]> right_rotation:<location[1,0,0].to_axis_angle_quaternion[<[values].get[3].to_radians>]>
    - adjust <[model]> scale:<[values].get[4]>,<[values].get[4]>,<[values].get[4]>
    - wait <[step]>
    - if !<[viewer].has_flag[marallyzen_dictaphone_session]>:
      - stop
  - flag <[viewer]> marallyzen_dictaphone_session.busy:false
  - playsound <[viewer]> sound:block_iron_trapdoor_open volume:0.28 pitch:1.65
  - run marallyzen_dictaphone_session_monitor def:<[viewer]>|<[session].get[session_key]>
  - run marallyzen_dictaphone_playback_start def:<[viewer]>|<[session].get[session_key]>

marallyzen_dictaphone_session_monitor:
  type: task
  debug: false
  definitions: viewer|session_key
  script:
  - while <[viewer].is_online||false> && <[viewer].flag[marallyzen_dictaphone_session.session_key]||null> == <[session_key]>:
    - define session <[viewer].flag[marallyzen_dictaphone_session]>
    - if <[viewer].world> != <[session].get[target].world> || <[viewer].eye_location.distance[<[session].get[target]>]> > 5:
      - run marallyzen_dictaphone_close def:<[viewer]>|true
      - stop
    - define wait_time 2t
    - if !<[session].get[busy]>:
      - define frames <script[marallyzen_dictaphone_config].data_key[sway_frames]>
      - define frame_index <[session].get[sway_frame]||1>
      - define values <[frames].get[<[frame_index]>].split[,]>
      - define x_angle <element[90].add[<[values].get[1]>].to_radians>
      - define y_angle <[values].get[2]>
      - define wait_time <[values].get[3]>
      - adjust <[session].get[model]> interpolation_duration:<[wait_time]>
      - adjust <[session].get[model]> teleport_duration:<[wait_time]>
      - adjust <[session].get[model]> interpolation_start:0t
      # Keep the required 180-degree roll in model space. Horizontal wind is
      # expressed through display yaw so it composes cleanly with that roll.
      - adjust <[session].get[model]> left_rotation:<location[0,0,1].to_axis_angle_quaternion[3.141592654]>
      - adjust <[session].get[model]> right_rotation:<location[1,0,0].to_axis_angle_quaternion[<[x_angle]>]>
      - define sway_yaw <[session].get[target].yaw.add[<[y_angle]>]>
      - teleport <[session].get[model]> <[session].get[target].with_yaw[<[sway_yaw]>]>
      - define frame_index <[frame_index].add[1]>
      - if <[frame_index]> > <[frames].size>:
        - define frame_index 1
      - flag <[viewer]> marallyzen_dictaphone_session.sway_frame:<[frame_index]>
    - wait <[wait_time]>

marallyzen_dictaphone_close:
  type: task
  debug: false
  definitions: viewer|animate
  script:
  - define session <[viewer].flag[marallyzen_dictaphone_session]||null>
  - if <[session]> == null:
    - stop
  - if <[session].get[closing]||false>:
    - stop
  # Invalidate playback/monitor queues immediately, before the return animation
  # yields on its first wait. This prevents a late audio stage racing the close.
  - flag <[viewer]> marallyzen_dictaphone_session.closing:true
  - flag <[viewer]> marallyzen_dictaphone_session.session_key:<util.random_uuid>
  - flag <[viewer]> marallyzen_dictaphone_session.busy:true
  - run marallyzen_dictaphone_playback_stop def:<[viewer]>
  - define entities <[session].get[entities]>
  - if <[animate]> && <[viewer].is_online||false> && <[viewer].world> == <[session].get[origin].world>:
    - define model <[session].get[model]>
    - define origin <[session].get[origin]>
    - define target <[session].get[target]>
    - define return_delta <[origin].sub[<[target]>]>
    - define step <script[marallyzen_dictaphone_config].data_key[animation_step]>
    - define sway_frames <script[marallyzen_dictaphone_config].data_key[sway_frames]>
    - define wind_index <[session].get[sway_frame]||1>
    # A quick anticipation beat lifts the recorder a fraction before it dives
    # home. Live wind, face rotation and scale inertia all damp into the exact
    # stationary pose during the same five-beat cadence.
    # return progress, vertical arc, X rotation degrees, uniform scale
    - define return_frames <list[0.10,0.07,82,1.014|0.34,0.19,61,1.028|0.66,0.24,31,1.012|0.89,0.11,8,0.978|1,0,0,0.96]>
    - playsound <[viewer]> sound:block_iron_trapdoor_close volume:0.25 pitch:1.55
    - foreach <[return_frames]> as:frame:
      - define values <[frame].split[,]>
      - define damping <[values].get[3].div[90]>
      - define wind <[sway_frames].get[<[wind_index]>].split[,]>
      - define x_angle <[values].get[3].add[<[wind].get[1].mul[<[damping]>]>].to_radians>
      - define y_angle <[wind].get[2].mul[<[damping]>]>
      - define z_angle <[values].get[3].mul[2].to_radians>
      - define frame_location <[target].add[<[return_delta].mul[<[values].get[1]>]>].add[0,<[values].get[2]>,0]>
      - adjust <[model]> teleport_duration:<[step]>
      - adjust <[model]> interpolation_duration:<[step]>
      - adjust <[model]> interpolation_start:0t
      - adjust <[model]> left_rotation:<location[0,0,1].to_axis_angle_quaternion[<[z_angle]>]>
      - adjust <[model]> right_rotation:<location[1,0,0].to_axis_angle_quaternion[<[x_angle]>]>
      - adjust <[model]> scale:<[values].get[4]>,<[values].get[4]>,<[values].get[4]>
      - define return_yaw <[origin].yaw.add[<[y_angle]>]>
      - teleport <[session].get[moving]> <[frame_location].with_yaw[<[return_yaw]>]>
      - define wind_index <[wind_index].add[1]>
      - if <[wind_index]> > <[sway_frames].size>:
        - define wind_index 1
      - wait <[step]>
      - if !<[viewer].has_flag[marallyzen_dictaphone_session]>:
        - stop
    - playsound <[viewer]> sound:block_wood_place volume:0.35 pitch:1.55
  - foreach <[entities]> as:entity:
    - if <[entity].is_spawned||false>:
      - remove <[entity]>
  - define stationary <[session].get[stationary]||null>
  - if <[stationary]> != null && <[stationary].is_spawned||false>:
    - adjust <[viewer]> show_entity:<[stationary]>
  - flag <[viewer]> marallyzen_dictaphone_session:!

marallyzen_dictaphone_playback_start:
  type: task
  debug: false
  definitions: viewer|session_key
  script:
  - define session <[viewer].flag[marallyzen_dictaphone_session]||null>
  - if <[session]> == null || <[session].get[session_key]||null> != <[session_key]>:
    - stop
  - define start_sound <script[marallyzen_dictaphone_config].data_key[start_sound]>
  - define stop_sound <script[marallyzen_dictaphone_config].data_key[stop_sound]>
  - define sound_id <[session].get[sound_id]>
  # Mechanical start, selected lore recording, mechanical stop. Every wait is
  # followed by a session-key check so cancel/movement/reload cannot revive an
  # obsolete playback queue or close a newer dictaphone session.
  - execute as_server "execute at <[viewer].name> run minecraft:playsound <[start_sound].parsed> voice <[viewer].name> ~ ~ ~ 1 1 0" silent
  - wait <script[marallyzen_dictaphone_config].data_key[start_duration]>
  - if <[viewer].flag[marallyzen_dictaphone_session.session_key]||null> != <[session_key]>:
    - stop
  # The original NeoForge renderer enables DictaphoneBlock.ANIMATED exactly
  # while narration is active. Mirror that state by swapping only the displayed
  # ItemStack model; position, rotations and wind interpolation remain intact.
  - if <[session].get[model].is_spawned||false>:
    - adjust <[session].get[model]> item:paper[item_model=marallyzen:dictaphone_animation]
  - execute as_server "execute at <[viewer].name> run minecraft:playsound <[sound_id].parsed> voice <[viewer].name> ~ ~ ~ 1 1 0" silent
  - run marallyzen_dictaphone_narration def:<[viewer]>|<[session_key]>|<[session].get[audio_file]>|<[session].get[sound_duration]>
  - wait <[session].get[sound_duration]>
  - if <[viewer].flag[marallyzen_dictaphone_session.session_key]||null> != <[session_key]>:
    - stop
  - if <[session].get[model].is_spawned||false>:
    - adjust <[session].get[model]> item:paper[item_model=marallyzen:dictaphone]
  - execute as_server "execute at <[viewer].name> run minecraft:playsound <[stop_sound].parsed> voice <[viewer].name> ~ ~ ~ 1 1 0" silent
  - wait <script[marallyzen_dictaphone_config].data_key[stop_duration]>
  - if <[viewer].flag[marallyzen_dictaphone_session.session_key]||null> != <[session_key]>:
    - stop
  - flag <[viewer]> marallyzen_dictaphone_session.playback_finished:true
  - run marallyzen_dictaphone_close def:<[viewer]>|true

marallyzen_dictaphone_narration:
  type: task
  debug: false
  definitions: viewer|session_key|audio_file|sound_duration
  script:
  - define lines <server.flag[marallyzen_dictaphone_narrations.<[audio_file]>.lines]||<list[]>>
  - if <[lines].is_empty>:
    - stop
  - define speaker <server.flag[marallyzen_dictaphone_narrations.<[audio_file]>.speaker]||null>
  - define total_ticks <[sound_duration].in_ticks.round_down>
  - define line_count <[lines].size>
  - define segment_ticks <[total_ticks].div[<[line_count]>].round_down>
  - if <[segment_ticks]> < 1:
    - define segment_ticks 1
  # The original mod spreads narration beats across the voice recording. The
  # final line receives the remainder so the actionbar ends exactly with audio.
  - foreach <[lines]> as:line:
    - if <[viewer].flag[marallyzen_dictaphone_session.session_key]||null> != <[session_key]>:
      - stop
    - define wait_ticks <[segment_ticks]>
    - if <[loop_index]> == <[line_count]>:
      - define wait_ticks <[total_ticks].sub[<[segment_ticks].mul[<[line_count].sub[1]>]>]>
    - define remaining_ticks <[wait_ticks]>
    # Refresh every two seconds so a long single subtitle cannot fade before
    # its section of the recording has finished.
    - while <[remaining_ticks]> > 0:
      - if <[speaker]> == null:
        - actionbar "<gray><[line].parse_color>" targets:<[viewer]>
      - else:
        - actionbar "<white><[speaker].parse_color><gray><&co> <[line].parse_color>" targets:<[viewer]>
      - define refresh_ticks 40
      - if <[remaining_ticks]> < <[refresh_ticks]>:
        - define refresh_ticks <[remaining_ticks]>
      - wait <[refresh_ticks]>t
      - if <[viewer].flag[marallyzen_dictaphone_session.session_key]||null> != <[session_key]>:
        - stop
      - define remaining_ticks <[remaining_ticks].sub[<[refresh_ticks]>]>
  - if <[viewer].flag[marallyzen_dictaphone_session.session_key]||null> == <[session_key]>:
    - actionbar "" targets:<[viewer]>

marallyzen_dictaphone_playback_stop:
  type: task
  debug: false
  definitions: viewer
  script:
  - define session <[viewer].flag[marallyzen_dictaphone_session]||null>
  - if <[session]> == null || <[session].get[playback_finished]||false>:
    - stop
  - if <[session].get[model].is_spawned||false>:
    - adjust <[session].get[model]> item:paper[item_model=marallyzen:dictaphone]
  - actionbar "" targets:<[viewer]>
  # Use the vanilla command path here as well, keeping start/play/stop on the
  # same protocol and avoiding custom-sound parsing differences in DEV builds.
  - execute as_server "minecraft:stopsound <[viewer].name> voice <script[marallyzen_dictaphone_config].data_key[start_sound].parsed>" silent
  - execute as_server "minecraft:stopsound <[viewer].name> voice <[session].get[sound_id].parsed>" silent
  - execute as_server "minecraft:stopsound <[viewer].name> voice <script[marallyzen_dictaphone_config].data_key[stop_sound].parsed>" silent
