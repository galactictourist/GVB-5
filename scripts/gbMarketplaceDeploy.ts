import { ethers } from 'hardhat'
import { save } from "./utils"

import * as dotenv from "dotenv";
dotenv.config();

async function main() {
    const ownerAddres = String(process.env.OWNER_ADDRESS!);
    const adminWalletAddress = String(process.env.ADMIN_WALLET_ADDRESS!);

    const factory = await ethers.getContractFactory("GBMarketplace");
    const contract = await factory.deploy(
        ownerAddres,
        adminWalletAddress
    );
    await contract.deployed();
    console.log("GBMarketplace deployed to:", contract.address);
    await save('GBMarketplace', {
        address: contract.address
    });
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});