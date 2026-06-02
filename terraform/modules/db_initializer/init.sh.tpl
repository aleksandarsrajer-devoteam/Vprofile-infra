#!/bin/bash
set -euo pipefail

echo "Updating system packages..."
apt-get update -y
apt-get install -y mysql-client

# ── Fetch DB password from Secret Manager at runtime ────────────────────────
# The DB init SA (vprofile-db-init-sa) has roles/secretmanager.secretAccessor.
# gcloud authenticates via the GCE metadata server — no credentials file needed.
echo "Fetching DB password from Secret Manager..."
DB_PASSWORD=$(gcloud secrets versions access latest \
  --secret="vprofile-db-password" \
  --format="get(payload.data)" | base64 --decode)
echo "Password fetched successfully."
# ─────────────────────────────────────────────────────────────────────────────

echo "Downloading database schema..."
wget https://raw.githubusercontent.com/aleksandarsrajer-devoteam/Vprofile-app/main/src/main/resources/db_backup.sql \
  -O /tmp/db_backup.sql

echo "Injecting data into Cloud SQL..."
mysql -h ${db_private_ip} -u root -p"$DB_PASSWORD" accounts < /tmp/db_backup.sql

# Clear the password from memory immediately after use
unset DB_PASSWORD

echo "Database initialization complete! Shutting down..."
sudo poweroff