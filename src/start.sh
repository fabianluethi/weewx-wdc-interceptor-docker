#!/bin/bash

# start rsyslog
echo 'Starting rsyslog'
# remove lingering pid file
rm -f /run/rsyslogd.pid
# start service
service rsyslog start

# Reconfigure for right driver
"${WEEWX_HOME}"/bin/wee_config --reconfigure --driver=user.gw1000

# start weewx
echo 'Starting weewx'
"${WEEWX_HOME}"/bin/weewxd /home/weewx/weewx.conf
