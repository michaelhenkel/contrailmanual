The instruction describes the manual setup of an OpenContrail Database Node using
the official PPA. In the instructions below 10.0.0.200 is used as the IP address
of the node and 'vip' as the hostname of the virtual IP address of the LB.

<ol>
<li>software installation</li>
</ol>

```
echo "deb http://www.apache.org/dist/cassandra/debian 21x main" >> /etc/apt/sources.list
echo "deb-src http://www.apache.org/dist/cassandra/debian 21x main" >> /etc/apt/sources.list
gpg --keyserver pgp.mit.edu --recv-keys F758CE318D77295D
gpg --export --armor F758CE318D77295D | sudo apt-key add -
gpg --keyserver pgp.mit.edu --recv-keys 2B5C1B00
gpg --export --armor 2B5C1B00 | sudo apt-key add -
gpg --keyserver pgp.mit.edu --recv-keys 0353B12C
gpg --export --armor 0353B12C | sudo apt-key add -
apt-get update
apt-get -y --force-yes install wget curl software-properties-common
add-apt-repository ppa:opencontrail/ppa
add-apt-repository ppa:opencontrail/r2.20
curl -L http://debian.datastax.com/debian/repo_key | apt-key add -
apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
wget https://apt.puppetlabs.com/puppetlabs-release-trusty.deb
dpkg -i puppetlabs-release-trusty.deb
apt-get update
apt-get install -y --force-yes curl tcpdump iptables openssh-server \
        ntp rsync software-properties-common wget libssl0.9.8 \
        contrail-nodemgr contrail-utils zookeeper supervisor \
        cassandra cassandra-tools python-cassandra-driver kafka puppet
```

<ol start=2>
<li>configuration variables</li>
</ol>
```
IP='10.0.0.200' # the IP address configured on the database node
DISCIP='10.0.0.201' # IP address, hostname of the Discovery server (config node). Can also be the vip if load-balanced
HOSTNAME=cas2 # the hostname of the database node
```

<ol start=3>
<li>configuration</li>
</ol>

<li>create /etc/contrail/contrail-database-nodemgr.conf</li>
```
cat << EOF > /etc/contrail/contrail-database-nodemgr.conf
[DEFAULT]
hostip=$IP
minimum_diskGB=20

[DISCOVERY]
server=$DISCIP
port=5998
EOF
```
<li>create contrail logfile directory</li>
```
mkdir /var/log/contrail
```

<li>create /etc/contrail/supervisord_database.conf</li>
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

autostart=true                ; start at supervisord start (default: true)
stopsignal=KILL               ; signal used to kill process (default TERM)
killasgroup=false             ; SIGKILL the UNIX process group (def false)

[include]
files = /etc/contrail/supervisord_database_files/*.ini
EOF
```

<li>create /etc/contrail/supervisord_database_files directory and files</li>
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

<li>create supervisor-database upstart job</li>
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

<li>modify /etc/cassandra/cassandra.yaml</li>
```
#sed -i "s/cluster_name: 'Test Cluster'/cluster_name: 'Contrail'/g" /etc/cassandra/cassandra.yaml
sed -i "s/ulimit -l unlimited/#ulimit -l unlimited/g" /etc/init.d/cassandra
sed -i "s/\"127.0.0.1\"/\"$IP\"/g" /etc/cassandra/cassandra.yaml
sed -i "s/localhost/$IP/g" /etc/cassandra/cassandra.yaml
```

<li>change cassandra stack size</li>
```
sed -i 's/JVM_OPTS="$JVM_OPTS -Xss180k"/JVM_OPTS="$JVM_OPTS -Xss512k"/g' /etc/cassandra/cassandra-env.sh
```

<li>create zookeeper upstart</li>
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

<li>modify zookeeper server</li>
```
sed -i "s/#server.1=zookeeper1:2888:3888/server.1=$IP:2888:3888/g" /etc/zookeeper/conf/zoo.cfg
```

<li>add host entry</li>
```
echo "$IP $HOSTNAME" >> /etc/hosts
```

<li>patch contrail-status</li>
```
sed -i "/storage = package_installed('contrail-storage')/a \ \ \ \ database = True" /usr/bin/contrail-status
```

<li>start zookeeper</li>
```
start zookeeper
```

<li>restart supervisor-database</li>
```
service cassandra start
start supervisor-database
```

<li>check status</li>
```
contrail-status
== Contrail Database ==
supervisor-database:          active
contrail-database-nodemgr     initializing (Disk space for analytics db not retrievable.)
kafka                         active
```
