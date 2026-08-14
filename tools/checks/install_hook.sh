#!/bin/sh
# Installs a git pre-push hook that runs every check in tools/checks/*.py and
# blocks the push if any fails - the same five checks CI runs, caught before
# the commit reaches origin (where history is append-only and a red X can
# only be fixed forward).
#
# Hooks live in .git/hooks/, which is untracked, so run this ONCE PER CLONE:
#
#   sh tools/checks/install_hook.sh
#
# To push past the hook in an emergency: git push --no-verify (then fix
# forward - CI will still be red).
set -e
ROOT="$(git rev-parse --show-toplevel)"
HOOK="$ROOT/.git/hooks/pre-push"

cat > "$HOOK" <<'EOF'
#!/bin/sh
# Installed by tools/checks/install_hook.sh - do not edit here; edit the
# checks themselves under tools/checks/.
ROOT="$(git rev-parse --show-toplevel)"
fail=0
for s in "$ROOT"/tools/checks/*.py; do
    python3 "$s" || fail=1
done
if [ "$fail" -ne 0 ]; then
    echo ""
    echo "pre-push: static checks FAILED - push blocked."
    echo "Fix the reported problem, commit, and push again."
    exit 1
fi
EOF
chmod +x "$HOOK"
echo "Installed pre-push hook at $HOOK"
