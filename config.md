The instruction describes the manual setup of an OpenContrail Config Node using
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
                                        ntp supervisor puppet \
					contrail-nodemgr contrail-utils python-contrail contrail-lib \
                                        contrail-config contrail-config-openstack ifmap-server python-ifmap
```

<ol start=2>
<li>configuration variables</li>
</ol>
```
IP='10.0.0.201' # the IP address configured on the database node
DISC_SERVER=$IP # IP address, hostname of the Discovery server (config node). Can also be the vip if load-balanced
HOSTNAME=conf2 # the hostname of the database node
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
CONTROL_SERVER_LIST='10.0.0.203'
```

<ol start=3>
<li>configuration</li>
</ol>

<li>add control nodes to /etc/ifmap-server/basicauthusers.properties</li>
```
for ctrl in $CONTROL_SERVER_LIST
do
echo $ctrl:$ctrl >> /etc/ifmap-server/basicauthusers.properties
echo $ctrl.dns:$ctrl.dns >> /etc/ifmap-server/basicauthusers.properties
done
```

<li>create /etc/contrail/contrail-api.conf</li>
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
    
cat << EOF > /etc/contrail/contrail-api.conf
[DEFAULTS]
ifmap_server_ip=$IP
ifmap_server_port=8443
ifmap_username=api-server
ifmap_password=api-server
cassandra_server_list=$casList
listen_ip_addr=0.0.0.0
listen_port=8082
auth=keystone
multi_tenancy=true
log_file=/var/log/contrail/api.log
log_local=1
log_level=SYS_NOTICE
disc_server_ip=$DISC_SERVER
disc_server_port=5998
zk_server_ip=$zooList
rabbit_server=$RABBIT_SERVER
rabbit_port=5672

[SECURITY]
use_certs=false
keyfile=/etc/contrail/ssl/private_keys/apiserver_key.pem
certfile=/etc/contrail/ssl/certs/apiserver.pem
ca_certs=/etc/contrail/ssl/certs/ca.pem

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

<li>create /etc/contrail/contrail-config-nodemgr.conf</li>
```
cat << EOF > /etc/contrail/contrail-config-nodemgr.conf
[DISCOVERY]
server=$DISC_SERVER
port=5998
EOF
```

<li>modify /etc/contrail/contrail-device-manager.conf</li>
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

cat << EOF > /etc/contrail/contrail-device-manager.conf
[DEFAULTS]
rabbit_server=$RABBIT_SERVER
api_server_ip=$IP
disc_server_ip=$IP
api_server_port=8082
rabbit_port=$RABBIT_PORT
zk_server_ip=$zooList
log_file=/var/log/contrail/contrail-device-manager.log
cassandra_server_list=$casList
disc_server_port=5998
log_local=1
log_level=SYS_NOTICE
EOF
```

<li>modify /etc/contrail/contrail-discovery.conf</li>
```
sed -i "s/zk_server_ip=127.0.0.1/zk_server_ip=$CASSANDRA_SERVER_LIST/g" /etc/contrail/contrail-discovery.conf
sed -i "s/cassandra_server_list = 127.0.0.1:9160/cassandra_server_list = $casList/g" /etc/contrail/contrail-discovery.conf
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

<li>modify /etc/contrail/contrail-schema.conf</li>
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

cat << EOF > /etc/contrail/contrail-schema.conf
[DEFAULTS]
ifmap_server_ip=$IP
ifmap_server_port=8443
ifmap_username=schema-transformer
ifmap_password=schema-transformer
api_server_ip=$IP
api_server_port=8082
zk_server_ip=$zooList
log_file=/var/log/contrail/schema.log
cassandra_server_list=$casList
disc_server_ip=$IP
disc_server_port=5998
log_local=1
log_level=SYS_NOTICE

[SECURITY]
use_certs=false
keyfile=/etc/contrail/ssl/private_keys/schema_xfer_key.pem
certfile=/etc/contrail/ssl/certs/schema_xfer.pem
ca_certs=/etc/contrail/ssl/certs/ca.pem

[KEYSTONE]
auth_host=$KEYSTONE_SERVER
admin_user=$ADMIN_USER
admin_password=$ADMIN_PASSWORD
admin_tenant_name=$ADMIN_TENANT
admin_token=$ADMIN_TOKEN
EOF
```

<li>modify /etc/contrail/contrail-svc-monitor.conf</li>
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

cat << EOF > /etc/contrail/contrail-svc-monitor.conf
[DEFAULTS]
ifmap_server_ip=$IP
ifmap_server_port=8443
ifmap_username=svc-monitor
ifmap_password=svc-monitor
api_server_ip=$IP
api_server_port=8082
zk_server_ip=$zooList
log_file=/var/log/contrail/svc-monitor.log
cassandra_server_list=$casList
disc_server_ip=$IP
disc_server_port=5998
region_name=
log_local=1
log_level=SYS_NOTICE
rabbit_server=$RABBIT_SERVER
rabbit_port=$RABBIT_PORT

[SECURITY]
use_certs=false
keyfile=/etc/contrail/ssl/private_keys/svc_monitor_key.pem
certfile=/etc/contrail/ssl/certs/svc_monitor.pem
ca_certs=/etc/contrail/ssl/certs/ca.pem

[SCHEDULER]
analytics_server_ip=$ANALYTICS_SERVER
analytics_server_port=8081

[KEYSTONE]
auth_host=$KEYSTONE_SERVER
admin_user=$ADMIN_USER
admin_password=$ADMIN_PASSWORD
admin_tenant_name=$ADMIN_TENANT
admin_token=$ADMIN_TOKEN
EOF
```


<li>create /etc/contrail/supervisord_config_files/contrail-nodemgr-config.ini</li>
```
cat << EOF > /etc/contrail/supervisord_config_files/contrail-nodemgr-config.ini
[eventlistener:contrail-config-nodemgr]
command=/bin/bash -c "exec python /usr/bin/contrail-nodemgr --nodetype=contrail-config"
events=PROCESS_COMMUNICATION,PROCESS_STATE,TICK_60
buffer_size=10000                ; event buffer queue size (default 10)
stdout_logfile=/var/log/contrail/contrail-config-nodemgr-stdout.log       ; stdout log path, NONE for none; default AUTO
stderr_logfile=/var/log/contrail/contrail-config-nodemgr-stderr.log ; stderr log path, NONE for none; default AUTO
EOF
```

<li>create /etc/contrail/supervisord_support_service.conf</li>
```
cat << EOF > /etc/contrail/supervisord_support_service.conf

[unix_http_server]
file=/tmp/supervisord_support_service.sock   ; (the path to the socket file)
chmod=0700                 ; socket file mode (default 0700)

[supervisord]
logfile=/var/log/contrail/supervisord-support-service.log ; (main log file;default $CWD/supervisord.log)
logfile_maxbytes=50MB        ; (max main logfile bytes b4 rotation;default 50MB)
logfile_backups=3            ; (num of main logfile rotation backups;default 10)
loglevel=info                ; (log level;default info; others: debug,warn,trace)
pidfile=/var/run/supervisord-support-service.pid   ; (supervisord pidfile;default supervisord.pid)
nodaemon=false               ; (start in foreground if true;default false)
minfds=1024                  ; (min. avail startup file descriptors;default 1024)
minprocs=200                 ; (min. avail process descriptors;default 200)
nocleanup=true              ; (dont clean up tempfiles at start;default false)
childlogdir=/var/log/contrail ; (AUTO child log dir, default $TEMP)

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///tmp/supervisord_support_service.sock ; use a unix:// URL  for a unix socket
buffer_size=10000                ; event buffer queue size (default 10)
stdout_logfile=/var/log/contrail/contrail-support-service-nodemgr-stdout.log       ; stdout log path, NONE for none; default AUTO
stderr_logfile=/var/log/contrail/contrail-support-service-nodemgr-stderr.log ; stderr log path, NONE for none; default AUTO

[include]
files = /etc/contrail/supervisord_support_service_files/*.ini
```

<li>create /etc/contrail/supervisord_support_service_files/ directory and files</li>
```
mkdir /etc/contrail/supervisord_support_service_files
cat << EOF > /etc/contrail/supervisord_support_service_files/rabbitmq-server.ini
[program:rabbitmq-server]
command=/usr/sbin/rabbitmq-server
redirect_stderr=true
stdout_logfile=/var/log/contrail/rabbit-server-supervisor-stdout.log
stderr_logfile=/var/log/contrail/rabbit-server-supervisor-stderr.log
priority=410
autostart=true
autorestart=true
startsecs=5
startretries=15
killasgroup=true
stopasgroup=true
stopsignal=TERM
exitcodes=0
EOF
```

<li>add host entry</li>
```
echo "$IP $HOSTNAME" >> /etc/hosts
```

<li>restart supervisor-config</li>
```
stop supervisor-config
start supervisor-config
```

<li>check status</li>
```
contrail-status
== Contrail Config ==
supervisor-config:            active
contrail-api:0                initializing (Collector connection down)
contrail-config-nodemgr       active
contrail-device-manager       initializing (Collector connection down)
contrail-discovery:0          active
contrail-schema               initializing (Collector connection down)
contrail-svc-monitor          initializing (Collector connection down)

== Contrail Support Services ==
supervisor-support-service:   inactive (disabled on boot)
unix:///tmp/supervisord_support_service.sockno
```
