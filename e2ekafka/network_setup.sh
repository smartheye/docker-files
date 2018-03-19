#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#


UP_DOWN="$1"
IS_FIRST="$2"
CH_NAME="$3"
CLI_TIMEOUT="$4"
IF_COUCHDB="$5"
ROOT_PASSWORD="justwait"

: ${CLI_TIMEOUT:="10000"}

COMPOSE_FILE=docker-compose-cli.yaml
COMPOSE_FILE_COUCH=docker-compose-couch.yaml
#COMPOSE_FILE=docker-compose-e2e.yaml

function printHelp () {
	echo "Usage: ./network_setup <up|down> <\$first> <\$channel-name> <\$cli_timeout> <couchdb>.\nThe arguments must be in order."
}

function validateArgs () {
	if [ -z "${UP_DOWN}" ]; then
		echo "Option up / down / restart not mentioned"
		printHelp
		exit 1
	fi
	if [ -z "${CH_NAME}" ]; then
		echo "setting to default channel 'mychannel'"
		CH_NAME=mychannel
	fi
}

function clearContainers () {
        CONTAINER_IDS=$(docker ps -aq)
        if [ -z "$CONTAINER_IDS" -o "$CONTAINER_IDS" = " " ]; then
                echo "---- No containers available for deletion ----"
        else
                docker rm -f $CONTAINER_IDS
        fi
}

function removeUnwantedImages() {
        DOCKER_IMAGE_IDS=$(docker images | grep "dev\|none\|test-vp\|peer[0-9]-" | awk '{print $3}')
        if [ -z "$DOCKER_IMAGE_IDS" -o "$DOCKER_IMAGE_IDS" = " " ]; then
                echo "---- No images available for deletion ----"
        else
                docker rmi -f $DOCKER_IMAGE_IDS
        fi
}

function initDataPersistence() {
        echo "CHECK ORDERER LEDGER FOLDER EXISTS"
        if [ -d "./data/hyperleger/orderer/orderer1.example.com/" ]; then
           echo "./data/hyperleger/orderer/orderer1.example.com/ exists"
        else
           mkdir -m 777 -p ./data/hyperleger/orderer/orderer1.example.com/
        fi
        if [ -d "./data/hyperleger/orderer/orderer2.example.com/" ]; then
           echo "./data/hyperleger/orderer/orderer2.example.com/ exists"
        else
           mkdir -m 777 -p ./data/hyperleger/orderer/orderer2.example.com/
        fi
        if [ -d "./data/hyperleger/orderer/orderer3.example.com/" ]; then
           echo "./data/hyperleger/orderer/orderer3.example.com/ exists"
        else
           mkdir -m 777 -p ./data/hyperleger/orderer/orderer3.example.com/
        fi
        if [ -d "./data/hyperleger/orderer/orderer4.example.com/" ]; then
           echo "./data/hyperleger/orderer/orderer4.example.com/ exists"
        else
           mkdir -m 777 -p ./data/hyperleger/orderer/orderer4.example.com/
        fi

        echo "CHECK PEER LEDGER FOLDER EXISTS"
        if [ -d "./data/hyperleger/peers/peer0.org1.example.com/" ]; then
           echo "./data/hyperleger/peers/peer0.org1.example.com/ exists"
        else
           mkdir -m 777 -p ./data/hyperleger/peers/peer0.org1.example.com/
        fi
        if [ -d "./data/hyperleger/peers/peer1.org1.example.com/" ]; then
           echo "./data/hyperleger/peers/peer1.org1.example.com/ exists"
        else
           mkdir -m 777 -p ./data/hyperleger/peers/peer1.org1.example.com/
        fi
        if [ -d "./data/hyperleger/peers/peer2.org1.example.com/" ]; then
           echo "./data/hyperleger/peers/peer2.org1.example.com/ exists"
        else
           mkdir -m 777 -p ./data/hyperleger/peers/peer2.org1.example.com/
        fi
        if [ -d "./data/hyperleger/peers/peer3.org1.example.com/" ]; then
           echo "./data/hyperleger/peers/peer3.org1.example.com/ exists"
        else
           mkdir -m 777 -p ./data/hyperleger/peers/peer3.org1.example.com/
        fi
        if [ -d "./data/hyperleger/peers/peer0.org2.example.com/" ]; then
           echo "./data/hyperleger/peers/peer0.org2.example.com/ exists"
        else
           mkdir -m 777 -p ./data/hyperleger/peers/peer0.org2.example.com/
        fi
        if [ -d "./data/hyperleger/peers/peer1.org2.example.com/" ]; then
           echo "./data/hyperleger/peers/peer1.org2.example.com/ exists"
        else
           mkdir -m 777 -p ./data/hyperleger/peers/peer1.org2.example.com/
        fi

        echo "CHECK KAFKA LEDGER FOLDER EXISTS"
        if [ -d "./data/hyperleger/kafka/kafka0/" ]; then
           echo "./data/hyperleger/kafka/kafka0/ exists"
        else
           mkdir -m 777 -p ./data/hyperleger/kafka/kafka0/
        fi
        if [ -d "./data/hyperleger/kafka/kafka1/" ]; then
           echo "./data/hyperleger/kafka/kafka1/ exists"
        else
           mkdir -m 777 -p ./data/hyperleger/kafka/kafka1/
        fi
        if [ -d "./data/hyperleger/kafka/kafka2/" ]; then
           echo "./data/hyperleger/kafka/kafka2/ exists"
        else
           mkdir -m 777 -p ./data/hyperleger/kafka/kafka2/
        fi
        if [ -d "./data/hyperleger/kafka/kafka0/" ]; then
           echo "./data/hyperleger/kafka/kafka0/ exists"
        else
           mkdir -m 777 -p ./data/hyperleger/kafka/kafka2/
        fi

        echo "CHECK ZOOKEEPER LEDGER FOLDER EXISTS"
        if [ -d "./data/hyperleger/zookeeper/zookeeper0/" ]; then
           echo "./data/hyperleger/zookeeper/zookeeper0/ exists"
        else
           mkdir -m 777 -p ./data/hyperleger/zookeeper/zookeeper0/
        fi
        if [ -d "./data/hyperleger/zookeeper/zookeeper1/" ]; then
           echo "./data/hyperleger/zookeeper/zookeeper1/ exists"
        else
           mkdir -m 777 -p ./data/hyperleger/zookeeper/zookeeper1/
        fi
        if [ -d "./data/hyperleger/zookeeper/zookeeper2/" ]; then
           echo "./data/hyperleger/zookeeper/zookeeper2/ exists"
        else
           mkdir -m 777 -p ./data/hyperleger/zookeeper/zookeeper2/
        fi
}

function removeDataPersistence() {
    echo $ROOT_PASSWORD | sudo rm -rf ./data
    echo $ROOT_PASSWORD | sudo rm -rf ./channel-artifacts/*
    echo $ROOT_PASSWORD | sudo rm -rf ./crypto-config
}

function networkUp () {
    if [ -d "./crypto-config" ]; then
      echo "crypto-config directory already exists."
    else
      #Generate all the artifacts that includes org certs, orderer genesis block,
      # channel configuration transaction
      source generateArtifacts.sh $CH_NAME
    fi

    if [ -d "./data" ]; then
        echo "./data exists."
    else
        IS_FIRST="first"
        echo "set first start $IS_FIRST"
    fi 
    initDataPersistence

    if [ "${IF_COUCHDB}" == "couchdb" ]; then
      IS_FIRST=$IS_FIRST CHANNEL_NAME=$CH_NAME TIMEOUT=$CLI_TIMEOUT docker-compose -f $COMPOSE_FILE -f $COMPOSE_FILE_COUCH up -d 2>&1
    else
      IS_FIRST=$IS_FIRST CHANNEL_NAME=$CH_NAME TIMEOUT=$CLI_TIMEOUT docker-compose -f $COMPOSE_FILE up -d 2>&1
    fi
    if [ $? -ne 0 ]; then
	echo "ERROR !!!! Unable to pull the images "
	exit 1
    fi
    docker logs -f cli
}

function networkDown () {
    docker-compose -f $COMPOSE_FILE down

    #Cleanup the chaincode containers
    clearContainers

    #Cleanup images
    removeUnwantedImages

    # remove orderer block and other channel configuration transactions and certs
    #rm -rf channel-artifacts/*.block channel-artifacts/*.tx crypto-config
}

validateArgs

#Create the network using docker compose
if [ "${UP_DOWN}" == "up" ]; then
	networkUp
elif [ "${UP_DOWN}" == "down" ]; then ## Clear the network
	networkDown
elif [ "${UP_DOWN}" == "restart" ]; then ## Restart the network
	networkDown
	networkUp
elif [ "${UP_DOWN}" == "first" ]; then ## Clear the data
        IS_FIRST="first"
        networkUp
elif [ "${UP_DOWN}" == "clean" ]; then ## Clear the data
        networkDown
        removeDataPersistence
elif [ "${UP_DOWN}" == "cleanstart" ]; then ## Clear the data
        removeDataPersistence
        networkUp
else
	printHelp
	exit 1
fi
