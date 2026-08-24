# Allows players to repair damaged anvils with one iron ingot per damage stage.
# Full anvils are ignored, so normal right-click interaction remains available.

marallyzen_anvil_repair_config:
  type: data
  debug: false
  cooldown: 4t

marallyzen_anvil_repair_events:
  type: world
  debug: false
  events:
    on player right clicks block with:iron_ingot using:hand:
    - define material <context.location.material>
    - if !<list[chipped_anvil|damaged_anvil].contains[<[material].name]>]:
      - stop

    # Block the inventory only when an actual repair can happen. The event may
    # double-fire on some clients, so the short ratelimit also protects ingots.
    - determine passively cancelled
    - ratelimit <player> <script[marallyzen_anvil_repair_config].data_key[cooldown]>
    - define direction <[material].direction>
    - if <[material].name> == damaged_anvil:
      - define repaired_material chipped_anvil
    - else:
      - define repaired_material anvil

    - take iteminhand quantity:1
    - modifyblock <context.location> <[repaired_material]>[direction=<[direction]>]
    - playsound <context.location.center> sound:block_anvil_use volume:0.65 pitch:1.35
    - actionbar "<gray>Вы восстановили наковальню с помощью <white>железного слитка<gray>." targets:<player>
