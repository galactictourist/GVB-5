import hre from "hardhat";
import { ethers } from 'hardhat'
import { load } from "./utils"

import * as dotenv from "dotenv";
dotenv.config();

async function main() {
    const ownerAddres = String(process.env.OWNER_ADDRESS!);
    const verifyRoleAddress = String(process.env.VERIFY_ROLE_ADDRESS!);
    const adminWalletAddress = String(process.env.ADMIN_WALLET_ADDRESS!);

    const contractAddress = (await load('GBMarketplace')).address
    console.log(contractAddress)
    await hre.run("verify:verify", {
        address: contractAddress,
        constructorArguments: [
            ownerAddres,
            verifyRoleAddress,
            adminWalletAddress
        ],
    });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});