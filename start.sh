set -o allexport
source .env
set +o allexport
rails server
# you should specify new --pid if you wan to run several instances of this app and port via -p
# rails server -p 3300 --pid tmp/pids/server2.pid
