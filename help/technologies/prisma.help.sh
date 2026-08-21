#!/usr/bin/env zsh
# 🔺 prisma — migrations, drift, and the schema path that trips everyone up.
# TH_TOPIC: prisma
# TH_EMOJI: 🔺
# TH_DESC:  Prisma — migrations, drift, generate, studio
# TH_RELATED: pgbouncer
# TH_ALSO:  get_prisma_migrate_help | 🚚 | migrations: dev, deploy, and unsticking one

_th_help_prisma() {
    th_head "🔺" "Prisma"

    th_sub "🧭" "Everyday"
    th_row "Regenerate the client:" "npx prisma generate"
    th_note "after EVERY schema change, or the types are the previous schema's"
    th_note "and the error lands somewhere unrelated"
    th_row "Browse the data:"    "npx prisma studio"
    th_row "Is the schema valid:" "npx prisma validate"
    th_row "Tidy the schema:"    "npx prisma format"
    th_row "Database -> schema:" "npx prisma db pull"
    th_note "introspects an existing database and rewrites schema.prisma"

    th_sub "📁" "Where the schema is"
    th_row "Say it outright:"    "npx prisma {cmd} --schema={path}/schema.prisma"
    th_note "in a monorepo the command is run from the root and the schema is"
    th_note "not, so every command needs this or it reports 'schema not found'"
    th_row "Or set it once:"     "\"prisma\": { \"schema\": \"...\" }   in package.json"
    th_warn "npx with no local install downloads the LATEST prisma"
    th_note "which then rejects a schema written for the pinned major, with"
    th_note "confident errors naming real lines. npm ci first, in a fresh tree."

    # Summary ends here. Everything below is the --detailed view.
    th_detail || return

    get_prisma_migrate_help

    th_sub "🔌" "Connections"
    th_row "Two URLs, on purpose:" "DATABASE_URL      — the app, may be pooled"
    th_row ""                    "DIRECT_URL        — migrations, never pooled"
    th_note "migrations need session state a transaction pooler will not give"
    th_note "them; see get_pgbouncer_help for why that is not Prisma's fault"
}

get_prisma_migrate_help() {
    th_sub "🚚" "Migrations"
    th_row "Create and apply:"   "npx prisma migrate dev --name {message}"
    th_note "development only — it can drop and recreate the database when it"
    th_note "decides history has diverged, so never point it at anything real"
    th_row "Write it, don't run it:" "npx prisma migrate dev --create-only"
    th_note "for custom SQL: it writes the file and stops, so you can edit"
    th_row "Apply to production:" "npx prisma migrate deploy"
    th_note "the only one for a real environment — non-interactive, additive,"
    th_note "and it never resets anything"
    th_row "Am I in sync:"       "npx prisma migrate status"
    th_row "After a failed one:" "npx prisma migrate resolve --rolled-back {name}"
    th_row ""                    "npx prisma migrate resolve --applied {name}"
    th_note "--rolled-back if you undid it, --applied if you finished it by"
    th_note "hand; a failed migration blocks every later deploy until told"
    th_row "Start over (dev):"   "npx prisma migrate reset"
    th_warn "that DROPS the database and replays every migration"
    print -r --
    th_text "A migration is a file, and the file is the record. Editing one"
    th_text "that has already been applied somewhere does not change that"
    th_text "database — it only makes the checksum disagree, which is what"
    th_text "'migration was modified after it was applied' means."
}
