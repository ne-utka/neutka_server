# Marallyzen posters for Paper 26.1.2 + Denizen 1.3.2-b7286M-DEV.
# Citizens, Depenizen and Clientizen are deliberately not required by this script.
# Persistent data is kept under server flag "marallyzen_posters".

marallyzen_poster_config:
  type: data
  debug: false
  use_permission: marallyzen.poster.use
  admin_permission: marallyzen.poster.admin
  view_distance: 2.25
  # Five client-interpolated segments preserve Marallyzen's cubic silhouette
  # while sending only five movement updates for the complete flight.
  animation_step: 5t
  # X angle, Y angle and client interpolation time. This deterministic wind
  # loop varies amplitude and phase without random jumps or per-tick updates.
  sway_frames:
  - "0.000,5.700,12t"
  - "2.286,4.972,11t"
  - "3.627,1.677,13t"
  - "3.262,-0.561,12t"
  - "2.462,-0.815,10t"
  - "2.102,-1.305,11t"
  - "1.782,-2.468,13t"
  - "1.111,-4.061,14t"
  - "0.000,-5.700,12t"
  - "-1.833,-4.972,11t"
  - "-3.969,-1.677,10t"
  - "-4.699,0.561,12t"
  - "-3.169,0.815,13t"
  - "-1.165,1.305,11t"
  - "-0.733,2.468,14t"
  - "-1.064,4.061,12t"
  types:
    poster1: "Плакат 1"
    poster2: "Плакат 2"
    poster3: "Плакат 3"
    poster4: "Плакат 4"
    poster5: "Плакат 5"
    poster6: "Плакат 6"
    poster7: "Плакат 7"
    poster8: "Плакат 8"
    poster9: "Плакат 9"
    poster10: "Плакат 10"
    oldposter: "Старый плакат"
    paperposter1: "Бумажный плакат 1"
    paperposter2: "Бумажный плакат 2"

marallyzen_poster1:
  type: item
  debug: false
  material: paper
  display name: <gold>Плакат 1
  lore:
  - <gray>ПКМ по вертикальной грани блока
  - <dark_gray>Только для администратора
  mechanisms:
    item_model: marallyzen:poster1
    max_stack_size: 1
  allow in material recipes: false

marallyzen_poster2:
  type: item
  debug: false
  material: paper
  display name: <gold>Плакат 2
  lore: [<gray>ПКМ по вертикальной грани блока, <dark_gray>Только для администратора]
  mechanisms: {item_model: marallyzen:poster2, max_stack_size: 1}
  allow in material recipes: false

marallyzen_poster3:
  type: item
  debug: false
  material: paper
  display name: <gold>Плакат 3
  lore: [<gray>ПКМ по вертикальной грани блока, <dark_gray>Только для администратора]
  mechanisms: {item_model: marallyzen:poster3, max_stack_size: 1}
  allow in material recipes: false

marallyzen_poster4:
  type: item
  debug: false
  material: paper
  display name: <gold>Плакат 4
  lore: [<gray>ПКМ по вертикальной грани блока, <dark_gray>Только для администратора]
  mechanisms: {item_model: marallyzen:poster4, max_stack_size: 1}
  allow in material recipes: false

marallyzen_poster5:
  type: item
  debug: false
  material: paper
  display name: <gold>Плакат 5
  lore: [<gray>ПКМ по вертикальной грани блока, <dark_gray>Только для администратора]
  mechanisms: {item_model: marallyzen:poster5, max_stack_size: 1}
  allow in material recipes: false

marallyzen_poster6:
  type: item
  debug: false
  material: paper
  display name: <gold>Плакат 6
  lore: [<gray>ПКМ по вертикальной грани блока, <dark_gray>Только для администратора]
  mechanisms: {item_model: marallyzen:poster6, max_stack_size: 1}
  allow in material recipes: false

marallyzen_poster7:
  type: item
  debug: false
  material: paper
  display name: <gold>Плакат 7
  lore: [<gray>ПКМ по вертикальной грани блока, <dark_gray>Только для администратора]
  mechanisms: {item_model: marallyzen:poster7, max_stack_size: 1}
  allow in material recipes: false

marallyzen_poster8:
  type: item
  debug: false
  material: paper
  display name: <gold>Плакат 8
  lore: [<gray>ПКМ по вертикальной грани блока, <dark_gray>Только для администратора]
  mechanisms: {item_model: marallyzen:poster8, max_stack_size: 1}
  allow in material recipes: false

marallyzen_poster9:
  type: item
  debug: false
  material: paper
  display name: <gold>Плакат 9
  lore: [<gray>ПКМ по вертикальной грани блока, <dark_gray>Только для администратора]
  mechanisms: {item_model: marallyzen:poster9, max_stack_size: 1}
  allow in material recipes: false

marallyzen_poster10:
  type: item
  debug: false
  material: paper
  display name: <gold>Плакат 10
  lore: [<gray>ПКМ по вертикальной грани блока, <dark_gray>Только для администратора]
  mechanisms: {item_model: marallyzen:poster10, max_stack_size: 1}
  allow in material recipes: false

marallyzen_oldposter:
  type: item
  debug: false
  material: paper
  display name: <gold>Старый плакат
  lore: [<gray>ПКМ по вертикальной грани блока, <dark_gray>Только для администратора]
  mechanisms: {item_model: marallyzen:oldposter, max_stack_size: 1}
  allow in material recipes: false

marallyzen_paperposter1:
  type: item
  debug: false
  material: paper
  display name: <gold>Бумажный плакат 1
  lore: [<gray>ПКМ по вертикальной грани блока, <dark_gray>Только для администратора]
  mechanisms: {item_model: marallyzen:paperposter1, max_stack_size: 1}
  allow in material recipes: false

marallyzen_paperposter2:
  type: item
  debug: false
  material: paper
  display name: <gold>Бумажный плакат 2
  lore: [<gray>ПКМ по вертикальной грани блока, <dark_gray>Только для администратора]
  mechanisms: {item_model: marallyzen:paperposter2, max_stack_size: 1}
  allow in material recipes: false

marallyzen_poster_command:
  type: command
  debug: false
  name: poster
  description: Управление плакатами Marallyzen
  usage: /poster spawn [asset_name] | give [type] [player] | info | remove | variant [default/alive/dead/band] | rebuild | cancel
  permission: marallyzen.poster.use
  permission message: <red>Недостаточно прав.
  tab complete:
  - define admin <context.server>
  - if !<[admin]>:
    - define admin <player.is_op.or[<player.has_permission[marallyzen.poster.admin]>]>
  - define argument <context.args.size>
  - if <[argument]> <= 1:
    - if <[admin]>:
      - determine spawn|give|info|remove|variant|rebuild|cancel
    - determine info|cancel
  - if !<[admin]>:
    - determine <list[]>
  - define sub <context.args.get[1].to_lowercase||null>
  - if <[argument]> == 2:
    - if <[sub]> == spawn || <[sub]> == give:
      - determine <script[marallyzen_poster_config].data_key[types].keys>
    - if <[sub]> == variant:
      - determine default|alive|dead|band
  - if <[argument]> == 3 && <[sub]> == give:
    - determine <server.online_players.parse[name]>
  - determine <list[]>
  script:
  - define sub <context.args.get[1].to_lowercase||help>
  - if <[sub]> == cancel:
    - if <player.exists||false>:
      - run marallyzen_poster_close def:<player>|true
    - stop
  - if <[sub]> == info:
    - if !<player.exists||false>:
      - narrate "Команда доступна только игроку."
      - stop
    - define target <player.eye_location.ray_trace_target[range=6;entities=item_display|interaction].hit_entity||null>
    - define id <[target].flag[poster_id]||null>
    - if <[id]> == null:
      - narrate "<yellow>Посмотрите на плакат в пределах 6 блоков."
      - stop
    - define record <server.flag[marallyzen_posters.<[id]>]>
    - narrate "<gold>ID<&co> <white><[id]>"
    - narrate "<gold>Тип<&co> <white><[record].get[type]> <gold>вариант<&co> <white><[record].get[variant]>"
    - narrate "<gold>Создатель<&co> <white><[record].get[creator]>"
    - stop
  - define admin true
  - if <player.exists||false>:
    - define admin <player.is_op.or[<player.has_permission[marallyzen.poster.admin]>]>
  - if !<[admin]>:
    - narrate "<red>Нужно право marallyzen.poster.admin или OP."
    - stop
  - choose <[sub]>:
    - case spawn:
      - if !<player.exists||false>:
        - narrate "Команда доступна только игроку."
        - stop
      - define poster_type <context.args.get[2].to_lowercase||null>
      # Minecraft resource identifiers are deliberately stricter here than
      # general file names: no spaces, dots, namespace escapes or subfolders.
      - if <[poster_type]> == null || !<[poster_type].matches[^[a-z0-9_-]+$]>:
        - narrate "<red>Имя ассета может содержать только a-z, 0-9, _ и -."
        - stop
      - define support <player.cursor_on[6]>
      - if <[support]> == null || !<[support].material.is_solid>:
        - narrate "<yellow>Посмотрите на твёрдый блок в пределах 6 блоков."
        - stop
      # Choose the vertical face of the targeted block that most directly
      # faces the command sender. This makes command placement predictable
      # without requiring a temporary placement item.
      - define toward <player.eye_location.sub[<[support].center]>
      - if <[toward].x.abs> >= <[toward].z.abs>:
        - if <[toward].x> >= 0:
          - define relative <[support].add[1,0,0]>
        - else:
          - define relative <[support].add[-1,0,0]>
      - else:
        - if <[toward].z> >= 0:
          - define relative <[support].add[0,0,1]>
        - else:
          - define relative <[support].add[0,0,-1]>
      - run marallyzen_poster_place def:<[poster_type]>|<[support]>|<[relative]>|<player>|true
    - case give:
      - define poster_type <context.args.get[2].to_lowercase||null>
      - if !<script[marallyzen_poster_config].data_key[types].contains[<[poster_type]>]>:
        - narrate "<red>Типы — poster1..poster10, oldposter, paperposter1, paperposter2."
        - stop
      - define target_player <server.match_player[<context.args.get[3]||<player.name||null>>]||null>
      - if <[target_player]> == null:
        - narrate "<red>Игрок не найден."
        - stop
      - give marallyzen_<[poster_type]> to:<[target_player].inventory>
      - narrate "<green>Выдан <[poster_type]> игроку <[target_player].name>."
    - case remove:
      - if !<player.exists||false>:
        - narrate "Команда доступна только игроку."
        - stop
      - define target <player.eye_location.ray_trace_target[range=6;entities=item_display|interaction].hit_entity||null>
      - define id <[target].flag[poster_id]||null>
      - if <[id]> == null:
        - narrate "<yellow>Посмотрите на плакат в пределах 6 блоков."
        - stop
      - run marallyzen_poster_remove def:<[id]>|<player>
    - case variant:
      - if !<player.exists||false>:
        - narrate "Команда доступна только игроку."
        - stop
      - define variant <context.args.get[2].to_lowercase||null>
      - if !<list[default|alive|dead|band].contains[<[variant]>]>:
        - narrate "<red>Варианты — default, alive, dead или band."
        - stop
      - define target <player.eye_location.ray_trace_target[range=6;entities=item_display|interaction].hit_entity||null>
      - define id <[target].flag[poster_id]||null>
      - if <[id]> == null || <server.flag[marallyzen_posters.<[id]>.type]||null> != oldposter:
        - narrate "<yellow>Посмотрите на oldposter."
        - stop
      - flag server marallyzen_posters.<[id]>.variant:<[variant]>
      - narrate "<green>Вариант изменён на <[variant]>."
    - case rebuild:
      - run marallyzen_poster_rebuild
      - narrate "<green>Проверка и восстановление плакатов запущены."
    - default:
      - narrate "<gold>/poster spawn [asset_name] <gray>— поставить ассет из ресурспака"
      - narrate "<gold>/poster give [type] [player]"
      - narrate "<gold>/poster info | remove | variant [default/alive/dead/band] | rebuild | cancel"

marallyzen_poster_events:
  type: world
  debug: false
  events:
    on player right clicks block:
    - if <context.hand> != HAND:
      - stop
    - define script_name <context.item.script.name||null>
    - define poster_type <[script_name].after[marallyzen_]||null>
    - if !<script[marallyzen_poster_config].data_key[types].contains[<[poster_type]>]>:
      - stop
    - ratelimit <player> 2t
    - determine passively cancelled
    - if !<player.is_op> && !<player.has_permission[marallyzen.poster.admin]>:
      - narrate "<red>Этот предмет может использовать только администратор."
      - stop
    - run marallyzen_poster_place def:<[poster_type]>|<context.location>|<context.relative>|<player>

    on player right clicks interaction:
    - define id <context.entity.flag[poster_id]||null>
    - if <[id]> == null:
      - stop
    - determine passively cancelled
    - ratelimit <player> 2t
    - if <context.entity.flag[poster_role]||null> == session_interaction:
      - if <context.entity.flag[poster_session_owner]||null> != <player.uuid>:
        - stop
      - if <player.is_sneaking>:
        - run marallyzen_poster_close def:<player>|true
      - else:
        - run marallyzen_poster_flip def:<player>
      - stop
    - run marallyzen_poster_open def:<[id]>|<player>

    on player tries to attack interaction:
    - define id <context.entity.flag[poster_id]||null>
    - if <[id]> == null:
      - stop
    - determine passively cancelled
    - if <player.is_sneaking> && (<player.is_op> || <player.has_permission[marallyzen.poster.admin]>) && <player.item_in_hand.script.name.starts_with[marallyzen_]||false>:
      - run marallyzen_poster_remove def:<[id]>|<player>

    on player damages item_display:
    - define id <context.entity.flag[poster_id]||null>
    - if <[id]> == null:
      - stop
    - determine passively cancelled
    - if <player.is_sneaking> && (<player.is_op> || <player.has_permission[marallyzen.poster.admin]>) && <player.item_in_hand.script.name.starts_with[marallyzen_]||false>:
      - run marallyzen_poster_remove def:<[id]>|<player>

    on player breaks block:
    - define attached <context.location.flag[marallyzen_poster_faces]||null>
    - if <[attached]> == null:
      - stop
    - if !<player.is_op> && !<player.has_permission[marallyzen.poster.admin]>:
      - determine cancelled
    - foreach <[attached].values> as:id:
      - run marallyzen_poster_remove def:<[id]>|<player>

    on player quits:
    - run marallyzen_poster_close def:<player>|false
    on player dies:
    - run marallyzen_poster_close def:<player>|false
    on player changes world:
    - run marallyzen_poster_close def:<player>|false
    on reload scripts:
    - foreach <server.online_players> as:viewer:
      - run marallyzen_poster_close def:<[viewer]>|false
    - run marallyzen_poster_rebuild delay:2t
    on server start:
    - run marallyzen_poster_rebuild delay:2s
    on chunk loads:
    - ratelimit <context.chunk> 2s
    - run marallyzen_poster_rebuild_chunk def:<context.chunk> delay:2t

marallyzen_poster_place:
  type: task
  debug: false
  definitions: poster_type|support|relative|admin|custom
  script:
  - if !<[support].material.is_solid>:
    - narrate "<red>Плакату нужна твёрдая опора." targets:<[admin]>
    - stop
  - define normal <[relative].sub[<[support]>]>
  - if <[normal].y.abs> > 0.01:
    - narrate "<red>Плакат можно ставить только на вертикальную грань." targets:<[admin]>
    - stop
  - if <[normal].x> > 0.5:
    - define face east
    - define yaw -90
  - else if <[normal].x> < -0.5:
    - define face west
    - define yaw 90
  - else if <[normal].z> > 0.5:
    - define face south
    - define yaw 0
  - else:
    - define face north
    - define yaw 180
  - if <[support].has_flag[marallyzen_poster_faces.<[face]>]>:
    - narrate "<red>На этой грани уже есть плакат." targets:<[admin]>
    - stop
  - define id <util.random_uuid>
  - define is_custom <[custom]||false>
  # The wall item models are centred on local z=8. Put their origin 0.01 blocks
  # outside the clicked face to avoid both wall clipping and z-fighting.
  - define position <[support].center.add[<[normal].mul[0.51]>].with_yaw[<[yaw]>]>
  - flag server marallyzen_posters.<[id]>:map@[type=<[poster_type]>;custom=<[is_custom]>;variant=default;position=<[position]>;normal=<[normal]>;support=<[support]>;face=<[face]>;creator=<[admin].uuid>]
  - flag <[support]> marallyzen_poster_faces.<[face]>:<[id]>
  - run marallyzen_poster_spawn_stationary def:<[id]>
  - playsound <[position]> sound:block_wood_place volume:0.7 pitch:1.2
  - narrate "<green>Плакат <[poster_type]> установлен. ID<&co> <[id]>" targets:<[admin]>

marallyzen_poster_spawn_stationary:
  type: task
  debug: false
  definitions: id
  script:
  - define record <server.flag[marallyzen_posters.<[id]>]||null>
  - if <[record]> == null:
    - stop
  - define support <[record].get[support]>
  - if !<[support].chunk.is_loaded>:
    - stop
  - if !<[support].material.is_solid>:
    - run marallyzen_poster_remove def:<[id]>|null
    - stop
  - if <server.has_flag[marallyzen_poster_spawning.<[id]>]>:
    - stop
  - flag server marallyzen_poster_spawning.<[id]>:true expire:2s
  - define old_display <[record].get[display]||null>
  - define old_interaction <[record].get[interaction]||null>
  - if <[old_display]> != null && <[old_display].is_spawned||false>:
    - remove <[old_display]>
  - if <[old_interaction]> != null && <[old_interaction].is_spawned||false>:
    - remove <[old_interaction]>
  # Recalculate the canonical wall origin so records made by older script
  # revisions are migrated on rebuild as well.
  - define position <[support].center>
  - choose <[record].get[face]>:
    - case east:
      - define position <[position].add[0.51,0,0].with_yaw[-90]>
    - case west:
      - define position <[position].add[-0.51,0,0].with_yaw[90]>
    - case south:
      - define position <[position].add[0,0,0.51].with_yaw[0]>
    - case north:
      - define position <[position].add[0,0,-0.51].with_yaw[180]>
  - flag server marallyzen_posters.<[id]>.position:<[position]>
  - define model marallyzen:<[record].get[type]>
  - spawn item_display[item=paper[item_model=<[model]>];display=fixed;pivot=fixed;scale=1,1,1;interpolation_duration=0t;teleport_duration=0t;view_range=32;shadow_radius=0] <[position]> persistent save:poster_display
  - define display <entry[poster_display].spawned_entity>
  - flag <[display]> poster_id:<[id]>
  - flag <[display]> poster_role:stationary_model
  - define hitbox_location <[position].sub[0,0.5,0]>
  - spawn interaction[width=0.8;height=1.0;is_aware=true] <[hitbox_location]> persistent save:poster_interaction
  - define interaction <entry[poster_interaction].spawned_entity>
  - flag <[interaction]> poster_id:<[id]>
  - flag <[interaction]> poster_role:stationary_interaction
  - flag server marallyzen_posters.<[id]>.display:<[display]>
  - flag server marallyzen_posters.<[id]>.interaction:<[interaction]>
  - flag <[support]> marallyzen_poster_faces.<[record].get[face]>:<[id]>
  - flag server marallyzen_poster_spawning.<[id]>:!

marallyzen_poster_remove:
  type: task
  debug: false
  definitions: id|actor
  script:
  - define record <server.flag[marallyzen_posters.<[id]>]||null>
  - if <[record]> == null:
    - stop
  - foreach <server.online_players> as:viewer:
    - if <[viewer].flag[marallyzen_poster_session.poster_id]||null> == <[id]>:
      - run marallyzen_poster_close def:<[viewer]>|false
  - foreach <list[<[record].get[display]||null>|<[record].get[interaction]||null>]> as:entity:
    - if <[entity]> != null && <[entity].is_spawned||false>:
      - remove <[entity]>
  - define support <[record].get[support]>
  - flag <[support]> marallyzen_poster_faces.<[record].get[face]>:!
  - flag server marallyzen_posters.<[id]>:!
  - if <[actor]> != null:
    - narrate "<green>Плакат удалён." targets:<[actor]>

marallyzen_poster_rebuild:
  type: task
  debug: false
  script:
  - foreach <server.flag[marallyzen_posters].keys||<list[]>> as:id:
    # Remove legacy dynamic-content data left by older script revisions.
    - foreach <list[title|author|front|back|names]> as:legacy_key:
      - flag server marallyzen_posters.<[id]>.<[legacy_key]>:!
    - define record <server.flag[marallyzen_posters.<[id]>]>
    - define support <[record].get[support]>
    - if !<[support].chunk.is_loaded>:
      - foreach next
    - if !<[support].material.is_solid>:
      - run marallyzen_poster_remove def:<[id]>|null
    - else:
      # A manual/global rebuild also migrates model geometry and wall offsets.
      - run marallyzen_poster_spawn_stationary def:<[id]>

marallyzen_poster_rebuild_chunk:
  type: task
  debug: false
  definitions: loaded_chunk
  script:
  - foreach <server.flag[marallyzen_posters].keys||<list[]>> as:id:
    - define record <server.flag[marallyzen_posters.<[id]>]>
    - if <[record].get[support].chunk> != <[loaded_chunk]>:
      - foreach next
    - if <server.has_flag[marallyzen_poster_spawning.<[id]>]>:
      - foreach next
    - if !<[record].get[support].material.is_solid>:
      - run marallyzen_poster_remove def:<[id]>|null
    - else if !<[record].get[display].is_spawned||false> || !<[record].get[interaction].is_spawned||false>:
      - run marallyzen_poster_spawn_stationary def:<[id]>

marallyzen_poster_open:
  type: task
  debug: false
  definitions: id|viewer
  script:
  - if <[viewer].has_flag[marallyzen_poster_opening]>:
    - stop
  - flag <[viewer]> marallyzen_poster_opening expire:3s
  - if <[viewer].has_flag[marallyzen_poster_session]>:
    - run marallyzen_poster_close def:<[viewer]>|false
    - wait 1t
  - define record <server.flag[marallyzen_posters.<[id]>]||null>
  - if <[record]> == null:
    - stop
  - define stationary <[record].get[display]||null>
  - if !<[stationary].is_spawned||false>:
    - run marallyzen_poster_spawn_stationary def:<[id]>
    - define stationary <server.flag[marallyzen_posters.<[id]>.display]>
  - adjust <[viewer]> hide_entity:<[stationary]>
  - define origin <[record].get[position]>
  - define direction <[viewer].eye_location.sub[<[origin]>].normalize>
  - define view_distance <script[marallyzen_poster_config].data_key[view_distance]>
  - define target <[origin].add[<[direction].mul[<[view_distance]>]>].face[<[viewer].eye_location>].with_pitch[0]>
  # Marallyzen billboards towards the camera for the entire fly-out. Spawn the
  # temporary group with that yaw immediately, not only at the final point.
  # Keep this separate from "origin": redefining a definition from itself is
  # preserved as literal text by Denizen and makes every temporary spawn fail.
  - define view_yaw <[target].yaw>
  - define view_origin <[origin].with_yaw[<[view_yaw]>].with_pitch[0]>
  - define full_model marallyzen:posterfull
  - if <[record].get[custom]||false>:
    - define full_model marallyzen:<[record].get[type]>_full
  - else if <[record].get[type].starts_with[paperposter]>:
    - define full_model marallyzen:paperposterfull
  - else if <[record].get[type]> == oldposter:
    - define full_model marallyzen:oldposterfull_<[record].get[variant]||default>
  - spawn item_display[item=paper[item_model=<[full_model]>];display=fixed;pivot=center;scale=0.78125,0.9375,1;interpolation_duration=5t;teleport_duration=5t;view_range=32;shadow_radius=0] <[view_origin]> save:view_model
  - define model <entry[view_model].spawned_entity||null>
  - if <[model]> == null || !<[model].is_spawned||false>:
    - adjust <[viewer]> show_entity:<[stationary]>
    - flag <[viewer]> marallyzen_poster_opening:!
    - stop
  - flag <[model]> poster_id:<[id]>
  - flag <[model]> poster_role:session_model
  - flag <[model]> poster_session_owner:<[viewer].uuid>
  - adjust <[model]> hide_from_players
  - adjust <[viewer]> show_entity:<[model]>
  - define entities <list[<[model]>]>
  - define moving <list[<[model]>]>
  - define interaction_location <[target].sub[0,0.55,0]>
  - spawn interaction[width=0.9;height=1.1;is_aware=true] <[interaction_location]> save:view_interaction
  - define interaction <entry[view_interaction].spawned_entity>
  - flag <[interaction]> poster_id:<[id]>
  - flag <[interaction]> poster_role:session_interaction
  - flag <[interaction]> poster_session_owner:<[viewer].uuid>
  - adjust <[interaction]> hide_from_players
  - adjust <[viewer]> show_entity:<[interaction]>
  - define entities:->:<[interaction]>
  - define session_key <util.random_uuid>
  - flag <[viewer]> marallyzen_poster_session:map@[session_key=<[session_key]>;poster_id=<[id]>;stationary=<[stationary]>;entities=<[entities]>;moving=<[moving]>;model=<[model]>;interaction=<[interaction]>;origin=<[view_origin]>;target=<[target]>;side=front;busy=true;sway_frame=1]
  - flag <[viewer]> marallyzen_poster_opening:!
  - run marallyzen_poster_animate_out def:<[viewer]>

marallyzen_poster_animate_out:
  type: task
  debug: false
  definitions: viewer
  script:
  - define session <[viewer].flag[marallyzen_poster_session]||null>
  - if <[session]> == null:
    - stop
  - define origin <[session].get[origin]>
  - define target <[session].get[target]>
  - define delta <[target].sub[<[origin]>]>
  - define model <[session].get[model]>
  - define step <script[marallyzen_poster_config].data_key[animation_step]>
  - foreach <[session].get[moving]> as:entity:
    - adjust <[entity]> teleport_duration:<[step]>
    - adjust <[entity]> interpolation_duration:<[step]>
  # Do not move in the spawn tick: otherwise Minecraft can merge the spawn and
  # first teleport packets, making most of the flight appear to be skipped.
  - wait 2t
  - if !<[viewer].has_flag[marallyzen_poster_session]>:
    - stop
  # Exact easeOutCubic samples at t = .2/.4/.6/.8/1. Five client-interpolated
  # segments give a close visual match to Marallyzen without per-tick packets.
  - define frames <list[0.488,0.888,0.968|0.784,0.95275,0.9865|0.936,0.986,0.996|0.992,0.99825,0.9995|1,1,1]>
  - foreach <[frames]> as:frame:
    - define values <[frame].split[,]>
    - teleport <[session].get[moving]> <[origin].add[<[delta].mul[<[values].get[1]>]>]>
    - adjust <[model]> interpolation_start:0t
    - adjust <[model]> scale:<[values].get[2]>,<[values].get[3]>,1
    - wait <[step]>
    - if !<[viewer].has_flag[marallyzen_poster_session]>:
      - stop
  - flag <[viewer]> marallyzen_poster_session.busy:false
  - playsound <[viewer]> sound:item_book_page_turn volume:0.5 pitch:1.15
  - run marallyzen_poster_session_monitor def:<[viewer]>|<[session].get[session_key]>

marallyzen_poster_session_monitor:
  type: task
  debug: false
  definitions: viewer|session_key
  script:
  - while <[viewer].is_online||false> && <[viewer].flag[marallyzen_poster_session.session_key]||null> == <[session_key]>:
    - define session <[viewer].flag[marallyzen_poster_session]>
    - if <[viewer].world> != <[session].get[target].world> || <[viewer].location.distance[<[session].get[target]>]> > 5:
      - run marallyzen_poster_close def:<[viewer]>|true
      - stop
    - define wait_time 2t
    - if !<[session].get[busy]>:
      - define frames <script[marallyzen_poster_config].data_key[sway_frames]>
      - define frame_index <[session].get[sway_frame]||1>
      - define values <[frames].get[<[frame_index]>].split[,]>
      - define x_angle <[values].get[1].to_radians>
      - define y_angle <[values].get[2].to_radians>
      - define wait_time <[values].get[3]>
      - define side <[session].get[side]>
      - define model_angle <[y_angle]>
      - if <[side]> == back:
        - define model_angle <element[3.141592654].add[<[y_angle]>]>
      - adjust <[session].get[model]> interpolation_duration:<[wait_time]>
      - adjust <[session].get[model]> interpolation_start:0t
      - adjust <[session].get[model]> left_rotation:<location[0,1,0].to_axis_angle_quaternion[<[model_angle]>]>
      - adjust <[session].get[model]> right_rotation:<location[1,0,0].to_axis_angle_quaternion[<[x_angle]>]>
      - define frame_index <[frame_index].add[1]>
      - if <[frame_index]> > <[frames].size>:
        - define frame_index 1
      - flag <[viewer]> marallyzen_poster_session.sway_frame:<[frame_index]>
    - wait <[wait_time]>

marallyzen_poster_flip:
  type: task
  debug: false
  definitions: viewer
  script:
  - define session <[viewer].flag[marallyzen_poster_session]||null>
  - if <[session]> == null || <[session].get[busy]>:
    - stop
  - define record <server.flag[marallyzen_posters.<[session].get[poster_id]>]||null>
  - if <[record]> == null:
    - run marallyzen_poster_close def:<[viewer]>|false
    - stop
  - if <[record].get[type]> == oldposter:
    - narrate "<gray>Старый плакат нельзя перевернуть." targets:<[viewer]>
    - stop
  - flag <[viewer]> marallyzen_poster_session.busy:true
  # Smoothly remove the X-axis wind tilt while the Y-axis flip takes control.
  - adjust <[session].get[model]> interpolation_duration:5t
  - adjust <[session].get[model]> interpolation_start:0t
  - adjust <[session].get[model]> right_rotation:0,0,0,1
  - define new_side back
  - if <[session].get[side]> == back:
    - define new_side front
  # Four keyframes (including the current angle) approximate cubic ease-in-out.
  - define flip_angles <list[0.465421134|2.676171520|3.141592654]>
  - if <[new_side]> == front:
    - define flip_angles <list[2.676171520|0.465421134|0]>
  - playsound <[viewer]> sound:item_book_page_turn volume:0.7 pitch:1
  - foreach <[flip_angles]> as:angle:
    - adjust <[session].get[model]> interpolation_duration:5t
    - adjust <[session].get[model]> interpolation_start:0t
    - adjust <[session].get[model]> left_rotation:<location[0,1,0].to_axis_angle_quaternion[<[angle]>]>
    - define frame_wait 5t
    - if <[loop_index]> == 2:
      - define frame_wait 2t
    - wait <[frame_wait]>
    - if <[loop_index]> == 2:
      - flag <[viewer]> marallyzen_poster_session.side:<[new_side]>
      - wait 3t
  - if !<[viewer].has_flag[marallyzen_poster_session]>:
    - stop
  - flag <[viewer]> marallyzen_poster_session.busy:false

marallyzen_poster_close:
  type: task
  debug: false
  definitions: viewer|animate
  script:
  - define session <[viewer].flag[marallyzen_poster_session]||null>
  - if <[session]> == null:
    - stop
  - flag <[viewer]> marallyzen_poster_session.busy:true
  - define entities <[session].get[entities]>
  - if <[animate]> && <[viewer].is_online||false> && <[viewer].world> == <[session].get[origin].world>:
    - define model <[session].get[model]>
    - define origin <[session].get[origin]>
    - define target <[session].get[target]>
    - define delta <[origin].sub[<[target]>]>
    - define step <script[marallyzen_poster_config].data_key[animation_step]>
    - define sway_frames <script[marallyzen_poster_config].data_key[sway_frames]>
    - define wind_index <[session].get[sway_frame]||1>
    - define returning_from_back <[session].get[side]>
    # Exact temporal mirror of animate_out: t^3 is the reverse-time form of
    # easeOutCubic, and these scale samples are animate_out's samples reversed.
    # The live wind phase continues while its amplitude fades with the flight.
    - define return_frames <list[0.008,0.99825,0.9995|0.064,0.986,0.996|0.216,0.95275,0.9865|0.512,0.888,0.968|1,0.78125,0.9375]>
    - playsound <[viewer]> sound:item_book_page_turn volume:0.5 pitch:0.92
    - foreach <[return_frames]> as:frame:
      - define values <[frame].split[,]>
      - define progress <[values].get[1]>
      - define wind <[sway_frames].get[<[wind_index]>].split[,]>
      - define damping <element[1].sub[<[progress]>]>
      - define x_angle <[wind].get[1].to_radians.mul[<[damping]>]>
      - define y_angle <[wind].get[2].to_radians.mul[<[damping]>]>
      - define model_angle <[y_angle]>
      - if <[returning_from_back]> == back:
        - define model_angle <element[3.141592654].mul[<[damping]>].add[<[y_angle]>]>
      - adjust <[model]> teleport_duration:<[step]>
      - adjust <[model]> interpolation_duration:<[step]>
      - adjust <[model]> interpolation_start:0t
      - adjust <[model]> left_rotation:<location[0,1,0].to_axis_angle_quaternion[<[model_angle]>]>
      - adjust <[model]> right_rotation:<location[1,0,0].to_axis_angle_quaternion[<[x_angle]>]>
      - adjust <[model]> scale:<[values].get[2]>,<[values].get[3]>,1
      - teleport <[session].get[moving]> <[target].add[<[delta].mul[<[progress]>]>]>
      - define wind_index <[wind_index].add[1]>
      - if <[wind_index]> > <[sway_frames].size>:
        - define wind_index 1
      - wait <[step]>
      - if !<[viewer].has_flag[marallyzen_poster_session]>:
        - stop
    - playsound <[viewer]> sound:block_wood_place volume:0.42 pitch:1.4
  - foreach <[entities]> as:entity:
    - if <[entity].is_spawned||false>:
      - remove <[entity]>
  - define stationary <[session].get[stationary]||null>
  - if <[stationary]> != null && <[stationary].is_spawned||false>:
    - adjust <[viewer]> show_entity:<[stationary]>
  - flag <[viewer]> marallyzen_poster_session:!
