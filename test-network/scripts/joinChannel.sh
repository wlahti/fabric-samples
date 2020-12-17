#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

CHANNEL_NAME="$1"
BLOCK="$2"
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

# joinChannel ORG
joinChannel() {
  FABRIC_CFG_PATH=$PWD/../config/
  ORG=$1
  BLOCK=$2
  setGlobals $ORG
	local rc=1
	local COUNTER=1
	## Sometimes Join takes time, hence retry
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ] ; do
    sleep $DELAY
    set -x
    peer channel join -b $BLOCK >&log.txt
    res=$?
    { set +x; } 2>/dev/null
		let rc=$res
		COUNTER=$(expr $COUNTER + 1)
	done
	cat log.txt
	verifyResult $res "After $MAX_RETRY attempts, peer0.org${ORG} has failed to join channel '$CHANNEL_NAME' "
}

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

## Join all the peers to the channel
infoln "Join Org1 peers to the channel..."
joinChannel 1 $BLOCK
infoln "Join Org2 peers to the channel..."
joinChannel 2 $BLOCK

## Set the anchor peers for each org in the channel
infoln "Updating anchor peers for org1..."
updateAnchorPeers 1
infoln "Updating anchor peers for org2..."
updateAnchorPeers 2

successln "Channel successfully joined"

exit 0
