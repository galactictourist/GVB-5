// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import {
  OrderItem, 
  Order
} from "./GBStructs.sol";

library Domain {

  bytes32 constant public ORDER_ITEM_TYPEHASH = 
    keccak256(
      "OrderItem(address nftContract,address seller,bool isMinted,uint256 tokenId,string tokenURI, uint256 quantity,uint256 itemPrice,uint256 additionalPrice,address charityAddress,uint96 charityFee,uint96 royaltyFee,uint256 deadline)"
    );

  function _hashOrderItem(OrderItem memory item)
    internal 
    pure returns (bytes32)
  {
    return keccak256(
      abi.encode(
        ORDER_ITEM_TYPEHASH,
        item.nftContract,
        item.seller,
        item.isMinted,
        item.tokenId,
        keccak256(bytes(item.tokenURI)),
        item.quantity,
        item.itemPrice,
        item.additionalPrice,
        item.charityAddress,
        item.charityFee,
        item.royaltyFee,
        item.deadline
      )
    );
  }

}