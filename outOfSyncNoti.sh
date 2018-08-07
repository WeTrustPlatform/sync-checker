#!/bin/bash
# A simple shell script to check if node is out of sync with ethereum testnet
# If node is out of sync, user will be nptofied by OpsGenie
# Using crontab command: `*/10 * * * * /home/someuser/tmp/` to run this script every 10 mins.

# Get current node block number
curBlock=$(eval geth --exec "eth.blockNumber" attach http://localhost:8545)

# Get latest block number from etherscan
# If on mainnet
if [ "$1" == "mainnet" ]; then
  res=$(curl -X GET "https://api.etherscan.io/api?module=proxy&action=eth_blockNumber" | grep -Eo '"result":.*?[^\\]"' | cut -d \: -f 2 | cut -d \" -f 2)
# If on testnet
else
  res=$(curl -X GET "https://api-rinkeby.etherscan.io/api?module=proxy&action=eth_blockNumber" | grep -Eo '"result":.*?[^\\]"' | cut -d \: -f 2 | cut -d \" -f 2)
fi

ethBlock=$(($res))

echo "latest block number from etherscan: $ethBlock"
echo "Our current block number: $curBlock"

# Check if node is out of sync.
# Will send notification when current block number is <numberofblocksbehind> blocks behind latest block on etherscan.
genieKey=$2
numberofblocksbehind=${3:-200}
lowestBlock=$(($ethBlock-$numberofblocksbehind))

if [ $curBlock -lt $lowestBlock ];then
  curl -X POST https://api.opsgenie.com/v2/alerts -H "Content-Type: application/json" -H "Authorization: GenieKey $genieKey" -d '{ "message": "Our block is out of sync." }'
  echo ""
fi
