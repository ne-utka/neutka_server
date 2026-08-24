# Shows the two input slots of an anvil as physical items on its top surface.
# The result slot is intentionally never rendered. Displays are public to
# nearby observers but hidden from the player currently using the GUI.

marallyzen_anvil_visual_config:
  type: data
  debug: false
  item_scale: 0.18
  surface_height: 0.58
  # Each input is this far from the block center, leaving a deliberate gap.
  slot_offset: 0.20

marallyzen_anvil_visual_events:
  type: world
  debug: false
  events:
    # Remember the physical block because InventoryOpenEvent does not expose a
    # dependable location for every server build and opening route.
    on player right clicks block:
    - if !<list[anvil|chipped_anvil|damaged_anvil].contains[<context.location.material.name>]>:
      - stop
    - flag player marallyzen_anvil_pending_block:<context.location> expire:2s

    on player opens anvil:
    - define anvil <player.flag[marallyzen_anvil_pending_block]||null>
    - flag player marallyzen_anvil_pending_block:!
    - if <[anvil]> == null:
      - stop
    - if !<list[anvil|chipped_anvil|damaged_anvil].contains[<[anvil].material.name>]>:
      - stop
    - run marallyzen_anvil_visual_start def:<[anvil]>

    # Read the inventory one tick after Bukkit has applied each mutation.
    after player clicks in anvil:
    - if <player.has_flag[marallyzen_anvil_visual]>:
      - wait 1t
      - run marallyzen_anvil_visual_update

    after player drags in anvil:
    - if <player.has_flag[marallyzen_anvil_visual]>:
      - wait 1t
      - run marallyzen_anvil_visual_update

    on player closes anvil:
    - run marallyzen_anvil_visual_cleanup

    on player quits:
    - run marallyzen_anvil_visual_cleanup

    on player dies:
    - run marallyzen_anvil_visual_cleanup

marallyzen_anvil_visual_start:
  type: task
  debug: false
  definitions: anvil
  script:
  - run marallyzen_anvil_visual_cleanup
  # Only the first active user owns the public display layer of this block.
  - define owner <[anvil].flag[marallyzen_anvil_visual_owner]||null>
  - if <[owner]> != null:
    - if <[owner].is_online||false> && <[owner].has_flag[marallyzen_anvil_visual]||false> && <[owner].flag[marallyzen_anvil_visual.block]||null> == <[anvil]>:
      - stop
    - flag <[anvil]> marallyzen_anvil_visual_owner:!
  - flag <[anvil]> marallyzen_anvil_visual_owner:<player>
  - flag player marallyzen_anvil_visual.block:<[anvil]>
  - flag player marallyzen_anvil_visual.entities:<map[]>
  - wait 1t
  - run marallyzen_anvil_visual_update

marallyzen_anvil_visual_update:
  type: task
  debug: false
  script:
  - if !<player.has_flag[marallyzen_anvil_visual]>:
    - stop
  - define anvil <player.flag[marallyzen_anvil_visual.block]||null>
  - if <[anvil]> == null:
    - run marallyzen_anvil_visual_cleanup
    - stop
  - if !<list[anvil|chipped_anvil|damaged_anvil].contains[<[anvil].material.name>]>:
    - run marallyzen_anvil_visual_cleanup
    - stop

  # Snap to the same four player-relative orientations used by the workbench.
  - define yaw <player.location.yaw.add[360].mod[360]>
  - if <[yaw]> < 45 || <[yaw]> >= 315:
    - define side south
  - else if <[yaw]> < 135:
    - define side west
  - else if <[yaw]> < 225:
    - define side north
  - else:
    - define side east

  # Anvil slots 1 and 2 are inputs. Slot 3 is the result and is ignored.
  - repeat 2 as:slot:
    - define item <player.open_inventory.slot[<[slot]>]||air>
    - define entity <player.flag[marallyzen_anvil_visual.entities.<[slot]>]||null>
    - if <[item].material.name> == air:
      - if <[entity]> != null && <[entity].is_spawned||false>:
        - remove <[entity]>
      - flag player marallyzen_anvil_visual.entities.<[slot]>:!
      - repeat next

    - define shown_item <[item].with[quantity=1]>
    - if <[entity]> != null && <[entity].is_spawned||false>:
      - adjust <[entity]> item:<[shown_item]>
      - adjust <[entity]> display:fixed
      - adjust <[entity]> pivot:fixed
      - adjust <[entity]> right_rotation:<location[1,0,0].to_axis_angle_quaternion[1.570796327]>
      - choose <[side]>:
        - case south:
          - adjust <[entity]> left_rotation:<location[0,1,0].to_axis_angle_quaternion[0]>
        - case north:
          - adjust <[entity]> left_rotation:<location[0,1,0].to_axis_angle_quaternion[3.141592654]>
        - case west:
          - adjust <[entity]> left_rotation:<location[0,1,0].to_axis_angle_quaternion[-1.570796327]>
        - case east:
          - adjust <[entity]> left_rotation:<location[0,1,0].to_axis_angle_quaternion[1.570796327]>
      - repeat next

    - define offset <script[marallyzen_anvil_visual_config].data_key[slot_offset]>
    - if <[slot]> == 1:
      - define offset <[offset].mul[-1]>
    - define item_offset <location[<[offset]>,0,0]>
    - choose <[side]>:
      - case east:
        - define item_offset <[item_offset].rotate_around_y[1.570796327]>
      - case west:
        - define item_offset <[item_offset].rotate_around_y[-1.570796327]>
      - case north:
        - define item_offset <[item_offset].rotate_around_y[3.141592654]>
    - define position <[anvil].center.add[<[item_offset]>].add[0,<script[marallyzen_anvil_visual_config].data_key[surface_height]>,0]>
    - define scale <script[marallyzen_anvil_visual_config].data_key[item_scale]>
    - spawn item_display[item=<[shown_item]>;display=fixed;pivot=fixed;scale=<[scale]>,<[scale]>,<[scale]>;interpolation_duration=2t;teleport_duration=0t;view_range=16;shadow_radius=0] <[position]> save:anvil_item
    - define entity <entry[anvil_item].spawned_entity>
    - adjust <[entity]> right_rotation:<location[1,0,0].to_axis_angle_quaternion[1.570796327]>
    - choose <[side]>:
      - case south:
        - adjust <[entity]> left_rotation:<location[0,1,0].to_axis_angle_quaternion[0]>
      - case north:
        - adjust <[entity]> left_rotation:<location[0,1,0].to_axis_angle_quaternion[3.141592654]>
      - case west:
        - adjust <[entity]> left_rotation:<location[0,1,0].to_axis_angle_quaternion[-1.570796327]>
      - case east:
        - adjust <[entity]> left_rotation:<location[0,1,0].to_axis_angle_quaternion[1.570796327]>
    - adjust <[entity]> force_no_persist:true
    - flag <[entity]> marallyzen_anvil_input_display:true
    - flag player marallyzen_anvil_visual.entities.<[slot]>:<[entity]>
    - adjust <player> hide_entity:<[entity]>

marallyzen_anvil_visual_cleanup:
  type: task
  debug: false
  script:
  - define anvil <player.flag[marallyzen_anvil_visual.block]||null>
  - if <[anvil]> != null && <[anvil].flag[marallyzen_anvil_visual_owner]||null> == <player>:
    - flag <[anvil]> marallyzen_anvil_visual_owner:!
  - define entities <player.flag[marallyzen_anvil_visual.entities]||<map[]>>
  - foreach <[entities].values> as:entity:
    - if <[entity].is_spawned||false>:
      - remove <[entity]>
  - flag player marallyzen_anvil_visual:!
  - flag player marallyzen_anvil_pending_block:!
