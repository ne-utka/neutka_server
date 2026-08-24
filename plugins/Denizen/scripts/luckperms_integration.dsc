# One-time LuckPerms bootstrap for the current Marallyzen command surface.
# Public read/cancel paths remain public inside their command scripts. Only
# mutating content-management operations are granted to the builder chain.

marallyzen_luckperms_events:
  type: world
  debug: false
  events:
    on server start:
    - run marallyzen_luckperms_bootstrap delay:10s
    - run marallyzen_luckperms_bootstrap_v2 delay:12s
    - run marallyzen_luckperms_bootstrap_v3 delay:14s

    on reload scripts:
    - run marallyzen_luckperms_bootstrap_v2 delay:2s
    - run marallyzen_luckperms_bootstrap_v3 delay:3s

marallyzen_luckperms_bootstrap:
  type: task
  debug: false
  script:
  - if <server.has_flag[marallyzen_luckperms_bootstrap_v1]>:
    - stop

  # Read-only/session paths of the mixed commands remain available to everyone.
  - execute as_server "lp group default permission set marallyzen.poster.use true" silent
  - execute as_server "lp group default permission set marallyzen.dictaphone.use true" silent

  # Content builders can manage every persistent visual system, without
  # receiving Denizen /ex, Citizens administration or LuckPerms management.
  - execute as_server "lp creategroup builder" silent
  - execute as_server "lp group builder parent add default" silent
  - execute as_server "lp group builder permission set marallyzen.poster.admin true" silent
  - execute as_server "lp group builder permission set marallyzen.dictaphone.admin true" silent
  - execute as_server "lp group builder permission set marallyzen.phantomitems.admin true" silent
  - execute as_server "lp group builder meta setprefix 50 &2[Builder] " silent

  # Admin inherits all server-content controls. Additional plugin permissions
  # can be attached here later without widening the builder role.
  - execute as_server "lp creategroup admin" silent
  - execute as_server "lp group admin parent add builder" silent
  - execute as_server "lp group admin meta setprefix 80 &6[Admin] " silent

  # Owner is the only role allowed to edit LuckPerms itself. This deliberately
  # avoids the global '*' permission while retaining complete LP management.
  - execute as_server "lp creategroup owner" silent
  - execute as_server "lp group owner parent add admin" silent
  - execute as_server "lp group owner permission set luckperms.* true" silent
  - execute as_server "lp group owner meta setprefix 100 &c[Owner] " silent
  - execute as_server "lp user dc4583b7-fa77-4621-bc85-03a55ae19cb0 parent add owner" silent

  - flag server marallyzen_luckperms_bootstrap_v1:true

marallyzen_luckperms_bootstrap_v2:
  type: task
  debug: false
  script:
  - if <server.has_flag[marallyzen_luckperms_bootstrap_v2]>:
    - stop
  - execute as_server "lp group builder permission set marallyzen.identity.admin true" silent
  - flag server marallyzen_luckperms_bootstrap_v2:true

marallyzen_luckperms_bootstrap_v3:
  type: task
  debug: false
  script:
  - if <server.has_flag[marallyzen_luckperms_bootstrap_v3]>:
    - stop
  # Cutscenes can change another player's camera and gamemode, so unlike the
  # content placement tools this remains restricted to the admin chain.
  - execute as_server "lp group admin permission set marallyzen.cutscene.admin true" silent
  - flag server marallyzen_luckperms_bootstrap_v3:true
