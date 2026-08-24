# Makes an exposed stonecutter blade deal continuous contact damage.
# A single global scanner is used instead of the unreliable one-shot step
# event, so standing still and entering from any block edge behave identically.

marallyzen_stonecutter_damage_config:
  type: data
  debug: false
  # Minecraft health is measured in half-hearts: 6 HP = three full hearts.
  damage: 6
  interval: 10t
  # A player is 0.6 blocks wide. Probe close to all four footprint corners so
  # touching the blade from an edge counts even when the player's center is on
  # the neighbouring block.
  footprint_radius: 0.29

marallyzen_stonecutter_damage_events:
  type: world
  debug: false
  events:
    on reload scripts:
    - define session <util.random_uuid>
    # Replacing the session instantly retires a loop left by /ex reload. The
    # expiry also recovers if a queue is externally stopped.
    - flag server marallyzen_stonecutter_scanner:<[session]> expire:2s
    - run marallyzen_stonecutter_damage_loop def:<[session]>

marallyzen_stonecutter_damage_loop:
  type: task
  debug: false
  definitions: session
  script:
  - while <server.flag[marallyzen_stonecutter_scanner]||null> == <[session]>:
    - flag server marallyzen_stonecutter_scanner:<[session]> expire:2s
    - define radius <script[marallyzen_stonecutter_damage_config].data_key[footprint_radius]>
    - foreach <server.online_players> as:victim:
      - if <[victim].gamemode> == spectator || <[victim].health||0> <= 0:
        - foreach next
      - define feet <[victim].location.sub[0,0.12,0]>
      - define probes <list[]>
      - define probes:->:<[feet]>
      - define probes:->:<[feet].add[<[radius]>,0,<[radius]>]>
      - define probes:->:<[feet].add[<[radius]>,0,-<[radius]>]>
      - define probes:->:<[feet].add[-<[radius]>,0,<[radius]>]>
      - define probes:->:<[feet].add[-<[radius]>,0,-<[radius]>]>
      - define cutter null
      - foreach <[probes]> as:probe:
        - if <[probe].material.name> == stonecutter:
          - define cutter <[probe].block_location>
          - foreach stop
      - if <[cutter]> == null:
        - foreach next
      # Vanilla damage immunity lasts longer than the requested 10-tick
      # cadence. Reset its current remainder so every pulse is applied.
      - adjust <[victim]> no_damage_duration:0t
      - hurt <script[marallyzen_stonecutter_damage_config].data_key[damage]> <[victim]> cause:contact source:<[cutter]>
    - wait <script[marallyzen_stonecutter_damage_config].data_key[interval]>
