# Resume Sessions hand-off. Source this at the END of ~/.bashrc, after anything that defines a
# `claude` wrapper. When the picker has just opened a tab, open-session leaves the session id in
# $XDG_RUNTIME_DIR/phone-sessions/next; the new tab's shell claims it here and resumes the
# session, so nothing has to be typed into the terminal.

__ps_dir=${XDG_RUNTIME_DIR:-/run/user/$UID}/phone-sessions
__ps_next=$__ps_dir/next
# Tell open-session a shell with this hook exists, so it can use tabs (builtins only: no fork).
[[ -d $__ps_dir ]] || mkdir -p -m 700 "$__ps_dir"
: >"$__ps_dir/hook"
# mv is atomic: if two shells start at once, only one of them gets the hand-off.
if [[ -f $__ps_next ]] && mv -f "$__ps_next" "$__ps_next.$$" 2>/dev/null; then
  printf -v __ps_now '%(%s)T' -1
  # A hand-off older than a few seconds is stale; never resume it in an unrelated shell.
  if ((__ps_now - $(stat -c %Y "$__ps_next.$$") <= 5)); then
    __ps_id=$(<"$__ps_next.$$")
    rm -f "$__ps_next.$$"
    . "$(dirname "${BASH_SOURCE[0]}")/resume-here" "$__ps_id"
  fi
  rm -f "$__ps_next.$$"
fi
unset __ps_dir __ps_next __ps_now __ps_id
