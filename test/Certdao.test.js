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
      expect(await certdao.verify(certdao.address, "certdao.net")).to.equal(
        true
      );
    });
  });

  describe("Test main certdao functionality", function () {
    it("Should not succeed if no funds sent", async function () {
      const { certdao } = await loadFixture(deployTokenFixture);
      await expect(
        certdao.submitForValidation(certdao.address, "certdao.net", "", {
          value: 0,
        })
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
          certdao.address,
          "certdao.net",
          "",
          payableParams
        )
      ).to.be.revertedWith(
        "Contract address already has a domain registered in the struct."
      );
    });

    it("Should not succeed if contract already registered", async function () {
      const { certdao, addr1 } = await loadFixture(deployTokenFixture);

      const payableParams = {
        value: ethers.utils.parseEther("0.05"),
      };

      await expect(
        certdao.submitForValidation(
          certdao.address,
          "certdao.net",
          "",
          payableParams
        )
      ).to.be.revertedWith(
        "Contract address already has a domain registered in the struct."
      );
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
      expect(
        await certdao
          .connect(addr2)
          .submitForValidation(
            testContract.address,
            domainToTest,
            "",
            payableParams
          )
      ).to.emit(certdao, "DomainSubmittedForValidation");

      expect(owner).to.changeEtherBalance(ethers.utils.parseEther("0.05"));

      // Approve the contract
      expect(
        await certdao.connect(owner).approve(testContract.address)
      ).to.emit(certdao, "ContractApproved");

      // Check that the domain and contract are registered and approved in the struct
      expect(await certdao.verify(testContract.address, domainToTest)).to.equal(
        true
      );

      // Get the owner of the domain
      expect(await certdao.getDomainOwner(testContract.address)).to.equal(
        addr2.address
      );

      // Check that the status is approved
      expect(await certdao.getDomainStatus(testContract.address)).to.equal(
        "approved"
      );
    });

    it("Test various forms of expiration", async function () {
      const { certdao, addr1, owner } = await loadFixture(deployTokenFixture);
      // Deploy a second contract to test the validation process
      const { certdao: testContract, addr2 } = await deployTokenFixture();

      const payableParams = {
        value: ethers.utils.parseEther("0.05"),
      };

      const domainToTest = "www.testsite.com";

      // Submit for validation
      expect(
        await certdao
          .connect(addr2)
          .submitForValidation(
            testContract.address,
            domainToTest,
            "",
            payableParams
          )
      ).to.emit(certdao, "DomainSubmittedForValidation");

      expect(owner).to.changeEtherBalance(ethers.utils.parseEther("0.05"));

      // Approve the contract
      expect(
        await certdao.connect(owner).approve(testContract.address)
      ).to.emit(certdao, "ContractApproved");

      expect(await certdao.getDomainStatus(testContract.address)).to.equal(
        "approved"
      );

      expect(await certdao.verify(testContract.address, domainToTest)).to.equal(
        true
      );

      // Increase time by 1.5 years
      await time.increase(time.duration.years(1.5));

      // Check that the status is expired
      expect(await certdao.getDomainStatus(testContract.address)).to.equal(
        "expired"
      );

      expect(await certdao.verify(testContract.address, domainToTest)).to.equal(
        false
      );

      // renew the domain
      expect(
        await certdao
          .connect(addr2)
          .renew(testContract.address, domainToTest, payableParams)
      ).to.emit(certdao, "ContractRenewed");

      expect(await certdao.getDomainStatus(testContract.address)).to.equal(
        "approved"
      );

      expect(await certdao.verify(testContract.address, domainToTest)).to.equal(
        true
      );

      // revoke by owner
      expect(await certdao.connect(owner).revoke(testContract.address)).to.emit(
        certdao,
        "ContractRevoked"
      );

      expect(await certdao.getDomainStatus(testContract.address)).to.equal(
        "revoked"
      );

      expect(await certdao.verify(testContract.address, domainToTest)).to.equal(
        false
      );
    });
  });
});
