# Persistent decorative item piles for Paper 26.1.2 + Denizen 1.3.2-b7286M-DEV.
# The visible objects are real dropped-item entities created by displayitem, so
# they retain vanilla spinning/bobbing while remaining impossible to collect.

marallyzen_phantom_items_config:
  type: data
  debug: false
  admin_permission: marallyzen.phantomitems.admin
  default_amount: 24
  default_radius: 1.5
  remove_radius: 3.0
  max_amount: 200
  max_radius: 5.0

marallyzen_phantom_items_command:
  type: command
  debug: false
  name: phantomitems
  aliases:
  - pitems
  description: Управление постоянными фантомными кучами предметов
  usage: /phantomitems spawn [id,id,...] [количество|each] [радиус] | remove [радиус] | list | purge
  permission: marallyzen.phantomitems.admin
  permission message: <red>Недостаточно прав.
  tab complete:
  - define argument <context.args.size>
  - if <[argument]> <= 1:
    - determine spawn|remove|list|purge
  - define sub <context.args.get[1].to_lowercase||null>
  - if <[argument]> == 2:
    - if <[sub]> == spawn:
      - determine <server.material_types.filter[is_item].parse[name]>
    - if <[sub]> == remove:
      - determine 1|2|3|5|8|16
  - if <[argument]> == 3 && <[sub]> == spawn:
    - determine each|1|8|16|24|32|64
  - if <[argument]> == 4 && <[sub]> == spawn:
    - determine 0|0.5|1|1.5|2|3|5
  - determine <list[]>
  script:
  - define admin true
  - if <player.exists||false>:
    - define admin <player.is_op.or[<player.has_permission[marallyzen.phantomitems.admin]>]>
  - if !<[admin]>:
    - narrate "<red>Нужно право marallyzen.phantomitems.admin или OP."
    - stop
  - define sub <context.args.get[1].to_lowercase||help>
  - choose <[sub]>:
    - case spawn:
      - if !<player.exists||false>:
        - narrate "<red>Создавать кучи можно только от имени игрока."
        - stop
      - define raw_ids <context.args.get[2]||null>
      - if <[raw_ids]> == null:
        - narrate "<yellow>Использование<&co> /phantomitems spawn diamond,emerald,gold_ingot [количество] [радиус]"
        - stop
      - define amount_input <context.args.get[3].to_lowercase||<script[marallyzen_phantom_items_config].data_key[default_amount]>>
      - define one_each <[amount_input].equals[each]>
      - define radius <context.args.get[4]||<script[marallyzen_phantom_items_config].data_key[default_radius]>>
      - if !<[one_each]> && !<[amount_input].is_integer>:
        - narrate "<red>Количество должно быть целым числом или словом each."
        - stop
      - if !<[radius].is_decimal>:
        - narrate "<red>Радиус должен быть числом."
        - stop
      - define radius <[radius].as_decimal>
      - if !<[one_each]>:
        - define amount <[amount_input].as_integer>
        - if <[amount]> < 1 || <[amount]> > <script[marallyzen_phantom_items_config].data_key[max_amount]>:
          - narrate "<red>Количество должно быть от 1 до <script[marallyzen_phantom_items_config].data_key[max_amount]>."
          - stop
      - if <[radius]> < 0 || <[radius]> > <script[marallyzen_phantom_items_config].data_key[max_radius]>:
        - narrate "<red>Радиус должен быть от 0 до <script[marallyzen_phantom_items_config].data_key[max_radius]>."
        - stop
      - define known_items <server.material_types.filter[is_item].parse[name]>
      - define item_ids <list[]>
      - foreach <[raw_ids].split[,].parse[trim]> as:raw_id:
        - define item_id <[raw_id].to_lowercase.replace[minecraft<&co>].with[]>
        - if !<[known_items].contains[<[item_id]>]>:
          - narrate "<red>Неизвестный или недоступный предмет<&co> <white><[raw_id]>"
          - stop
        - define item_ids:->:<[item_id]>
      - if <[item_ids].is_empty>:
        - narrate "<red>Не указано ни одного ID предмета."
        - stop
      - define spawn_items <list[]>
      - if <[one_each]>:
        - define spawn_items <[item_ids]>
      - else:
        - repeat <[amount]>:
          - define spawn_items:->:<[item_ids].random>
      - if <[spawn_items].size> > <script[marallyzen_phantom_items_config].data_key[max_amount]>:
        - narrate "<red>За один раз можно создать не больше <script[marallyzen_phantom_items_config].data_key[max_amount]> предметов."
        - stop
      - define pile_id <util.random_uuid>
      # Anchor the pile 0.15 blocks above the top face of the block under the
      # player, independent of the player's fractional standing position.
      - define origin <player.location.below.center.add[0,0.65,0]>
      - define point_types <[spawn_items].deduplicate>
      - define angle_step <element[6.283185307].div[<[point_types].size>]>
      - define start_angle <util.random.decimal[0].to[6.283185307]>
      - define entities <list[]>
      - foreach <[spawn_items]> as:item_id:
        - define token <util.random_uuid>
        - define shown_item <material[<[item_id]>].item.with_flag[marallyzen_phantom_token:<[token]>]>
        # All entities of one material share one point. Different materials are
        # placed at equal intervals around a randomly rotated circle.
        - define point_index <[point_types].find[<[item_id]>]>
        - define angle <[start_angle].add[<[angle_step].mul[<[point_index].sub[1]>]>]>
        - define circle_offset <location[0,0,<[radius]>].rotate_around_y[<[angle]>]>
        - define spawn_location <[origin].add[<[circle_offset]>]>
        - spawn item_display[item=<[shown_item]>;display=ground;pivot=fixed;scale=1,1,1;interpolation_duration=5t;teleport_duration=0t;view_range=32;shadow_radius=0.15] <[spawn_location]> persistent save:phantom_display
        - define entity <entry[phantom_display].spawned_entity||null>
        - if <[entity]> != null:
          - adjust <[entity]> invulnerable:true
          - flag <[entity]> marallyzen_phantom_item:true
          - flag <[entity]> marallyzen_phantom_pile:<[pile_id]>
          - flag <[entity]> marallyzen_phantom_home:<[spawn_location]>
          - flag <[entity]> marallyzen_phantom_phase:<util.random.decimal[0].to[6.283185307]>
          - define entities:->:<[entity]>
      - flag server marallyzen_phantom_piles.<[pile_id]>:map@[location=<[origin]>;creator=<player.uuid>;items=<[item_ids]>;entities=<[entities]>;amount=<[entities].size>;created=<util.time_now>]
      - narrate "<green>Создана фантомная куча<&co> <white><[entities].size> <green>предметов."
      - narrate "<gray>ID кучи<&co> <[pile_id]>"
    - case remove:
      - if !<player.exists||false>:
        - narrate "<red>Удалять кучи под собой можно только от имени игрока."
        - stop
      - define radius <context.args.get[2]||<script[marallyzen_phantom_items_config].data_key[remove_radius]>>
      - if !<[radius].is_decimal>:
        - narrate "<red>Радиус должен быть числом."
        - stop
      - define radius <[radius].as_decimal>
      - if <[radius]> < 0 || <[radius]> > 16:
        - narrate "<red>Радиус удаления должен быть от 0 до 16."
        - stop
      - define removed_piles 0
      - define removed_entities 0
      - foreach <server.flag[marallyzen_phantom_piles].keys||<list[]>> as:pile_id:
        - define record <server.flag[marallyzen_phantom_piles.<[pile_id]>]>
        - define pile_location <[record].get[location]||null>
        - if <[pile_location]> != null && <[pile_location].world> == <player.world>:
          - if <[pile_location].distance[<player.location>]> <= <[radius]>:
            - foreach <[record].get[entities]||<list[]>> as:entity:
              - if <[entity].is_spawned||false>:
                - remove <[entity]>
                - define removed_entities <[removed_entities].add[1]>
            - flag server marallyzen_phantom_piles.<[pile_id]>:!
            - define removed_piles <[removed_piles].add[1]>
      - if <[removed_piles]> == 0:
        - narrate "<yellow>В радиусе <[radius]> блоков фантомных куч не найдено."
      - else:
        - narrate "<green>Удалено куч<&co> <white><[removed_piles]><green>, предметов<&co> <white><[removed_entities]><green>."
    - case list:
      - define piles <server.flag[marallyzen_phantom_piles].keys||<list[]>>
      - narrate "<gold>Сохранено фантомных куч<&co> <white><[piles].size>"
      - if <player.exists||false>:
        - define nearby 0
        - foreach <[piles]> as:pile_id:
          - define pile_location <server.flag[marallyzen_phantom_piles.<[pile_id]>.location]||null>
          - if <[pile_location]> != null && <[pile_location].world> == <player.world>:
            - if <[pile_location].distance[<player.location>]> <= 16:
              - define nearby <[nearby].add[1]>
        - narrate "<gray>Из них в радиусе 16 блоков<&co> <white><[nearby]>"
    - case purge:
      - define removed_piles 0
      - define removed_entities 0
      - foreach <server.flag[marallyzen_phantom_piles].keys||<list[]>> as:pile_id:
        - define record <server.flag[marallyzen_phantom_piles.<[pile_id]>]>
        - foreach <[record].get[entities]||<list[]>> as:entity:
          - if <[entity].is_spawned||false>:
            - remove <[entity]>
            - define removed_entities <[removed_entities].add[1]>
        - define removed_piles <[removed_piles].add[1]>
      - flag server marallyzen_phantom_piles:!
      - narrate "<green>Удалены все фантомные кучи<&co> <white><[removed_piles]><green>, предметов<&co> <white><[removed_entities]><green>."
    - default:
      - narrate "<gold>/phantomitems spawn [id,id,...] [количество|each] [радиус]"
      - narrate "<gold>/phantomitems remove [радиус] <gray>— удалить кучи под собой"
      - narrate "<gold>/phantomitems list <gray>— показать количество куч"
      - narrate "<gold>/phantomitems purge <gray>— удалить все кучи на сервере"
      - narrate "<gray>Короткий алиас<&co> /pitems"

marallyzen_phantom_items_events:
  type: world
  debug: false
  events:
    on tick every:5:
    - define base_angle <util.delta_time_since_start.in_ticks.mul[0.05]>
    - foreach <server.flag[marallyzen_phantom_piles].keys||<list[]>> as:pile_id:
      - foreach <server.flag[marallyzen_phantom_piles.<[pile_id]>.entities]||<list[]>> as:entity:
        - if <[entity].is_spawned||false> && <[entity].entity_type> == item_display:
          - define phase <[entity].flag[marallyzen_phantom_phase]||0>
          - define angle <[base_angle].add[<[phase]>]>
          - define bob <[angle].mul[2].sin.mul[0.08].add[0.08]>
          - adjust <[entity]> left_rotation:<location[0,1,0].to_axis_angle_quaternion[<[angle]>]>
          - adjust <[entity]> translation:<location[0,<[bob]>,0]>
          - adjust <[entity]> interpolation_start:0t
