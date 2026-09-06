#!/bin/bash
# Manage local Postgres + Redis without Docker (installed under ~/.local).
# Usage: ./scripts/services.sh {start|stop|status}
set -e

PGBIN="$HOME/.local/pgsql/bin"
PGDATA="$HOME/.local/pgsql-data"
REDISBIN="$HOME/.local/redis/bin"

start() {
  if "$PGBIN/pg_ctl" -D "$PGDATA" status >/dev/null 2>&1; then
    echo "postgres: already running"
  else
    "$PGBIN/pg_ctl" -D "$PGDATA" -l /tmp/pg.log -o "-p 5432" start
  fi
  if "$REDISBIN/redis-cli" -p 6379 ping >/dev/null 2>&1; then
    echo "redis: already running"
  else
    "$REDISBIN/redis-server" --port 6379 --daemonize yes --dir /tmp --logfile /tmp/redis.log --save ''
    echo "redis: started"
  fi
}

stop() {
  "$PGBIN/pg_ctl" -D "$PGDATA" stop >/dev/null 2>&1 && echo "postgres: stopped" || echo "postgres: not running"
  "$REDISBIN/redis-cli" -p 6379 shutdown nosave >/dev/null 2>&1 && echo "redis: stopped" || echo "redis: not running"
}

status() {
  "$PGBIN/pg_ctl" -D "$PGDATA" status >/dev/null 2>&1 && echo "postgres: running" || echo "postgres: stopped"
  "$REDISBIN/redis-cli" -p 6379 ping >/dev/null 2>&1 && echo "redis: running (PONG)" || echo "redis: stopped"
}

case "${1:-status}" in
  start) start ;;
  stop) stop ;;
  status) status ;;
  *) echo "usage: $0 {start|stop|status}"; exit 1 ;;
esac
