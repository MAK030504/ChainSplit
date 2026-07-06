import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying ExpenseSplit with account:", deployer.address);

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Account balance:", ethers.formatEther(balance), "AVAX");

  const Factory = await ethers.getContractFactory("ExpenseSplit");
  const contract = await Factory.deploy();
  await contract.waitForDeployment();

  const address = await contract.getAddress();
  console.log("ExpenseSplit deployed to:", address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
