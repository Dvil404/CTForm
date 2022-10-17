exporter_package_name="nginx-vts-exporter-0.8.3.linux-amd64.tar.gz"
exporter_path="/tmp/nginx"
package_path = "./nginx-vts-exporter-0.8.3.linux-amd64.tar.gz"
if [ ! -d ${exporter_path} ]; then
  mkdir /tmp/nginx
fi

tar -zxvf ${package_path} -C ${exporter_path}