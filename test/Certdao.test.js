const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

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
      expect(await certdao.verify("www.certdao.net", certdao.address)).to.equal(
        true
      );
    });
  });

  describe("Test main certdao functionality", function () {
    it("Should not succeed if no funds sent", async function () {
      const { certdao } = await loadFixture(deployTokenFixture);
      await expect(
        certdao.submitForValidation("www.certdao.net", certdao.address)
      ).to.be.revertedWith(
        "Please send 0.05 ether to start the validation process."
      );
    });

    it("Should not succeed if contract already registered", async function () {
      const { certdao, addr1 } = await loadFixture(deployTokenFixture);

      const payableParams = {
        value: ethers.utils.parseEther("0.05"),
      };

      await expect(
        certdao.submitForValidation(
          "www.certdao.net",
          certdao.address,
          payableParams
        )
      ).to.be.revertedWith("Domain name already registered in struct.");
    });

    it("Should not succeed if contract already registered", async function () {
      const { certdao, addr1 } = await loadFixture(deployTokenFixture);

      const payableParams = {
        value: ethers.utils.parseEther("0.05"),
      };

      await expect(
        certdao.submitForValidation(
          "www.certdao.net",
          certdao.address,
          payableParams
        )
      ).to.be.revertedWith("Domain name already registered in struct.");
    });

    it("Fully validation should succeed.", async function () {
      const { certdao, addr1, owner } = await loadFixture(deployTokenFixture);

      // Deploy a second contract to test the validation process
      const { certdao: testContract, addr2 } = await deployTokenFixture();

      const payableParams = {
        from: addr2.address,
        value: ethers.utils.parseEther("0.05"),
      };

      const domainToTest = "www.testsite.com";

      // Submit for validation
      await certdao
        .connect(addr2)
        .submitForValidation(domainToTest, testContract.address, payableParams);

      // Approve the contract
      await certdao.connect(owner).approve(testContract.address);

      // Check that the domain and contract are registered and approved in the struct
      expect(await certdao.verify(domainToTest, testContract.address)).to.equal(
        true
      );

      // Get the owner of the domain
      expect(await certdao.getDomainOwner(testContract.address)).to.equal(
        addr2.address
      );

      // Check that the status is pending
      expect(await certdao.getDomainStatus(testContract.address)).to.equal(
        "approved"
      );
    });
  });
});
