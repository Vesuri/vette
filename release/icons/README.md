# Release icon assets

Base64 preserves the original binary assets in text patches; packaging decodes
them into standard .info files. No image data is changed.

- `drawer.info.b64`: WHDLoad Install Template / `Xxx Install.info`.
- `install.info.b64`: Rescue on Fractalus / whdload / `RoF Install/Install.info`.
- `game.inf.b64`: the same release's `RoF.inf`, packaged as `Vette.inf`.
- `readme.info.b64`: the same release's `ReadMe.info` (MultiView default tool).

The released reference archive is https://whdload.de/games/RescueOnFractalus.lha.
The game icon is copied to Vette.info and given WHDLoad/Slave/PreLoad tooltypes
by Installer, following the template. ReadMe.info is copied with ReadMe.

The project icon retains its classic and ColorIcon images. Packaging changes
only its length-prefixed APPNAME field to Vette!. Default tool is Installer;
LOG=FALSE, PRETEND=FALSE and MINUSER=AVERAGE are retained. Installer defaults
DEFUSER to MINUSER. There is no SCRIPT override pointing at the old game.
