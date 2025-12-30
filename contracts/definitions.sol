// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

uint8 constant PERMIT_TYPE_ADVENTURE = 1;
uint8 constant PERMIT_TYPE_CREATE_MEMORY = 2;
uint8 constant PERMIT_TYPE_SET_LEVEL = 3;
uint8 constant PERMIT_TYPE_SET_PERSONALITY = 4;
uint8 constant PERMIT_TYPE_MINT = 5;

interface IPermitVerifier {
    function verifyAndInvalidatePermit(uint8 permitType, uint256 tokenId, bytes memory params, Permit memory permit) external;
}

struct Permit {
    uint8 permitType;
    uint128 nonce;
    uint dataHash;
    uint expire;
    bytes sig;
}