import { expect } from 'chai';
import { ethers, network } from 'hardhat';
const hre = require("hardhat");
import * as helpers from "@nomicfoundation/hardhat-network-helpers";
import { parseUnits, formatUnits, parseEther } from "ethers/lib/utils";
import { GB721Contract, GBMarketplace, Domain, GBPrimaryCollection } from "../typechain-types";
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  OrderItemData,
  getBigNumber,
  signOrderItemData,
  generateSalt,
  OrderData,
} from './utils'
import { BigNumber, Contract, Signer } from 'ethers';

describe('Test marketplace functions', () => {
  let gbMarketplace: GBMarketplace
  let gB721Contract: GB721Contract
  let gbPrimaryCollection: GBPrimaryCollection
  let oldOwner: SignerWithAddress
  let owner: SignerWithAddress
  let alice: SignerWithAddress
  let bob: SignerWithAddress
  let carol: SignerWithAddress
  let adminWallet: SignerWithAddress
  let ownerAddress: string
  let adminWalletAddress: string
  let aliceAddress: string
  let bobAddress: string
  let carolAddress: string

  let backendNonce = 0;
  let tokenId = 1;
  let royaltyFee = getBigNumber('0.2', 2);
  let tokenURI = "https://bafybeicea5ajmz7gcw25qwkungxrn3ayalwt5igdawviquztks3d7c77y4.ipfs.nftstorage.link/";
  let singleItemData: OrderItemData;

  let ordersData: OrderData[];
  let totalPrice: BigNumber = getBigNumber(0);
  before(async () => {
    [
      owner,
      oldOwner,
      adminWallet,
      alice,
      bob,
      carol
    ] = await ethers.getSigners()
    ownerAddress = await owner.getAddress()
    adminWalletAddress = await adminWallet.getAddress()
    aliceAddress = await alice.getAddress()
    bobAddress = await bob.getAddress()
    carolAddress = await carol.getAddress()
    console.log('===================Deploying Contract=====================')

    const contractFactory1 = await ethers.getContractFactory("GBMarketplace")
    gbMarketplace = (await contractFactory1.connect(oldOwner).deploy(
      ownerAddress,
      adminWalletAddress
    )) as GBMarketplace
    await gbMarketplace.deployed()
    console.log('GBMarketplace deployed: ', gbMarketplace.address)

    const contractFactory2 = await ethers.getContractFactory("GB721Contract")
    gB721Contract = (await contractFactory2.deploy(
      "Givabit Collection",
      "GBC",
      gbMarketplace.address
    )) as GB721Contract
    await gB721Contract.deployed()
    console.log('GB721Contract deployed: ', gB721Contract.address)

    const contractFactory3 = await ethers.getContractFactory('GBPrimaryCollection')
    gbPrimaryCollection = (await contractFactory3.connect(oldOwner).deploy(
      "GB Primary Collection",
      "GPC",
      aliceAddress
    )) as GBPrimaryCollection
    await gbPrimaryCollection.deployed()
    console.log('GBPrimaryCollection contract deployed: ', gbPrimaryCollection.address)

    const currentTimestamp = await helpers.time.latest();
    ordersData = [
      {
        orderItem: {
          nftContract: gbPrimaryCollection.address,
          seller: owner.address,
          isMinted: true,
          tokenId: 0,
          tokenURI: tokenURI,
          quantity: 1,
          itemAmount: getBigNumber('0.01'),
          charityAddress: carolAddress,
          charityShare: getBigNumber('15', 2),
          royaltyFee: 0,
          deadline: currentTimestamp + 10 * 60,
          salt: generateSalt()
        },
        additionalAmount: 0,
        signature: ''
      },
      {
        orderItem: {
          nftContract: gbPrimaryCollection.address,
          seller: owner.address,
          isMinted: true,
          tokenId: 9998,
          tokenURI: tokenURI,
          quantity: 1,
          itemAmount: getBigNumber('0.02'),
          charityAddress: carolAddress,
          charityShare: getBigNumber('20', 2),
          royaltyFee: 0,
          deadline: currentTimestamp + 10 * 60,
          salt: generateSalt()
        },
        additionalAmount: getBigNumber('0.05'),
        signature: ''
      },
      {
        orderItem: {
          nftContract: gbPrimaryCollection.address,
          seller: owner.address,
          isMinted: true,
          tokenId: 9999,
          tokenURI: tokenURI,
          quantity: 1,
          itemAmount: getBigNumber('0.02'),
          charityAddress: bobAddress,
          charityShare: getBigNumber('20', 2),
          royaltyFee: 0,
          deadline: currentTimestamp + 10 * 60,
          salt: generateSalt()
        },
        additionalAmount: getBigNumber('0.1'),
        signature: ''
      },
    ]

    // when list nfts, generate signature using alice account
    for (const order of ordersData) {
      const signature = await signOrderItemData(
        order.orderItem,
        gbMarketplace,
        alice
      );
      order.signature = signature;
      const price = BigNumber.from(order.orderItem.itemAmount).add(order.additionalAmount);
      totalPrice = totalPrice.add(price);
    }

    console.log("total price: ", formatUnits(totalPrice));
  })

  describe('Test AccessControl', async () => {
    it('Require owner role', async () => {
      await expect(
        gbMarketplace
        .connect(oldOwner)
        .setNftContractAddress(gB721Contract.address, true)
      ).to.be.reverted;
    })
  })
  
  describe('SetNftContractAddress', async () => {
    it('gbCollection address must not be zero address', async () => {
      await expect(
        gbMarketplace
        .connect(owner)
        .setNftContractAddress(ethers.constants.AddressZero, true)
      ).to.be.revertedWith('NftContract address must not be zero address');
    })

    it('PASS', async () => {
      await expect(
        gbMarketplace
        .connect(owner)
        .setNftContractAddress(gB721Contract.address, true)
      ).to.emit(gbMarketplace, 'SetNftContractAddress')
      .withArgs(gB721Contract.address, true);
    })
  })

  describe('Alice mint PrimaryCollection NFTs', async () => {
    it('Only Alice can mint nfts', async () => {
      await expect(
        gbPrimaryCollection
        .connect(owner)
        .mint(10000)
      ).to.be.reverted;
    })

    it('Set BaseURI', async () => {
      await expect(
        gbPrimaryCollection
        .connect(alice)
        .setBaseURI(tokenURI)
      ).to.emit(gbPrimaryCollection, 'SetBaseURI')
      .withArgs(tokenURI);
    })
    it('Mint NFT', async () => {
      await expect(
        gbPrimaryCollection
        .connect(alice)
        .mint(10000)
      ).to.be.not.reverted;
    })
  })

  describe('Cancel listed nfts', async () => {
    it('List nfts', async () => {
      await expect(
        gbMarketplace.cancelOrders([
          ordersData[1].orderItem
        ])
      )
    })
  })

  describe('Buy items', async () => {
    it('PASS!', async () => {
      const tx = await gbMarketplace
      .connect(bob)
      .buyItems(ordersData, {value: totalPrice});
      // const receipt = await tx.wait();
      // console.log(receipt);
    })
  })
});
