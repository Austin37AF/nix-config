# Bump every addon in curseforge.json to its newest stable WoW Forever file.
# To add an addon, add `"<name>": { "projectId": <id> }` (Project ID is on its CurseForge page),
# run this, then commit and rebuild.
pins="${1:-$HOME/homelab/nix/hosts/gaming-pc/wow-forever/curseforge.json}"
gameVersion="${WOW_GAME_VERSION:-1.60.}" # CurseForge's game version for WoW Forever
api=https://www.curseforge.com/api/v1/mods

new=$(cat "$pins")
for name in $(jq -r 'keys[]' "$pins"); do
  id=$(jq -r --arg n "$name" '.[$n].projectId' "$pins")
  current=$(jq -r --arg n "$name" '.[$n].fileId // empty' "$pins")
  file=$(curl -fsS "$api/$id/files?pageSize=50" | jq -c --arg v "$gameVersion" \
    'first(.data[] | select(.releaseType == 1 and any(.gameVersions[]; startswith($v))))')
  if [ -z "$file" ]; then
    echo "$name: no stable release for game version $gameVersion*" >&2
    continue
  fi
  fileId=$(jq -r .id <<<"$file")
  fileName=$(jq -r .fileName <<<"$file")
  if [ "$fileId" = "$current" ]; then
    echo "$name: up to date ($fileName)"
    continue
  fi
  hash=$(nix --extra-experimental-features nix-command store prefetch-file --json \
    --name "$name-$fileId.zip" "$api/$id/files/$fileId/download" | jq -r .hash)
  new=$(jq --arg n "$name" --argjson f "$fileId" --arg fn "$fileName" --arg h "$hash" \
    '.[$n] += { fileId: $f, fileName: $fn, hash: $h }' <<<"$new")
  echo "$name: ${current:-none} -> $fileId ($fileName)"
done
printf '%s\n' "$new" > "$pins"
