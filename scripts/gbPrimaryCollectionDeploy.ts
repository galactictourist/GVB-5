import { ethers } from 'hardhat'
import { load, save } from "./utils"

import * as dotenv from "dotenv";
dotenv.config();

async function main() {
    const ownerAddres = String(process.env.OWNER_ADDRESS!);

    const factory = await ethers.getContractFactory("GBPrimaryCollection");
    const contract = await factory.deploy(
        "Givabit Primary Collection",
        "GPC",
        ownerAddres
    );
    await contract.deployed();
    console.log("GBPrimaryCollection deployed to:", contract.address);
    await save('GBPrimaryCollection', {
        address: contract.address
    });
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});