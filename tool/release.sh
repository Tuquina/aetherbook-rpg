#!/usr/bin/env bash
# Corta un release: mira los commits desde el último tag, decide el bump de
# versión (major/minor/patch) a partir de su prefijo Conventional Commits, y
# actualiza pubspec.yaml/CHANGELOG.md — commitea y taggea localmente. Nunca
# hace push ni publica nada por su cuenta (ver "próximos pasos" al final).
#
# Uso:
#   tool/release.sh            # dry run: muestra el bump calculado, no toca nada
#   tool/release.sh --apply    # bump de pubspec.yaml/CHANGELOG.md + commit + tag
#
# Formato de commit esperado (CLAUDE.md §13): "<tipo>(<scope>)<!>: <resumen>".
# tipos que suman al changelog/versión: feat (minor), fix/perf (patch),
# cualquiera + "!" o un pie "BREAKING CHANGE:" (major). El resto
# (docs/chore/test/refactor/style/build/ci) entra en el changelog como "Otros
# cambios" pero no fuerza un bump por sí solo.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

APPLY=0
if [[ "${1:-}" == "--apply" ]]; then
  APPLY=1
fi

PUBSPEC="pubspec.yaml"
CHANGELOG="CHANGELOG.md"

CURRENT_LINE=$(grep -E '^version:' "$PUBSPEC")
CURRENT_VERSION=$(echo "$CURRENT_LINE" | sed -E 's/^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)[[:space:]]*$/\1/')
CURRENT_BUILD=$(echo "$CURRENT_LINE" | sed -E 's/^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)[[:space:]]*$/\2/')

LAST_TAG=$(git tag --list 'v*' --sort=-v:refname | head -1 || true)
if [[ -n "$LAST_TAG" ]]; then
  RANGE="${LAST_TAG}..HEAD"
else
  RANGE="HEAD"
fi

mapfile -t SUBJECTS < <(git log $RANGE --pretty=format:%s 2>/dev/null || true)

if [[ ${#SUBJECTS[@]} -eq 0 ]]; then
  echo "No hay commits nuevos desde ${LAST_TAG:-el inicio del repo}. Nada que versionar."
  exit 0
fi

BUMP="none"
BREAKING=()
FEATS=()
FIXES=()
OTHER=()

for subject in "${SUBJECTS[@]}"; do
  if [[ "$subject" =~ ^([a-z]+)(\([a-zA-Z0-9_/-]+\))?(!)?:\ (.+)$ ]]; then
    type="${BASH_REMATCH[1]}"
    bang="${BASH_REMATCH[3]}"
    if [[ "$bang" == "!" ]]; then
      BUMP="major"
      BREAKING+=("$subject")
    elif [[ "$type" == "feat" ]]; then
      [[ "$BUMP" != "major" ]] && BUMP="minor"
      FEATS+=("$subject")
    elif [[ "$type" == "fix" || "$type" == "perf" ]]; then
      [[ "$BUMP" == "none" ]] && BUMP="patch"
      FIXES+=("$subject")
    else
      OTHER+=("$subject")
    fi
  else
    OTHER+=("$subject")
  fi
done

# Un pie "BREAKING CHANGE:" en cualquier commit del rango también fuerza
# major, aunque su primera línea no lleve "!".
if git log $RANGE --pretty=format:%B 2>/dev/null | grep -q '^BREAKING CHANGE:'; then
  BUMP="major"
fi

# Un release disparado a mano siempre publica algo, aunque el rango sea
# solo chore/docs/test.
[[ "$BUMP" == "none" ]] && BUMP="patch"

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
case "$BUMP" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
esac
NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
NEW_BUILD=$((CURRENT_BUILD + 1))

echo "Versión actual: ${CURRENT_VERSION}+${CURRENT_BUILD}"
echo "Commits desde ${LAST_TAG:-el inicio}: ${#SUBJECTS[@]}"
echo "Bump: ${BUMP} -> ${NEW_VERSION}+${NEW_BUILD}"
echo
if [[ ${#BREAKING[@]} -gt 0 ]]; then echo "Breaking changes:"; printf '  - %s\n' "${BREAKING[@]}"; fi
if [[ ${#FEATS[@]} -gt 0 ]]; then echo "Nuevo:"; printf '  - %s\n' "${FEATS[@]}"; fi
if [[ ${#FIXES[@]} -gt 0 ]]; then echo "Arreglos:"; printf '  - %s\n' "${FIXES[@]}"; fi
if [[ ${#OTHER[@]} -gt 0 ]]; then echo "Otros cambios:"; printf '  - %s\n' "${OTHER[@]}"; fi

if [[ "$APPLY" -eq 0 ]]; then
  echo
  echo "Dry run — no se tocó nada. Corré con --apply para aplicar el bump y taggear."
  exit 0
fi

sed -i -E "s/^version:.*/version: ${NEW_VERSION}+${NEW_BUILD}/" "$PUBSPEC"

NOTES_FILE=".release-notes-v${NEW_VERSION}.md"
{
  echo "## v${NEW_VERSION} — $(date +%Y-%m-%d)"
  echo
  if [[ ${#BREAKING[@]} -gt 0 ]]; then
    echo "### Breaking changes"
    printf -- '- %s\n' "${BREAKING[@]}"
    echo
  fi
  if [[ ${#FEATS[@]} -gt 0 ]]; then
    echo "### Nuevo"
    printf -- '- %s\n' "${FEATS[@]}"
    echo
  fi
  if [[ ${#FIXES[@]} -gt 0 ]]; then
    echo "### Arreglos"
    printf -- '- %s\n' "${FIXES[@]}"
    echo
  fi
  if [[ ${#OTHER[@]} -gt 0 ]]; then
    echo "### Otros cambios"
    printf -- '- %s\n' "${OTHER[@]}"
    echo
  fi
} > "$NOTES_FILE"

touch "$CHANGELOG"
cat "$NOTES_FILE" "$CHANGELOG" > "${CHANGELOG}.tmp"
mv "${CHANGELOG}.tmp" "$CHANGELOG"

git add "$PUBSPEC" "$CHANGELOG"
git commit -m "chore(release): v${NEW_VERSION}"
git tag -a "v${NEW_VERSION}" -m "v${NEW_VERSION}"

echo
echo "Listo en local: commit + tag v${NEW_VERSION} creados (nada publicado todavía)."
echo "Notas de esta versión: ${NOTES_FILE}"
echo
echo "Para publicarlo:"
echo "  git push && git push origin v${NEW_VERSION}"
echo "  gh release create v${NEW_VERSION} --title \"v${NEW_VERSION}\" --notes-file ${NOTES_FILE}"
