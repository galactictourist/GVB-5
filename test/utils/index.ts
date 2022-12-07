import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumberish, Contract } from 'ethers';
import { parseUnits } from 'ethers/lib/utils'
import { ethers } from 'hardhat';
const { BigNumber } = require('ethers')

export enum TOKEN_DECIMAL {
  MYTOKEN = 18,
  DEFAULT = ''
}

export enum TOKEN_NAME {
  MYTOKEN = 'MYTOKEN',
  DEFAULT = ''
}

// Defaults to e18 using amount * 10^18
export function getBigNumber(amount:number | string, decimals = 18) {
  return parseUnits(amount.toString(), decimals);
}

const GB_MARKETPLACE_CONTRACT_NAME = "GBMarketplace";
const GB_MARKETPLACE_VERSION = "1.0.0";
const ADD_SINGLE_ITEM_DATA_TYPE = {
  AddSingleItem: [
    { name: "account", type: "address" },
    { name: "collection", type: "address" },
    { name: "tokenId", type: "uint256" },
    { name: "royaltyFee", type: "uint96" },
    { name: "tokenURI", type: "string" },
    { name: "deadline", type: "uint256" },
    { name: "nonce", type: "uint256" }
  ],
};

export type SingleItemData = {
  account: string,
  collection: string,
  tokenId: BigNumberish,
  royaltyFee: BigNumberish,
  tokenURI: string,
  deadline: BigNumberish,
  nonce: BigNumberish
};

export async function signSingleItemData(
  singleItemData: Object,
  gbMarketplaceContract: Contract,
  signer: SignerWithAddress
): Promise<string> {
  const domain = {
    name: GB_MARKETPLACE_CONTRACT_NAME,
    version: GB_MARKETPLACE_VERSION,
    chainId: await signer.getChainId(),
    verifyingContract: gbMarketplaceContract.address,
  };
  return await signer._signTypedData(
    domain,
    ADD_SINGLE_ITEM_DATA_TYPE,
    singleItemData
  );
}

export * from './time';