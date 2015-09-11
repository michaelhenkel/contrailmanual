The instruction describes the manual setup of an OpenContrail Control Node using
the official PPA. In the instructions below 10.0.0.203 is used as the IP address
of the node and 'vip' as the hostname of the virtual IP address of the LB.

<ol>
<li>software installation</li>
</ol>

```
apt-get -y --force-yes install wget curl software-properties-common
add-apt-repository ppa:opencontrail/ppa
add-apt-repository ppa:opencontrail/r2.20
apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
wget https://apt.puppetlabs.com/puppetlabs-release-trusty.deb
dpkg -i puppetlabs-release-trusty.deb
apt-get update
apt-get install -y --force-yes curl tcpdump iptables openssh-server rsync software-properties-common wget libssl0.9.8 \
					contrail-nodemgr contrail-utils puppet supervisor python-contrail contrail-lib \
                                        contrail-control contrail-dns
```

<ol start=2>
<li>configuration variables</li>
</ol>
```
IP='10.0.0.203' # the IP address configured on the database node
DISC_SERVER='10.0.0.201' # IP address, hostname of the Discovery server (config node). Can also be the vip if load-balanced
HOSTNAME=ctrl2 # the hostname of the database node
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
ANALYTICS_SERVER='10.0.0.202'
DNS_SERVER='10.0.0.1'
```

<ol start=3>
<li>configuration</li>
</ol>

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

<li>create /etc/contrail/contrail-control-nodemgr.conf</li>
```
cat << EOF > /etc/contrail/contrail-control-nodemgr.conf
[DISCOVERY]
server=$DISC_SERVER
port=5998
EOF
```

<li>create /etc/contrail/supervisord_control_files/contrail-nodemgr-control.ini</li>
```
cat << EOF > /etc/contrail/supervisord_control_files/contrail-nodemgr-control.ini
; The below sample eventlistener section shows all possible
; eventlistener subsection values, create one or more 'real'
; eventlistener: sections to be able to handle event notifications
; sent by supervisor.

[eventlistener:contrail-control-nodemgr]
command=/bin/bash -c "exec python /usr/bin/contrail-nodemgr --nodetype=contrail-control"
events=PROCESS_COMMUNICATION,PROCESS_STATE,TICK_60
buffer_size=10000                ; event buffer queue size (default 10)
stdout_logfile=/var/log/contrail/contrail-control-nodemgr-stdout.log ; stdout log path, NONE for none; default AUTO
stderr_logfile=/var/log/contrail/contrail-control-nodemgr-stderr.log ; stderr log path, NONE for none; default AUTO
EOF
```

<li>modify /etc/contrail/dns/contrail-named.conf</li>
```
sed -i "/match-recursive-only no;/a \ \ \ \ forwarders {$DNS_SERVER; };" /etc/contrail/dns/contrail-named.conf
```

<li>modify /etc/contrail/contrail-control.conf</li>
```
cat << EOF > /etc/contrail/contrail-control.conf
#
# Copyright (c) 2014 Juniper Networks, Inc. All rights reserved.
#
# Control-node configuration options
#

[DEFAULT]
# bgp_config_file=bgp_config.xml
# bgp_port=179
# collectors= # Provided by discovery server
  hostip=$IP # Resolved IP of `hostname`
#  hostip=ctrl1 # Resolved IP of `hostname`
# http_server_port=8083
# log_category=
# log_disable=0
  log_file=/var/log/contrail/contrail-control.log
# log_files_count=10
# log_file_size=10485760 # 10MB
  log_level=SYS_NOTICE
  log_local=1
# test_mode=0
# xmpp_server_port=5269

[DISCOVERY]
# port=5998
  server=$DISC_SERVER # discovery-server IP address

[IFMAP]
  certs_store=
  password=$HOSTNAME
  #server_url=https://vip:8443 # Provided by discovery server, e.g. https://127.0.0.1:8443
  user=$HOSTNAME
EOF
```

<li>modify /etc/contrail/contrail-discovery.conf</li>
```
sed -i "s/zk_server_ip=127.0.0.1/zk_server_ip=$CASSANDRA_SERVER_LIST/g" /etc/contrail/contrail-discovery.conf
sed -i "s/cassandra_server_list = 127.0.0.1:9160/cassandra_server_list = $casList/g" /etc/contrail/contrail-discovery.conf
``` 

<li>add host entry</li>
```
echo "$IP $HOSTNAME" >> /etc/hosts
```

<li>restart supervisor-control</li>
```
stop supervisor-control
start supervisor-control
```

<li>check status</li>
```
contrail-status
```
