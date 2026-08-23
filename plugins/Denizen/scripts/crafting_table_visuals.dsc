# Shows a crafting player's 3x3 matrix as small physical items on the table.
# The displays are server-side, non-interactive, and hidden from the crafter.

marallyzen_crafting_visual_config:
  type: data
  debug: false
  # The vanilla top is 16x16 px. Its 10x10 crafting grid has 2x2 px cell
  # interiors separated by 1 px frames, so adjacent centers are exactly 3/16.
  cell_spacing: 0.1875
  # The display plane sits ~0.08 blocks above the table to prevent z-fighting
  # on flat sprites (raw ores, ingots, dusts, sticks, etc.).
  item_scale: 0.18
  surface_height: 0.58

marallyzen_crafting_visual_events:
  type: world
  debug: false
  events:
    # InventoryOpenEvent does not reliably expose the physical workbench on all
    # server builds, so remember the clicked block for the following open event.
    on player right clicks crafting_table:
    - flag player marallyzen_crafting_pending_table:<context.location> expire:2s

    on player opens workbench:
    - define table <player.flag[marallyzen_crafting_pending_table]||null>
    - flag player marallyzen_crafting_pending_table:!
    - if <[table]> == null || <[table].material.name> != crafting_table:
      - stop
    - run marallyzen_crafting_visual_start def:<[table]>

    # Use after-events so the matrix is read after Bukkit applies the click.
    after player clicks in workbench:
    - if <player.has_flag[marallyzen_crafting_visual]>:
      - wait 1t
      - run marallyzen_crafting_visual_update

    after player drags in workbench:
    - if <player.has_flag[marallyzen_crafting_visual]>:
      - wait 1t
      - run marallyzen_crafting_visual_update

    after player crafts item:
    - if <player.has_flag[marallyzen_crafting_visual]>:
      - wait 1t
      - run marallyzen_crafting_visual_update

    on player closes workbench:
    - run marallyzen_crafting_visual_cleanup

    on player quits:
    - run marallyzen_crafting_visual_cleanup

    on player dies:
    - run marallyzen_crafting_visual_cleanup

marallyzen_crafting_visual_start:
  type: task
  debug: false
  definitions: table
  script:
  - run marallyzen_crafting_visual_cleanup
  # One physical table may be viewed by many players, but only its first
  # active crafter owns the public display layer.
  - define owner <[table].flag[marallyzen_crafting_visual_owner]||null>
  - if <[owner]> != null:
    - if <[owner].is_online||false> && <[owner].has_flag[marallyzen_crafting_visual]||false> && <[owner].flag[marallyzen_crafting_visual.table]||null> == <[table]>:
      - stop
    # Recover automatically from stale locks left by a reload or restart.
    - flag <[table]> marallyzen_crafting_visual_owner:!
  - flag <[table]> marallyzen_crafting_visual_owner:<player>
  - flag player marallyzen_crafting_visual.table:<[table]>
  - flag player marallyzen_crafting_visual.entities:<map[]>
  - wait 1t
  - run marallyzen_crafting_visual_update

marallyzen_crafting_visual_update:
  type: task
  debug: false
  script:
  - if !<player.has_flag[marallyzen_crafting_visual]>:
    - stop
  - define table <player.flag[marallyzen_crafting_visual.table]||null>
  - if <[table]> == null || <[table].material.name> != crafting_table:
    - run marallyzen_crafting_visual_cleanup
    - stop
  # Match the player's F3 "Facing" direction, snapped to four cardinals.
  # Bukkit may expose East as either -90 or 270, so normalize to 0..360.
  - define yaw <player.location.yaw.add[360].mod[360]>
  - if <[yaw]> < 45 || <[yaw]> >= 315:
    - define side south
  - else if <[yaw]> < 135:
    - define side west
  - else if <[yaw]> < 225:
    - define side north
  - else:
    - define side east
  - define matrix <player.open_inventory.matrix||<list[]>>
  - repeat 9 as:slot:
    - define item <[matrix].get[<[slot]>]||air>
    - define entity <player.flag[marallyzen_crafting_visual.entities.<[slot]>]||null>
    - if <[item].material.name> == air:
      - if <[entity]> != null && <[entity].is_spawned||false>:
        - remove <[entity]>
      - flag player marallyzen_crafting_visual.entities.<[slot]>:!
      - repeat next

    # Amount is intentionally normalized: the surface shows the recipe layout,
    # never misleading piles that imply extra dropped items.
    - define shown_item <[item].with[quantity=1]>
    - if <[entity]> != null && <[entity].is_spawned||false>:
      - adjust <[entity]> item:<[shown_item]>
      # FIXED + exact quarter-turn quaternions: fully horizontal, sideways,
      # and identical for every slot (no dropped-item/randomized tilt).
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

    - define zero <[slot].sub[1]>
    - define column <[zero].mod[3]>
    - define row <[zero].div[3].round_down>
    - define x_offset <[column].sub[1].mul[<script[marallyzen_crafting_visual_config].data_key[cell_spacing]>]>
    - define z_offset <[row].sub[1].mul[<script[marallyzen_crafting_visual_config].data_key[cell_spacing]>]>
    - define grid_offset <location[<[x_offset]>,0,<[z_offset]>]>
    - choose <[side]>:
      - case east:
        - define grid_offset <[grid_offset].rotate_around_y[1.570796327]>
      - case west:
        - define grid_offset <[grid_offset].rotate_around_y[-1.570796327]>
      - case north:
        - define grid_offset <[grid_offset].rotate_around_y[3.141592654]>
    - define position <[table].center.add[<[grid_offset]>].add[0,<script[marallyzen_crafting_visual_config].data_key[surface_height]>,0]>
    - define scale <script[marallyzen_crafting_visual_config].data_key[item_scale]>
    - spawn item_display[item=<[shown_item]>;display=fixed;pivot=fixed;scale=<[scale]>,<[scale]>,<[scale]>;interpolation_duration=2t;teleport_duration=0t;view_range=16;shadow_radius=0] <[position]> save:crafting_item
    - define entity <entry[crafting_item].spawned_entity>
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
    - flag <[entity]> marallyzen_crafting_grid_display:true
    - flag player marallyzen_crafting_visual.entities.<[slot]>:<[entity]>
    # The GUI user already sees exact stack counts in the matrix. The physical
    # layer is aimed at nearby observers and is hidden from its owner.
    - adjust <player> hide_entity:<[entity]>

marallyzen_crafting_visual_cleanup:
  type: task
  debug: false
  script:
  - define table <player.flag[marallyzen_crafting_visual.table]||null>
  - if <[table]> != null && <[table].flag[marallyzen_crafting_visual_owner]||null> == <player>:
    - flag <[table]> marallyzen_crafting_visual_owner:!
  - define entities <player.flag[marallyzen_crafting_visual.entities]||<map[]>>
  - foreach <[entities].values> as:entity:
    - if <[entity].is_spawned||false>:
      - remove <[entity]>
  - flag player marallyzen_crafting_visual:!
  - flag player marallyzen_crafting_pending_table:!
