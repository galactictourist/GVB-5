// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./IGBCollection.sol";

contract GBMarketplace is AccessControl, EIP712, ReentrancyGuard, Pausable {

    event AddItem(
        address collection,
        address from,
        uint256 tokenId,
        uint256 quantity,
        string tokenURI,
        uint256 timestamp
    );
    
    event BuyItem(
        address collection,
        address buyer,
        address seller,
        uint256 tokenId,
        uint256 quantity,
        uint256 totalPrice,
        uint256 itemPrice,
        address charityAddress,
        uint256 timestamp
    );
    
    event UpdateItemMetaData(
        address collection,
        address from,
        uint256 tokenId,
        string tokenURI,
        uint256 timestamp
    );

    event SetCollectionAddress(address collectionAddress, bool status);
    event SetVerifyRole(address verifyRoleAddress);
    event SetAdminWallet(address account);

    bytes32 constant public ADDITEM_TYPEHASH = keccak256("AddItem(address account,address collection,uint256 tokenId,uint256 quantity,uint96 royalty,string tokenURI,uint256 deadline,uint256 nonce)");
    bytes32 constant public BUYITEM_TYPEHASH = keccak256("BuyItem(address account,address collection,address seller,uint256 tokenId,uint256 quantity,uint256 totalPrice,uint256 itemPrice,address charityAddress,uint256 deadline,uint256 nonce)");
    mapping(address => bool) public gbCollection;
    mapping(address => uint256) public nonces;

    bytes32 public constant VERIFY_ROLE = keccak256("VERIFY_ROLE");

    address private adminWallet;

    constructor(
        address owner,
        address verifyRoleAddress,
        address adminWallet_
    ) EIP712("GBMarketplace", "1.0.0") {
        _setupRole(DEFAULT_ADMIN_ROLE, owner);
        _setupRole(VERIFY_ROLE, verifyRoleAddress);
        adminWallet = adminWallet_;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function setGBCollectionAddress(address collectionAddress, bool isCollection) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require (collectionAddress != address(0), "gbCollection address must not be zero address");
        gbCollection[collectionAddress] = isCollection;
        emit SetCollectionAddress(collectionAddress, isCollection);
    }

    function setVerifyRole(address verifyRoleAddress) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require (verifyRoleAddress != address(0), "verifyRole address must not be zero address");
        _grantRole(VERIFY_ROLE, verifyRoleAddress);
        emit SetVerifyRole(verifyRoleAddress);
    }

    function setAdminWallet(address adminWallet_) external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require (adminWallet_ != address(0), "adminWallet address must not be zero address");
        adminWallet = adminWallet_;
        emit SetAdminWallet(adminWallet_);
    }

    function addItem(
        address collection,
        uint256 tokenId,
        uint256 quantity,
        uint96 royalty,
        string memory tokenURI,
        uint256 deadline,
        bytes memory signature
    ) external nonReentrant whenNotPaused {
        require(collection != address(0), "GBMarketplace: collection address must not be zero address");
        require(gbCollection[collection], "GBMarketplace: Invalid collection address");
        require(quantity == 1, "GBMarketplace: Quantity must be 1");
        require(block.timestamp <= deadline, "GBMarketplace: Signature expired");
        uint256 validNonce = nonces[_msgSender()];
        require(
            _verify(
                VERIFY_ROLE,
                _hashAddItem(
                    _msgSender(),
                    collection,
                    tokenId,
                    quantity,
                    royalty,
                    tokenURI,
                    deadline,
                    validNonce
                ), 
                signature
            ), 
        "Invalid signature");
        
        IGBCollection(collection).mintToken(
            _msgSender(),
            tokenId,
            quantity,
            royalty,
            tokenURI
        );
        
        unchecked {
            ++ nonces[_msgSender()];
        }
        emit AddItem(collection, _msgSender(), tokenId, quantity, tokenURI, block.timestamp);
    }

    function buyItem(
        address collection,
        address seller,
        uint256 tokenId,
        uint256 quantity,
        uint256 totalPrice,
        uint256 itemPrice,
        address charityAddress,
        uint256 deadline,
        bytes memory signature
    ) external payable nonReentrant whenNotPaused {
        require(collection != address(0), "GBMarketplace: collection address must not be zero address");
        require(seller.code.length == 0, "GBMarketplace: seller address must not be contract address");
        require(totalPrice > 0, "GBMarketplace: Price must be greater than 0");
        require(itemPrice > 0, "GBMarketplace: NFT Price must be greater than 0");
        require(totalPrice - itemPrice >= 0, "GBMarketplace: totalPrice must be more than itemPrice");
        require(msg.value >= totalPrice, "GBMarketplace: Insufficient funds");
        require(block.timestamp <= deadline, "GBMarketplace: Signature expired");
        require(gbCollection[collection], "GBMarketplace: Invalid collection address");
        require(quantity == 1, "GBMarketplace: Quantity must be 1");
        uint256 validNonce = nonces[_msgSender()];
        require(
            _verify(
                VERIFY_ROLE,
                _hashBuyItem(
                    _msgSender(),
                    collection,
                    seller,
                    tokenId,
                    quantity,
                    totalPrice,
                    itemPrice,
                    charityAddress,
                    deadline,
                    validNonce
                ), 
                signature
            ), 
        "Invalid signature");
        (address royaltyReceiver, uint256 royaltyAmount) = IGBCollection(collection).royaltyInfo(tokenId, itemPrice);
        if (charityAddress != address(0)) { // send charity amount to charity address
            Address.sendValue(payable(charityAddress), totalPrice - itemPrice);
        }
        Address.sendValue(payable(seller), itemPrice - royaltyAmount);  // send seller amount to seller
        Address.sendValue(payable(royaltyReceiver), royaltyAmount); // send royalty amount to royalty receiver
        IERC721(collection).safeTransferFrom(
            seller,
            _msgSender(),
            tokenId
        );
        emit BuyItem(collection, _msgSender(), seller, tokenId, quantity, totalPrice, itemPrice, charityAddress, block.timestamp);
    }

    function _hashAddItem(address account, address collection, uint256 tokenId, uint256 quantity, uint96 royalty, string memory tokenURI, uint256 deadline, uint256 nonce)
    internal view returns (bytes32)
    {
        return _hashTypedDataV4(keccak256(abi.encode(
            ADDITEM_TYPEHASH,
            account,
            collection,
            tokenId,
            quantity,
            royalty,
            tokenURI,
            deadline,
            nonce
        )));
    }

    function _hashBuyItem(
        address account, 
        address collection, 
        address seller,
        uint256 tokenId, 
        uint256 quantity, 
        uint256 totalPrice,
        uint256 itemPrice,
        address charityAddress,
        uint256 deadline, 
        uint256 nonce
    )
    internal view returns (bytes32)
    {
        return _hashTypedDataV4(keccak256(abi.encode(
            BUYITEM_TYPEHASH,
            account,
            collection,
            seller,
            tokenId,
            quantity,
            totalPrice,
            itemPrice,
            charityAddress,
            deadline,
            nonce
        )));
    }

    function _verify(bytes32 role, bytes32 digest, bytes memory signature)
    internal view returns (bool)
    {
        return hasRole(role, ECDSA.recover(digest, signature));
    }

    function pause() public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}