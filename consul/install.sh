echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ wheezy main" | \
     sudo tee /etc/apt/sources.list.d/azure-cli.list
sudo apt-key adv --keyserver packages.microsoft.com --recv-keys 52E16F86FEE04B979B07E28DB02C46DF417A0893
sudo apt-get install apt-transport-https
wget -qO- https://github.com/hashicorp/terraform-azurerm-consul/archive/v0.0.5.tar.gz | tar xvz -C /tmp
/tmp/terraform-azurerm-consul-0.0.5/modules/install-consul/install-consul --version 1.0.1
/opt/consul/bin/run-consul --server --cluster-tag-key consul-cluster
