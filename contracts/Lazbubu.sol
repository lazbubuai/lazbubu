// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Permit, IPermitVerifier, PERMIT_TYPE_ADVENTURE, PERMIT_TYPE_CREATE_MEMORY, PERMIT_TYPE_SET_LEVEL, PERMIT_TYPE_SET_PERSONALITY, PERMIT_TYPE_MINT} from "./definitions.sol";


contract Lazbubu is ERC1155 {
    string public constant name = "Lazbubu";
    string public constant symbol = "LAZBUBU";

    event AdventureCreated(uint256 indexed tokenId, address indexed user, uint8 adventureType, uint256 contentHash);
    event MemoryCreated(uint256 indexed tokenId, uint256 indexed id, address indexed user, uint256 contentHash);
    event MemoryDeleted(uint256 indexed tokenId, uint256 indexed id, address indexed user);
    event LevelSet(uint256 indexed tokenId, address indexed user, uint8 level, bool mature);
    event MessageQuotaClaimed(uint256 indexed tokenId, address indexed user);
    event PersonalitySet(uint256 indexed tokenId, address indexed user, string personality);
    event AdventureMigrated(uint256 indexed tokenId, bytes32 indexed adventureId, address indexed user, uint8 adventureType, uint256 contentHash, uint32 timestamp);
    event MemoryMigrated(uint256 indexed tokenId, uint256 indexed id, address indexed user, uint256 contentHash, uint32 timestamp);
    event TokenMigrated(uint256 indexed tokenId, address indexed owner, string fileUrl, uint32 birthday);
    event TokenMinted(address indexed to, uint256 indexed tokenId, string fileUrl);

    uint256 public currentTokenId;
    mapping(uint256 => LazbubuState) public states;
    address public permitVerifier;
    mapping(uint256 => string) public fileUrl;
    mapping(bytes32 => bool) public urlHashExists;

    error NotTokenOwner();
    error TokenAlreadyMinted();
    error NonMatureTokenCannotBeTransferred();
    error InvalidAmount();
    error TokenAlreadyMature();
    error TokenIdMismatch();
    error UrlHashAlreadyExists();

    modifier onlyTokenOwner(uint256 tokenId) {
        if (states[tokenId].owner != _msgSender()) {
            revert NotTokenOwner();
        }
        _;
    }

    modifier onlyPermit(uint256 tokenId, uint8 permitType, bytes memory params, Permit memory permit) {
        IPermitVerifier(permitVerifier).verifyAndInvalidatePermit(permitType, tokenId, params, permit);
        _;
    }

    constructor(string memory uri, address permitVerifier_) ERC1155(uri) {
        permitVerifier = permitVerifier_;
    }
    
    function mint(address to, string memory tokenUrl_, Permit memory permit) public onlyPermit(_tokenIdForMint(to), PERMIT_TYPE_MINT, abi.encodePacked(to, tokenUrl_), permit) {
        uint256 tokenId = ++currentTokenId;
        _mint(to, tokenId, 1, "");
        bytes32 urlHash = keccak256(abi.encodePacked(tokenUrl_));
        if (urlHashExists[urlHash]) {
            revert UrlHashAlreadyExists();
        }
        urlHashExists[urlHash] = true;
        fileUrl[tokenId] = tokenUrl_;
        emit TokenMinted(to, tokenId, tokenUrl_);
    }

    function adventure(uint256 tokenId, uint8 adventureType, uint256 contentHash, Permit memory permit) public onlyPermit(tokenId, PERMIT_TYPE_ADVENTURE, abi.encodePacked(tokenId, adventureType, contentHash), permit) {
        address user = states[tokenId].owner;
        emit AdventureCreated(tokenId, user, adventureType, contentHash);
    }

    function createMemory(uint256 tokenId, uint256 contentHash, Permit memory permit) public onlyPermit(tokenId, PERMIT_TYPE_CREATE_MEMORY, abi.encodePacked(tokenId, contentHash), permit) {
        address user = states[tokenId].owner;
        uint256 id= uint256(keccak256(abi.encodePacked(tokenId, contentHash, uint32(block.timestamp))));
        emit MemoryCreated(tokenId, id, user, contentHash);
    }

    function deleteMemory(uint256 tokenId, uint256 id) public {
        address user = states[tokenId].owner;
        emit MemoryDeleted(tokenId, id, user);
    }

    function setPersonality(uint256 tokenId, string memory personality, Permit memory permit) public onlyPermit(tokenId, PERMIT_TYPE_SET_PERSONALITY, abi.encodePacked(tokenId, personality), permit) {
        address user = states[tokenId].owner;
        states[tokenId].personality = personality;
        emit PersonalitySet(tokenId, user, personality);
    }

    function setLevel(uint256 tokenId, uint8 level, bool mature, Permit memory permit) public onlyPermit(tokenId, PERMIT_TYPE_SET_LEVEL, abi.encodePacked(tokenId, level, mature), permit) {
        LazbubuState storage state = states[tokenId];
        if (state.maturity != 0) {
            revert TokenAlreadyMature();
        }
        address user = states[tokenId].owner;
        state.level = level;
        state.maturity = mature ? uint32(block.timestamp) : 0;
        emit LevelSet(tokenId, user, level, mature);
    }
    
    function claimMessageQuota(uint256 tokenId) public onlyTokenOwner(tokenId) {
        LazbubuState storage state = states[tokenId];
        if (state.firstTimeMessageQuotaClaimed == 0) {
            state.firstTimeMessageQuotaClaimed = uint32(block.timestamp);
        }

        state.lastTimeMessageQuotaClaimed = uint32(block.timestamp);

        emit MessageQuotaClaimed(tokenId, states[tokenId].owner);
    }

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values) internal virtual override {
        super._update(from, to, ids, values);
        for (uint256 i = 0; i < ids.length; i++) {
            if (values[i] != 1) {
                revert InvalidAmount();
            }
            uint256 tokenId = ids[i];
            if (from == address(0)) {
                if (states[tokenId].owner != address(0)) {
                    revert TokenAlreadyMinted();
                }
                states[tokenId].birthday = uint32(block.timestamp);
            } else {
                if (states[tokenId].maturity == 0) {
                    revert NonMatureTokenCannotBeTransferred();
                }
            }
            states[tokenId].owner = to;
        }
    }

    function _tokenIdForMint(address to) internal pure returns (uint256) {
        return 2**255 + uint256(uint160(to));
    }

}

struct Adventure {
    address user;
    uint8 adventureType;
    uint256 contentHash;
    uint32 timestamp;
}

struct Memory {
    uint256 contentHash;
    uint32 timestamp;
}

struct LazbubuState {
    uint32 birthday;
    uint8 level;
    uint32 maturity;
    uint32 reserved;
    uint32 lastTimeMessageQuotaClaimed;
    uint32 firstTimeMessageQuotaClaimed;
    string personality;
    address owner;
}
