#!/usr/bin/env bash
#
# Reset the demo database back to its seeded state.
#
# Run this before every rehearsal and before the demo itself. Two reasons:
#
#  1. Every run of the §9 capture writes its own timeline events, so after
#     three rehearsals the pattern banner reads "sixth missed evening dose"
#     instead of "third". The seed deliberately contains TWO missed evening
#     doses; the demo capture is the third. That only holds from a clean seed.
#
#  2. Approved artifacts stay approved, so the Review sheet stops having
#     anything to approve.
#
# 002_seed.sql already truncates before inserting, so this is safe to run
# repeatedly. It is applied directly rather than through `supabase db push`:
# the schema was applied out of band and the remote migration history is
# empty, so a push would try to re-run 001 as well.
#
# Usage:
#   tools/reseed.sh                      # the linked project
#   SUPABASE_DB_URL=... tools/reseed.sh  # an explicit connection string

set -euo pipefail

cd "$(dirname "$0")/.."

SEED="supabase/migrations/002_seed.sql"
[ -f "$SEED" ] || { echo "Can't find $SEED — run this from the repo."; exit 1; }

command -v supabase >/dev/null || {
  echo "The supabase CLI is not installed. brew install supabase/tap/supabase"
  exit 1
}

echo "Reseeding from $SEED"

if [ -n "${SUPABASE_DB_URL:-}" ]; then
  supabase db query --db-url "$SUPABASE_DB_URL" --file "$SEED"
else
  supabase db query --linked --file "$SEED"
fi

echo
echo "Done. Expect: 15 medications, 2 missed evening doses, Dr Okafor on 14 August."
echo "The demo capture is the THIRD missed dose — that is what the banner says."
