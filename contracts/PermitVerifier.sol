// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import {IPermitVerifier, Permit} from "./definitions.sol";

contract PermitVerifier is IPermitVerifier {
    event PermitInvalidated(uint256 indexed tokenId, uint8 permitType, bytes params, uint128 nonce, uint256 dataHash, uint256 expire, bytes sig);

    address public admin;
    address public serviceTo;
    address public signer;
    mapping(uint256 => uint128) public nextPermitNonce;
    error InvalidPermitType();
    error PermitExpired();
    error InvalidDataHash();
    error InvalidNonce();
    error InvalidPermitSignature();
    error NotAdmin();
    error NotServiceTo();

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert NotAdmin();
        }
        _;
    }

    modifier onlyServiceTo() {
        if (msg.sender != serviceTo) {
            revert NotServiceTo();
        }
        _;
    }

    constructor() {
        admin = signer = msg.sender;
    }

    function setAdmin(address admin_) public onlyAdmin {
        admin = admin_;
    }

    function setSigner(address signer_) public onlyAdmin {
        signer = signer_;
    }

    function setServiceTo(address serviceTo_) public onlyAdmin {
        serviceTo = serviceTo_;
    }

    function verifyAndInvalidatePermit(
        uint8 permitType,
        uint256 tokenId,
        bytes memory params,
        Permit memory permit
    ) external onlyServiceTo {
        if (permit.permitType != permitType) {
            revert InvalidPermitType();
        }
        if (permit.expire != 0 && permit.expire <= block.timestamp) {
            revert PermitExpired();
        }
        if (permit.dataHash != uint256(keccak256(params))) {
            revert InvalidDataHash();
        }
        if (nextPermitNonce[tokenId] != permit.nonce) {
            revert InvalidNonce();
        }
        if (signer != getSigner(permit)) {
            revert InvalidPermitSignature();
        }
        nextPermitNonce[tokenId]++;
        emit PermitInvalidated(tokenId, permitType, params, permit.nonce, permit.dataHash, permit.expire, permit.sig);
    }

    function getSigner(
        Permit memory permit
    ) public pure returns (address) {
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                permit.permitType,
                permit.nonce,
                permit.dataHash,
                permit.expire
            )
        );
        return recoverSigner(messageHash, permit.sig);
    }

    function recoverSigner(bytes32 _messageHash, bytes memory sig) private pure returns (address) {
        require(sig.length == 65, "invalid signature length");

        bytes32 r; bytes32 s; uint8 v;
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }

        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash)
        );

        return ecrecover(ethSignedMessageHash, v, r, s);
    }
}
