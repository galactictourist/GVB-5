// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract GBPrimaryCollection is ERC721A, ERC2981, Ownable {

  event MintedNFT(address mintAddress, uint256 tokenId);
  event SetBaseURI(string baseURI);

  string private baseURI;
  uint256 private constant TOTAL_SUPPLY = 10000;

  constructor(
    string memory name_, 
    string memory symbol_,
    address owner_
  ) ERC721A(name_, symbol_) {
    _transferOwnership(owner_);
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721A, ERC2981) returns (bool) {
    return super.supportsInterface(interfaceId);
  }
  
  function setBaseURI(string calldata uri) external onlyOwner {
    baseURI = uri;
    emit SetBaseURI(uri);
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

  function getBaseURI() external view returns (string memory) {
    return baseURI;
  }

  function mint(
    uint256 quantity,
    uint96 royaltyFee
  ) external onlyOwner {
    require(royaltyFee <= 10000, "RoyaltyFee must not be greater than 100%");
    uint256 totalSupply = totalSupply();
    require(totalSupply <= 10000, "Cannot mint more than 10000 NFTs");
    // _setDefaultRoyalty(msg.sender, royaltyFee); 
    _mint(msg.sender, quantity);
  }
}