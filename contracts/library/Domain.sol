// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library Domain {

  bytes32 constant public ADD_SINGLE_ITEM_TYPEHASH = 
    keccak256(
      "AddSingleItem(address account,address collection,uint256 tokenId,uint96 royaltyFee,string tokenURI,address charityAddress,uint96 charityFee,uint256 deadline,uint256 nonce)"
    );

  bytes32 constant public BUY_ITEM_TYPEHASH = 
    keccak256(
      "BuyItem(address account,address collection,address seller,uint256 tokenId,uint256 itemPrice,uint256 additionalPrice,uint256 deadline,uint256 nonce)"
    );

  bytes32 constant public UPDATE_CHARITY_TYPEHASH = 
    keccak256(
      "UpdateCharity(address account,address collection,uint256 tokenId,address charityAddress,uint96 charityFee,uint256 deadline,uint256 nonce)"
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
    address charityAddress;
    uint96 charityFee;
    uint256 deadline;
  }

  struct BuyItem {
    address account;
    address collection;
    address seller;
    uint256 tokenId;
    uint256 itemPrice;
    uint256 additionalPrice;
    uint256 deadline;
  }

  struct UpdateCharity {
    address account;
    address collection;
    uint256 tokenId;
    address charityAddress;
    uint96 charityFee;
    uint256 deadline;
  }

  struct UpdateTokenURI {
    address account;
    address collection;
    uint256 tokenId;
    string tokenURI;
    uint256 deadline;
  }

  function _hashAddSingleItem(AddSingleItem calldata addSingleItem, uint256 nonce)
    internal 
    pure returns (bytes32)
  {
    return keccak256(
      abi.encode(
        ADD_SINGLE_ITEM_TYPEHASH,
        addSingleItem.account,
        addSingleItem.collection,
        addSingleItem.tokenId,
        addSingleItem.royaltyFee,
        addSingleItem.tokenURI,
        addSingleItem.charityAddress,
        addSingleItem.charityFee,
        addSingleItem.deadline,
        nonce
      )
    );
  }

  function _hashBuyItem(BuyItem calldata buyItem, uint256 nonce)
    internal 
    pure returns (bytes32)
  {
    return keccak256(
      abi.encode(
        BUY_ITEM_TYPEHASH,
        buyItem.account,
        buyItem.collection,
        buyItem.seller,
        buyItem.tokenId,
        buyItem.itemPrice,
        buyItem.additionalPrice,
        buyItem.deadline,
        nonce
      )
    );
  }

  function _hashUpdateCharity(UpdateCharity calldata updateCharity, uint256 nonce)
    internal 
    pure returns (bytes32)
  {
    return keccak256(
      abi.encode(
        UPDATE_CHARITY_TYPEHASH,
        updateCharity.account,
        updateCharity.collection,
        updateCharity.tokenId,
        updateCharity.charityAddress,
        updateCharity.charityFee,
        updateCharity.deadline,
        nonce
      )
    );
  }

  function _hashUpdateTokenURI(UpdateTokenURI calldata updateTokenURI, uint256 nonce)
    internal 
    pure returns (bytes32)
  {
    return keccak256(
      abi.encode(
        UPDATE_TOKENURI_TYPEHASH,
        updateTokenURI.account,
        updateTokenURI.collection,
        updateTokenURI.tokenId,
        updateTokenURI.tokenURI,
        updateTokenURI.deadline,
        nonce
      )
    );
  }
  
}