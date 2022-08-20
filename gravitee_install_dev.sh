#!/bin/bash

update_yum() {
    sudo yum update -y
}

install_java() {
    echo "==========Install Java========="
    wget https://download.oracle.com/java/17/latest/jdk-17_linux-x64_bin.rpm
    rpm -Uvh jdk-17_linux-x64_bin.rpm
    java -version
}

install_nginx() {
    echo "==========Install Nginx========="
    sudo yum install -y nginx
    printf "[Service]\nExecStartPost=/bin/sleep 0.1\n" > /etc/systemd/system/nginx.service.d/override.conf
}

install_mongo() {
    echo "==========Install MongoDB========="
    echo "[mongodb-org-6.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/8/mongodb-org/6.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-6.0.asc" | sudo tee /etc/yum.repos.d/mongodb-org-6.0.repo > /dev/null

    sudo systemctl daemon-reload
    sudo enable mongod
    sudo start mongod
}

install_elasticsearch() {
    echo "==========Install Elasticsearch========="
    echo "[elasticsearch-7.x]
name=Elasticsearch repository for 7.x packages
baseurl=https://artifacts.elastic.co/packages/7.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md" | sudo tee /etc/yum.repos.d/elasticsearch.repo > /dev/null

    sudo systemctl daemon-reload
    sudo enable elasticsearch.service
    sudo start elasticsearch.service
}

install_graviteeio() {
    echo "==========Install GraviteeIO========="
    echo "[graviteeio]
name=graviteeio
baseurl=https://packagecloud.io/graviteeio/rpms/el/7/\$basearch
gpgcheck=0
enabled=1
gpgkey=https://packagecloud.io/graviteeio/rpms/gpgkey
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300" | sudo tee /etc/yum.repos.d/graviteeio.repo > /dev/null
    sudo yum -q makecache -y --disablerepo='*' --enablerepo='graviteeio'
    sudo yum install -y graviteeio-apim-3x
    sudo systemctl daemon-reload
    sudo systemctl enable graviteeio-apim-gateway graviteeio-apim-rest-api
    sudo systemctl start graviteeio-apim-gateway graviteeio-apim-rest-api
    http_response=$(curl -w "%{http_code}" -o /tmp/curl_body "http://169.254.169.254/latest/meta-data/public-ipv4")
    if [ $http_response == "200" ]; then
        sudo sed -i -e "s/localhost/$(cat /tmp/curl_body)/g" /opt/graviteeio/apim/management-ui/constants.json
        sudo sed -i -e "s;/portal;http://$(cat /tmp/curl_body):8083/portal;g" /opt/graviteeio/apim/portal-ui/assets/config.json
    fi

    ui_port=$(sudo semanage port -l | grep 8084 | wc -l)
    if [[ "$ui_port" -eq 0 ]]
    then
        sudo semanage port -a -t http_port_t -p tcp 8084
    else
        sudo semanage port -m -t http_port_t -p tcp 8084
    fi

    portal_port=$(sudo semanage port -l | grep 8085 | wc -l)
    if [[ "$portal_port" -eq 0 ]]
    then
        sudo semanage port -a -t http_port_t -p tcp 8085
    else
        sudo semanage port -m -t http_port_t -p tcp 8085
    fi

}

install_tools() {
    os=`cat /etc/redhat-release  | awk '{ print tolower($1) }'`
    version=$(awk -F'=' '/VERSION_ID/{ gsub(/"/,""); print $2}' /etc/os-release | cut -d. -f1)
    echo "Detect version: $os/$version"

    sudo yum install -y policycoreutils-python-utils
}

install_corrections () {
    
    echo "==========Making Firewall opening and json corrections ========="
    sudo firewall-cmd --permanent --zone=public --add-service=http
    sudo firewall-cmd --zone=public --add-port=8083/tcp --permanent
    sudo firewall-cmd --zone=public --add-port=8084/tcp --permanent
    sudo firewall-cmd --zone=public --add-port=8085/tcp --permanent
    sudo firewall-cmd --reload
    
    sed -i '/baseURL/c\   \"baseURL\" : \"http:\/\/20.168.16.23:8083\/management\/organizations\/DEFAULT\/environments\/DEFAULT\",' /opt/graviteeio/apim/management-ui/constants.json
    sed -i '/baseURL/c\   \"baseURL\" : \"http:\/\/20.168.16.23:8083\/portal\/environments\/DEFAULT\",' /opt/graviteeio/apim/portal-ui/assets/config.json
    sed -i '/baseURL/c\   \"baseURL\" : \"http:\/\/20.168.16.23:8083\/portal\/environments\/DEFAULT\",' /opt/graviteeio/apim/portal-ui/assets/config.prod.json

    sudo systemctl restart nginx
}

main() {
    update_yum
    install_tools
    install_java
    install_nginx
    install_mongo
    install_elasticsearch
    install_graviteeio
    install_corrections
}
