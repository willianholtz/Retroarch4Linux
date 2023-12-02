![Retroarch para ArchLinux](IMG/Retroarch.png)

![Retroarch para ArchLinux](IMG/01.png)

![Retroarch para ArchLinux](IMG/02.png)

# The best of Retroarch for Linux Project
Retroarch configured for Arch Linux and Linux in general.

# Initial setting
Download retroarch on your Linux, the default system settings are always in /home/user/.config/retroarch.
The configuration of this repository is already pre-configured to point directly to ~/.config regardless of the active user.

## Linux modification
Retroarch was configured from scratch, using some packages found on the net, such as:
- Wallpaper from Crazymac project
- Bezzels for all games
- Mega Bezels pack for shaders (CRT) and configured without TV curvature (Default comes with curvature)
- All roms (games) have their overlays (roms not included!).

## Games (Roms)
Roms must all be NO-INTRO or REDUMP (RECOMMENDED), or edit all the roms you download.

- [Redump](http://redump.org)
- [No-Intro](https://no-intro.org)

All roms should be REDUMP preferably, thus making retro arch configuration files with playlists.lpl and core configs (OVERLAYS) defaults.

## BIOS
Bios are in the system folder, but only what is necessary for this project to work, if you want to change, or use other bios, use Google to do so!

# TIPS
- You can found roms in archive.org.
- Retroarch does not use MAME emulators, only FBNeo, and all roms work perfectly (as far as I was able to do the tests) so avoid using the MAME core (any of them, as you won't need it). There is a rom pack, which has 16GB with all the perfect roms, you can find it using the following keywords: "Final Burn Alpha v0.2.97.43 Merged Arcade Roms Only" (Torrent)

# What do you need to know?
Retroarch is configured with CRT shader (Mega Bezel/Presets/MBZ__3__STD) and overlay bezzels for a better experience. You can disable or change the shader at will.
Package contains around 25GB, with 100% of the emulator configured, using Vulkan. It is also worth noting that GPU and CPU usage may change depending on the computer. For example, my equipment is:
- Ryzen 7 5700x
- RXT 2060 12GB
- 64GB RAM
- 4K monitor

In this configuration it is observed that CPU usage is 1% or not even that for retroarch in the MENU and in-game.
On the GPU, due to the use of shaders, in the MENU the use is between 15% and 20% maximum, in-game, you can notice the difference, 40% to 60%, although 99% of the time it is on average 60% of GPU usage!

**You don't need to configure ANYTHING, other than just downloading the roms and placing them in their proper places. Just download the roms and enjoy!
