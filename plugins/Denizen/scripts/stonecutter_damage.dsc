# Makes an exposed stonecutter blade deal contact damage while stood upon.
# A per-player mutex prevents the rapidly firing step event from spawning many
# simultaneous damage queues.

marallyzen_stonecutter_damage_config:
  type: data
  debug: false
  damage: 1
  interval: 10t

marallyzen_stonecutter_damage_events:
  type: world
  debug: false
  events:
    on player steps on stonecutter:
    - if <player.has_flag[marallyzen_stonecutter_damage_active]>:
      - stop
    - define session <util.random_uuid>
    # The expiry makes the mechanic recover automatically if queues are stopped
    # by a script reload while a player is still standing on the blade.
    - flag player marallyzen_stonecutter_damage_active:<[session]> expire:2s
    - run marallyzen_stonecutter_damage_loop def:<player>|<[session]>

    on player dies:
    - flag player marallyzen_stonecutter_damage_active:!

    on player quits:
    - flag player marallyzen_stonecutter_damage_active:!

marallyzen_stonecutter_damage_loop:
  type: task
  debug: false
  definitions: victim|session
  script:
  - while <[victim].flag[marallyzen_stonecutter_damage_active]||null> == <[session]>:
    # Keep spawned-entity tags on separate lines: Denizen resolves every tag in
    # a condition before comparing it, so this avoids errors after disconnects.
    - if !<[victim].is_online||false>:
      - stop
    - if <[victim].health||0> <= 0:
      - flag <[victim]> marallyzen_stonecutter_damage_active:!
      - stop
    - define cutter <[victim].location.sub[0,0.2,0]>
    - if <[cutter].material.name> != stonecutter:
      - flag <[victim]> marallyzen_stonecutter_damage_active:!
      - stop
    - flag <[victim]> marallyzen_stonecutter_damage_active:<[session]> expire:2s
    - hurt <script[marallyzen_stonecutter_damage_config].data_key[damage]> <[victim]> cause:contact source:<[cutter]>
    - wait <script[marallyzen_stonecutter_damage_config].data_key[interval]>
