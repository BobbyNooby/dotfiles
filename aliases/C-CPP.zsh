# cr: compile & run C/C++. Sources before `--`, program args after.
#     cr main.c | cr main.c helper.c | cr main.cpp -- arg1 arg2
# Compiles to a temp binary in /tmp, runs it, then deletes the binary.
cr() {
    local out="/tmp/crun${$}"
    local srcs=() args=() after=false
    for a in "$@"; do
        if [[ "$a" == "--" ]]; then after=true; continue; fi
        if $after; then args+=("$a"); else srcs+=("$a"); fi
    done
    local compiler="clang"
    case "${srcs[1]}" in
        *.cpp|*.cc|*.cxx) compiler="clang++" ;;
    esac
    "$compiler" "${srcs[@]}" -o "$out" -g -Wall && "$out" "${args[@]}"
    rm -f "$out"
}
alias crr=cr
