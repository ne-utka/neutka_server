# SpringRP Launcher Privacy Policy

Effective date: August 27, 2026

This Privacy Policy describes how the SpringRP Launcher desktop application
("SpringRP Launcher", "the launcher", "we") handles information when a user
signs in with Microsoft or with a Telegram-confirmed nickname.

## Information handled by the launcher

During Microsoft authentication, the launcher receives and handles:

- Microsoft OAuth access and refresh tokens;
- Xbox Live and XSTS authentication tokens and the Xbox user hash;
- a Minecraft Services access token;
- the Minecraft: Java Edition profile ID and player name.

The launcher does not request the user's Microsoft password. Authentication is
completed on Microsoft's own website through the OAuth 2.0 device-code flow.

If the user chooses nickname mode instead, the entered nickname is sent to
the SpringRP auth bot (`springrp.ru/auth-bot/launcher.php`) so a one-time
Telegram confirmation code can be issued. After `@springauthbot` confirms
that code, the launcher stores the confirmed nickname locally and uses it as
an offline Minecraft identity. The nickname is also sent to `mc-heads.net` to
request the avatar shown on the home screen.

## Purpose and legal basis

This information is processed only at the user's request to:

- authenticate the user's Microsoft and Xbox account, or confirm a Telegram
  nickname binding;
- confirm access to a Minecraft: Java Edition profile when Microsoft is used;
- identify the Minecraft profile used to launch the game;
- display the signed-in player name, account kind and avatar in the launcher.

Processing is necessary to provide the authentication feature requested by the
user. The user initiates the flow explicitly by selecting **Microsoft
authentication** or by submitting a nickname for Telegram confirmation, and
can decline or cancel Microsoft consent on Microsoft's website.

## Storage and retention

Authentication tokens and the confirmed nickname are kept in the launcher's
process memory while it is running. They are also written to `session.toml`
in the launcher's Windows application-data directory so the user stays signed
in after a restart.

That file is encrypted with Windows DPAPI for the current Windows user.
Copying it to another account or another computer does not restore the
session. Selecting sign out deletes the file and clears the in-memory
session. Closing the launcher without signing out leaves the encrypted file
in place until the next launch.

No operator-controlled SpringRP game server receives Microsoft, Xbox or
Minecraft authentication tokens. The auth bot stores only the Telegram chat
binding and short-lived login codes needed to confirm a nickname.

## Sharing and third-party services

The Microsoft authentication flow communicates directly with the following
service providers solely to complete sign-in:

- Microsoft identity platform (`login.microsoftonline.com`);
- Xbox Live authentication (`user.auth.xboxlive.com`);
- Xbox Secure Token Service (`xsts.auth.xboxlive.com`);
- Minecraft Services (`api.minecraftservices.com`).

Nickname mode communicates with:

- the SpringRP auth bot (`springrp.ru/auth-bot/launcher.php`), which receives
  the nickname to issue and confirm a Telegram login code, and later to check
  that the nick is still bound;
- Telegram, through `@springauthbot`, when the user sends that code.

Both modes may contact:

- MC Heads (`mc-heads.net`), which receives the player name in the avatar URL
  and ordinary connection metadata such as the IP address in order to return a
  rendered player-head image.

These providers process information under their own terms and privacy policies.
SpringRP does not sell personal information, share it with advertisers or use
it for behavioral advertising.

## Analytics and tracking

The current launcher does not include analytics, advertising SDKs, crash
reporting services or behavioral tracking. It does not create advertising
profiles or use authentication information for marketing.

## Security

Authentication tokens remain inside the native Rust backend and are not
returned to the web-based user interface. Persistent sessions are encrypted
with Windows DPAPI before they are written to disk. The launcher uses HTTPS
connections to the official Microsoft, Xbox and Minecraft service endpoints
and to the SpringRP auth bot. No client secret is embedded in the public
desktop application; Microsoft sign-in uses the device-code flow intended for
public clients.

## User choices and rights

Users may:

- choose Telegram nickname mode instead of Microsoft authentication;
- cancel the Microsoft consent flow before completing it;
- select sign out to delete the local session file and clear the launcher
  session;
- revoke previously granted SpringRP access from their Microsoft account;
- contact us with a privacy question or request.

Requests relating to data held directly by Microsoft, Xbox, Minecraft or
Telegram must be submitted to the relevant provider. SpringRP cannot access
or delete data held solely by those providers.

## Children's privacy

SpringRP Launcher does not knowingly collect or retain children's personal
information on an operator-controlled backend beyond the nickname binding
needed for server access. Microsoft family and account controls continue to
apply to the Microsoft authentication flow.

## Changes to this policy

If launcher data handling changes, this policy will be updated before the new
behavior is released. The effective date above will be revised when material
changes are made.

## Contact

For privacy questions or requests, contact:
[va@llebedev.ru](mailto:va@llebedev.ru).

SpringRP Launcher is an independent project and is not affiliated with or
endorsed by Microsoft, Xbox or Mojang Studios.
