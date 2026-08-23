# Hidden player names and tactile introductions for Marallyzen.
# The vanilla team owns in-world name-tag visibility. Right-clicking a player
# reveals their real account name only to the clicking player.

marallyzen_identity_config:
  type: data
  debug: false
  team: mlz_hidden
  cooldown: 15t
  slap_chance: 10

marallyzen_identity_events:
  type: world
  debug: false
  events:
    on reload scripts:
    - run marallyzen_identity_setup

    on server start:
    - run marallyzen_identity_setup delay:2s

    on player joins:
    - run marallyzen_identity_assign def:<player> delay:2t

    # A generic entity matcher is required for Citizens NPCs in this Denizen
    # build. The guards below admit only real players and our marked dummy.
    on player right clicks entity:
    - if <context.hand> != mainhand:
      - stop
    - define target <context.entity>
    - if <[target].is_npc>:
      - if !<[target].has_flag[marallyzen_slap_dummy]>:
        - stop
    - else if !<[target].is_player>:
      - stop
    - determine passively cancelled
    - run marallyzen_identity_interact def:<player>|<[target]>

marallyzen_identity_interact:
  type: task
  debug: false
  definitions: actor|target
  script:
    - ratelimit <[actor]> <script[marallyzen_identity_config].data_key[cooldown]>

    # Sneaking is the discreet identification path: name only.
    - if <[actor].is_sneaking>:
      - actionbar "<gray>Вы аккуратно коснулись плеча <white><[target].name><gray>." targets:<[actor]>
      - if !<[target].is_npc>:
        - actionbar "<white><[actor].name><gray> аккуратно касается вашего плеча." targets:<[target]>
      - stop

    - animate <[actor]> animation:ARM_SWING
    - define roll <util.random.int[1].to[100]>
    - if <[roll]> <= <script[marallyzen_identity_config].data_key[slap_chance]>:
      # Rare lower slap: a sharper sound and a compact puff behind the hips.
      - actionbar "<gray>Ой! Вы зарядили <white><[target].name><gray> прям по заднице!" targets:<[actor]>
      - if !<[target].is_npc>:
        - actionbar "<gray>Ой! <white><[actor].name><gray> заряжает вам прям по заднице!" targets:<[target]>
      - define impact <[target].location.add[0,0.72,0]>
      - playeffect effect:DUST at:<[impact]> quantity:14 offset:0.24,0.12,0.20 special_data:[size=0.75;color=#B98B64] visibility:20
      - playsound <[impact]> sound:entity_player_attack_knockback volume:0.65 pitch:1.45
    - else:
      # Normal shoulder pat: two soft beats and dust from both shoulders.
      - actionbar "<gray>Вы шлепнули <white><[target].name><gray> по спине!" targets:<[actor]>
      - if !<[target].is_npc>:
        - actionbar "<white><[actor].name><gray> шлепает вас по спине!" targets:<[target]>
      - define shoulders <[target].location.add[0,1.43,0]>
      - playeffect effect:DUST at:<[shoulders]> quantity:16 offset:0.34,0.16,0.23 special_data:[size=0.65;color=#A0A0A0] visibility:20
      - playsound <[shoulders]> sound:block_wool_hit volume:0.55 pitch:1.25
      - wait 3t
      - animate <[actor]> animation:ARM_SWING
      - playeffect effect:DUST at:<[shoulders]> quantity:8 offset:0.28,0.12,0.18 special_data:[size=0.55;color=#A0A0A0] visibility:20
      - playsound <[shoulders]> sound:block_wool_hit volume:0.4 pitch:1.4

marallyzen_slap_dummy_command:
  type: command
  debug: false
  name: slapdummy
  description: Creates or removes the player-like slap test dummy.
  usage: /slapdummy spawn [name] | remove
  permission: marallyzen.identity.admin
  tab completions:
    1: spawn|remove
    2: <context.args.get[1].equals_case_sensitive[spawn].if_true[SlapTest].if_false[]>
  script:
  - define action <context.args.get[1].to_lowercase||help>
  - choose <[action]>:
    - case spawn:
      - if <context.server>:
        - narrate "<red>This command must be used by a player."
        - stop
      - define dummy_name <context.args.get[2]||SlapTest>
      - if !<[dummy_name].regex_matches[^[A-Za-z0-9_]{1,16}$]>:
        - narrate "<red>Имя: 1-16 латинских букв, цифр или символов _."
        - stop
      - define old_dummy <server.flag[marallyzen_slap_dummy]||null>
      - if <[old_dummy]> != null && <server.npcs.contains[<[old_dummy]>]>:
        - remove <[old_dummy]>
      - define spawn_location <player.location.forward_flat[2].with_yaw[<player.location.yaw.add[180]>]>
      - create player <[dummy_name]> <[spawn_location]> save:slap_dummy
      - define dummy <entry[slap_dummy].created_npc>
      - adjust <[dummy]> name_visible:false
      - adjust <[dummy]> mirror_player:true
      - flag <[dummy]> marallyzen_slap_dummy:true
      - flag server marallyzen_slap_dummy:<[dummy]>
      - narrate "<green>Манекен <gold><[dummy_name]><green> создан. ПКМ — хлопок, Shift+ПКМ — только имя."
    - case remove:
      - define dummy <server.flag[marallyzen_slap_dummy]||null>
      - if <[dummy]> == null || !<server.npcs.contains[<[dummy]>]>:
        - flag server marallyzen_slap_dummy:!
        - narrate "<yellow>Активный тестовый манекен не найден."
        - stop
      - remove <[dummy]>
      - flag server marallyzen_slap_dummy:!
      - narrate "<green>Тестовый манекен удалён."
    - default:
      - narrate "<gold>/slapdummy spawn [name] <gray>- создать манекен"
      - narrate "<gold>/slapdummy remove <gray>- удалить манекен"

marallyzen_identity_setup:
  type: task
  debug: false
  script:
  - define team <script[marallyzen_identity_config].data_key[team]>
  # The team and its option persist in the world's scoreboard data. The flag
  # prevents a harmless but noisy "team already exists" message on restarts.
  - if !<server.has_flag[marallyzen_identity_team_ready]>:
    - execute as_server "team add <[team]>" silent
    - execute as_server "team modify <[team]> nametagVisibility never" silent
    - flag server marallyzen_identity_team_ready:true
  - foreach <server.online_players> as:target:
    - run marallyzen_identity_assign def:<[target]>

marallyzen_identity_assign:
  type: task
  debug: false
  definitions: target
  script:
  - if !<[target].is_online||false>:
    - stop
  - define team <script[marallyzen_identity_config].data_key[team]>
  - execute as_server "team join <[team]> <[target].name>" silent
