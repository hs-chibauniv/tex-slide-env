#!/usr/bin/env bash
# Deck outputs: PDF stays in slide/out/<deck>/, everything else in build/.
# A deck is a date folder, template, or others. Anything else is compiled unchanged.
set -euo pipefail

args=()
promote=""
engine_out=""
expect_dir=0
for arg in "$@"; do
  if [[ "$expect_dir" -eq 1 ]]; then
    expect_dir=0
    raw="$arg"
  elif [[ "$arg" == "-output-directory" ]]; then
    expect_dir=1
    continue
  elif [[ "$arg" == -output-directory=* ]]; then
    raw="${arg#-output-directory=}"
  else
    args+=("$arg")
    continue
  fi

  real="$(readlink -f "$raw")"
  base="$(basename "$real")"
  if [[ "$base" =~ ^[0-9]{8}$ || "$base" == "template" || "$base" == "others" ]]; then
    mkdir -p "$real/build"
    args+=("-output-directory=$real/build")
    engine_out="$real/build"
    promote="$real"
  else
    args+=("-output-directory=$raw")
  fi
done

set +e
lualatex "${args[@]}"
status=$?
set -e

if [[ -n "$promote" ]]; then
  doc=""
  for arg in "${args[@]}"; do
    [[ "$arg" == -* ]] && continue
    doc="$arg"
  done
  job="$(basename "$doc")"
  job="${job%.tex}"
  if [[ -n "$job" && -f "$engine_out/$job.pdf" ]]; then
    mv -f "$engine_out/$job.pdf" "$promote/$job.pdf"
  fi
  # LaTeX Workshop only reads <pdf-dir>/<job>.synctex.gz. The record must use
  # a path that exists where the PDF is opened. Inside Docker that path is
  # /workspace, which is the bind-mount of the host project.
  if [[ -n "$job" && -f "$engine_out/$job.synctex.gz" ]]; then
    cp -f "$engine_out/$job.synctex.gz" "$promote/$job.synctex.gz"
    host="${SYNCTEX_ROOT:-}"
    if [[ -z "$host" && -r /proc/self/mountinfo ]]; then
      host="$(awk '$5=="/workspace" { print $4; exit }' /proc/self/mountinfo)"
    fi
    if [[ -n "$host" && "$host" != "/workspace" ]]; then
      tmp="$(mktemp)"
      gzip -dc "$promote/$job.synctex.gz" \
        | sed "s|^\(Input:[0-9]*:\)/workspace/|\1${host}/|" \
        | gzip -c > "$tmp"
      mv -f "$tmp" "$promote/$job.synctex.gz"
    fi
  fi
fi

exit "$status"
