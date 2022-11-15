// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IGBCollection {
    function setTokenURI(uint256 tokenId, string memory tokenURI_) external ; 
    function setMarketplaceAddress(address _marketplaceAddress) external ;
    function mintToken(
        address account,
        uint256 tokenId,
        uint256 supply,
        uint96 royalty,
        string memory tokenURI_
    ) external ;
}