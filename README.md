# DevOps Infrastructure Automation
Containerize a [multi-component Web Application](https://github.com/Pokfinner/ironhack-project-1) using Docker, provision infrastructure on AWS with Terraform and configuration management using Ansible.

## Objectives:
1. Provision AWS infrastructure using **Terraform**  
2. Secure the environment with **VPCs, subnets, security groups, and remote state storage**  
3. Automate  Docker setup and instance configuration using **Ansible**  
4. Ensure secure access to private instances using a **Bastion Host**  

This provides a **scalable, secure, and automated deployment workflow** for the multi-stack application.

## Step 0 - Overview of Multistack Voting Application
This [application](https://github.com/Pokfinner/ironhack-project-1) consists of multiple services built with different languages and technologies, simulating real-world scenarios where various components interact within a microservices architecture. The application includes:  
- **Vote (Python/Flask):** A web app for casting votes.  
- **Redis:** An in-memory queue for temporary vote storage.  
- **Worker (.NET 7.0):** Processes votes from Redis and stores them in a database. Worker reads from Redis and writes to Postgres 
- **Postgres:** A database for persistent vote storage.  
- **Result (Node.js/Express):** Displays real-time voting results.<br><br>  

<div style="text-align: center;">
  <img src="https://drive.google.com/thumbnail?id=1S6COvf1ANiTbtZ2e5RD0LveZBGKDoKJj" alt="Application Architecture" width="500">
</div>
<!-- ![Application Architecture](https://drive.google.com/thumbnail?id=1S6COvf1ANiTbtZ2e5RD0LveZBGKDoKJj) -->

<br><br> It is recommended to run the services directly on your local machine to get comfortable with the components before containerization.
***Prerequisites***: You must have Python, Node.js, and .NET SDK installed locally (<u>See the corresponding README.md</u>). <br><br> 
Once all services are running locally and correctly configured (you might need to adjust connection strings in the code), you can open the vote app in your browser, cast some votes, and see them reflected in the result app. The worker should process the votes from Redis to Postgres in the background.

## Step 1 - Containerize the Microservices
### 1.1 Containerize the services (`vote`, `result`, `worker`) using Docker.
#### Vote (Python)
```sh
cd vote
docker build -t vote:latest .
docker run -p 8080:80 vote:latest
```
Visit http://localhost:8080 to see the vote app running in Docker.


#### Result (Node.js)
```sh
cd result
docker build -t result:latest .
docker run -p 8081:80 result:latest
```
Access http://localhost:8081 for the result app.

#### Worker (.NET)
```sh
cd worker
docker build -t worker:latest .
docker run worker:latest
```
The worker runs in the background, no direct HTTP port is exposed, but it needs Redis and Postgres reachable.

### 1.2 Orchestrate multi-service deployments with Docker Compose (for single-machine deployments).
To manage and run all services (`vote`, `result`, `worker`, `redis`, and `db`) together, create a `docker-compose.yml` file in root directory of the Microservices project. It sets up **networks and volumes**, ensuring seamless communication between containers. 
```sh
docker compose up -d --build
```
This will:
- Start **Redis** and **Postgres**
- Build and run **Vote** and **Result** apps
- Start the **Worker** service
- Create isolated networks: `front-tier` and `back-tier`

Access the Applications:
- **Vote App:** [http://localhost:8080](http://localhost:8080)
- **Result App:** [http://localhost:8081](http://localhost:8081)

Cast votes and see them update in real time! The **worker** service moves votes from **Redis** to **Postgres** for persistence.


### 1.3 Push the docker images to Dockerhub (for use in step 3).
```sh
docker push your_dockerhub_username/vote:latest
docker push your_dockerhub_username/result:latest
docker push your_dockerhub_username/worker:latest
```

## Step 2 - Setting up Infrastructure using Terraform
- Create a VPC with at least two subnets (public and private) and configure route tables with Internet and NAT Gateways.
- Create appropriate Security Groups for each EC2 instance, allowing necessary inbound and outbound traffic.
- Create Security Groups for Bastion host and Application Load Balancer.
- Create 5 EC2 instances (one for each service, one for each Vote, Result, Worker, Redis, and Postgres), placed in private subnet of the VPC.
- Configure an Application Load Balancer (with two public subnets in different availability zones) that routes traffic to the vote and result services based on URL paths.
- Store `terraform.tfstate` file in a remote backend (Amazon S3 bucket) and enable state locking with DynamoDB.</br>
To provision the AWS infrastructure, run the following:

```
cd terraform
terraform init
terraform apply -auto-approve
```

### Security Groups:

- **ALB SG:** Allows incoming HTTP/HTTPS from the internet. Outbound traffic is restricted to specific private IPs of votes and results instances.
- **Vote Sg:** Allows inbound traffic from the ALB (on HTTP port 80) for accessing the Python/Flask App and allow SSH connection from Bastion host for securely configuring deployments.
 Outbound should allow connections to Redis on port 6379.
- **Redis SG:** Allows inbound traffic from Vote EC2 instance to Redis port (6379), and allows inbound SSH (port 22) access from the Bastion security group. Permits all outbound traffic with the VPC.
- **Worker SG:** Allows inbound traffic from Bastion on port 22 (SSH connection). Worker makes connection to Redis and Postgres, therefore it has outbound to Redis & Postgres.
- **Postgres SG:** Allows inbound PostgreSQL (port 5432) traffic from both Worker and Result security groups. Allows SSH connection from Bastion EC2 instance. Permits all outbound traffic with the VPC.
- **Result SG:** Allows inbound traffic from the ALB (on HTTP port 8080) for accessing the Node.js App and SSH connection from Bastion host. Allows outbound PostgreSQL (port 5432) traffic to the PostgreSQL security group. Allows all outbound traffic to any destination.

## Step 3 - Configuration Management with Ansible
- Using **Ansible playbooks** to connect to Bastion host (via SSH) and install Docker on newly provisioned EC2 instances.
- Ensure Docker is running on each instance, and your user is added to the `docker` group to run containers without `sudo`.
- Deploy Containers by pulling your images from DockerHub on the EC2 instances and run the containers using `docker run`.
- Ensure **environment variables** are correctly set (e.g., database credentials, Redis hostnames/ private instances I.P addresses).
- Use **Ansible Vault**, or a secure location for managing secrets (passwords, tokens, private keys, etc.).</br>
To configure the EC2 instances, run the following:

```
cd ansible
ansible-playbook -i inventory.ini playbook.yml
```

### Managing SSH Keys for Ansible
To securely manage SSH connections to the EC2 instances:
- Create or import an **SSH key pair** in AWS.
- Reference that key pair in Terraform `aws_instance` resource.
- Use **Ansible’s inventory** to define private key used to connect to each EC2 instance.

### Connecting to Private Subnet Instances with Ansible
Since the EC2 instances live in **private subnets** (and do not have public IP addresses), we cannot SSH into them directly from the internet. Instead, use a **Bastion (Jump) Host**.

#### Using a Bastion (Jump) Host

1. **Create a Bastion Host in a Public Subnet:**
   - This is a small EC2 instance (e.g., Amazon Linux or Ubuntu) with a **public IP or Elastic IP**.
   - Configure its **security group** to allow inbound SSH from specific IP address (e.g., your PC).

2. **SSH Into the Bastion Host:**
   - From your PC, SSH into the bastion using its public IP.

3. **Install or Use Ansible on the Bastion:**
   - **Approach A:** Install Ansible on the **bastion host** and run playbooks from there. In this project, this approach is used.
   - **Approach B:** Keep Ansible on your **local machine** but configure SSH proxying (SSH "jump host") so that your connections to the private instances go through the bastion automatically..

#### How to use Bastion Hosts: 
You can also do it via inventory files or ~/.ssh/config. For example:

**Inventory file approach:**
```ini
[targets]
target1 ansible_host=10.11.21.169 ansible_user=ubuntu ansible_ssh_private_key_file=./connection-key.pem

[targets:vars]
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -i ./connection-key.pem ubuntu@3.70.100.200"'

```

**Use simpler Ansible Inventory and `ssh_config`**
If using a jump host from your local machine, you can add something like this to your local ~/.ssh/config:

```
# ~/.ssh/config

Host bastion
  HostName <BASTION_PUBLIC_IP_OR_DNS>
  User ubuntu
  IdentityFile ~/.ssh/mykey.pem

Host ip-10-0-*.ec2.internal
  User ubuntu
  ProxyJump bastion
  IdentityFile ~/.ssh/mykey.pem
```
---

Then, in your **Ansible inventory**, refer to the private EC2 hosts by their internal DNS names (e.g., `ip-10-0-123-45.ec2.internal`), and Ansible will automatically route through the bastion.</br>
**Important**: Make sure that your SSH private key has the correct permissions: ```chmod 400 <YOUR_PRIVATE_KEY_PATH>```


## Step 4 - Running the Application End-to-End in AWS
- Once Docker is installed and images of Mircorservices are pulled, start the containers on their respective EC2 instances(by running the main Playbook.yml).
- Confirm that the Load Balancer forwards traffic:
   - **Vote service:** `http://<load_balancer_dns>/vote`
   - **Result service:** `http://<load_balancer_dns>/result`
- Perform test votes to verify that the results are reflected accordingly and entire system is functioning properly.

## Possible Enhancements
 

### 1. Create a Container Volume for PostgreSQL  
To ensure data persistence, map a named volume or a host path for Postgres data in your Docker configuration.  

Example in `docker-compose.yml`:  

```yaml
volumes:
  - postgres_data:/var/lib/postgresql/data
```

### 2. Adding Availability Zones (Multi-AZ) and Subnets  
In a production environment, you’d want multiple subnets across different Availability Zones (AZs) for high availability.  

- By placing EC2 instances in more than one AZ, you reduce the risk of downtime if one AZ goes offline.  
- Subnets in different AZs let your load balancer route traffic to healthy instances in any zone.  
- Terraform supports creating resources in multiple AZs by specifying `count` or using modules that handle multi-AZ patterns.  

### 3. High Availability (Step by Step)  

1. **Provision subnets** in two or more Availability Zones.  
2. **Deploy at least two instances** for your “Vote” frontend behind an Application Load Balancer (ALB) in separate AZs.  
   - This requires at least two private subnets in different AZs.  
3. **Use an autoscaling group** to automatically scale instances up or down based on demand.  
4. **Database and caching considerations:**  
   - Use a managed service or multi-node setup for Redis/Postgres.  
   - Alternatively, create secondary replicas to enable failover in case of failure.  
5. **Ensure ALB health checks** are properly configured:  
   - If one instance fails health checks, traffic is routed to a healthy instance.  

### 4. Logging & Monitoring  

- **Install or configure a monitoring agent** (e.g., CloudWatch Agent) to gather logs from Docker containers into CloudWatch Logs.  
- **Set up CloudWatch metrics** or use a third-party solution like Datadog to monitor CPU, memory, and container health.  
- **Define alarms** (e.g., CPU usage, container restart counts) to get alerts when something goes wrong.  



## Links

### Trello/Kanban
[Trello board](https://trello.com/b/YqdasITR/devops-infra-automation)

### Git
[Github repository Link](https://github.com/najjaved/devOps-infrastructure-automation)

