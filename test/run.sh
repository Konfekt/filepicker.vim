#!/bin/sh
# Run the smoke tests in Vim and Neovim (whichever are installed).
# Usage: test/run.sh [vim|nvim]...
cd "$(dirname "$0")/.." || exit 1
PATH="$PWD/test/bin:$PATH"
export PATH
[ $# -gt 0 ] || set -- vim nvim
status=0
for editor in "$@"; do
  command -v "$editor" >/dev/null 2>&1 || { echo "skip: $editor not found"; continue; }
  out=$(mktemp)
  printf 'not run\n' > "$out"
  export FILEPICKER_TEST_OUT="$out"
  if [ "$editor" = nvim ]; then
    timeout 60 nvim --headless -u NONE -i NONE -n -S test/test.vim >/dev/null 2>&1
  else
    # Vim's terminal needs a tty, so run it under script(1).
    timeout 60 script -qec "vim -N -u NONE -i NONE -n -S test/test.vim" /dev/null >/dev/null 2>&1
  fi
  if [ -s "$out" ]; then
    echo "FAIL: $editor"
    sed 's/^/  /' "$out"
    status=1
  else
    echo "ok: $editor"
  fi
  rm -f "$out"
done
exit $status
