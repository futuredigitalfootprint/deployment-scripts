#!/usr/bin/env bash
set -e

echo "Configuring iptables-persistent to prevent dialogue boxes during install..."
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections

echo "Installing dependencies..."
if [ -x "$(command -v apt-get)" ]; then
  sudo su -s /bin/bash -c 'sleep 30 && apt-get update && apt-get install unzip && apt-get -y install iptables-persistent' root
else
  sudo yum update -y
  sudo yum install -y unzip wget
fi

echo "Fetching Consul..."
CONSUL=1.0.1
cd /tmp
wget https://releases.hashicorp.com/consul/${CONSUL}/consul_${CONSUL}_linux_amd64.zip -O consul.zip --quiet

echo "Installing Consul..."
unzip consul.zip >/dev/null
chmod +x consul
sudo mv consul /usr/local/bin/consul
sudo mkdir -p /opt/consul/data
sudo mkdir -p /etc/consul.d
sudo chmod 0644 /etc/consul.d

SERVER_COUNT=$1
CONSUL_JOIN=$2
MASTER_TOKEN=$3
ADDRESS=`ifconfig eth0 | grep "inet addr" | awk '{ print substr($2,6) }'`

echo "Creating Consul config file..."
sudo tee /etc/consul.d/config.json << EOF
{
  "acl_datacenter":"arbitrary",
  "acl_default_policy":"deny",
  "acl_down_policy":"extend-cache",
  "acl_master_token":"${MASTER_TOKEN}",
  "bind_addr":"${ADDRESS}",
  "bootstrap_expect":${SERVER_COUNT},
  "client_addr":"${ADDRESS}",
  "data_dir":"/opt/consul/data",
  "retry_join":"${CONSUL_JOIN}",
  "server":true,
  "ui":true,
}
EOF

echo "Creating Systemd daemon config..."
cat >/tmp/consul.service << EOF
[Unit]
Description=consul agent
Requires=network-online.target
After=network-online.target

[Service]
EnvironmentFile=-/etc/sysconfig/consul
Restart=on-failure
ExecStart=/usr/local/bin/consul agent -config-dir=/etc/consul.d
ExecReload=/bin/kill -HUP $MAINPID

[Install]
WantedBy=multi-user.target
EOF

echo "Opening ports..."
sudo iptables -I INPUT -s 0/0 -p tcp --dport 8300 -j ACCEPT
sudo iptables -I INPUT -s 0/0 -p tcp --dport 8301 -j ACCEPT
sudo iptables -I INPUT -s 0/0 -p tcp --dport 8302 -j ACCEPT
sudo iptables -I INPUT -s 0/0 -p tcp --dport 8400 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 8500 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -p tcp --sport 8500 -m conntrack --ctstate ESTABLISHED -j ACCEPT

sudo bash -c "iptables-save > /etc/iptables/rules.v4"

echo "Installing Systemd service..."
sudo mkdir -p /etc/sysconfig
sudo mkdir -p /etc/systemd/system/consul.d
sudo chown root:root /tmp/consul.service
sudo mv /tmp/consul.service /etc/systemd/system/consul.service
sudo chmod 0644 /etc/systemd/system/consul.service

echo "Starting Consul..."
sudo systemctl enable consul.service
sudo systemctl start consul
