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

echo 'Run > chronyc sources-----------------------------------'
chronyc sources
echo '--------------------------------------------------------'

# # sudo apt-get install -y software-properties-common
# # sudo add-apt-repository -y cloud-archive:ocata
# #
# # sudo apt-get update
# # sudo apt-get install -y python-openstackclient
#
#
# # Install and configure: This section describes how to install and configure the Compute service on a compute node
# sudo apt-get install -y nova-compute
#
# CONF_NOVA=/etc/nova/nova.conf
# sudo sed -i "s|#transport_url=<None>|transport_url = rabbit://openstack:welcome@controller|g" ${CONF_NOVA}
# sudo sed -i "s|#auth_strategy=keystone|auth_strategy=keystone|g" ${CONF_NOVA}
# sudo sed -i "s|#auth_uri = <None>|auth_uri = http://controller:5000\nauth_url = http://controller:35357|g" ${CONF_NOVA}
# sudo sed -i "s|#memcached_servers = <None>|controller:11211|g" ${CONF_NOVA}
# sudo sed -i "s|#auth_type = <None>|auth_type = password\nproject_domain_name=default\nuser_domain_name = default\nproject_name = service\nusername = glance\npassword = welcome|g" ${CONF_NOVA}
# sudo sed -i "s|#project_domain_name=<None>|project_domain_name=default|g" ${CONF_NOVA}
# sudo sed -i "s|#user_domain_name=<None>|user_domain_name=default|g" ${CONF_NOVA}
# sudo sed -i "s|#project_name=<None>|project_name=service|g" ${CONF_NOVA}
# sudo sed -i "s|#username =|username = nova|g" ${CONF_NOVA}
# sudo sed -i "s|#password =|password = welcome|g" ${CONF_NOVA}
# sudo sed -i "s|^#my_ip.*|my_ip = 10.0.0.31|g" ${CONF_NOVA}
# sudo sed -i "s|#use_neutron=true|use_neutron=true|g" ${CONF_NOVA}
# sudo sed -i "s|#firewall_driver=<None>|firewall_driver=nova.virt.firewall.NoopFirewallDriver|g" ${CONF_NOVA}
# # vnc is not configured here
# # glance
# sudo sed -i "s|#api_servers=<None>|api_servers= http://controller:9292|g" ${CONF_NOVA}
# sudo sed -i "s|lock_path=/var/lock/nova|lock_path=/var/lock/nova/tmp|g" ${CONF_NOVA}
# # rm log_dir
#
# sudo sed -i "s|^os_region_name.*|os_region_name = RegionOne|g" ${CONF_NOVA}
# sudo sed -i "s|#project_domain_name=<None>|project_domain_name=Default|g" ${CONF_NOVA}
# sudo sed -i "s|#project_name=<None>|project_name=service|g" ${CONF_NOVA}
#
# sudo sed -i "s|#user_domain_name=<None>|user_domain_name=Default|g" ${CONF_NOVA}
# sudo sed -i "s|#auth_url=<None>|auth_url=http://controller:35357/v3|g" ${CONF_NOVA}
# sudo sed -i "s|#username =|username = placement|g" ${CONF_NOVA}
# sudo sed -i "s|#password =|password = welcome|g" ${CONF_NOVA}
#
# sudo sed -i "s|virt_type=.*|virt_type=qemu|g" /etc/nova/nova-compute.conf
# sudo service nova-compute restart
