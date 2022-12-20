// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract GB721Contract is ERC721URIStorage, ERC2981, AccessControl, ReentrancyGuard {

  bytes32 public constant MARKETPLACE_ROLE = keccak256("MARKETPLACE_ROLE");

  constructor(
    string memory name_, 
    string memory symbol_,
    address marketplace_
  ) ERC721(name_, symbol_) {
    _setupRole(MARKETPLACE_ROLE, marketplace_);
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC2981, AccessControl) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  function setTokenURI(uint256 tokenId, string memory tokenURI_) external onlyRole(MARKETPLACE_ROLE)
  {
    require(_exists(tokenId), "GB721Contract: This token is not minted");
    _setTokenURI(tokenId, tokenURI_);
  }

  function setMarketplaceAddress(address _marketplaceAddress) external onlyRole(MARKETPLACE_ROLE)
  {
    require(_marketplaceAddress != address(0), "marketplace address must not be zero address");
    _grantRole(MARKETPLACE_ROLE, _marketplaceAddress);
  }

  function mintToken(
    address account,
    uint256 tokenId,
    uint96 royalty,
    string memory tokenURI_
  ) external onlyRole(MARKETPLACE_ROLE) nonReentrant {
    require(
      !_exists(tokenId),
      "GB721Contract: This token is already minted"
    );

    _mint(account, tokenId);
    _setTokenURI(tokenId, tokenURI_);

    _setTokenRoyalty(tokenId, account, royalty);

    // set approve for marketplace
    _setApprovalForAll(account, _msgSender(), true);
  }

}