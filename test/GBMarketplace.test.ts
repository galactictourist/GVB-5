import { expect } from 'chai';
import { ethers, network } from 'hardhat';
const hre = require("hardhat");
import { parseUnits, formatUnits, parseEther } from "ethers/lib/utils";
import { GBCollection, GBMarketplace, Domain } from "../typechain-types";
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

import {
  SingleItemData,
  getBigNumber,
  getTimeStamp,
  signSingleItemData,
} from './utils'
import { BigNumber, Contract, Signer } from 'ethers';

describe('Test marketplace functions', () => {
  let gbMarketplace: GBMarketplace
  let gBCollection: GBCollection
  let oldOwner: SignerWithAddress
  let owner: SignerWithAddress
  let verifier: SignerWithAddress
  let alice: SignerWithAddress
  let bob: SignerWithAddress
  let carol: SignerWithAddress
  let adminWallet: SignerWithAddress
  let ownerAddress: string
  let verifierAddress: string
  let adminWalletAddress: string
  let aliceAddress: string
  let bobAddress: string
  let carolAddress: string

  let backendNonce = 0;
  let tokenId = 1;
  let royaltyFee = getBigNumber('0.2', 2);
  let tokenURI = "https://bafybeicea5ajmz7gcw25qwkungxrn3ayalwt5igdawviquztks3d7c77y4.ipfs.nftstorage.link/995.json";
  let singleItemData: SingleItemData;
  before(async () => {
    [
      owner,
      verifier,
      oldOwner,
      adminWallet,
      alice,
      bob,
      carol
    ] = await ethers.getSigners()
    ownerAddress = await owner.getAddress()
    verifierAddress = await verifier.getAddress()
    adminWalletAddress = await adminWallet.getAddress()
    aliceAddress = await alice.getAddress()
    bobAddress = await bob.getAddress()
    carolAddress = await carol.getAddress()
    console.log('===================Deploying Contract=====================')

    const contractFactory1 = await ethers.getContractFactory("GBMarketplace")
    gbMarketplace = (await contractFactory1.connect(oldOwner).deploy(
      ownerAddress,
      verifierAddress,
      adminWalletAddress
    )) as GBMarketplace
    await gbMarketplace.deployed()
    console.log('GBMarketplace deployed: ', gbMarketplace.address)

    const contractFactory2 = await ethers.getContractFactory("GBCollection")
    gBCollection = (await contractFactory2.deploy(
      "Givabit Collection",
      "GBC",
      gbMarketplace.address
    )) as GBCollection
    await gBCollection.deployed()
    console.log('GBCollection deployed: ', gBCollection.address)

    let deadline = await getTimeStamp();
    deadline = deadline + 10 * 60;

    singleItemData = {
      account: bobAddress,
      collection: gBCollection.address,
      tokenId,
      royaltyFee,
      tokenURI,
      deadline,
      nonce: backendNonce
    };
  })

  describe('Test: AccessControl', async () => {
    it('Require owner role', async () => {
      await expect(
        gbMarketplace
        .connect(oldOwner)
        .setGBCollectionAddress(gBCollection.address, true)
      ).to.be.reverted;
    })
  })
  
  describe('Test: setGBCollectionAddress', async () => {
    it('gbCollection address must not be zero address', async () => {
      await expect(
        gbMarketplace
        .connect(owner)
        .setGBCollectionAddress(ethers.constants.AddressZero, true)
      ).to.be.revertedWith('gbCollection address must not be zero address');
    })

    it('PASS', async () => {
      await expect(
        gbMarketplace
        .connect(owner)
        .setGBCollectionAddress(gBCollection.address, true)
      ).to.emit(gbMarketplace, 'SetCollectionAddress')
      .withArgs(gBCollection.address, true);
    })
  })

  describe('Test: addSingleItem', async () => {
    it('PASS!', async () => {
      const signature = await signSingleItemData(
        singleItemData, 
        gbMarketplace, 
        verifier
      );
      await expect(
        gbMarketplace
        .connect(bob)
        .addSingleItem(singleItemData, signature)
      ).to.emit(gbMarketplace, 'AddedSingleItem')
      .withArgs(
        singleItemData.collection,
        singleItemData.account,
        singleItemData.tokenId,
        singleItemData.tokenURI,
        singleItemData.royaltyFee
      );
    })
  })
});
