# SpringRP Launcher Privacy Policy

Effective date: August 25, 2026

This Privacy Policy describes how the SpringRP Launcher desktop application
("SpringRP Launcher", "the launcher", "we") handles information when a user
chooses Microsoft authentication.

## Information handled by the launcher

During Microsoft authentication, the launcher receives and temporarily handles:

- Microsoft OAuth access and refresh tokens;
- Xbox Live and XSTS authentication tokens and the Xbox user hash;
- a Minecraft Services access token;
- the Minecraft: Java Edition profile ID and player name.

The launcher does not request the user's Microsoft password. Authentication is
completed on Microsoft's own website through the OAuth 2.0 device-code flow.

If the user chooses manual nickname mode instead, the entered nickname is used
in the local launcher interface and is not sent to Microsoft by the launcher.
The nickname is sent to `mc-heads.net` to request the avatar shown on the home
screen.

## Purpose and legal basis

This information is processed only at the user's request to:

- authenticate the user's Microsoft and Xbox account;
- confirm access to a Minecraft: Java Edition profile;
- identify the Minecraft profile that would be used by the launcher;
- display the authenticated player name and avatar in the launcher.

Processing is necessary to provide the authentication feature requested by the
user. The user initiates the flow explicitly by selecting **Microsoft
authentication** and can decline or cancel it on Microsoft's website.

## Storage and retention

In the current implementation, authentication tokens and the authenticated
Minecraft profile are stored only in the launcher's process memory. They are
not written to a local session file or database. Selecting sign out clears the
in-memory session; closing the launcher also discards it.

No operator-controlled SpringRP backend receives or stores these authentication
tokens or profile data. Because SpringRP does not retain this account data,
there is no server-side account record for SpringRP to delete.

## Sharing and third-party services

The authentication flow communicates directly with the following service
providers solely to complete sign-in:

- Microsoft identity platform (`login.microsoftonline.com`);
- Xbox Live authentication (`user.auth.xboxlive.com`);
- Xbox Secure Token Service (`xsts.auth.xboxlive.com`);
- Minecraft Services (`api.minecraftservices.com`).
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
returned to the web-based user interface. The launcher uses HTTPS connections
to the official Microsoft, Xbox and Minecraft service endpoints. No client
secret is embedded in the public desktop application; it uses the device-code
flow intended for public clients.

## User choices and rights

Users may:

- choose manual nickname mode instead of Microsoft authentication;
- cancel the Microsoft consent flow before completing it;
- select sign out to clear the active in-memory launcher session;
- revoke previously granted SpringRP access from their Microsoft account;
- contact us with a privacy question or request.

Requests relating to data held directly by Microsoft, Xbox or Minecraft must be
submitted to the relevant provider. SpringRP cannot access or delete data held
solely by those providers.

## Children's privacy

SpringRP Launcher does not knowingly collect or retain children's personal
information on an operator-controlled backend. Microsoft family and account
controls continue to apply to the authentication flow.

## Changes to this policy

If launcher data handling changes, this policy will be updated before the new
behavior is released. The effective date above will be revised when material
changes are made.

## Contact

For privacy questions or requests, contact:
[va@llebedev.ru](mailto:va@llebedev.ru).

SpringRP Launcher is an independent project and is not affiliated with or
endorsed by Microsoft, Xbox or Mojang Studios.
