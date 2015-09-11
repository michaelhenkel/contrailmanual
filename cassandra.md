1. software:

```
apt-get -y --force-yes install wget curl software-properties-common
add-apt-repository ppa:opencontrail/ppa
add-apt-repository ppa:opencontrail/r2.20
echo "deb http://debian.datastax.com/community stable main" | sudo tee -a /etc/apt/sources.list.d/cassandra.sources.list
curl -L http://debian.datastax.com/debian/repo_key | apt-key add -
apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
wget https://apt.puppetlabs.com/puppetlabs-release-trusty.deb
dpkg -i puppetlabs-release-trusty.deb
apt-get update
apt-get install -y --force-yes curl tcpdump iptables openssh-server rsync software-properties-common wget libssl0.9.8 \
        contrail-nodemgr contrail-utils zookeeper supervisor cassandra kafka puppet
```

2. configuration
a. /etc/contrail/contrail-database-nodemgr.conf
```
cat << EOF > /etc/contrail/contrail-database-nodemgr.conf
[DEFAULT]
hostip=10.0.0.200
minimum_diskGB=20

[DISCOVERY]
server=vip
port=5998
EOF
```
b. contrail logfile
```
mkdir /var/log/contrail
```

c. create supervisord_database.conf
```
cat << EOF > /etc/contrail/supervisord_database.conf
; contrail database (cassandra) supervisor config file.
;
; For more example, check supervisord_analytics.conf

[unix_http_server]
file=/tmp/supervisord_database.sock   ; (the path to the socket file)
chmod=0700                 ; socket file mode (default 0700)

[supervisord]
logfile=/var/log/contrail/supervisord_contrail_database.log  ; (main log file;default $CWD/supervisord.log)
logfile_maxbytes=10MB        ; (max main logfile bytes b4 rotation;default 50MB)
logfile_backups=5           ; (num of main logfile rotation backups;default 10)
loglevel=info                ; (log level;default info; others: debug,warn,trace)
pidfile=/var/run/supervisord_contrail_database.pid  ; (supervisord pidfile;default supervisord.pid)
nodaemon=false               ; (start in foreground if true;default false)
minfds=1024                  ; (min. avail startup file descriptors;default 1024)
minprocs=200                 ; (min. avail process descriptors;default 200)
nocleanup=true              ; (dont clean up tempfiles at start;default false)

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///tmp/supervisord_database.sock ; use a unix:// URL  for a unix socket

[program:contrail-database]
command=cassandra -f

autostart=true                ; start at supervisord start (default: true)
stopsignal=KILL               ; signal used to kill process (default TERM)
killasgroup=false             ; SIGKILL the UNIX process group (def false)

[include]
files = /etc/contrail/supervisord_database_files/*.ini
EOF
```

d. create supervisord_database_files/ and files
```
mkdir /etc/contrail/supervisord_database_files

cat << EOF > /etc/contrail/supervisord_database_files/contrail-database.rules
{ "Rules": [
     ]
}
EOF

cat << EOF > /etc/contrail/supervisord_database_files/contrail-nodemgr-database.ini
[eventlistener:contrail-database-nodemgr]
command=/bin/bash -c "exec python /usr/bin/contrail-nodemgr --nodetype=contrail-database"
environment_file= /etc/contrail/database_nodemgr_param
events=PROCESS_COMMUNICATION,PROCESS_STATE,TICK_60
events=PROCESS_COMMUNICATION,PROCESS_STATE,TICK_60
buffer_size=10000                ; event buffer queue size (default 10)
stdout_logfile=/var/log/contrail/contrail-database-nodemgr-stdout.log ; stdout log path, NONE for none; default AUTO
stderr_logfile=/var/log/contrail/contrail-database-nodemgr-stderr.log ; stderr log path, NONE for none; default AUTO
EOF

cat << EOF > /etc/contrail/supervisord_database_files/kafka.ini
[program:kafka]
command=/usr/share/kafka/bin/kafka-server-start.sh /usr/share/kafka/config/server.properties
autostart=true                ; start at supervisord start (default: true)
killasgroup=false             ; SIGKILL the UNIX process group (def false)
EOF
``` 

e. create upstart job
```
cat << EOF > /etc/init/supervisor-database.conf
description     "Supervisord for VNC Database"

start on runlevel [2345]
stop on runlevel [016]
limit core unlimited unlimited

# Restart the process if it dies with a signal
# or exit code not given by the 'normal exit' stanza.
respawn

# Give up if restart occurs 10 times in 90 seconds.
respawn limit 10 90

pre-start script
    ulimit -s unlimited
    ulimit -c unlimited
    ulimit -d unlimited
    ulimit -v unlimited
    ulimit -n 4096
end script

script
    supervisord --nodaemon -c /etc/contrail/supervisord_database.conf || true
    echo "supervisor-database start failed...."
    (lsof | grep -i supervisord_database.sock) || true
    pid=\`lsof | grep -i supervisord_database.sock | cut -d' ' -f3\` || true
    if [ "x\$pid" != "x" ]; then
        ps uw -p \$pid
    fi
end script

pre-stop script
    supervisorctl -s unix:///tmp/supervisord_database.sock stop all
    supervisorctl -s unix:///tmp/supervisord_database.sock shutdown
end script
EOF
```

f. change cassandra.yaml:
```
sed -i "s/cluster_name: 'Test Cluster'/cluster_name: 'Contrail'/g" /etc/cassandra/cassandra.yaml
sed -i 's/"127.0.0.1"/"10.0.0.200"/g' /etc/cassandra/cassandra.yaml
sed -i 's/localhost/10.0.0.200/g' /etc/cassandra/cassandra.yaml
sed -i 's/start_rpc: false/start_rpc: true/g' /etc/cassandra/cassandra.yaml
```

g. create zookeeper upstart
```
cat << EOF > /etc/init/zookeeper.conf
description "zookeeper centralized coordination service"

start on runlevel [2345]
stop on runlevel [!2345]

respawn

limit nofile 8192 8192

pre-start script
    [ -r "/usr/share/java/zookeeper.jar" ] || exit 0
    [ -r "/etc/zookeeper/conf/environment" ] || exit 0
    . /etc/zookeeper/conf/environment
    [ -d \$ZOO_LOG_DIR ] || mkdir -p \$ZOO_LOG_DIR
    chown \$USER:$GROUP \$ZOO_LOG_DIR
end script

script
    . /etc/zookeeper/conf/environment
    [ -r /etc/default/zookeeper ] && . /etc/default/zookeeper
    if [ -z "\$JMXDISABLE" ]; then
        JAVA_OPTS="\$JAVA_OPTS -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.local.only=\$JMXLOCALONLY"
    fi
    exec start-stop-daemon --start -c \$USER --exec \$JAVA --name zookeeper \\
    	-- -cp \$CLASSPATH \$JAVA_OPTS -Dzookeeper.log.dir=\${ZOO_LOG_DIR} \\
      	-Dzookeeper.root.logger=\${ZOO_LOG4J_PROP} \$ZOOMAIN \$ZOOCFG
end script
EOF
```

d. change zookeeper server:
```
sed -i 's/#server.1=zookeeper1:2888:3888/server.1=10.0.0.200:2888:3888/g' /etc/zookeeper/conf/zoo.cfg
```

e. change stack size:
```
sed -i 's/JVM_OPTS="$JVM_OPTS -Xss180k"/JVM_OPTS="$JVM_OPTS -Xss512k"/g' /etc/cassandra/cassandra-env.sh
```

f. add host entry:
```
echo "10.0.0.200	cas2" >> /etc/hosts
```

g. patch contrail-status
```
sed -i "/storage = package_installed('contrail-storage')/a \ \ \ \ database = True" /usr/bin/contrail-status
```

h. start zookeeper
```
start zookeeper
```

i. restart supervisor-database
```
start supervisor-database
```

