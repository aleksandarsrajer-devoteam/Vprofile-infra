#!/bin/bash
set -e

echo "Cekamo stabilizaciju mreze..."
sleep 60

echo "Instalacija Jave i osnovnih alata..."
apt update -y
apt install -y openjdk-17-jdk openjdk-17-jdk-headless git wget unzip zip rsync

echo "Preuzimanje i konfiguracija Tomcat 10..."
TOMURL="https://archive.apache.org/dist/tomcat/tomcat-10/v10.1.26/bin/apache-tomcat-10.1.26.tar.gz"
cd /tmp/
wget $TOMURL -O tomcatbin.tar.gz
EXTOUT=$(tar xzvf tomcatbin.tar.gz)
TOMDIR=$(echo "$EXTOUT" | cut -d '/' -f1)

useradd --shell /bin/false --system tomcat || true
mkdir -p /usr/local/tomcat
rsync -avzh /tmp/$TOMDIR/ /usr/local/tomcat/
chown -R tomcat:tomcat /usr/local/tomcat

# Kreiranje sistemskog servisa za Tomcat
cat > /etc/systemd/system/tomcat.service << 'EOL'
[Unit]
Description=Apache Tomcat 10
After=network.target

[Service]
Type=simple
User=tomcat
Group=tomcat
Environment="JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64"
Environment="CATALINA_PID=/tmp/tomcat.pid"
Environment="CATALINA_HOME=/usr/local/tomcat"
Environment="CATALINA_BASE=/usr/local/tomcat"
ExecStart=/usr/local/tomcat/bin/catalina.sh run
ExecStop=/usr/local/tomcat/bin/catalina.sh stop 15 -force
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable --now tomcat

echo "Instalacija Maven-a..."
cd /tmp/
wget https://archive.apache.org/dist/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.zip
unzip apache-maven-3.9.9-bin.zip
cp -r apache-maven-3.9.9 /usr/local/maven3.9

export MAVEN_OPTS="-Xmx512m"

echo "Kloniranje koda sa gcp grane i bildovanje aplikacije..."
git clone -b gcp https://github.com/hkhcoder/vprofile-project.git
cd vprofile-project
/usr/local/maven3.9/bin/mvn install

echo "Deploy-ovanje aplikacije u Tomcat..."
systemctl stop tomcat
sleep 20
rm -rf /usr/local/tomcat/webapps/ROOT*
cp target/vprofile-v2.war /usr/local/tomcat/webapps/ROOT.war
systemctl start tomcat
sleep 20

ufw allow 8080/tcp || true
systemctl restart tomcat
echo "Tomcat je uspesno konfigurisan i pokrenut!"