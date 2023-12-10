#!/usr/bin/bash

source ./duck.env
echo url="https://www.duckdns.org/update?domains=$DOMAINS&token=$TOKEN&ip=" | curl -k -o ./duck.log -K -
