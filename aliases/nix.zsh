# rebuild: apply config changes from your flake ($NH_FLAKE: system + home), shows a diff of what changed
alias rebuild='nh os switch'

# update: update every package to the latest, then apply
alias update='nh os switch --update'

# nixcheck: build the config without switching, to catch errors before they apply
alias nixcheck='nh os build'

# rollback: go back to the previous system version
alias rollback='sudo nixos-rebuild switch --rollback'

# nixclean: delete old versions and unused packages (keeps the last 5 and 14 days)
alias nixclean='nh clean all --keep-since 14d --keep 5'

# nixedit: open the config repo in the editor
alias nixedit='nvim "${NH_FLAKE:-$HOME/nixos-config}"'
