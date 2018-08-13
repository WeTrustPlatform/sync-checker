#!/bin/bash
# A simple shell script to check if node is out of sync with ethereum
# If node is out of sync, user will be notified by OpsGenie
# Using crontab command:
# */10 * * * * /home/foo/outOfSyncNoti.sh rinkeby 8545 opsgeniekeyhere geth.service >> /home/foo/nodeSync.log 2>&1`
# to run this script every 10 mins.

network=$1           # ethereum network in letters
port=$2              # local geth port
genieKey=$3          # opsgenie key
serviceName=$4       # name of the systemd service to restart
threshold=${5:200}   # number of blocks behind

# Get current node block number
curBlock=$(geth --exec "eth.blockNumber" attach http://localhost:${port})
if [ $? -ne 0 ]; then
  curBlock=0
fi

# Get latest block number from etherscan
etherscanDomain="api.etherscan.io"
if [ "$network" == "rinkeby" ]; then
  etherscanDomain="api-rinkeby.etherscan.io"
fi

ethBlock=$(( $(curl -s -X GET "https://${etherscanDomain}/api?module=proxy&action=eth_blockNumber" | grep -Eo '"result":.*?[^\\]"' | cut -d \: -f 2 | cut -d \" -f 2) ));

echo "latest block number from etherscan: $ethBlock"
echo "latest block number from localhost:${port} : $curBlock"

# Check if node is out of sync.
# Will send notification when current block number is <threshold> blocks behind latest block on etherscan.
if [[ ( $(( ${ethBlock} - ${curBlock} )) -ge $threshold ) && ( curBlock -ne 0 ) ]]; then
  curl -X POST https://api.opsgenie.com/v2/alerts -H "Content-Type: application/json" -H "Authorization: GenieKey $genieKey" -d '{ "message": "Our block is out of sync." }'
  echo ""
fi
