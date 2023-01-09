import { expect } from 'chai';
import { ethers, network } from 'hardhat';
const hre = require("hardhat");
import * as helpers from "@nomicfoundation/hardhat-network-helpers";
import { parseUnits, formatUnits, parseEther } from "ethers/lib/utils";
import { GB721Contract, GBMarketplace, Domain, GBPrimaryCollection, ERC721 } from "../typechain-types";
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  OrderItemData,
  getBigNumber,
  signOrderItemData,
  generateSalt,
  OrderData,
  ItemType,
} from './utils'
import { BigNumber, Contract, Signer } from 'ethers';

describe('Test marketplace functions', () => {
  let gbMarketplace: GBMarketplace
  let gB721Contract: GB721Contract
  let gbPrimaryCollection: GBPrimaryCollection
  let oldOwner: SignerWithAddress
  let marketplaceOwner: SignerWithAddress
  let alice: SignerWithAddress  // // primary collection nfts owner(seller)
  let bob: SignerWithAddress  // buyer
  let carol: SignerWithAddress  // charity
  let adminWallet: SignerWithAddress
  let marketplaceOwnerAddress: string
  let adminWalletAddress: string
  let aliceAddress: string  // primary collection nfts owner address(seller address)
  let bobAddress: string  // buyer address
  let carolAddress: string  // charity address

  let tokenURI = "https://bafybeicea5ajmz7gcw25qwkungxrn3ayalwt5igdawviquztks3d7c77y4.ipfs.nftstorage.link/";

  let ordersData: OrderData[];
  let totalPrice: BigNumber = getBigNumber(0);
  before(async () => {
    [
      marketplaceOwner,
      oldOwner,
      adminWallet,
      alice,
      bob,
      carol
    ] = await ethers.getSigners()
    marketplaceOwnerAddress = await marketplaceOwner.getAddress()
    adminWalletAddress = await adminWallet.getAddress()
    aliceAddress = await alice.getAddress()
    bobAddress = await bob.getAddress()
    carolAddress = await carol.getAddress()
    console.log('===================Deploying Contract=====================')

    const contractFactory1 = await ethers.getContractFactory("GBMarketplace")
    gbMarketplace = (await contractFactory1.connect(oldOwner).deploy(
      marketplaceOwnerAddress,
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
      { // gbPrimaryCollection nft which is minted already
        orderItem: {
          nftContract: gbPrimaryCollection.address,
          itemType: ItemType.ERC721,
          seller: aliceAddress,
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
      { // gbPrimaryCollection nft which is minted already
        orderItem: {
          nftContract: gbPrimaryCollection.address,
          itemType: ItemType.ERC721,
          seller: aliceAddress,
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
      { // gbPrimaryCollection nft which is minted already
        orderItem: {
          nftContract: gbPrimaryCollection.address,
          itemType: ItemType.ERC721,
          seller: aliceAddress,
          isMinted: true,
          tokenId: 9999,
          tokenURI: tokenURI,
          quantity: 1,
          itemAmount: getBigNumber('0.02'),
          charityAddress: carolAddress,
          charityShare: getBigNumber('20', 2),
          royaltyFee: 0,
          deadline: currentTimestamp + 10 * 60,
          salt: generateSalt()
        },
        additionalAmount: getBigNumber('0.1'),
        signature: ''
      },
      { // non-minted nft which will be minted by gb721Contract
        orderItem: {
          nftContract: gB721Contract.address,
          itemType: ItemType.ERC721,
          seller: aliceAddress,
          isMinted: false,
          tokenId: 86,
          tokenURI: tokenURI,
          quantity: 1,
          itemAmount: getBigNumber('0.03'),
          charityAddress: carolAddress,
          charityShare: getBigNumber('50', 2),
          royaltyFee: getBigNumber('20', 2),
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
      // console.log(order);
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
        .connect(marketplaceOwner)
        .setNftContractAddress(ethers.constants.AddressZero, true)
      ).to.be.revertedWith('NftContract address must not be zero address');
    })

    it('PASS', async () => {
      await expect(
        gbMarketplace
        .connect(marketplaceOwner)
        .setNftContractAddress(gB721Contract.address, true)
      ).to.emit(gbMarketplace, 'SetNftContractAddress')
      .withArgs(gB721Contract.address, true);
    })
  })

  describe('Alice mint PrimaryCollection NFTs', async () => {
    it('Only Alice can mint nfts', async () => {
      await expect(
        gbPrimaryCollection
        .connect(marketplaceOwner)
        .mint(aliceAddress, 10000)
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
        .mint(aliceAddress, 10000)
      ).to.be.not.reverted;
    })
    
    it('Alice approves NFTs to marketplace contract', async () => {
      await expect(
        gbPrimaryCollection
        .connect(alice)
        .setApprovalForAll(gbMarketplace.address, true)
      ).to.emit(gbPrimaryCollection, 'ApprovalForAll')
      .withArgs(aliceAddress, gbMarketplace.address, true);
    })
  })

  describe('Cancel listed nfts', async () => {
    it('Cannot cancel listed order unless nft owner', async () => {
      await expect(
        gbMarketplace
        .callStatic
        .cancelOrders([ordersData[1].orderItem])
      ).to.be.not.reverted;
      const cancelTx = await gbMarketplace.cancelOrders([ordersData[1].orderItem]);
      const receipt = await cancelTx.wait();
      const cancelledEvent = receipt.events[0];
      expect(cancelledEvent).to.not.undefined;
      expect(cancelledEvent["args"]["cancelResults"][0])
      .to.equal(false);
      expect(cancelledEvent["args"]["cancelStatus"][0])
      .to.equal("GBMarketplace: Invalid order canceller.");
    })
    it('Cancel listed order', async () => {
      await expect(
        gbMarketplace
        .connect(alice)
        .callStatic
        .cancelOrders([ordersData[1].orderItem])
      ).to.be.not.reverted;
      const cancelTx = await gbMarketplace
      .connect(alice)
      .cancelOrders([ordersData[1].orderItem]);
      const receipt = await cancelTx.wait();
      const cancelledEvent = receipt.events[0];
      expect(cancelledEvent).to.not.undefined;
      expect(cancelledEvent["args"]["cancelResults"][0])
      .to.equal(true);
      expect(cancelledEvent["args"]["cancelStatus"][0])
      .to.equal("GBMarketplace: Cancelled order.");
    })
  })

  describe('Buy items', async () => {
    it('Not enough tokens', async() => {
      await expect(
        gbMarketplace
        .connect(bob)
        .callStatic
        .buyItems(ordersData, {value: getBigNumber(0.1)})
      ).to.be.not.reverted;

      const tx = await gbMarketplace
      .connect(bob)
      .buyItems(ordersData, {value: getBigNumber(0.1)});
      const receipt = await tx.wait();

      const events = receipt.events;
      expect(events).to.not.undefined;

      for(const event of events) {
        if (!event.hasOwnProperty("args")) {
          continue;
        }
        console.log(JSON.stringify(event.args.ordersResult, null, 2));
        console.log(JSON.stringify(event.args.ordersStatus, null, 2));
        console.log(JSON.stringify(event.args.ordersHash, null, 2));
      }
    })

    it('PASS!', async () => {
      console.log("Admin wallet balance before sale: ", formatUnits(await adminWallet.getBalance()));
      console.log("Carol wallet balance before sale: ", formatUnits(await carol.getBalance()));
      await expect(
        gbMarketplace
        .connect(bob)
        .callStatic
        .buyItems(ordersData, {value: totalPrice})
      ).to.be.not.reverted;

      const tx = await gbMarketplace
      .connect(bob)
      .buyItems(ordersData, {value: totalPrice});
      const receipt = await tx.wait();

      const events = receipt.events;
      expect(events).to.not.undefined;

      for(const event of events) {
        if (!event.hasOwnProperty("args")) {
          continue;
        }
        // console.log(JSON.stringify(event, null, 2))
        console.log(JSON.stringify(event.args.ordersResult, null, 2));
        console.log(JSON.stringify(event.args.ordersStatus, null, 2));
        console.log(JSON.stringify(event.args.ordersHash, null, 2));
      }

      expect(await gbPrimaryCollection.balanceOf(aliceAddress)).to.equal(9998);
      expect(await gbPrimaryCollection.balanceOf(bobAddress)).to.equal(2);
      expect(await gB721Contract.balanceOf(bobAddress)).to.equal(1);

      console.log("Admin wallet balance after sale: ", formatUnits(await adminWallet.getBalance()));
      console.log("Carol wallet balance after sale: ", formatUnits(await carol.getBalance()));
    })
  })
});
