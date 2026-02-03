#!/bin/bash
# Wait for SQL Server to be ready

set -e

host="$1"
port="${2:-1433}"
shift 2
cmd="$@"

until nc -z "$host" "$port"; do
  echo "Waiting for SQL Server at $host:$port..."
  sleep 2
done

echo "SQL Server is ready at $host:$port"
exec $cmd
