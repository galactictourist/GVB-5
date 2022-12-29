import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumberish, Contract } from 'ethers';
import { parseUnits } from 'ethers/lib/utils'
import { ethers } from 'hardhat';
import * as uuid from "uuid";
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
const ORDER_ITEM_DATA_TYPE = {
  OrderItem: [
    { name: "nftContract", type: "address" },
    { name: "seller", type: "address" },
    { name: "isMinted", type: "bool" },
    { name: "tokenId", type: "uint256" },
    { name: "tokenURI", type: "string" },
    { name: "quantity", type: "uint256" },
    { name: "itemAmount", type: "uint256" },
    { name: "charityAddress", type: "address" },
    { name: "charityShare", type: "uint96" },
    { name: "royaltyFee", type: "uint96" },
    { name: "deadline", type: "uint256" },
    { name: "salt", type: "uint256" }
  ],
};

export type OrderItemData = {
  nftContract: BigNumberish,
  seller: BigNumberish,
  isMinted: Boolean,
  tokenId: BigNumberish,
  tokenURI: BigNumberish,
  quantity: BigNumberish,
  itemAmount: BigNumberish,
  charityAddress: BigNumberish,
  charityShare: BigNumberish,
  royaltyFee: BigNumberish,
  deadline: BigNumberish,
  salt: BigNumberish
};

export type OrderData = {
  orderItem: OrderItemData,
  additionalAmount: BigNumberish,
  signature: BigNumberish
}

export async function signOrderItemData(
  orderItemData: Object,
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
    ORDER_ITEM_DATA_TYPE,
    orderItemData
  );
}

export function generateSalt() {
  const uuidValue = uuid.v4();
  const salt = BigNumber.from(ethers.utils.keccak256(uuid.parse(uuidValue)));
  return salt;
}