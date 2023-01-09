// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import {
  OrderItem, 
  Order
} from "./GBStructs.sol";

library Domain {

  bytes32 constant public ORDER_ITEM_TYPEHASH = 
    keccak256(
      "OrderItem(address nftContract,uint256 itemType,address seller,bool isMinted,uint256 tokenId,string tokenURI,uint256 quantity,uint256 itemPrice,address charityAddress,uint96 charityShare,uint96 royaltyFee,uint256 deadline,uint256 salt)"
    );

  function _hashOrderItem(OrderItem memory item)
    internal 
    pure returns (bytes32)
  {
    return keccak256(
      abi.encode(
        ORDER_ITEM_TYPEHASH,
        item.nftContract,
        item.itemType,
        item.seller,
        item.isMinted,
        item.tokenId,
        keccak256(bytes(item.tokenURI)),
        item.quantity,
        item.itemPrice,
        item.charityAddress,
        item.charityShare,
        item.royaltyFee,
        item.deadline,
        item.salt
      )
    );
  }

}