#!/usr/bin/env zsh
# 🐘 pgbouncer — connection pooling for Postgres, and the mode that bites.
# TH_TOPIC: pgbouncer
# TH_EMOJI: 🐘
# TH_DESC:  pgBouncer — pool modes, auth, and the admin console
# TH_ALSO:  get_pgbouncer_admin_help | 🎛 | the admin console: SHOW POOLS, PAUSE, RELOAD

_th_help_pgbouncer() {
    th_head "🐘" "pgBouncer"
    th_text "A Postgres connection pooler. Postgres gives every connection its"
    th_text "own backend process, so a few hundred idle app connections cost"
    th_text "real memory; pgBouncer holds a small pool of server connections and"
    th_text "hands them out. It listens on 6432 by convention, Postgres on 5432."

    th_sub "🔀" "Pool modes — this is the decision that matters"
    th_row "session"             "one server connection per client connection"
    th_note "safest, pools least: the connection is held until the client"
    th_note "disconnects, so a client that never disconnects never gives it back"
    th_row "transaction"         "returned at COMMIT — the usual choice"
    th_note "what almost everyone means by pooling, and what breaks things below"
    th_row "statement"           "returned after every statement"
    th_note "no multi-statement transactions at all; for autocommit workloads"

    # Summary ends here. Everything below is the --detailed view.
    th_detail || return

    th_sub "⚠️" "What transaction mode breaks"
    th_text "Anything that expects a connection to remember something:"
    th_row "Prepared statements:" "the plan lives on the server connection"
    th_note "most drivers now name them and reuse them, and the second use"
    th_note "lands on a different backend — 'prepared statement \"s0\" already"
    th_note "exists' or 'does not exist'. Disable them, or pool per session."
    th_row "SET / session GUCs:" "set on one backend, invisible on the next"
    th_note "including SET ROLE and search_path — a security decision that"
    th_note "silently applies to the wrong connection is worth being sure about"
    th_row "LISTEN / NOTIFY:"    "needs a session; use session mode for it"
    th_row "Advisory locks:"     "session-scoped ones outlive the transaction"
    th_row "Temp tables:"        "gone, or worse, still there for someone else"
    print -r --
    th_warn "Migrations go DIRECT to 5432, not through the pooler"
    th_note "they hold advisory locks and set session state across statements —"
    th_note "which is exactly the list above. This is why tools want two URLs."

    th_sub "🔐" "Auth"
    th_row "Config:"             "pgbouncer.ini    ·    userlist.txt"
    th_row "The user list:"      "\"{user}\" \"SCRAM-SHA-256\$...\"    (one per line)"
    th_note "a user absent from userlist.txt cannot connect THROUGH the pooler"
    th_note "however valid their Postgres password is — the tell is that psql"
    th_note "to 5432 works and 6432 fails for the same credentials"
    th_row "Get the hash:"       "SELECT rolname, rolpassword FROM pg_authid;"
    th_note "copy the stored hash rather than writing a plaintext password"
    th_row "Or delegate:"        "auth_query = SELECT usename, passwd FROM ..."
    th_note "looks the user up in Postgres instead of a file, so adding a user"
    th_note "needs no pgBouncer redeploy"

    get_pgbouncer_admin_help
}

get_pgbouncer_admin_help() {
    th_sub "🎛" "The admin console"
    th_row "Connect:"            "psql -p 6432 -U {admin_user} pgbouncer"
    th_note "'pgbouncer' is a virtual database, not a real one; the user must"
    th_note "be listed in admin_users"
    th_row "Is anything queued:" "SHOW POOLS;"
    th_note "cl_waiting above zero means clients are waiting for a server"
    th_note "connection — the pool is too small, or something is holding one"
    th_row "Who is connected:"   "SHOW CLIENTS;    ·    SHOW SERVERS;"
    th_row "Counters:"           "SHOW STATS;"
    th_row "Effective config:"   "SHOW CONFIG;"
    th_row "Pick up an edit:"    "RELOAD;"
    th_note "no dropped connections; a restart is rarely the right tool"
    th_row "Before a failover:"  "PAUSE;   ...   RESUME;"
    th_note "PAUSE waits for in-flight transactions and then holds clients"
    th_note "connected but blocked, so a brief switchover looks like latency"
    th_note "rather than an outage"
    print -r --
    th_text "Sizing is the other half: max_client_conn is how many clients may"
    th_text "connect, default_pool_size is how many SERVER connections each"
    th_text "user/database pair may hold. The second is the one Postgres feels."
}
