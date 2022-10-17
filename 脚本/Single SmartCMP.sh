#!/bin/bash
#参数定义：
# ${hostname} 云主机hostname
# ${IP} 自动读取的192网段的IP，作为部署json的内容
# ${URL} 部署包URL
IP=`ip addr | grep inet | awk '{ print $2; }' | sed 's/\/.*$//' | grep 192`
hostname=`hostname`

# firewalld
systemctl start firewalld
systemctl enable firewalld
# selinux
sed -i "s/enforcing/disabled/g" /etc/selinux/config
setenforce 0 
#timezone
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
#hosts
echo "
127.0.0.1 ${hostname}
${IP} ${hostname}
" > /etc/hosts

curl -LO ${URL}

tar -zxvf `find . -type f -name "smartcmp*"`

echo '{
  "enable_ha": false,
  "gateway": false,
  "enable_clear": true,
  "enable_firewall": true,
  "mysql_port": 3306,
  "ssh_port": 22,
  "default_locale": "zh_CN",
  "default_time_zone": "GMT+8",
  "elasticsearch": {
    "cluster_name": "es_cluster_001",
    "node_ip_list": [
      "IP"
    ],
    "heapsize_mb": "2048"
  },
  "single": {
    "single_node": "IP",
    "cmp_domain_name": "hostname"
  }
}
'> ./smartcmp-ansible/input.json
sed -i "s#IP#${IP}#g" ./smartcmp-ansible/input.json

sed -i "s#hostname#${hostname}#g" ./smartcmp-ansible/input.json

cd ./smartcmp-ansible 

python ./ansible_init.py |tee ./install.log
