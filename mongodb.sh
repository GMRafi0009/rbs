#!/bin/bash

LOGFILE="mongodb_setup.log"
SUCCESS_COLOR='\033[0;32m'
ERROR_COLOR='\033[0;31m'
NC='\033[0m' # No Color

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOGFILE
}

check_and_log() {
    if [ $? -eq 0 ]; then
        log "${SUCCESS_COLOR}$1 completed successfully.${NC}"
    else
        log "${ERROR_COLOR}$1 failed.${NC}"
    fi
}

log "Script started."

# Check if user is root
if [ "$EUID" -ne 0 ]; then
    log "${ERROR_COLOR}Please run as root.${NC}"
    exit 1
fi

# Retrieve and log the User ID
USER_ID=$(id -u)
log "Executing script as User ID: $USER_ID"

# 1. Setup the MongoDB repo file
if ! grep -q "^deb .*mongodb" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
    wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/4.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.4.list
    apt-get update
    check_and_log "MongoDB repository setup"
else
    log "MongoDB repository already setup."
fi

# 2. Install MongoDB
if ! dpkg -l | grep -q mongodb-org; then
    apt-get install -y mongodb-org
    check_and_log "MongoDB installation"
else
    log "MongoDB is already installed."
fi

# 3. Start & Enable MongoDB Service
if ! systemctl is-active --quiet mongod; then
    systemctl start mongod
    check_and_log "MongoDB service start"
else
    log "MongoDB service is already running."
fi

if ! systemctl is-enabled --quiet mongod; then
    systemctl enable mongod
    check_and_log "MongoDB service enable"
else
    log "MongoDB service is already enabled."
fi

# 4. Update listen address from 127.0.0.1 to 0.0.0.0 in /etc/mongod.conf
if grep -q "bindIp: 127.0.0.1" /etc/mongod.conf; then
    sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf
    check_and_log "MongoDB listen address update"
else
    log "MongoDB listen address already updated."
fi

# 5. Restart the mongod service
systemctl restart mongod
check_and_log "MongoDB service restart"

log "Script completed."

