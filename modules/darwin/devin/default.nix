# Devin CLI user config (~/.config/devin)
#
# AGENTS.md and mcp_config.json are declarative symlinks into /nix/store.
#
# config.json is different: Devin mutates it at runtime (approvals it has
# saved, keymap, shell state) and Orca adds hooks, so it can't be a store
# symlink. Instead the `devinConfig` activation script deep-merges the
# managed settings below into whatever is already there: managed keys win
# for scalars, permission allow/deny/ask lists are unioned (existing order
# preserved, managed items appended), and everything else is left alone.
# Consequence: deleting an entry from the Nix permission lists does NOT
# remove it from the file — remove it by hand (or deny it explicitly).
{ config, lib, pkgs, ... }:

let
  # Fusion pairs a lead model with a sidekick; the model ID is
  # fusion-<lead>-sidekick-<sidekick> (switch per session with /fusion or /model)
  fusion = { lead = "claude-opus-5-5-medium"; sidekick = "claude-sonnet-5-5-medium"; };

  settings = {
    agent = {
      model = "fusion-${fusion.lead}-sidekick-${fusion.sidekick}";
      # Explore and custom subagents (not the Fusion sidekick)
      subagent_model = "claude-sonnet-5-5-medium";
    };
    theme_mode = "dark";
    show_hints = false;
    show_path = true;
    attribution = false;
    permissions = {
      allow = [
        "Exec(git status)" "Exec(git diff)" "Exec(git log)" "Exec(git show)" "Exec(git branch --show-current)"
        "Exec(nix eval)" "Exec(nix build)" "Exec(nix flake show)" "Exec(nix flake metadata)" "Exec(nix flake check)"
        "Exec(darwin-rebuild build)"
        "Exec(ls)" "Exec(readlink)" "Exec(which)" "Exec(wc)"
      ];
      deny = [
        "Exec(sudo)" "Exec(darwin-rebuild switch)" "Exec(darwin-rebuild activate)"
        "Exec(git push --force)" "Exec(git push -f)" "Exec(git push --force-with-lease)"
      ];
    };
  };

  mergeScript = pkgs.writeShellScript "devin-config-merge" ''
    set -euo pipefail
    cfg="$1"
    jq=${pkgs.jq}/bin/jq
    managed='${builtins.toJSON settings}'

    mkdir -p "$(dirname "$cfg")"

    # An old home-manager managed file is a store symlink; replace it with a
    # regular mutable file.
    if [ -L "$cfg" ]; then
      rm -f "$cfg"
    fi

    if [ -s "$cfg" ]; then
      existing=$(cat "$cfg")
    else
      existing='{}'
    fi

    # Devin tolerates JSONC comments; if we can't parse it, don't touch it.
    if ! printf '%s' "$existing" | "$jq" -e . >/dev/null 2>&1; then
      echo "warning: ~/.config/devin/config.json is not plain JSON; leaving it unchanged" >&2
      exit 0
    fi

    new=$(printf '%s' "$existing" | "$jq" --argjson managed "$managed" '
      def union($e; $m): ($e // []) + (($m // []) - ($e // []));
      . as $existing
      | ($existing * $managed)
      | .permissions = (
          (($existing.permissions // {}) * ($managed.permissions // {}))
          | .allow = union($existing.permissions.allow; $managed.permissions.allow)
          | .deny  = union($existing.permissions.deny;  $managed.permissions.deny)
          | if ($existing.permissions.ask != null) or ($managed.permissions.ask != null)
            then .ask = union($existing.permissions.ask; $managed.permissions.ask)
            else . end
        )
    ')

    # No-op if nothing would change.
    if [ -f "$cfg" ] && printf '%s\n' "$new" | cmp -s - "$cfg"; then
      exit 0
    fi

    tmp=$(mktemp "$cfg.XXXXXX")
    printf '%s\n' "$new" > "$tmp"
    chmod 600 "$tmp"
    mv -f "$tmp" "$cfg"
    chmod 600 "$cfg"
  '';
in
{
  # Global Devin CLI rules (~/.config/devin/AGENTS.md; the CLI reads this
  # like AGENTS.md/global rules)
  home.file.".config/devin/AGENTS.md".text = ''
    # Global rules

    ## This machine
    - macOS managed by nix-darwin + home-manager from the flake at ~/homelab/nix. Homebrew packages, dotfiles and app settings are declared there: change the Nix config instead of running `brew install` or editing managed files (they are symlinks into /nix/store).
    - The user applies changes by running `rebuild` (needs sudo). Don't run `darwin-rebuild switch` or sudo yourself; validate with `nix build .#darwinConfigurations.<host>.system` or `darwin-rebuild build`. Flakes only see files git knows about, so `git add` (or `git add -N`) new files first.

    ## Git
    - Don't push or force-push unless asked.
    - Keep commits small and focused; match the repo's existing commit message style.

    ## Responses
    - Be concise. Verify claims with tools before stating them. No emojis.
  '';

  # Devin CLI user-scope MCP servers (authenticate once with `devin mcp login <name>`)
  home.file.".config/devin/mcp_config.json" = {
    force = true;
    text = builtins.toJSON {
      mcpServers = {
        atlassian = {
          url = "https://mcp.atlassian.com/v1/mcp";
          transport = "http";
        };
      };
    };
  };

  home.activation.devinConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${mergeScript} "$HOME/.config/devin/config.json"
  '';
}
