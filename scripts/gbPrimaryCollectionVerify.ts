import hre from "hardhat";
import { ethers } from 'hardhat'
import { load } from "./utils"

import * as dotenv from "dotenv";
dotenv.config();

async function main() {
    const ownerAddres = String(process.env.OWNER_ADDRESS!);
    
    const contractAddress = (await load('GBPrimaryCollection')).address
    console.log(contractAddress)
    await hre.run("verify:verify", {
        address: contractAddress,
        constructorArguments: [
            "TestNaga",
            "TNG",
            ownerAddres
        ],
    });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});