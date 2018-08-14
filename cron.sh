#!/bin/bash
# A simple shell script to check if node is out of sync with ethereum
# If node is out of sync, the node service will be restarted
# If node is out of sync and slackhook is set, a message will be sent to slack
# If node is out of sync and opsgeniekey is set, a message will be sent through opsgenie
# Using crontab command:
# */10 * * * * /home/foo/cron.sh rinkeby 8545 geth.service 200 slackhook opsgeniekey >> /home/foo/cron.log 2>&1`
# to run this script every 10 mins.

network=$1           # ethereum network in letters
port=$2              # local geth port
serviceName=$3       # name of the systemd service to restart
threshold=$4         # number of blocks behind
slackHook=$5         # slack hook url
genieKey=$6          # opsgenie key

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
  if [[ -n $slackHook ]]; then
    curl -s -X POST -H 'Content-type: application/json' --data "{\"text\": \"Our block is out of sync on ${network} on ${HOSTNAME}.\"}" "$slackHook"
  fi
  if [[ -n $genieKey ]]; then
    curl -s -X POST https://api.opsgenie.com/v2/alerts -H "Content-Type: application/json" -H "Authorization: GenieKey $genieKey" -d "{ \"message\": \"Our block is out of sync on ${network} on ${HOSTNAME}.\" }"
  fi
  systemctl restart ${serviceName};
  echo ""
fi
