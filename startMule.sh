#!/bin/bash

#set -x

# SIGUSR1-handler
SIGUSR1_handler() {
  echo -e "\n++++++++++++++++++++++++++++++++++++"
  echo -e "+++++ STARTING SIGUSR1 HANDLER +++++"
  echo -e "++++++++++++++++++++++++++++++++++++\n"
}

# SIGTERM-handler
SIGTERM_handler() {
  echo -e "\n++++++++++++++++++++++++++++++++++++"
  echo -e "+++++ STARTING SIGTERM HANDLER +++++"
  echo -e "++++++++++++++++++++++++++++++++++++\n"
  source /opt/mule/bin/deregister.sh
  exit 143; # 128 + 15 -- SIGTERM
}

# setup handlers
# on callback, kill the last background process, which is `tail -f /dev/null` and execute the specified handler
trap 'kill ${!}; SIGUSR1_handler' SIGUSR1
trap 'kill ${!}; SIGTERM_handler' SIGTERM

# run application
source /opt/mule/bin/register.sh &

# wait forever
while true
do
  tail -f /dev/null & wait ${!}
done
