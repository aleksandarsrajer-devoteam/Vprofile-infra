#!/bin/bash
set -e

echo "Updating system packages..."
apt-get update -y

echo "Installing MySQL client..."
apt-get install mysql-client -y

echo "Downloading database schema..."
wget https://raw.githubusercontent.com/aleksandarsrajer-devoteam/VProfile/main/src/main/resources/db_backup.sql -O /tmp/db_backup.sql

echo "Injecting data into Cloud SQL..."
mysql -h ${db_private_ip} -u root -p'${db_password}' accounts < /tmp/db_backup.sql

echo "Database initialization complete! Shutting down..."
sudo poweroff