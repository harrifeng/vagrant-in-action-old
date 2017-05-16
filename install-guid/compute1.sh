echo "
deb http://mirrors.aliyun.com/ubuntu/ xenial main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ xenial-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ xenial-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ xenial-proposed main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ xenial-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ xenial main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ xenial-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ xenial-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ xenial-proposed main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ xenial-backports main restricted universe multiverse" | sudo tee /etc/apt/sources.list
sudo apt-get update

# # page 12: [Set the hostname of the node to controller]
echo "
# controller
10.0.0.11  controller

# compute1
10.0.0.31 compute1

# block1
10.0.0.41 block1

# object1
10.0.0.51 object1

# object2
10.0.0.52 object2" | sudo tee -a /etc/hosts

# NTP implementation Chrony
echo '-----Install Chrony-----------------------'
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install chrony
echo '-----Install Chrony-----------------------'

# page 16: Edit the /tec/chrony/chrony.conf and comment out or remove all but one server key.
CONF_CHRONY=/etc/chrony/chrony.conf
sudo sed -i 's/server //g' ${CONF_CHRONY}
# Change it to reference the controller node.
echo "
server controller iburst" | sudo tee -a ${CONF_CHRONY}
sudo service chrony restart

echo ${CONF_CHRONY} '------------------------------------------------------>>'
cat ${CONF_CHRONY}
echo ${CONF_CHRONY} '------------------------------------------------------>>'

# page 17
echo 'Run > chronyc sources-----------------------------------'
chronyc sources
echo '--------------------------------------------------------'

# page 17 Distributions release Openstack packages as part of the distribution or
# using other methods because of differing release schedules.
# Perform these procedures on all nodes.
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install software-properties-common
sudo add-apt-repository -y cloud-archive:ocata
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install python-openstackclient


# # Install and configure: This section describes how to install and configure the Compute service on a compute node
# Page 41: Install the packages
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install nova-compute

CONF_NOVA=/etc/nova/nova.conf
sudo sed -i "/\[DEFAULT\]$/a transport_url = rabbit://openstack:welcome@controller" ${CONF_NOVA}
sudo sed -i "/\[api\]$/a auth_strategy=keystone" ${CONF_NOVA}
sudo sed -i "/\[keystone_authtoken\]$/a auth_uri = http://controller:5000" ${CONF_NOVA}
sudo sed -i "/\[keystone_authtoken\]$/a auth_url = http://controller:35357" ${CONF_NOVA}
sudo sed -i "/\[keystone_authtoken\]$/a memcached_servers = controller:11211" ${CONF_NOVA}
sudo sed -i "/\[keystone_authtoken\]$/a auth_type = password" ${CONF_NOVA}
sudo sed -i "/\[keystone_authtoken\]$/a project_domain_name = default" ${CONF_NOVA}
sudo sed -i "/\[keystone_authtoken\]$/a user_domain_name = default" ${CONF_NOVA}
sudo sed -i "/\[keystone_authtoken\]$/a project_name = service" ${CONF_NOVA}
sudo sed -i "/\[keystone_authtoken\]$/a username = nova" ${CONF_NOVA}
sudo sed -i "/\[keystone_authtoken\]$/a password = welcome" ${CONF_NOVA}
sudo sed -i "/\[DEFAULT\]$/a my_ip = 10.0.0.11" ${CONF_NOVA}
sudo sed -i "/\[DEFAULT\]$/a use_neutron = True" ${CONF_NOVA}
sudo sed -i "/\[DEFAULT\]$/a firewall_driver=nova.virt.firewall.NoopFirewallDriver" ${CONF_NOVA}
sudo sed -i "/\[vnc\]$/a enabled = true" ${CONF_NOVA}
sudo sed -i "/\[vnc\]$/a vncserver_listen = 0.0.0.0" ${CONF_NOVA}
sudo sed -i "/\[vnc\]$/a vncserver_proxyclient_address = 10.0.0.11" ${CONF_NOVA}
sudo sed -i "/\[vnc\]$/a novncproxy_base_url = http://controller:6080/vnc_auto.html" ${CONF_NOVA}
sudo sed -i "/\[glance\]$/a api_servers = http://controller:9292" ${CONF_NOVA}
sudo sed -i "/\[oslo_concurrency\]$/a lock_path=/var/lock/nova/tmp" ${CONF_NOVA}
sudo sed -i "/\[placement\]$/a os_region_name = RegionOne             " ${CONF_NOVA}
sudo sed -i "/\[placement\]$/a project_domain_name = Default          " ${CONF_NOVA}
sudo sed -i "/\[placement\]$/a project_name = service                 " ${CONF_NOVA}
sudo sed -i "/\[placement\]$/a auth_type = password                   " ${CONF_NOVA}
sudo sed -i "/\[placement\]$/a user_domain_name = Default             " ${CONF_NOVA}
sudo sed -i "/\[placement\]$/a auth_url = http://controller:35357/v3  " ${CONF_NOVA}
sudo sed -i "/\[placement\]$/a username = placement                   " ${CONF_NOVA}
sudo sed -i "/\[placement\]$/a password = welcome                     " ${CONF_NOVA}
sudo sed -i "/\[libvirt\]$/a virt_type = qemu                         " ${CONF_NOVA}
sudo service nova-compute restart

echo '-------------------------------------------------------------------------'
echo 'log'
echo '-------------------------------------------------------------------------'

sudo cat /var/log/nova/nova-compute.log
