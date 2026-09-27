# Jellyfin TV installer for spectors

A one-click installer that puts the right Jellyfin app on your Samsung TV, already pointed at the server, so you only need to sign in.

| | |
|---|---|
| Your TV | Samsung, Tizen 9 (2025 model) |
| App it installs | `Jellyfin.wgt`: the standard build, Jellyfin web v12.1 |
| Server it connects to | `https://jellyfin.pcmunro.synology.me` |

It's a customized build of [Apps2Samsung](https://github.com/Apps2Samsung/Apps2Samsung) (MIT license). It runs on Windows 10 and 11 (64-bit), needs no installation, and changes nothing on your PC apart from its own settings.

## What you need

- A Windows PC on the **same home network** as the TV
- About 10 minutes
- Your Jellyfin username and password
- A free **Samsung account**. Your TV is a 2023-or-newer model, so the installer needs one to create a signing certificate for your TV.

## Steps

1. **Find your PC's IP address.** Press <kbd>Win</kbd>+<kbd>R</kbd>, type `cmd`, press Enter, then type `ipconfig` and press Enter. Note the **IPv4 Address**, something like `192.168.1.25`.
2. **Turn on Developer mode on the TV:**
   1. Open **Apps** on the TV.
   2. Using the number buttons on the remote, or the on-screen keypad, type **1 2 3 4 5**.
   3. Switch **Developer mode ON**, and enter your PC's IP address from step 1 as the **Host PC IP**.
   4. **Restart the TV properly:** hold the remote's power button until the TV turns off and back on. A quick off/on isn't enough.
3. **Run `Jellyfin-TV-Installer-spectors.exe`.** The first launch takes about 20 seconds while it unpacks. If Windows shows **"Windows protected your PC"**, click **More info → Run anyway**. The file isn't signed by a publisher, which is why Windows warns you.
4. The window, titled *Jellyfin installer for spectors*, finds your TV and **preselects the right app and version**. Check that your TV is selected under **Select TV**, then click **Install**.
   - **The first time**, a Samsung account sign-in window opens. Sign in and it creates a certificate for your TV automatically. This happens once.
5. When it says the install finished, open **Jellyfin** on the TV and sign in with your Jellyfin username and password. The server address is already filled in.
6. **Optional:** go back to Apps → **1 2 3 4 5** and turn Developer mode **OFF**. The Jellyfin app keeps working.

## Your current Jellyfin app

Your TV currently has a different Jellyfin app ("Jellyfin for Tizen 1.1.0"). If you end up with **two** Jellyfin apps, keep the one you just signed in to and delete the other: **Apps → ⚙ Settings**, select it, then **Delete**.

## If something goes wrong

- **The TV doesn't appear, or you see "TV Name could not be found":**
  - Make sure Developer mode shows **your PC's** IP address, and that you fully restarted the TV.
  - **Turn off any VPN** (NordVPN, Tailscale, work VPN) while installing. They can route the connection away from your home network, and then the TV refuses it.
- **Install fails partway:** click **Install** again. If it still fails, send a screenshot of the error to the person who gave you this installer.
- **Jellyfin keeps signing you out:** tell the person who gave you this installer.

## Why this build

Your TV runs Tizen 9, which runs the current Jellyfin web client (v12.1) without trouble. That's the same version as the server, which keeps sign-in reliable.

---

## For the builder

This repo builds the installer from the official Apps2Samsung source, a small patch and a preset:

| File | Purpose |
|---|---|
| `preset.json` | Window title, which Jellyfin `.wgt` to preselect, and the server address written into the TV app |
| `apps2samsung-preset.patch` | Adds `Helpers/Preset.cs`. At startup it reads `Assets/preset.json`, sets the Jellyfin server URL, and turns off the update check. After the release list loads, it selects the release carrying `assetName` |
| `build.ps1` | Clones Apps2Samsung at `v2.8.1`, applies the patch, adds the preset, runs `dotnet publish` as a single self-contained file, and zips the result with Apps2Samsung's LICENSE and NOTICE |

```powershell
.\build.ps1                            # needs git and the .NET 10 SDK
.\build.ps1 -Apps2SamsungTag v2.8.2    # after checking the patch still applies
```

Output goes to `dist\`: `Jellyfin-TV-Installer-spectors.exe` (about 200 MB, everything inside) and a `.zip` for handing out.

No Jellyfin credentials or API keys are included. The installed TV app only gets the server address. The builds come from [jeppevinkel/jellyfin-tizen-builds](https://github.com/jeppevinkel/jellyfin-tizen-builds); the preset picks the newest release that contains `Jellyfin.wgt`.

Licenses: Apps2Samsung is MIT (Copyright (c) 2025 Patrick Stel; see `LICENSE-Apps2Samsung.txt` and `NOTICE-Apps2Samsung.md` in the zip). The patch and scripts in this repo are MIT too.
