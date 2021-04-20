const Marketplace = artifacts.require("Marketplace");
const NFT = artifacts.require("NFT");

module.exports = async (deployer) => {
  await deployer.deploy(NFT);

  const nft = await NFT.deployed();
  const factory = "0x6725F303b657a9451d8BA641348b6761A6CC7a17";
  const router = "0xD99D1c33F9fC3444f8101754aBC46c52416550D1";
  const wbnb = "0xD99D1c33F9fC3444f8101754aBC46c52416550D1";

  await deployer.deploy(Marketplace, factory, router, wbnb, nft.address);
};
