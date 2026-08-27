# SpringRP Telegram auth bot

PHP on REG.RU (`springrp.ru/auth-bot/`). Telegram cannot webhook into this host, so Paper Denizen pokes `poll.php`, which calls Telegram `getUpdates`.

`/auth <nickname>` grants LuckPerms group `игрок` for 30 days:

```text
lp user <nickname> parent addtemp игрок 30d
```

The group has `marallyzen.play`. Without it, login is kicked.

Launcher nickname login (`launcher.php`):

1. Player binds a nick with `/auth` in [@springauthbot](https://t.me/springauthbot).
2. Launcher asks `launcher.php` for a 6-digit code, or gets `not_bound`.
3. Player sends that code to the bot; launcher polls until it is verified.
4. Later restores call `GET launcher.php?nick=` to confirm the nick is still
   bound. `not_bound` drops the local session. Older PHP that ignores `nick`
   keeps returning code status, and the launcher treats that as unreachable.

Upload to `www/springrp.ru/auth-bot/` on REG.RU:

- `bot_lib.php`, `poll.php`, `claim.php`, `launcher.php`, `.htaccess`
- `.env` (never commit)

`bound.json` and `codes.json` are created at runtime. Do not commit them.

If REG.RU cannot open RCON (port 25575), `/auth` queues the nick and Paper Denizen claims it from `claim.php`.
