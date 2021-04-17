require("truffle-test-utils").init();

const Marketplace = artifacts.require("Marketplace");

contract("Marketplace", (accounts) => {
  const [bob] = accounts;

  it("should mint new zTokens through the marketplace", async () => {
    const instance = await Marketplace.deployed();

    await instance.createPairAndAddLiquidity(
      "0xdf9093c19f12a7355fe9fda4bf8636ae6733188e",
      { from: bob, value: 5000000 }
    );
  });
});
