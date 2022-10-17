#!/bin/bash
export exporter_host = exporter_host
export exporter_por t= exporter_port
export nginx_host = nginx_host
export nginx_port = nginx_port
export nginx_vts_url = nginx_vts_url

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