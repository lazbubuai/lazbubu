// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Permit, PERMIT_TYPE_ADVENTURE, PERMIT_TYPE_CREATE_MEMORY, PERMIT_TYPE_SET_LEVEL, PERMIT_TYPE_SET_PERSONALITY, PERMIT_TYPE_MINT} from "./definitions.sol";

/**
 * @title Lazbubu
 * @notice ERC1155 token contract with permit-based authorization and token lifecycle management
 * @dev Implements EIP712 for structured data signing
 */
contract Lazbubu is ERC1155, EIP712 {
    using ECDSA for bytes32;

    /// @dev EIP712 type hash for Permit struct
    bytes32 private constant PERMIT_TYPEHASH = keccak256("Permit(uint8 permitType,uint128 nonce,uint256 dataHash,uint256 expire)");

    string public constant name = "Lazbubu";
    string public constant symbol = "LAZBUBU";

    /// @notice Emitted when an adventure is created for a token
    event AdventureCreated(uint256 indexed tokenId, address indexed user, uint8 adventureType, uint256 contentHash);
    /// @notice Emitted when a memory is created for a token
    event MemoryCreated(uint256 indexed tokenId, uint256 indexed id, address indexed user, uint256 contentHash);
    /// @notice Emitted when a memory is deleted
    event MemoryDeleted(uint256 indexed tokenId, uint256 indexed id, address indexed user);
    /// @notice Emitted when token level is set
    event LevelSet(uint256 indexed tokenId, address indexed user, uint8 level, bool mature);
    /// @notice Emitted when message quota is claimed
    event MessageQuotaClaimed(uint256 indexed tokenId, address indexed user);
    /// @notice Emitted when token personality is set
    event PersonalitySet(uint256 indexed tokenId, address indexed user, string personality);
    /// @notice Emitted when a new token is minted
    event TokenMinted(address indexed to, uint256 indexed tokenId, string fileUrl);
    /// @notice Emitted when a permit is invalidated after use
    event PermitInvalidated(uint256 indexed tokenId, uint8 permitType, bytes params, uint128 nonce, uint256 dataHash, uint256 expire, bytes sig);
    /// @notice Emitted when admin address is updated
    event AdminSet(address indexed admin);
    /// @notice Emitted when signer address is updated
    event SignerSet(address indexed signer);

    /// @notice Current token ID counter
    uint256 public currentTokenId;
    /// @notice Token state mapping
    mapping(uint256 => LazbubuState) public states;
    /// @notice Token file URL mapping
    mapping(uint256 => string) public fileUrl;
    /// @notice URL hash existence check to prevent duplicates
    mapping(bytes32 => bool) public urlHashExists;

    /// @notice Admin address with permission to update signer and admin
    address public admin;
    /// @notice Signer address for permit verification
    address public signer;
    /// @notice Nonce mapping for permit replay protection
    mapping(uint256 => uint128) public nextPermitNonce;

    /// @notice Thrown when caller is not the token owner
    error NotTokenOwner();
    /// @notice Thrown when attempting to mint an already minted token
    error TokenAlreadyMinted();
    /// @notice Thrown when attempting to transfer a non-mature token
    error NonMatureTokenCannotBeTransferred();
    /// @notice Thrown when token amount is invalid (must be 1)
    error InvalidAmount();
    /// @notice Thrown when attempting to set level on an already mature token
    error TokenAlreadyMature();
    /// @notice Thrown when URL hash already exists
    error UrlHashAlreadyExists();
    /// @notice Thrown when permit type doesn't match expected type
    error InvalidPermitType();
    /// @notice Thrown when permit has expired
    error PermitExpired();
    /// @notice Thrown when permit data hash doesn't match params
    error InvalidDataHash();
    /// @notice Thrown when permit nonce is invalid
    error InvalidNonce();
    /// @notice Thrown when permit signature is invalid
    error InvalidPermitSignature();
    /// @notice Thrown when caller is not the admin
    error NotAdmin();

    /// @notice Restricts access to token owner only
    modifier onlyTokenOwner(uint256 tokenId) {
        if (states[tokenId].owner != _msgSender()) {
            revert NotTokenOwner();
        }
        _;
    }

    /// @notice Restricts access to admin only
    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert NotAdmin();
        }
        _;
    }

    /// @notice Verifies and invalidates permit before executing function
    modifier onlyPermit(uint256 tokenId, uint8 permitType, bytes memory params, Permit memory permit) {
        _verifyAndInvalidatePermit(permitType, tokenId, params, permit);
        _;
    }

    /// @notice Initializes the contract with URI and EIP712 domain
    /// @param uri Base URI for token metadata
    constructor(string memory uri, address admin_, address signer_) ERC1155(uri) EIP712("Lazbubu", "1") {
        admin = admin_;
        signer = signer_;
        emit AdminSet(admin_);
        emit SignerSet(signer_);
    }
    
    /// @notice Mints a new token with permit authorization
    /// @param to Address to mint token to
    /// @param tokenUrl_ File URL for the token
    /// @param permit EIP712 signed permit
    function mint(address to, string memory tokenUrl_, Permit memory permit) external onlyPermit(_tokenIdForMint(to), PERMIT_TYPE_MINT, abi.encodePacked(to, tokenUrl_), permit) {
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

    /// @notice Creates an adventure for a token
    /// @param tokenId Token ID
    /// @param adventureType Type of adventure
    /// @param contentHash Hash of adventure content
    /// @param permit EIP712 signed permit
    function adventure(uint256 tokenId, uint8 adventureType, uint256 contentHash, Permit memory permit) external onlyPermit(tokenId, PERMIT_TYPE_ADVENTURE, abi.encodePacked(tokenId, adventureType, contentHash), permit) {
        address user = states[tokenId].owner;
        emit AdventureCreated(tokenId, user, adventureType, contentHash);
    }

    /// @notice Creates a memory for a token
    /// @param tokenId Token ID
    /// @param contentHash Hash of memory content
    /// @param permit EIP712 signed permit
    function createMemory(uint256 tokenId, uint256 contentHash, Permit memory permit) external onlyPermit(tokenId, PERMIT_TYPE_CREATE_MEMORY, abi.encodePacked(tokenId, contentHash), permit) {
        address user = states[tokenId].owner;
        uint256 id= uint256(keccak256(abi.encodePacked(tokenId, contentHash, uint32(block.timestamp))));
        emit MemoryCreated(tokenId, id, user, contentHash);
    }

    /// @notice Deletes a memory for a token
    /// @param tokenId Token ID
    /// @param id Memory ID to delete
    function deleteMemory(uint256 tokenId, uint256 id) external onlyTokenOwner(tokenId) {
        address user = states[tokenId].owner;
        emit MemoryDeleted(tokenId, id, user);
    }

    /// @notice Sets personality for a token
    /// @param tokenId Token ID
    /// @param personality Personality string
    /// @param permit EIP712 signed permit
    function setPersonality(uint256 tokenId, string memory personality, Permit memory permit) external onlyPermit(tokenId, PERMIT_TYPE_SET_PERSONALITY, abi.encodePacked(tokenId, personality), permit) {
        address user = states[tokenId].owner;
        states[tokenId].personality = personality;
        emit PersonalitySet(tokenId, user, personality);
    }

    /// @notice Sets level and maturity status for a token (can only be set once)
    /// @param tokenId Token ID
    /// @param level Token level
    /// @param mature Whether token is mature
    /// @param permit EIP712 signed permit
    function setLevel(uint256 tokenId, uint8 level, bool mature, Permit memory permit) external onlyPermit(tokenId, PERMIT_TYPE_SET_LEVEL, abi.encodePacked(tokenId, level, mature), permit) {
        LazbubuState storage state = states[tokenId];
        if (state.maturity != 0) {
            revert TokenAlreadyMature();
        }
        address user = states[tokenId].owner;
        state.level = level;
        state.maturity = mature ? uint32(block.timestamp) : 0;
        emit LevelSet(tokenId, user, level, mature);
    }
    
    /// @notice Claims message quota for a token
    /// @param tokenId Token ID
    function claimMessageQuota(uint256 tokenId) external onlyTokenOwner(tokenId) {
        LazbubuState storage state = states[tokenId];
        if (state.firstTimeMessageQuotaClaimed == 0) {
            state.firstTimeMessageQuotaClaimed = uint32(block.timestamp);
        }

        state.lastTimeMessageQuotaClaimed = uint32(block.timestamp);

        emit MessageQuotaClaimed(tokenId, states[tokenId].owner);
    }

    /// @notice Sets the admin address
    /// @param admin_ New admin address
    function setAdmin(address admin_) public onlyAdmin {
        admin = admin_;
        emit AdminSet(admin_);
    }

    /// @notice Sets the signer address for permit verification
    /// @param signer_ New signer address
    function setSigner(address signer_) public onlyAdmin {
        signer = signer_;
        emit SignerSet(signer_);
    }

    /// @notice Recovers signer address from EIP712 permit signature
    /// @param permit Permit struct with signature
    /// @return Signer address
    function getSigner(
        Permit memory permit
    ) public view returns (address) {
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                permit.permitType,
                permit.nonce,
                permit.dataHash,
                permit.expire
            )
        );
        bytes32 digest = _hashTypedDataV4(structHash);
        return ECDSA.recover(digest, permit.sig);
    }

    /// @notice Verifies permit and invalidates it to prevent replay
    /// @param permitType Expected permit type
    /// @param tokenId Token ID
    /// @param params Function parameters
    /// @param permit Permit struct with signature
    function _verifyAndInvalidatePermit(
        uint8 permitType,
        uint256 tokenId,
        bytes memory params,
        Permit memory permit
    ) internal {
        if (permit.permitType != permitType) {
            revert InvalidPermitType();
        }
        if (permit.expire < block.timestamp) {
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

    /// @notice Overrides ERC1155 _update to enforce token lifecycle rules
    /// @param from Source address (address(0) for minting)
    /// @param to Destination address
    /// @param ids Token IDs
    /// @param values Token amounts (must be 1)
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values) internal virtual override {
        super._update(from, to, ids, values);
        for (uint256 i = 0; i < ids.length; i++) {
            if (values[i] != 1) {
                revert InvalidAmount();
            }
            uint256 tokenId = ids[i];
            if (from == address(0)) {
                // Minting: set birthday and check for duplicates
                if (states[tokenId].owner != address(0)) {
                    revert TokenAlreadyMinted();
                }
                states[tokenId].birthday = uint32(block.timestamp);
            } else {
                // Transfer: require token to be mature
                if (states[tokenId].maturity == 0) {
                    revert NonMatureTokenCannotBeTransferred();
                }
            }
            states[tokenId].owner = to;
        }
    }

    /// @notice Generates a unique token ID for mint permit verification
    /// @param to Address to mint to
    /// @return Pseudo token ID for permit verification
    function _tokenIdForMint(address to) internal pure returns (uint256) {
        return 2**255 + uint256(uint160(to));
    }

}

/// @notice Adventure data structure
struct Adventure {
    address user;
    uint8 adventureType;
    uint256 contentHash;
    uint32 timestamp;
}

/// @notice Memory data structure
struct Memory {
    uint256 contentHash;
    uint32 timestamp;
}

/// @notice Token state structure
struct LazbubuState {
    uint32 birthday;                      // Token creation timestamp
    uint8 level;                           // Token level
    uint32 maturity;                       // Maturity timestamp (0 if not mature)
    uint32 reserved;                       // Reserved for future use
    uint32 lastTimeMessageQuotaClaimed;    // Last quota claim timestamp
    uint32 firstTimeMessageQuotaClaimed;   // First quota claim timestamp
    string personality;                     // Token personality string
    address owner;                         // Current token owner
}
