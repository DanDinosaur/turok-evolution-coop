# Turok: Evolution – 2-Player Split-Screen Co-op Mod

Play the entire **Turok: Evolution** single-player campaign with a friend in local split-screen co-op on the original Xbox version of the game.

**Split screen starts automatically.** There's no menu option to turn on. If a second controller is connected when a level loads, Player 2 joins and the screen splits top/bottom. With only one controller, the game plays as normal single-player. If you plug in the second controller mid-level, Player 2 joins the next time a level or checkpoint loads.

**Tested on Xbox 360 only** (RGH/JTAG with Aurora, using original-Xbox backwards compatibility). It may also run on an original Xbox (softmod/modchip) or the xemu emulator, but those haven't been tested yet. Reports are welcome in the Issues tab.

Made by **DanDinosaur**.

> **No game files are included.** You need your own copy of *Turok: Evolution* for the original Xbox (USA / NTSC, Title ID `41430004`). The patcher adds the mod to your ISO.

## Features

- **2-player split-screen co-op** through the whole campaign: plug in a second controller and the screen splits top/bottom.
  - The **flight levels** (where you ride the Quetzalcoatlus) are still single-player for now.
- **Player 2 is Metalhead** and **Player 1 is Tal'Set**, using the multiplayer character models, with running/swimming animations and a visible weapon in hand.
- **Shared pickups.**
- **No friendly fire.**
- **Respawning:** if one player dies, they respawn next to their partner after 10 seconds, and their screen goes black while they wait. If both players are down, the game restarts from the checkpoint as normal.
- **In-game cutscenes** switch to Player 1's view in full screen.
- **Co-op weapons and ammo:** in co-op you get all weapons you've unlocked so far in the campaign, plus unlimited ammo, built in without using the cheat menu, so **saving still works**.
- **16:9 widescreen** for the whole game, single-player included.

## What you need

- **Your own copy of Turok: Evolution for the original Xbox, USA version** (NTSC, Title ID `41430004`), as an ISO file. Other regions (PAL/Europe) won't work, and the patcher will tell you if your copy doesn't match.
- **Two controllers.**
- **A way to play original Xbox games:**
  - **Xbox 360 RGH/JTAG with Aurora:** this is what the mod was tested on. Your console needs original-Xbox backwards compatibility set up; the hacked compatibility files that run more games than officially supported work.
  - **Original Xbox (softmod/modchip) or the xemu emulator:** untested. It may well work, but it hasn't been tried.
- **A computer to run the patcher:**
  - **Windows 10/11:** nothing extra to install.
  - **Mac or Linux:** Python 3, from [python.org](https://www.python.org/downloads/).
- **Free disk space:** about as much as your ISO's size. The patcher writes a modded copy and leaves your original untouched.

## How to install

### Step 1: Download

1. Download `turok-evolution-coop-v1.0.zip` from the **[Releases](../../releases)** page.
2. **Windows only:** before unzipping, right-click the zip, choose **Properties**, tick **Unblock** if you see it, then click **OK**. This stops Windows blocking the patcher.
3. Unzip it anywhere, for example to your Desktop.

### Step 2: Patch your ISO

**Windows:**

1. Drag your Turok: Evolution `.iso` file onto **`Patch_Turok_Coop.bat`**. Or double-click the `.bat` and, when it asks, drag the ISO into the window and press **Enter**.
2. If Windows shows *"Windows protected your PC"*, click **More info → Run anyway**.
3. Wait until it says **Done**. Copying a large ISO can take a few minutes.

**Mac/Linux:** open a terminal in the unzipped folder and run:

```
python3 turok_coop_patch.py "/path/to/Turok Evolution.iso"
```

You get a new file next to your ISO named `<your iso name>_coop.iso`. **Your original ISO is never changed.**

### Step 3: Play it

- **Xbox 360 RGH (Aurora):**
  1. Convert `_coop.iso` to GOD format with **Iso2God** (or ISO2GOD-cs).
  2. Copy the resulting `41430004` folder to your console, for example `Hdd1:\Content\0000000000000000\41430004`, replacing any older copy of the game.
  3. Make sure that folder is in one of Aurora's scan paths, then launch the game from Aurora.
- **Original Xbox:** load the `_coop.iso` the way you normally load ISOs, or extract it (for example with extract-xiso) and copy the folder to the console.
- **xemu:** xemu needs XISO format. If yours is a full redump-style ISO, convert the patched ISO with extract-xiso first.

**If you already have the game as a GOD folder on your PC** (the `41430004` folder), you can skip Iso2God: drag that folder onto `Patch_Turok_Coop.bat`. It makes a patched copy in `GOD_coop\41430004` next to the patcher, and you copy that to your console. You can also patch an extracted game folder or its `default.xbe`; that writes `default_coop.xbe`, which you rename to `default.xbe`.

### Step 4: Set up and play

- **Widescreen:** set your console's video output to **16:9 / widescreen**: the 360 dashboard display settings, the original Xbox dashboard's Widescreen option, or xemu's display settings. On a 4:3 setting the picture looks squeezed.
- **Co-op:** connect a **second controller** and start or continue the campaign. Split screen turns on automatically when the level loads.
- **Saves** work as normal, including in co-op.

### Uninstalling

Just play your original, unpatched ISO or GOD folder again. The patcher never changes it.

## Troubleshooting

| Message | What it means |
|---|---|
| *does not match the original Turok: Evolution (USA) XBE* | Your copy is a different region or version, or it was changed by another mod. You need the original USA release. |
| *this default.xbe already has the co-op mod* | That file is already patched, so there's nothing to do. |
| *this file is not an Xbox game ISO* | The file isn't an Xbox disc image. It may be a PS2/GameCube version, or a broken download. |
| *output file/folder already exists* | Delete or rename the old `_coop.iso` / `GOD_coop` folder from a previous run, then try again. |
| The window flashes and closes, or nothing happens | Unblock the zip (Step 1), unzip it, and run the `.bat` from the unzipped folder, not from inside the zip. |
| The game shows black bars or a stretched picture | Set the console's video output to widescreen (Step 4). |

## Known issues

- Minor visual issues:
  - Tal'Set's feet sit slightly below the floor.
  - There's no crouch animation.
- When one player is swimming, the water effect can also show on the other player's screen. There's very little swimming in the campaign, so you'll rarely see it.
- Very rarely, a quick-fire shot from the primitive bow can nick Player 2. You'll hardly ever use that bow after the first level.
- Flight levels aren't set up for co-op yet.

## Credits and legal

Co-op mod by **DanDinosaur**.

*Turok: Evolution* is © its respective owners. This is an unofficial fan mod, not affiliated with or endorsed by the game's publishers or rights holders. It contains no game code or assets: the patch only holds the mod's own changes, and you apply it to a copy of the game you own.

The patcher scripts are released under the MIT License (see `LICENSE`).
