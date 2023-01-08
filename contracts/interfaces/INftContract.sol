// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface INftContract {
  function isApprovedForAll(address account, address operator) external view returns (bool);
}