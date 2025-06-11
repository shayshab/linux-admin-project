#!/bin/bash

# Update package list and upgrade installed packages
sudo apt update && sudo apt upgrade -y

# Install necessary packages
sudo apt install -y nginx mysql-server python3-pip

# Start and enable services
sudo systemctl start nginx
sudo systemctl enable nginx
sudo systemctl start mysql
sudo systemctl enable mysql

# Create a new user and set permissions
sudo adduser adminuser
sudo usermod -aG sudo adminuser

# Set up firewall rules
sudo ufw allow 'Nginx Full'
sudo ufw allow OpenSSH
sudo ufw enable

# Print completion message
echo "Setup completed successfully!"