#!/bin/bash
# A simple shell script to check if node is out of sync with ethereum
# If node is out of sync, user will be notified by OpsGenie
# Using crontab command: `*/10 * * * * /home/foo/outOfSyncNoti.sh 'rinkeby' 'opsgeniekeyhere' >> /home/foo/nodeSync.log 2>&1` to run this script every 10 mins.

network=$1
port=$2
genieKey=$3
threshold=${4:-200}

# Get current node block number
curBlock=$(eval geth --exec "eth.blockNumber" attach http://localhost:$port)
if [ "$?" = "1" ]; then
  curBlock=0
fi

# Get latest block number from etherscan
# If on mainnet
if [ "$network" == "mainnet" ]; then
  res=$(curl -X GET "https://api.etherscan.io/api?module=proxy&action=eth_blockNumber" | grep -Eo '"result":.*?[^\\]"' | cut -d \: -f 2 | cut -d \" -f 2)
# If on testnet
else
  res=$(curl -X GET "https://api-rinkeby.etherscan.io/api?module=proxy&action=eth_blockNumber" | grep -Eo '"result":.*?[^\\]"' | cut -d \: -f 2 | cut -d \" -f 2)
fi

ethBlock=$(($res))

echo "latest block number from etherscan: $ethBlock"
echo "Our current block number: $curBlock"

# Check if node is out of sync.
# Will send notification when current block number is <threshold> blocks behind latest block on etherscan.
lowestBlock=$(($ethBlock-$threshold))
if [ $curBlock -lt $lowestBlock ];then
  systemctl restart geth
  curl -X POST https://api.opsgenie.com/v2/alerts -H "Content-Type: application/json" -H "Authorization: GenieKey $genieKey" -d '{ "message": "Our block is out of sync." }'
  echo ""
fi
