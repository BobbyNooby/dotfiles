# ass: list every alias & function in ~/aliases with what it does
ass() {
  local f
  for f in "$HOME"/aliases/*.zsh(N); do
    print -P "\n%F{cyan}%B${f:t}%b%f"
    awk '
      {
        line = $0
        if (line ~ /^[[:space:]]*#/) {
          c = line
          sub(/^[[:space:]]*#[[:space:]]?/, "", c)
          sub(/^[[:space:]]+/, "", c)
          if (comment == "") comment = c; else comment = comment " " c
          next
        }
        if (line ~ /^[[:space:]]*alias[[:space:]]+[A-Za-z_][A-Za-z0-9_-]*=/) {
          d = line
          sub(/^[[:space:]]*alias[[:space:]]+/, "", d)
          eq = index(d, "=")
          name = substr(d, 1, eq - 1)
          rhs = substr(d, eq + 1)
          gsub(/^["'"'"']|["'"'"']$/, "", rhs)
          emit(name, "alias", rhs)
        } else if (line ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)/) {
          d = line
          sub(/[[:space:]]*\(\).*/, "", d)
          sub(/^[[:space:]]+/, "", d)
          emit(d, "function", "")
        }
        comment = ""
      }
      function emit(n, t, fallback,  desc) {
        desc = (comment == "") ? fallback : comment
        if (length(desc) > 72) desc = substr(desc, 1, 69) "..."
        printf "  \033[1m%-16s\033[0m %-9s %s\n", n, t, desc
      }
    ' "$f"
  done
  print -P "\n%F{8}(edit with: aliasedit)%f"
}
