import { ethers } from "hardhat";
import "@nomiclabs/hardhat-ethers";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("default signer:", deployer.address);
  console.log("default signer balance:", (await deployer.getBalance()).toString());

  const PermissionedOracleAdapter = await ethers.getContractFactory("PermissionedOracleAdapter");
  const oracleAdapter = await PermissionedOracleAdapter.deploy();

  await oracleAdapter.deployed();
  console.log(`permissioned oracleAdapter contract deployed to ${oracleAdapter.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
