#!/bin/bash -xe

action=$1; shift

case $action in

  shell)
    exec bash -il
  ;;

  yarn-run)
    yarn run $@
  ;;

  exec)
    exec "$@"
  ;;

  *)
    echo "Invalid action: $action"
    exit 1
  ;;
esac
