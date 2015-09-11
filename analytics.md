The instruction describes the manual setup of an OpenContrail Analytics Node using
the official PPA. In the instructions below 10.0.0.201 is used as the IP address
of the node and 'vip' as the hostname of the virtual IP address of the LB.

<ol>
<li>software installation</li>
</ol>

```
apt-get update
apt-get -y --force-yes install wget curl software-properties-common
add-apt-repository ppa:opencontrail/ppa
add-apt-repository ppa:opencontrail/r2.20
apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
wget https://apt.puppetlabs.com/puppetlabs-release-trusty.deb
dpkg -i puppetlabs-release-trusty.deb
apt-get update
apt-get install -y --force-yes curl tcpdump iptables openssh-server rsync software-properties-common wget libssl0.9.8 \
                                        supervisor puppet \
					contrail-nodemgr contrail-utils python-contrail contrail-lib \
                                        contrail-analytics
```

<ol start=2>
<li>configuration variables</li>
</ol>
```
IP='10.0.0.202' # the IP address configured on the database node
DISC_SERVER='10.0.0.201' # IP address, hostname of the Discovery server (config node). Can also be the vip if load-balanced
HOSTNAME=analy2 # the hostname of the database node
ADMIN_USER=admin
ADMIN_PASSWORD=ladakh1
ADMIN_TENANT=admin
ADMIN_TOKEN=ladakh1
KEYSTONE_SERVER=vip
CASSANDRA_SERVER_LIST='10.0.0.200'
CASSANDRA_PORT=9160
ZOOKEEPER_PORT=2181
RABBIT_SERVER=vip
RABBIT_PORT=5672
ANALYTICS_SERVER_LIST='10.0.0.202'
ANALYTICS_PORT=8086
```

<ol start=3>
<li>configuration</li>
</ol>

<li>modify /etc/contrail/contrail-analytics-api.conf</li>
```
casList=
for ip in $CASSANDRA_SERVER_LIST
do
    casList=`echo $casList$ip:$CASSANDRA_PORT,`
done
casList=`echo ${casList::-1}`

zooList=
for ip in $CASSANDRA_SERVER_LIST
do
    zooList=`echo $zooList$ip:$ZOOKEEPER_PORT,`
done
zooList=`echo ${zooList::-1}`

anaList=
for ip in $ANALYTICS_SERVER_LIST
do
    anaList=`echo $anaList$ip:$ANALYTICS_PORT,`
done
anaList=`echo ${anaList::-1}`
    
cat << EOF > /etc/contrail/contrail-analytics-api.conf
[DEFAULTS]
host_ip = $IP
cassandra_server_list=$casList
collectors = $anaList
http_server_port = 8090
rest_api_port = 9081
rest_api_ip = 0.0.0.0
log_local = 1
log_level = SYS_NOTICE
log_category =
log_file = /var/log/contrail/contrail-analytics-api.log

# Time-to-live in hours of the data stored by collector into cassandra
analytics_data_ttl=48
analytics_config_audit_ttl=168
analytics_statistics_ttl=24
analytics_flow_ttl=2

[DISCOVERY]
disc_server_ip = $DISC_SERVER
disc_server_port = 5998

[REDIS]
redis_server_port = 6379
redis_query_port = 6379
EOF
```

<li>create /etc/contrail/contrail-analytics-nodemgr.conf</li>
```
cat << EOF > /etc/contrail/contrail-analytics-nodemgr.conf
[DISCOVERY]
server=$DISC_SERVER
port=5998
EOF
```

<li>modify /etc/contrail/contrail-collector.conf</li>
```
casList=
for ip in $CASSANDRA_SERVER_LIST
do
    casList=`echo $casList$ip:$CASSANDRA_PORT,`
done
casList=`echo ${casList::-1}`

zooList=
for ip in $CASSANDRA_SERVER_LIST
do
    zooList=`echo $zooList$ip:$ZOOKEEPER_PORT,`
done
zooList=`echo ${zooList::-1}`

anaList=
for ip in $ANALYTICS_SERVER_LIST
do
    anaList=`echo $anaList$ip:$ANALYTICS_PORT,`
done
anaList=`echo ${anaList::-1}`

cat << EOF > /etc/contrail/contrail-collector.conf
#
# Copyright (c) 2014 Juniper Networks, Inc. All rights reserved.
#
# Control-node configuration options
#

[DEFAULT]
# Everything in this section is optional

# Time-to-live in hours of the data stored by collector into cassandra
analytics_data_ttl=48
analytics_config_audit_ttl=168
analytics_statistics_ttl=24
analytics_flow_ttl=2

# IP address and port to be used to connect to cassandra.
# Multiple IP:port strings separated by space can be provided
cassandra_server_list=$casList

# IP address of analytics node. Resolved IP of 'hostname'
hostip=$IP

# Hostname of analytics node. If this is not configured value from ostname# will be taken
# hostname=

# Http server port for inspecting collector state (useful for debugging)
http_server_port=8089

# Category for logging. Default value is '*'
# log_category=

# Local log file name
log_file=/var/log/contrail/collector.log

# Maximum log file rollover index
# log_files_count=10

# Maximum log file size
# log_file_size=1048576 # 1MB

# Log severity levels. Possible values are SYS_EMERG, SYS_ALERT, SYS_CRIT,
# SYS_ERR, SYS_WARN, SYS_NOTICE, SYS_INFO and SYS_DEBUG. Default is SYS_DEBUG
log_level=SYS_NOTICE

# Enable/Disable local file logging. Possible values are 0 (disable) and
# 1 (enable)
log_local=1

# TCP and UDP ports to listen on for receiving syslog messages. -1 to disable.
syslog_port=-1

# UDP port to listen on for receiving sFlow messages. -1 to disable.
# sflow_port=6343

[COLLECTOR]
# Everything in this section is optional

# Port to listen on for receiving Sandesh messages
port=8086

# IP address to bind to for listening
# server=0.0.0.0

# UDP port to listen on for receiving Google Protocol Buffer messages
# protobuf_port=3333

[DISCOVERY]
# Port to connect to for communicating with discovery server
# port=5998

# IP address of discovery server
server=$DISC_SERVER

[REDIS]
# Port to connect to for communicating with redis-server
port=6379


# IP address of redis-server
server=127.0.0.1
EOF
```

<li>modify /etc/contrail/vnc_api_lib.ini</li>
```
cat << EOF > /etc/contrail/vnc_api_lib.ini
[global]
;WEB_SERVER = 127.0.0.1
;WEB_PORT = 9696  ; connection through quantum plugin

WEB_SERVER = 127.0.0.1
WEB_PORT = 8082 ; connection to api-server directly
BASE_URL = /
;BASE_URL = /tenants/infra ; common-prefix for all URLs

; Authentication settings (optional)
[auth]
AUTHN_TYPE = keystone
AUTHN_PROTOCOL = http
AUTHN_SERVER=$KEYSTONE_SERVER
AUTHN_PORT = 35357
AUTHN_URL = /v2.0/tokens
EOF
```

<li>create /etc/contrail/contrail-keystone-auth.conf</li>
```
cat << EOF > /etc/contrail/contrail-keystone-auth.conf
[KEYSTONE]
auth_host=$KEYSTONE_SERVER
auth_protocol=http
auth_port=35357
admin_user=$ADMIN_USER
admin_password=$ADMIN_PASSWORD
admin_token=$ADMIN_TOKEN
admin_tenant_name=$ADMIN_TENANT
insecure=false
memcache_servers=127.0.0.1:11211
EOF
```

<li>modify /etc/contrail/contrail-query-engine.conf</li>
```
casList=
for ip in $CASSANDRA_SERVER_LIST
do
    casList=`echo $casList$ip:$CASSANDRA_PORT,`
done
casList=`echo ${casList::-1}`

zooList=
for ip in $CASSANDRA_SERVER_LIST
do
    zooList=`echo $zooList$ip:$ZOOKEEPER_PORT,`
done
zooList=`echo ${zooList::-1}`

cat << EOF > /etc/contrail/contrail-query-engine.conf
#
# Copyright (c) 2014 Juniper Networks, Inc. All rights reserved.
#
# Query-Engine configuration options
#

[DEFAULT]
# analytics_data_ttl=48
  cassandra_server_list=$casList
  collectors=127.0.0.1:8086
  hostip=$IP # Resolved IP of `hostname`
# log_category=
# log_disable=0
  log_file=/var/log/contrail/contrail-query-engine.log
# log_files_count=10
# log_file_size=1048576 # 1MB
  log_level=SYS_NOTICE
  log_local=1
# test_mode=0

[DISCOVERY]
#  port=5998
#  server=

[REDIS]
  port=6379
  server=127.0.0.1
EOF
```

<li>modify /etc/contrail/contrail-snmp-collector.conf</li>
```
casList=
for ip in $CASSANDRA_SERVER_LIST
do
    casList=`echo $casList$ip:$CASSANDRA_PORT,`
done
casList=`echo ${casList::-1}`

zooList=
for ip in $CASSANDRA_SERVER_LIST
do
    zooList=`echo $zooList$ip:$ZOOKEEPER_PORT,`
done
zooList=`echo ${zooList::-1}`

cat << EOF > /etc/contrail/contrail-snmp-collector.conf
[DEFAULTS]
log_local = 1
log_level = SYS_NOTICE
#log_category =
log_file = /var/log/contrail/contrail-snmp-collector.log
scan_frequency = 600
fast_scan_frequency = 60
http_server_port = 5920
zookeeper=$zooList

[DISCOVERY]
disc_server_ip=$DISC_SERVER
disc_server_port=5998
EOF
```

<li>modify /etc/contrail/contrail-topology.conf</li>
```
casList=
for ip in $CASSANDRA_SERVER_LIST
do
    casList=`echo $casList$ip:$CASSANDRA_PORT,`
done
casList=`echo ${casList::-1}`

zooList=
for ip in $CASSANDRA_SERVER_LIST
do
    zooList=`echo $zooList$ip:$ZOOKEEPER_PORT,`
done
zooList=`echo ${zooList::-1}`

cat << EOF > /etc/contrail/contrail-topology.conf
[DEFAULTS]
log_local = 1
log_level = SYS_NOTICE
#log_category = ''
log_file = /var/log/contrail/contrail-topology.log
#use_syslog =
#syslog_facility =
scan_frequency = 60
#http_server_port = 5921
zookeeper=$zooList
EOF
```


<li>create /etc/contrail/supervisord_analytics_files/contrail-nodemgr-analytics.ini</li>
```
cat << EOF > /etc/contrail/supervisord_analytics_files/contrail-nodemgr-analytics.ini
[eventlistener:contrail-analytics-nodemgr]
command=/bin/bash -c "exec /usr/bin/contrail-nodemgr"
events=PROCESS_COMMUNICATION,PROCESS_STATE,TICK_60
buffer_size=10000                ; event buffer queue size (default 10)
stdout_logfile=/var/log/contrail/contrail-analytics-nodemgr-stdout.log        ; stdout log path, NONE for none; default AUTO
stderr_logfile=/var/log/contrail/contrail-analytics-nodemgr-stderr.log ; stderr log path, NONE for none; default AUTO
EOF
```

<li>add host entry</li>
```
echo "$IP $HOSTNAME" >> /etc/hosts
```

<li>start redis-server</li>
```
service redis-server start
```

<li>restart supervisor-analytics</li>
```
stop supervisor-analytics
start supervisor-analytics
```

<li>check status</li>
```
contrail-status
== Contrail Analytics ==
supervisor-analytics:         active
contrail-alarm-gen            active
contrail-analytics-api        active
contrail-analytics-nodemgr    active
contrail-collector            active
contrail-query-engine         active
contrail-snmp-collector       active
contrail-topology             active
```
