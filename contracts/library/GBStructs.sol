// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ItemType } from "./GBEnums.sol";

struct OrderItem {
  address nftContract;
  address seller;
  bool isMinted;
  uint256 tokenId;
  string tokenURI;
  uint256 quantity;
  uint256 itemPrice;  // listed price
  uint256 additionalPrice;  // additional price for charity
  address charityAddress;
  uint96 charityFee;
  uint96 royaltyFee;
  uint256 deadline;   // expiry time of listed NFT
}

struct Order {
  OrderItem orderItem;
  bytes signature;
}