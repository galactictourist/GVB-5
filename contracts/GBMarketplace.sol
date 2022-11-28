// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./interfaces/IGBCollection.sol";
import "./library/Domain.sol";

contract GBMarketplace is AccessControl, EIP712, ReentrancyGuard, Pausable {

  event AddedSingleItem(
    address collection,
    address from,
    uint256 tokenId,
    string tokenURI,
    uint96 royaltyFee,
    address charityAddress,
    uint96 charityFee,
    uint256 timestamp
  );
  
  event AddedMultiplePrimaryItems(
    address collection,
    address from,
    uint256[] tokenIds,
    string[] tokenURIs,
    uint96 royaltyFee,
    address charityAddress,
    uint96 charityFee,
    address artistAddress,
    uint256 timestamp
  );

  event BoughtItem(
    address collection,
    address buyer,
    address seller,
    uint256 tokenId,
    uint256 itemPrice,
    uint256 additionalPrice,
    uint256 timestamp
  );

  event UpdatedCharity(
    address collection,
    address from,
    uint256 tokenId,
    address charityAddress,
    uint96 charityFee,
    uint256 timestamp
  );
  
  event UpdatedItemMetaData(
    address collection,
    address from,
    uint256 tokenId,
    string tokenURI,
    uint256 timestamp
  );

  event UpdatedTokenURI(
    address collection,
    address from,
    uint256 tokenId,
    string tokenURI,
    uint256 timestamp
  );

  event SetCollectionAddress(address collectionAddress, bool status);
  event SetVerifyRole(address verifyRoleAddress);
  event SetAdminWallet(address account);
  event SetPlatformFee(uint96 platformFee);

  struct ItemInfo {
    address charityAddress;
    uint96 charityFee;   // 2 decimals
    address royaltyAddress;
    uint96 royaltyFee;   // 2 decimals
    bool isPrimaryCollection;
  }

  mapping(address => bool) public gbCollection;
  mapping(address => uint256) public nonces;
  mapping(address => mapping(uint256 => ItemInfo)) public itemInfo;   // collection => tokenId => ItemInfo

  bytes32 public constant VERIFY_ROLE = keccak256("VERIFY_ROLE");

  address private adminWallet;
  uint96 public platformFee = 250;   // 2.5% platform fee

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

  function setPlatformFee(uint96 platformFee_) external onlyRole(DEFAULT_ADMIN_ROLE)
  {
    require (platformFee_ > 0, "platformFee must be greater than zero");
    platformFee = platformFee_;
    emit SetPlatformFee(platformFee_);
  }

  function addSingleItem(
    Domain.AddSingleItem calldata item,
    bytes memory signature
  ) external nonReentrant whenNotPaused {
    require(item.collection != address(0), "GBMarketplace: collection address must not be zero address");
    require(item.tokenId > 0, "GBMarketplace: tokenId must be greater than zero");
    require(item.charityAddress != address(0), "GBMarketplace: charity address must not be zero address");
    require(
      item.charityFee >= 1000 && item.charityFee <= 10000, 
      "GBMarketplace: charity percentage must be between 10% and 100%"
    );
    require(item.charityFee + platformFee + item.royaltyFee <= 10000, "GBMarketplace: total fee must be less than 100%");
    require(gbCollection[item.collection], "GBMarketplace: Invalid collection address");
    require(block.timestamp <= item.deadline, "GBMarketplace: Signature expired");
    uint256 validNonce = nonces[_msgSender()];
    require(
      _verify(
        _hashTypedDataV4(Domain._hashAddSingleItem(item, validNonce)),
        signature
      ), 
      "Invalid signature"
    );
    
    itemInfo[item.collection][item.tokenId] = ItemInfo(
      item.charityAddress, 
      item.charityFee, 
      _msgSender(), 
      item.royaltyFee, 
      false
    );
    
    unchecked {
      ++ nonces[_msgSender()];
    }

    // mint token to nft creator
    IGBCollection(item.collection).mintToken(
      _msgSender(),
      item.tokenId,
      item.royaltyFee,
      item.tokenURI
    );
    emit AddedSingleItem(item.collection, _msgSender(), item.tokenId, item.tokenURI, item.royaltyFee, item.charityAddress, item.charityFee, block.timestamp);
  }

  function addPrimaryMultipleItems(
    address collection,
    uint256[] calldata tokenIds,
    uint96 royaltyFee,
    string[] calldata tokenURIs,
    address charityAddress,
    uint96 charityFee,
    address artistAddress
  ) external nonReentrant whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) {
    require(collection != address(0), "GBMarketplace: collection address must not be zero address");
    require(tokenIds.length == tokenURIs.length, "GBMarketplace: tokenIds and tokenURIs length must be equal");
    require(charityAddress != address(0), "GBMarketplace: charity address must not be zero address");
    require(
      charityFee >= 1000 && charityFee <= 10000, 
      "GBMarketplace: charity percentage must be between 10% and 100%"
    );
    require(charityFee + platformFee + royaltyFee <= 10000, "GBMarketplace: total fee must be less than 100%");
    require(gbCollection[collection], "GBMarketplace: Invalid collection address");
    
    for (uint256 i = 0; i < tokenIds.length; _unsafe_inc(i)) {
      require(tokenIds[i] > 0, "GBMarketplace: tokenId must be greater than zero");
      itemInfo[collection][tokenIds[i]] = ItemInfo(
        charityAddress, 
        charityFee, 
        artistAddress, 
        royaltyFee, 
        true
      );
      IGBCollection(collection).mintToken(
        artistAddress,
        tokenIds[i],
        royaltyFee,
        tokenURIs[i]
      );
      emit AddedSingleItem(collection, artistAddress, tokenIds[i], tokenURIs[i], royaltyFee, charityAddress, charityFee, block.timestamp);
    }
    
    emit AddedMultiplePrimaryItems(collection, _msgSender(), tokenIds, tokenURIs, royaltyFee, charityAddress, charityFee, artistAddress, block.timestamp);
  }

  function buyItem(
    Domain.BuyItem calldata item,
    bytes memory signature
  ) external payable nonReentrant whenNotPaused {
    require(item.collection != address(0), "GBMarketplace: collection address must not be zero address");
    require(item.seller.code.length == 0, "GBMarketplace: seller address must not be contract address");
    require(item.itemPrice > 0, "GBMarketplace: NFT Price must be greater than 0");
    require(msg.value >= item.itemPrice + item.additionalPrice, "GBMarketplace: Insufficient funds");
    require(block.timestamp <= item.deadline, "GBMarketplace: Signature expired");
    require(gbCollection[item.collection], "GBMarketplace: Invalid collection address");
    uint256 validNonce = nonces[_msgSender()];
    require(
      _verify(
        _hashTypedDataV4(Domain._hashBuyItem(item, validNonce)),
        signature
      ), 
      "Invalid signature"
    );

    uint256 charityAmount = 0;
    ItemInfo memory nftItemInfo = itemInfo[item.collection][item.tokenId];
    if (nftItemInfo.charityAddress != address(0) && nftItemInfo.charityFee > 0) { // send charity amount to charity address
      charityAmount = _calcFeeAmount(item.itemPrice, nftItemInfo.charityFee);
      Address.sendValue(payable(nftItemInfo.charityAddress), charityAmount + item.additionalPrice);
    }

    (address royaltyReceiver, uint256 royaltyAmount) = IGBCollection(item.collection).royaltyInfo(item.tokenId, item.itemPrice);
    Address.sendValue(payable(royaltyReceiver), royaltyAmount); // send royalty amount to royalty receiver

    uint256 platformAmount = _calcFeeAmount(item.itemPrice, platformFee);
    Address.sendValue(payable(adminWallet), platformAmount);  // send platformFee to adminWallet

    uint256 sellerAmount = item.itemPrice - charityAmount - royaltyAmount - platformAmount;
    if (sellerAmount > 0) {
      if (nftItemInfo.isPrimaryCollection) {  // check if nft is primary collection
        uint256 artistAmount = sellerAmount / 2;
        Address.sendValue(payable(item.seller), artistAmount);
        Address.sendValue(payable(adminWallet), sellerAmount - artistAmount);
      } else {
        Address.sendValue(payable(item.seller), sellerAmount); // send rest amount to seller
      }
    }

    unchecked {
      ++ nonces[_msgSender()];
    }

    // transfer NFT from seller to buyer
    IERC721(item.collection).safeTransferFrom(
        item.seller,
        _msgSender(),
        item.tokenId
    );
    emit BoughtItem(item.collection, _msgSender(), item.seller, item.tokenId, item.itemPrice, item.additionalPrice, block.timestamp);
  }

  function updateCharity(
    Domain.UpdateCharity calldata charityInfo,
    bytes memory signature
  ) external whenNotPaused {
    require(charityInfo.collection != address(0), "GBMarketplace: collection address must not be zero address");
    require(charityInfo.tokenId > 0, "GBMarketplace: tokenId must be greater than zero");
    require(charityInfo.charityAddress != address(0), "GBMarketplace: charity address must not be zero address");
    require(
      charityInfo.charityFee >= 1000 && charityInfo.charityFee <= 10000, 
      "GBMarketplace: charity percentage must be between 10% and 100%"
    );
    ItemInfo storage nftItemInfo = itemInfo[charityInfo.collection][charityInfo.tokenId];
    require(charityInfo.charityFee + platformFee + nftItemInfo.royaltyFee <= 10000, "GBMarketplace: total fee must be less than 100%");
    require(gbCollection[charityInfo.collection], "GBMarketplace: Invalid collection address");
    require(block.timestamp <= charityInfo.deadline, "GBMarketplace: Signature expired");
    uint256 validNonce = nonces[_msgSender()];
    require(
      _verify(
        _hashTypedDataV4(Domain._hashUpdateCharity(charityInfo, validNonce)),
        signature
      ), 
      "Invalid signature"
    );
    require(
      IGBCollection(charityInfo.collection).ownerOf(charityInfo.tokenId) == _msgSender(), 
      "GBMarketplace: Only NFT owner can update charity info"
    );
    nftItemInfo.charityAddress = charityInfo.charityAddress;
    nftItemInfo.charityFee = charityInfo.charityFee;
    
    unchecked {
      ++ nonces[_msgSender()];
    }
    emit UpdatedCharity(charityInfo.collection, _msgSender(), charityInfo.tokenId, charityInfo.charityAddress, charityInfo.charityFee, block.timestamp);
  }

  function updateTokenURI(
    Domain.UpdateTokenURI calldata tokenUriInfo,
    bytes memory signature
  ) external nonReentrant whenNotPaused {
    require(tokenUriInfo.collection != address(0), "GBMarketplace: collection address must not be zero address");
    require(tokenUriInfo.tokenId > 0, "GBMarketplace: tokenId must be greater than zero");
    require(gbCollection[tokenUriInfo.collection], "GBMarketplace: Invalid collection address");
    require(block.timestamp <= tokenUriInfo.deadline, "GBMarketplace: Signature expired");
    uint256 validNonce = nonces[_msgSender()];
    require(
      _verify(
        _hashTypedDataV4(Domain._hashUpdateTokenURI(tokenUriInfo, validNonce)),
        signature
      ), 
      "Invalid signature"
    );
    require(
      IGBCollection(tokenUriInfo.collection).ownerOf(tokenUriInfo.tokenId) == _msgSender(), 
      "GBMarketplace: Only NFT owner can update charity info"
    );
    
    unchecked {
      ++ nonces[_msgSender()];
    }
    IGBCollection(tokenUriInfo.collection).setTokenURI(tokenUriInfo.tokenId, tokenUriInfo.tokenURI);
    
    emit UpdatedTokenURI(tokenUriInfo.collection, _msgSender(), tokenUriInfo.tokenId, tokenUriInfo.tokenURI, block.timestamp);
  }

  function _calcFeeAmount(uint256 amount, uint96 fee) internal pure returns (uint256) {
    unchecked { return amount * fee / 10000; }
  }

  function _unsafe_inc(uint256 i) internal pure returns (uint256) {
    unchecked {
      return ++ i;
    }
  }

  function _verify(bytes32 digest, bytes memory signature)
  internal view returns (bool)
  {
      return hasRole(VERIFY_ROLE, ECDSA.recover(digest, signature));
  }

  function pause() public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
      _pause();
  }

  function unpause() public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
      _unpause();
  }
}