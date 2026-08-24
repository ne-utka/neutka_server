# Makes an exposed stonecutter blade deal contact damage while stood upon.
# A per-player mutex prevents the rapidly firing step event from spawning many
# simultaneous damage queues.

marallyzen_stonecutter_damage_config:
  type: data
  debug: false
  # Minecraft health is measured in half-hearts: 2 HP = one full heart.
  damage: 2
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
    - run marallyzen_stonecutter_damage_loop def:<player>|<[session]>|<context.location>

    on player dies:
    - flag player marallyzen_stonecutter_damage_active:!

    on player quits:
    - flag player marallyzen_stonecutter_damage_active:!

marallyzen_stonecutter_damage_loop:
  type: task
  debug: false
  definitions: victim|session|cutter
  script:
  - while <[victim].flag[marallyzen_stonecutter_damage_active]||null> == <[session]>:
    # Keep spawned-entity tags on separate lines: Denizen resolves every tag in
    # a condition before comparing it, so this avoids errors after disconnects.
    - if !<[victim].is_online||false>:
      - stop
    - if <[victim].health||0> <= 0:
      - flag <[victim]> marallyzen_stonecutter_damage_active:!
      - stop
    # Test the block immediately under the player's feet against the exact
    # cutter that started this queue. Walking onto another block ends it and a
    # fresh step event can safely start another session.
    - define standing_block <[victim].location.sub[0,0.2,0].block_location>
    - if <[cutter].material.name> != stonecutter || <[standing_block]> != <[cutter].block_location>:
      - flag <[victim]> marallyzen_stonecutter_damage_active:!
      - stop
    - flag <[victim]> marallyzen_stonecutter_damage_active:<[session]> expire:2s
    # Vanilla damage immunity lasts longer than the requested 10-tick cadence.
    # Reset only its current remainder so every stonecutter pulse is applied.
    - adjust <[victim]> no_damage_duration:0t
    - hurt <script[marallyzen_stonecutter_damage_config].data_key[damage]> <[victim]> cause:contact source:<[cutter]>
    - wait <script[marallyzen_stonecutter_damage_config].data_key[interval]>
