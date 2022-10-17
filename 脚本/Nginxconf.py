#!/usr/bin/env python
# encoding: utf-8

import json
import os
import sys
import subprocess
try:
    from cloudify import ctx

    INCTX = True
except ImportError:
    INCTX = False


def get_parameters(key):
    if INCTX:
        if key == 'instance_id':
            return ctx.instance.id
        return ctx.instance.runtime_properties.get(key)
    else:
        return os.environ.get(key)


def write_runtime(key, value):
    if INCTX:
        ctx.instance.runtime_properties[key] = value
        ctx.instance.update()
    else:
        value = json.dumps(value)
        sys.stdout.write("set_output {}={}".format(key, value))


def log(message):
    if INCTX:
        ctx.logger.info(message)
    else:
        sys.stdout.write(message)

def run(cmd):
    ret = subprocess.call(cmd, shell=True)
    if ret != 0:
        sys.exit('Exec cmd %s error, return value: %s' % (cmd, str(ret)))


def gen_script_file(env_dict):
    env = create_env_str(env_dict)
    cmd = '''
exporter_path="/tmp/nginx"
exporter_file="nginx-vts-exporter-0.8.3.linux-amd64/nginx-vts-exporter"

sudo touch /tmp/nginx-exporter-systemctl
sudo touch /tmp/nginx-exporter-service

function make_file(){
sudo cat >/tmp/nginx-exporter-systemctl<<EOF
[Unit]
Description=nginx_exporter
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
ExecStart=${exporter_path}/${exporter_file} --telemetry.address=:${exporter_port} --nginx.scrape_uri=http://${nginx_host}:${nginx_port}/${nginx_vts_url}
Type=simple
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF

sudo cat >/tmp/nginx-exporter-service<<EOF
#!/bin/bash
case "\$1" in
start)
   ${exporter_path}/${exporter_file} --telemetry.address=:${exporter_port} --nginx.scrape_uri=http://${nginx_host}:${nginx_port}/${nginx_vts_url} > /var/log/nginx_exporter.log 2>&1 &
   echo \$!>/var/run/nginx_exporter.pid
   ;;
stop)
   sudo kill \`cat /var/run/nginx_exporter.pid\`
   sudo rm -f /var/run/nginx_exporter.pid
   ;;
restart)
   \$0 stop
   \$0 start
   ;;
status)
   if [ -e /var/run/nginx_exporter.pid ]; then
      echo nginx_exporter is running, pid=\`cat /var/run/nginx_exporter.pid\`
   else
      echo nginx_exporter is NOT running
      exit 1
   fi
   ;;
*)
   echo "Usage: \$0 {start|stop|status|restart}"
esac

exit 0
EOF
}


function service_conf(){
  if [ -x /usr/bin/systemctl ]; then
    sudo mv /tmp/nginx-exporter-systemctl /usr/lib/systemd/system/nginx-exporter.service
    sudo chmod 754 /usr/lib/systemd/system/nginx-exporter.service
    sudo systemctl daemon-reload
    sudo systemctl enable nginx-exporter.service
  elif [ -x /bin/systemctl ]; then
    sudo mv /tmp/nginx-exporter-systemctl /lib/systemd/system/nginx-exporter.service
    sudo chmod 754 /lib/systemd/system/nginx-exporter.service
    sudo systemctl daemon-reload
    sudo systemctl enable nginx-exporter.service
  else
    sudo mv /tmp/nginx-exporter-service /etc/init.d/nginx-exporter
    sudo chmod 755 /etc/init.d/nginx-exporter
  fi
}

function firewall_conf(){
  if [ -x /usr/bin/firewall-cmd ]; then
    systemctl status firewalld
    if [ "$?" == 0  ]; then
      default_zone=`firewall-cmd --get-default-zone`
      if  [ ! -n $default_zone ] ;then
        sudo firewall-cmd --set-default-zone public
        default_zone='public'
      fi
      sudo firewall-cmd --zone=$default_zone --add-port=${exporter_port}/tcp --permanent
      sudo firewall-cmd --reload
    fi
  elif [ -x /sbin/iptables ]; then
    sudo /sbin/iptables -I INPUT -p tcp --dport ${exporter_port} -j ACCEPT
    sudo /sbin/iptables -I OUTPUT -p tcp --sport ${exporter_port} -j ACCEPT
    if [ -x /etc/init.d/iptables ];then
      sudo service iptables save
      sudo service iptables restart
    fi
  else
    echo "Firewalld and iptables are both not installed."
  fi
}

make_file
service_conf
firewall_conf
'''
    with open('/tmp/install_exporter.sh', 'w') as f:
        f.write("#!/bin/bash" + "\n")
        f.write(env)
        f.write(cmd)


def create_env_str(env_dict):
    env_str = ""
    for k, v in list(env_dict.items()):
        env_str = env_str + "export " + k + "=" + v + "\n"
    return env_str


def run_script():
    run("sudo bash /tmp/install_exporter.sh")


# get env params and run script
exporter_host = get_parameters("host")
exporter_port = get_parameters("port")
nginx_host = get_parameters("target_host")
nginx_port = get_parameters("target_port")
instance_id = get_parameters('instance_id')
nginx_vts_url = 'status/format/json'


# exporter and nginx in same server
env_dict = {
    "exporter_host": exporter_host,
    "exporter_port": exporter_port,
    "nginx_host": nginx_host,
    "nginx_port": nginx_port,
    "nginx_vts_url": nginx_vts_url
}

gen_script_file(env_dict)
run_script()
write_runtime(key=instance_id, value={'target_name': '-'.join(['nginx', nginx_host])})
