// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library Domain {

  bytes32 constant public ADD_SINGLE_ITEM_TYPEHASH = 
    keccak256(
      "AddSingleItem(address account,address collection,uint256 tokenId,uint96 royaltyFee,string tokenURI,uint256 deadline,uint256 nonce)"
    );

  bytes32 constant public BUY_ITEM_TYPEHASH = 
    keccak256(
      "BuyItem(address account,address collection,address seller,uint256 tokenId,uint256 itemPrice,uint256 additionalPrice,address charityAddress,uint96 charityFee,uint256 deadline,uint256 nonce)"
    );

  bytes32 constant public UPDATE_TOKENURI_TYPEHASH = 
    keccak256(
      "UpdateTokenURI(address account,address collection,uint256 tokenId,string tokenURI,uint256 deadline,uint256 nonce)"
    );

  struct AddSingleItem {
    address account;
    address collection;
    uint256 tokenId;
    uint96 royaltyFee;
    string tokenURI;
    uint256 deadline;
    uint256 nonce;
  }

  struct BuyItem {
    address account;
    address collection;
    address seller;
    uint256 tokenId;
    uint256 itemPrice;  // listed price
    uint256 additionalPrice;  // additional price for charity
    address charityAddress;
    uint96 charityFee;
    uint256 deadline;
    uint256 nonce;
  }

  struct UpdateTokenURI {
    address account;
    address collection;
    uint256 tokenId;
    string tokenURI;
    uint256 deadline;
    uint256 nonce;
  }
  
  function _hashAddSingleItem(AddSingleItem calldata item, uint256 nonce)
    internal 
    pure returns (bytes32)
  {
    return keccak256(
      abi.encode(
        ADD_SINGLE_ITEM_TYPEHASH,
        item.account,
        item.collection,
        item.tokenId,
        item.royaltyFee,
        keccak256(bytes(item.tokenURI)),
        item.deadline,
        nonce
      )
    );
  }

  function _hashBuyItem(BuyItem calldata item, uint256 nonce)
    internal 
    pure returns (bytes32)
  {
    return keccak256(
      abi.encode(
        BUY_ITEM_TYPEHASH,
        item.account,
        item.collection,
        item.seller,
        item.tokenId,
        item.itemPrice,
        item.additionalPrice,
        item.charityAddress,
        item.charityFee,
        item.deadline,
        nonce
      )
    );
  }

  function _hashUpdateTokenURI(UpdateTokenURI calldata item, uint256 nonce)
    internal 
    pure returns (bytes32)
  {
    return keccak256(
      abi.encode(
        UPDATE_TOKENURI_TYPEHASH,
        item.account,
        item.collection,
        item.tokenId,
        item.tokenURI,
        item.deadline,
        nonce
      )
    );
  }
  
}