launcherDir="$WINEPREFIX/drive_c/Program Files (x86)/Jagex Launcher"

if [ ! -f "$launcherDir/JagexLauncher.exe" ]; then
  mkdir -p "$launcherDir"
  cp -r --no-preserve=mode,ownership "$LAUNCHER_FILES"/. "$launcherDir/"
fi

exec umu-run "$launcherDir/JagexLauncher.exe" "$@"
