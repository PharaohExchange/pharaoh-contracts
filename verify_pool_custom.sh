#!/bin/bash
source .env

export FOUNDRY_LIBRARIES="Oracle:0x389dF9430143880ddb13bdd5FD30Daf2D57E7d55,Position:0x2832e19221631e7082926e2bB354497613BF9D6F,ProtocolActions:0x34413f3CdDAfEF7Db46f92296A7CEa444b3140fD"

forge verify-contract 0x90E8a5b881D211f418d77Ba8978788b62544914B \
    contracts/CL/core/RamsesV3Pool.sol:RamsesV3Pool \
    --chain-id 59144 \
    --etherscan-api-key $ETHERSCAN_V2_API_KEY \
    --compiler-version 0.8.28 \
    --via-ir \
    --optimizer-runs 200 \
    --evm-version paris \
    --guess-constructor-args \
    --rpc-url $LINEA_RPC
