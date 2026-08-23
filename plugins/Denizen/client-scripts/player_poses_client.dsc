# Clientizen key bridge for the server-side Marallyzen pose controller.

marallyzen_pose_client_keys:
  type: world
  debug: false
  events:
    on keyboard key pressed name:left_bracket:
    - serverevent id:marallyzen_pose data:[pose=lay]

    on keyboard key pressed name:right_bracket:
    - serverevent id:marallyzen_pose data:[pose=sit]

    # Any movement key asks the server to leave sitting mode. Crawling keeps
    # these keys untouched and remains movable.
    on keyboard key pressed name:w:
    - serverevent id:marallyzen_pose data:[pose=move]

    on keyboard key pressed name:a:
    - serverevent id:marallyzen_pose data:[pose=move]

    on keyboard key pressed name:s:
    - serverevent id:marallyzen_pose data:[pose=move]

    on keyboard key pressed name:d:
    - serverevent id:marallyzen_pose data:[pose=move]

    on keyboard key pressed name:space:
    - serverevent id:marallyzen_pose data:[pose=move]
