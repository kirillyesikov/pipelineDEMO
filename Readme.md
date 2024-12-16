# CI/CD pipeline using Harness for your homelab/cloud with a Kubernetes cluster running on Ubuntu VMs, here’s a structured breakdown of the process and tools:

![Pipeline Screenshot](https://raw.githubusercontent.com/kirillyesikov/pipelineDEMO/main/Pipeline.PNG)

# 1. Prerequisites
### VM Setup ( multiple tools are avaliable online to provision a VM , ProxMox was used in this particular demo)
### Ensure your instance is running a VM with Ubuntu 23.10 live server.
### Allocate sufficient CPU, RAM (16GB is fine), and storage.



### Run the following commands to install Docker cleanly:
```
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```
# 2. Kubernetes Setup with kubeadm
## Here are the instructions to setup a Kubernetes cluster from "scratch":

### Container Runtime: containerd
### Install containerd and runc:
### Disable swap
```
sudo swapoff -a
cd /usr/local/
wget https://github.com/containerd/containerd/releases/download/v2.0.0/containerd-2.0.0-linux-amd64.tar.gz
tar Cxzvf /usr/local containerd-2.0.0-linux-amd64.tar.gz

cd /usr/local/lib/systemd/system/
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
systemctl daemon-reload
systemctl enable --now containerd

cd /usr/local/sbin/
wget https://github.com/opencontainers/runc/releases/download/v1.2.1/runc.amd64
install -m 755 runc.amd64 /usr/local/sbin/runc
```
## Update containerd configuration:
```
mkdir /etc/containerd
containerd config default > /etc/containerd/config.toml
```
### Configure the systemd cgroup drive inside the config.toml
### To use the systemd cgroup driver in /etc/containerd/config.toml with runc OCI runtime, set
```
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  ...
  
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true

sudo systemctl restart containerd
```
### Update the apt package index and install packages needed to use the Kubernetes apt repository
### The apt-transport-https, ca-certificates, curl, and gpg tools ensure the system can handle HTTPS-based repositories and key management
### Download the public signing key for the Kubernetes package repositories.
### Add Kubernetes repository and sign the repository
### Update required modules and install kubeadm:
```
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

### Setup the certs using kubeadm
### Initialize the Cluster
### Install Calico CNI
```
kubeadm certs certificate-key
kubeadm certs renew all
kubeadm init --apiserver-advertise-address=<VM_PRIVATE_IP>
export KUBECONFIG=/etc/kubernetes/admin.conf
curl https://raw.githubusercontent.com/projectcalico/calico/v3.29.0/manifests/calico.yaml -O
kubectl apply -f calico.yaml
```

## Clone the repo if you want to use Harness CLI
## You can also use Harness UI (https://www.harness.io/)

```
git clone https://github.com/kirillyesikov/pipelineDEMO.git
cd pipelineDEMO
```

# 3. CI/CD with Harness
## Harness CLI Installation
### Download and configure the Harness CLI:
```
curl -LO https://github.com/harness/harness-cli/releases/download/v0.0.25-Preview/harness-v0.0.25-Preview-linux-amd64.tar.gz
tar -xvf harness-v0.0.25-Preview-linux-amd64.tar.gz
export PATH="$(pwd):$PATH"
echo 'export PATH="'$(pwd)':$PATH"' >> ~/.bash_profile
```
### Create an API key and login to harness CLI (auto generated by Harness framework go to "Get Started" inside you project https://developer.harness.io/docs/platform/automation/api/api-quickstart/ )
```
harness login --api-key HARNESS-API-KEY --account-id HARNESS-ACCOUNT-ID
```
## Harness Delegate Deployment
### Deploy the delegate inside your Kubernetes cluster using Helm:
```
helm repo add harness-delegate https://app.harness.io/storage/harness-download/delegate-helm-chart/
helm repo update harness-delegate

helm upgrade -i helm-delegate --namespace harness-delegate-ng --create-namespace \
  harness-delegate/harness-delegate-ng \
  --set delegateName=helm-delegate \
  --set accountId=<HARNESS_ACCOUNT_ID> \
  --set delegateToken=<DELEGATE_TOKEN> \
  --set managerEndpoint=https://app.harness.io \
  --set delegateDockerImage=harness/delegate:24.10.84200 \
  --set replicas=1 --set upgrader.enabled=true
```
## Configure Harness Components
### Create Secrets:
```
harness secret apply --token <GITHUB_PAT> --secret-name "git_pat_secret"
```
## Connectors:
### GitHub Connector:
### Kubernetes Connector

```
harness connector --file github-connector.yml apply --git-user <GITHUB_USER>
harness connector --file kubernetes-connector.yml apply --delegate-name helm-delegate
```
## Define Services and Environments:

### Service:
### Environment
### Infrastructure Definition
```
harness service --file service.yml apply
harness environment --file environment.yml apply
harness infrastructure --file infrastructure-definition.yml apply

```
## Create the Pipeline:
```
harness pipeline --file pipeline.yml apply
```
# 4. Validate the Deployment

### Ensure the pipeline runs and deployments occur smoothly:
### Use Harness UI (https://www.harness.io/) to 

### Check Kubernetes pods:
```
kubectl get pods -A
```

![Pods Screenshot](https://raw.githubusercontent.com/kirillyesikov/pipelineDEMO/main/pods.PNG)

### Harness pipeline can be executed through the Harness UI or with Harness CLI.
# 5. Continuous Monitoring
### Set up logging and metrics within Kubernetes using tools like Prometheus or Grafana.
### Integrate Harness with monitoring tools for automated rollback capabilities.
# Summary
### This end-to-end solution creates a robust CI/CD pipeline using Harness to manage deployments into a Kubernetes cluster running on Proxmox-based VMs. By using kubeadm, Docker, and containerd with a systemd cgroup driver, you ensure Kubernetes operates efficiently, while Harness orchestrates the CI/CD lifecycle seamlessly.
