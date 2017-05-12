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
