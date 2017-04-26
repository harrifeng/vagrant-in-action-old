sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install rabbitmq-server \
     python-mysqldb \
     keystone \
     glance \
     glance-api \
     glance-registry \
     glance-common \
     python-glanceclient \
     cinder-api \
     cinder-scheduler \
     neutron-server \
     nova-api \
     nova-cert \
     nova-conductor \
     nova-consoleauth \
     nova-novncproxy \
     nova-scheduler \
     python-novaclient \
     mysql-server
sudo rabbitmqctl change_password guest openstack1
echo 'rabbitmq status------------------->'
sudo rabbitmqctl status
sudo sed -i "s/^bind\-address.*/bind-address = 0.0.0.0/g" /etc/mysql/my.cnf
sudo service mysql restart
echo 'mysql status---------------------->'
sudo service mysql status
echo 'keystone status---------------------->'
id keystone
