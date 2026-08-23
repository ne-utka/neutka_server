# Player pose controller. Arbitrary keyboard input arrives from Clientizen
# through Depenizen's validated custom event channel.

marallyzen_pose_config:
  type: data
  debug: false
  cooldown: 5t

marallyzen_pose_events:
  type: world
  debug: false
  events:
    on clientizen event id:marallyzen_pose:
    - define requested <context.pose.to_lowercase||null>
    - if <[requested]> == move:
      - if <player.flag[marallyzen_pose]||none> == sit:
        - run marallyzen_pose_clear
      - stop
    - if !<list[sit|lay].contains[<[requested]>]>:
      - stop
    - ratelimit <player> <script[marallyzen_pose_config].data_key[cooldown]>
    # An active GSit seat is technically not on the ground. Ground validation
    # is needed only when entering a pose from the normal standing state.
    - if !<player.has_flag[marallyzen_pose]> && !<player.is_on_ground>:
      - actionbar "<gray>Эту позу можно принять только на земле."
      - stop
    - run marallyzen_pose_toggle def:<[requested]>

    # Sitting ends on actual positional movement. Crawling is maintained by
    # GSit's native crawl controller, so Denizen must not rewrite the pose.
    on player walks:
    - if !<player.has_flag[marallyzen_pose]>:
      - stop
    - if <player.flag[marallyzen_pose]> != sit:
      - stop
    - if <context.old_location.x> != <context.new_location.x> || <context.old_location.y> != <context.new_location.y> || <context.old_location.z> != <context.new_location.z>:
      - run marallyzen_pose_clear

    # Shift is Minecraft's sneak action. It exits both states; GSit itself
    # releases crawl on the same action, while this handler clears our flag.
    on player starts sneaking:
    - if !<player.has_flag[marallyzen_pose]>:
      - stop
    # GSit has already removed its invisible seat/crawl controller here.
    # Calling the toggle command again would immediately put the player back.
    - flag player marallyzen_pose:!
    - actionbar "<gray>Вы встали."

    on player dies:
    - flag player marallyzen_pose:!

    on player quits:
    - flag player marallyzen_pose:!

    on player joins:
    - if <player.has_flag[marallyzen_pose]>:
      - flag player marallyzen_pose:!

marallyzen_pose_toggle:
  type: task
  debug: false
  definitions: requested
  script:
  - if <player.flag[marallyzen_pose]||none> == <[requested]>:
    - run marallyzen_pose_clear
    - stop

  # Clear the other pose before switching, so the metadata transitions never
  # overlap even if the player alternates both keys rapidly.
  - define previous <player.flag[marallyzen_pose]||none>
  - define sit_origin <player.flag[marallyzen_pose_origin]||null>
  # Clear our state before GSit dismounts. Its return teleport fires a walk
  # event, which must not be mistaken for a request to cancel/re-toggle sitting.
  - flag player marallyzen_pose:!
  - if <[previous]> == lay:
    - execute as_player "crawl" silent
  - if <[previous]> == sit:
    - execute as_player "sit" silent
    # Immediately switch the eye/body height toward crawl before the seat is
    # visually released. This hides vanilla's one-frame STANDING transition.
    - adjust <player> visual_pose:SWIMMING
    # Return to the exact grounded position recorded before mounting. Purpur
    # can otherwise retain is_on_ground=false after GSit's safe dismount.
    - if <[sit_origin]> != null:
      - teleport <player> <[sit_origin]>
    # Vanilla may recalculate the pose while acknowledging the teleport. Keep
    # the crawl pose as the final metadata update of every transition tick.
    - repeat 10:
      - adjust <player> visual_pose:SWIMMING
      - if <player.is_on_ground>:
        - repeat stop
      - wait 1t
  - if <[previous]> == lay:
    - wait 2t
  - flag player marallyzen_pose_origin:!
  - choose <[requested]>:
    - case sit:
      # GSit uses a non-living invisible seat, so no mount health bar appears.
      - flag player marallyzen_pose_origin:<player.location>
      - execute as_player "sit" silent
      - flag player marallyzen_pose:sit
      - actionbar "<gray>Вы сели. <white>]<gray> — встать."
    - case lay:
      # GSit keeps the native crawl pose and its low hitbox synchronized.
      - waituntil rate:1t max:1s <player.is_on_ground>
      - execute as_player "crawl" silent
      - wait 2t
      - if <player.visual_pose> != swimming:
        # One retry handles a late client teleport acknowledgement without
        # ever toggling off an already successful crawl.
        - waituntil rate:1t max:1s <player.is_on_ground>
        - execute as_player "crawl" silent
        - wait 2t
      - if <player.visual_pose> == swimming:
        - flag player marallyzen_pose:lay
        - actionbar "<gray>Вы легли и можете ползти. <white>[<gray> — встать."
      - else:
        - adjust <player> visual_pose:STANDING
        - actionbar "<red>Не удалось лечь: сначала встаньте на устойчивый блок."

marallyzen_pose_clear:
  type: task
  debug: false
  script:
  - define previous <player.flag[marallyzen_pose]||none>
  # Prevent GSit's dismount/return movement from recursively running this task.
  - flag player marallyzen_pose:!
  - flag player marallyzen_pose_origin:!
  - if <[previous]> == lay:
    - execute as_player "crawl" silent
  - if <[previous]> == sit:
    - execute as_player "sit" silent
  - actionbar "<gray>Вы встали."
