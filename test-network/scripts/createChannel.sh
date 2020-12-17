#!/bin/bash

CHANNEL_NAME="$1"
OUTPUT="$2"
DELAY="$3"
MAX_RETRY="$4"
VERBOSE="$5"
: ${CHANNEL_NAME:="mychannel"}
: ${DELAY:="3"}
: ${MAX_RETRY:="5"}
: ${VERBOSE:="false"}

# import utils
. scripts/utils.sh
. scripts/envVar.sh

if [ ! -d "channel-artifacts" ]; then
	mkdir channel-artifacts
fi

createChannelTx() {
  FABRIC_CFG_PATH=${PWD}/configtx

	set -x
	configtxgen -profile TwoOrgsChannel -outputCreateChannelTx ./channel-artifacts/${CHANNEL_NAME}.tx -channelID $CHANNEL_NAME
	res=$?
	{ set +x; } 2>/dev/null
  verifyResult $res "Failed to generate channel configuration transaction..."
}


createChannel() {
  FABRIC_CFG_PATH=$PWD/../config/

	setGlobals 1
	# Poll in case the raft leader is not set yet
	local rc=1
	local COUNTER=1
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
		sleep $DELAY
		set -x
		peer channel create -o localhost:7050 -c $CHANNEL_NAME --ordererTLSHostnameOverride orderer.example.com -f ./channel-artifacts/${CHANNEL_NAME}.tx --outputBlock $OUTPUT --tls --cafile $ORDERER_CA >&log.txt
		res=$?
		{ set +x; } 2>/dev/null
		let rc=$res
		COUNTER=$(expr $COUNTER + 1)
	done
	cat log.txt
	verifyResult $res "Channel creation failed"
	successln "Channel '$CHANNEL_NAME' created"
}

# # joinChannel ORG
# joinChannel() {
#   ORG=$1
#   setGlobals $ORG
# 	local rc=1
# 	local COUNTER=1
# 	## Sometimes Join takes time, hence retry
# 	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
#     sleep $DELAY
#     set -x
#     peer channel join -b ./channel-artifacts/$CHANNEL_NAME.block >&log.txt
#     res=$?
#     { set +x; } 2>/dev/null
# 		let rc=$res
# 		COUNTER=$(expr $COUNTER + 1)
# 	done
# 	cat log.txt
# 	verifyResult $res "After $MAX_RETRY attempts, peer0.org${ORG} has failed to join channel '$CHANNEL_NAME' "
# }

updateAnchorPeers() {
  ORG=$1
  # setGlobals $ORG
  # setPeerAddressForCLI $ORG

  CLI_TIMEOUT=10
  # default for delay
  CLI_DELAY=3

  # Use the CLI container to create the configuration transaction needed to add
  # Org3 to the network
  # echo
  # echo "###############################################################"
  # echo "####### Generate and submit config tx to add Org3 #############"
  # echo "###############################################################"
  docker exec cli ./scripts/addAnchorPeer.sh $ORG $CHANNEL_NAME $MAX_RETRY $CLI_DELAY $CLI_TIMEOUT $VERBOSE
  # if [ $? -ne 0 ]; then
  #   echo "ERROR !!!! Unable to create config tx"
  #   exit 1
  # fi
  # createAnchorPeerUpdate $ORG

	# local rc=1
	# local COUNTER=1
	# ## Sometimes Join takes time, hence retry
	# while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
  #   sleep $DELAY
  #   set -x
		# peer channel update -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx --tls --cafile $ORDERER_CA >&log.txt
  #   res=$?
  #   { set +x; } 2>/dev/null
		# let rc=$res
		# COUNTER=$(expr $COUNTER + 1)
	# done
	# cat log.txt
  # verifyResult $res "Anchor peer update failed"
  # successln "Anchor peers updated for org '$CORE_PEER_LOCALMSPID' on channel '$CHANNEL_NAME'"
  # sleep $DELAY
}

# verifyResult() {
#   if [ $1 -ne 0 ]; then
#     fatalln "$2"
#   fi
# }

## Create channeltx
infoln "Generating channel create transaction '${CHANNEL_NAME}.tx'"
createChannelTx

## Create channel
infoln "Creating channel ${CHANNEL_NAME}"
createChannel

# ## Join all the peers to the channel
# infoln "Join Org1 peers to the channel..."
# joinChannel 1
# infoln "Join Org2 peers to the channel..."
# joinChannel 2

# ## Set the anchor peers for each org in the channel
# infoln "Updating anchor peers for org1..."
# updateAnchorPeers 1
# infoln "Updating anchor peers for org2..."
# updateAnchorPeers 2

# successln "Channel successfully joined"

exit 0
