const { expect } = require("chai");

const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

describe("main certdao contract", function () {
  async function deployTokenFixture() {
    // Get the ContractFactory and Signers here.
    const certDaoContract = await ethers.getContractFactory("CertDao");
    const [owner, addr1, addr2] = await ethers.getSigners();

    // To deploy our contract, we just have to call Token.deploy() and await
    // for it to be deployed(), which happens onces its transaction has been
    // mined.
    const certdao = await certDaoContract.deploy();

    await certdao.deployed();

    // Fixtures can return anything you consider useful for your tests
    return { certDaoContract, certdao, owner, addr1, addr2 };
  }

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { certdao, owner } = await loadFixture(deployTokenFixture);
      expect(await certdao.owner()).to.equal(owner.address);
    });

    it("Should return true if certdao is registered", async function () {
      const { certdao } = await loadFixture(deployTokenFixture);
      expect(await certdao.verify("www.certdao.org", certdao.address)).to.equal(
        true
      );
    });
  });
});
