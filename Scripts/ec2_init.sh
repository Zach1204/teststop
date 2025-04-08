# Initialize EC2 w/ Required Services

# Update all packages
sudo yum update -y

# Install Docker
sudo yum install -y docker

# Install Docker-Compose & Give it Execution Permissions & Restart Service to Apply
sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Git
sudo yum install git

# Start and enable Docker service (persistent on reboot)
sudo systemctl start docker
sudo systemctl enable docker

# Add ec2-user to the Docker group
sudo usermod -aG docker ec2-user



