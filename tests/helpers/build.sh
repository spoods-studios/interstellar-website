# shellcheck shell=bash
SITE_ROOT=$(pwd -P)

build_site() {
  if [ -n "${SMOKE_RUN_DIR-}" ] && [ -e "$SMOKE_RUN_DIR/built" ]; then return; fi
  rm -rf dist
  npm run build
  if [ -n "${SMOKE_RUN_DIR-}" ]; then touch "$SMOKE_RUN_DIR/built"; fi
}

scratch_tree() {
  mkdir "$1"
  tar -C "$SITE_ROOT" --exclude=./node_modules --exclude=./dist --exclude=./.astro --exclude=./.git --exclude=./.claude -cf - . | tar -C "$1" -xf -
  ln -s "$SITE_ROOT/node_modules" "$1/node_modules"
}

build_in() {
  local dir=$1
  shift
  (cd "$dir" && env "$@" npm run build)
}

build_variant() {
  scratch_tree "$1"
  build_in "$@"
}

site_value() {
  node --input-type=module -e 'console.log((await import(process.argv[1]))[process.argv[2]])' "$SITE_ROOT/src/lib/site.mjs" "$1"
}
