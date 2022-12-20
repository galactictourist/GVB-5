// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "./interfaces/IGB721Contract.sol";
import {
  OrderItem, 
  Order
} from "./library/GBStructs.sol";
import "./library/Domain.sol";

contract GBMarketplace is AccessControl, EIP712, ReentrancyGuard, Pausable {

  event BoughtItem(
    OrderItem item,
    bytes32 orderHash
  );

  event UpdatedTokenURI(
    address nftContract,
    address owner,
    uint256 tokenId,
    string tokenURI
  );

  event SetNftContractAddress(address nftContract, bool status);
  event SetAdminWallet(address account);
  event SetPlatformFee(uint96 platformFee);
  event OrderCancelled(bytes32 orderHash, address account);

  bytes4 private constant InterfaceId_ERC721 = 0x80ac58cd;
  bytes4 private constant InterfaceId_ERC1155 = 0xd9b67a26;

  mapping(address => bool) public gbNftContracts;
  mapping(bytes32 => bool) public orderCancelled;  // orderHash => isCancelled

  address private adminWallet;
  uint96 public platformFee = 250;   // 2.5% platform fee

  constructor(
    address owner,
    address adminWallet_
  ) EIP712("GBMarketplace", "1.0.0") {
    adminWallet = adminWallet_;
    _setupRole(DEFAULT_ADMIN_ROLE, owner);
  }

  modifier contractCheck(address contractAddress) {
    require(
      IERC721(contractAddress).supportsInterface(InterfaceId_ERC721) || 
      IERC1155(contractAddress).supportsInterface(InterfaceId_ERC1155),
      "GBMarketplace: This is not ERC721/ERC1155 contract"
    );
    _;
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  function setNftContractAddress(address nftContractAddress, bool isEnabled) external onlyRole(DEFAULT_ADMIN_ROLE)
  {
    require (nftContractAddress != address(0), "NftContract address must not be zero address");
    gbNftContracts[nftContractAddress] = isEnabled;
    emit SetNftContractAddress(nftContractAddress, isEnabled);
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

  function buyItems(
    Order[] calldata orders
  ) external payable nonReentrant whenNotPaused returns(bool[] memory ordersResult, string[] memory ordersStatus, bytes32[] memory ordersHash) {
    uint256 totalValue = msg.value;
    uint256 orderLength = orders.length;
    ordersResult = new bool[](orderLength);
    ordersStatus = new string[](orderLength);
    ordersHash = new bytes32[](orderLength);
    for (uint256 i; i < orderLength; _unsafe_inc(i)) {
      Order memory order = orders[i];
      OrderItem memory orderItem = order.orderItem;
      bytes memory orderSignature = order.signature;
      (ordersResult[i], ordersStatus[i], ordersHash[i]) = _checkOrder(orderItem, orderSignature, totalValue);
      if (!ordersResult[i]) {
        continue;
      }
      
      uint256 charityAmount = 0;
      charityAmount = _calcFeeAmount(orderItem.itemPrice, orderItem.charityFee);
      Address.sendValue(payable(orderItem.charityAddress), charityAmount + orderItem.additionalPrice);  // send charity amount

      uint256 platformAmount = _calcFeeAmount(orderItem.itemPrice, platformFee);
      Address.sendValue(payable(adminWallet), platformAmount);  // send platformFee to adminWallet

      address royaltyReceiver;
      uint256 royaltyAmount;
      if (gbNftContracts[orderItem.nftContract]) {
        if (!orderItem.isMinted) {
          // mint token to nft creator
          if (IERC721(orderItem.nftContract).supportsInterface(InterfaceId_ERC721)) {
            IGB721Contract(orderItem.nftContract).mintToken(
              orderItem.seller,
              orderItem.tokenId,
              orderItem.royaltyFee,
              orderItem.tokenURI
            );
          }
        }
        (royaltyReceiver, royaltyAmount) = IERC2981(orderItem.nftContract)
          .royaltyInfo(
            orderItem.tokenId, 
            orderItem.itemPrice
          );
        Address.sendValue(payable(royaltyReceiver), royaltyAmount); // send royalty amount to royalty receiver
      }
      unchecked {  
        uint256 totalFeeAmount = charityAmount + royaltyAmount + platformAmount;
        if (orderItem.itemPrice > totalFeeAmount) {
          Address.sendValue(payable(orderItem.seller), orderItem.itemPrice - totalFeeAmount); // send rest amount to seller
        }
      }

      // transfer NFT from seller to buyer
      if (IERC721(orderItem.nftContract).supportsInterface(InterfaceId_ERC721)) {
        IERC721(orderItem.nftContract).safeTransferFrom(
          orderItem.seller,
          _msgSender(),
          orderItem.tokenId
        );
      }
      emit BoughtItem(
        orderItem,
        ordersHash[i]
      );
      unchecked {
        totalValue = totalValue - orderItem.itemPrice - orderItem.additionalPrice;
      }
    }
  }

  function cancelOrders(OrderItem[] calldata orderItems) external returns(bool[] memory cancelResults, string[] memory cancelStatus) {
    uint256 orderItemsLength = orderItems.length;
    cancelResults = new bool[](orderItemsLength);
    cancelStatus = new string[](orderItemsLength);
    for(uint256 i; i < orderItems.length; _unsafe_inc(i)) {
      OrderItem calldata order = orderItems[i];
      if(msg.sender != order.seller) {
        cancelStatus[i] = "GBMarketplace: Invalid order canceller.";
      } else {
        cancelResults[i] = true;
        bytes32 orderHash = Domain._hashOrderItem(order);
        orderCancelled[orderHash] = true;
        emit OrderCancelled(orderHash, order.seller);
      }
    }
  }

  function updateTokenURI(
    address nftContract,
    uint256 tokenId,
    string memory tokenURI
  ) external nonReentrant whenNotPaused contractCheck(nftContract){
    require(nftContract != address(0), "GBMarketplace: nftContract address must not be zero address");
    require(tokenId > 0, "GBMarketplace: tokenId must be greater than zero");
    require(gbNftContracts[nftContract], "GBMarketplace: Invalid nftContract address");
    require(
      IGB721Contract(nftContract).ownerOf(tokenId) == msg.sender, 
      "GBMarketplace: is not nft owner"
    );
    
    IGB721Contract(nftContract).setTokenURI(tokenId, tokenURI);
    
    emit UpdatedTokenURI(
      nftContract, 
      msg.sender, 
      tokenId, 
      tokenURI
    );
  }

  function _checkOrder(
    OrderItem memory orderItem, 
    bytes memory orderSignature,
    uint256 totalValue
  ) internal view returns (bool checkResult, string memory checkStatus, bytes32 orderHash){
    if(orderItem.nftContract == address(0)) {
      checkStatus = "GBMarketplace: nftContract address must not be zero address";
    } else if (
      !IERC721(orderItem.nftContract).supportsInterface(InterfaceId_ERC721) &&
      !IERC1155(orderItem.nftContract).supportsInterface(InterfaceId_ERC1155)
    ) {
      checkStatus = "GBMarketplace: nftContract address must not be zero address";
    } else if (Address.isContract(orderItem.seller)) {
      checkStatus = "GBMarketplace: seller address must not be contract address";
    } else if (orderItem.charityAddress == address(0)) {
      checkStatus = "GBMarketplace: charity address must not be zero address";
    } else if(orderItem.charityFee < 1000 || orderItem.charityFee > 10000) {
      checkStatus = "GBMarketplace: charity percentage must be between 10% and 100%";
    } else if (orderItem.royaltyFee > 10000) {
      checkStatus = "GBMarketplace: royalty fee must not be greater than 100%";
    } else if (orderItem.charityFee + platformFee + orderItem.royaltyFee > 10000) {
      checkStatus = "GBMarketplace: total fee must be less than 100%";
    } else if (orderItem.itemPrice == 0) {
      checkStatus = "GBMarketplace: NFT Price must be greater than 0";
    } else if (totalValue < orderItem.itemPrice + orderItem.additionalPrice) {
      checkStatus = "GBMarketplace: Insufficient funds";
    } else if (orderItem.deadline < block.timestamp) {
      checkStatus = "GBMarketplace: Signature expired";
    } else {
      orderHash = Domain._hashOrderItem(orderItem);
      if (orderCancelled[orderHash]) {
        checkStatus = "GBMarketplace: Order is already cancelled";
      } else if (!_verify(orderItem.seller, _hashTypedDataV4(orderHash),orderSignature)) {
        checkStatus = "GBMarketplace: Invalid signature";
      } else {
        checkResult = true;
        checkStatus = "GBMarketplace: Passed";
      }
    }
  }

  function _calcFeeAmount(uint256 amount, uint96 fee) internal pure returns (uint256) {
    unchecked { return amount * fee / 10000; }
  }

  function _unsafe_inc(uint256 i) internal pure returns (uint256) {
    unchecked {
      return ++ i;
    }
  }

  function _verify(address account, bytes32 digest, bytes memory signature)
  internal pure returns (bool)
  {
    return account == ECDSA.recover(digest, signature);
  }

  function pause() public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
      _pause();
  }

  function unpause() public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
      _unpause();
  }
}