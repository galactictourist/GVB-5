import { ethers } from 'hardhat'
import { load, save } from "./utils"

import * as dotenv from "dotenv";
dotenv.config();

async function main() {
    const marketplaceAddress = (await load('GBMarketplace')).address;

    const factory = await ethers.getContractFactory("GBCollection");
    const contract = await factory.deploy(
        "Givabit Collection",
        "GBC",
        marketplaceAddress
    );
    await contract.deployed();
    console.log("GBCollection deployed to:", contract.address);
    await save('GBCollection', {
        address: contract.address
    });
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});