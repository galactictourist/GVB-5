// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ItemType } from "./GBEnums.sol";

struct OrderItem {
  address nftContract;
  uint256 itemType;
  address seller;
  address artist;
  bool isMinted;
  uint256 tokenId;
  string tokenURI;
  uint256 quantity;
  uint256 itemPrice;  // listed price
  address charityAddress;
  uint96 charityShare;
  uint96 royaltyFee;
  uint256 deadline;   // expiry time of listed NFT
  uint256 salt;
}

struct Order {
  OrderItem orderItem;
  uint256 additionalAmount;
  bytes signature;
}