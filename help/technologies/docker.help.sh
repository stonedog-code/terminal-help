#!/usr/bin/env zsh
# 🐳 docker — images, containers, logs, and getting the disk back.
# TH_TOPIC: docker
# TH_EMOJI: 🐳
# TH_DESC:  Docker — images, containers, logs, exec, cleaning up
# TH_ALSO:  get_docker_cleanup_help | 🧹 | reclaiming disk, and what each prune deletes

_th_help_docker() {
    th_head "🐳" "Docker"

    th_sub "▶️" "Run something"
    th_row "Run and detach:"     "docker run -d -p {host}:{container} {image}"
    th_note "-p is HOST:CONTAINER — the container's port is the right-hand one"
    th_row "Run and watch it:"   "docker run --rm -it {image}"
    th_note "--rm deletes the container on exit; without it they pile up"
    th_row "With an env file:"   "docker run --env-file .env {image}"
    th_row "Override the entry:" "docker run --rm -it --entrypoint sh {image}"
    th_note "the way in when the image starts a process that dies immediately"

    th_sub "📋" "What is running"
    th_row "Running:"            "docker ps"
    th_row "Including stopped:"  "docker ps -a"
    th_row "Just the ids:"       "docker ps -q"
    th_row "What it maps to:"    "docker port {container}"
    th_row "What it is doing:"   "docker stats --no-stream"

    th_sub "🔍" "Look inside"
    th_row "Follow the logs:"    "docker logs -f --tail 100 {container}"
    th_note "--tail first, or you replay the whole history before the live line"
    th_row "Shell in:"           "docker exec -it {container} sh"
    th_note "sh, not bash — alpine and distroless images have no bash"
    th_row "One command:"        "docker exec {container} env"
    th_row "Copy a file out:"    "docker cp {container}:/path/file ."
    th_row "How it was built:"   "docker inspect {container}"
    th_row "What changed on disk:" "docker diff {container}"

    # Summary ends here. Everything below is the --detailed view.
    th_detail || return

    th_sub "🏗" "Build"
    th_row "Build and tag:"      "docker build -t {name}:{tag} ."
    th_row "For another arch:"   "docker build --platform linux/amd64 -t {name}:{tag} ."
    th_note "an ARM laptop building for an x86 host needs this, and the failure"
    th_note "without it is a container that exits immediately on the server"
    th_row "Ignore the cache:"   "docker build --no-cache -t {name}:{tag} ."
    th_row "See the layers:"     "docker history {image}"

    th_sub "🛑" "Stop"
    th_row "Politely:"           "docker stop {container}"
    th_note "SIGTERM, then SIGKILL after 10s — docker stop -t 30 to wait longer"
    th_row "Immediately:"        "docker kill {container}"
    th_row "Everything running:" "docker stop \$(docker ps -q)"

    get_docker_cleanup_help
}

get_docker_cleanup_help() {
    th_sub "🧹" "Reclaiming disk — read this before pruning"
    th_row "What is using it:"   "docker system df"
    th_note "start here; it names which of images, containers, volumes or the"
    th_note "build cache is actually holding the space"
    print -r --
    th_row "Stopped containers:" "docker container prune"
    th_row "Dangling images:"    "docker image prune"
    th_note "only untagged layers nothing points at — the safe one"
    th_row "ALL unused images:"  "docker image prune -a"
    th_warn "-a removes every image no CONTAINER uses, not just dangling layers"
    th_note "a stopped container counts as a user; an image you pulled and have"
    th_note "not run does not, so this re-downloads more than people expect"
    th_row "Build cache:"        "docker builder prune"
    th_row "The lot:"            "docker system prune -a --volumes"
    th_warn "--volumes deletes DATA. A database volume is not rebuildable."
    print -r --
    th_row "Named volumes:"      "docker volume ls    ·    docker volume prune"
    th_note "prune only removes volumes no container references — which is"
    th_note "exactly how a database volume disappears after you tidy containers"
}
