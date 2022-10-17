#!/bin/bash
if type ctx >/dev/null 2>&1; then
  INCTX=true
else
  INCTX=false
fi

function get_parameters() {
  key=$1
  if [ $INCTX = true ]; then
    echo $(ctx instance runtime_properties $key)
  else
    echo ${!key}
  fi
}

function write_runtime() {
  key=$1
  value=$2
  if [ $INCTX = true ]; then
    ctx instance runtime_properties $key $value
    ctx instance update
  else
    echo "set_output $key=$value"
  fi
}

function log() {
  message=$1
  if [ $INCTX = true ]; then
    ctx logger info "$message"
  else
    echo $message
  fi
}

function start_nginx_exporter(){
    log "Start nginx-exporter"
    if [ -e /usr/lib/systemd/system/nginx-exporter.service -o -e /lib/systemd/system/nginx-exporter.service ]; then
      sudo systemctl start nginx-exporter
      status=$(sudo systemctl status nginx-exporter)
    else
      sudo service nginx-exporter start
      status=$(sudo service nginx-exporter status)
    fi

    result=$(echo $status | grep 'running' )
    if [[ "$result" != "" ]];then
        log "Start nginx-exporter success"
        exit 0
    else
        log "Start nginx-exporter Failed: $status"
        exit 1
    fi
}

start_nginx_exporter