// This is a script for deploying your contracts. You can adapt it to deploy
// yours, or create new ones.

const path = require("path");

async function main() {
  // This is just a convenience check
  if (network.name === "hardhat") {
    console.warn(
      "You are trying to deploy a contract to the Hardhat Network, which" +
        "gets automatically created and destroyed every time. Use the Hardhat" +
        " option '--network localhost'"
    );
  }

  // ethers is available in the global scope
  const [deployer] = await ethers.getSigners();
  console.log(
    "Deploying the contracts with the account:",
    await deployer.getAddress()
  );

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const certdao = await ethers.getContractFactory("CertDao");
  const certdaoDeployed = await certdao.deploy();
  await certdaoDeployed.deployed();

  console.log("Certdao address:", certdaoDeployed.address);

  // We also save the contract's artifacts and address in the frontend directory
  saveFrontendFiles(certdao);
}

function saveFrontendFiles(certdao) {
  const fs = require("fs");
  const contractsDir = path.join(
    __dirname,
    "../../",
    "certDAO-frontend",
    "src",
    "data"
  );

  if (!fs.existsSync(contractsDir)) {
    fs.mkdirSync(contractsDir);
  }

  fs.writeFileSync(
    path.join(contractsDir, "contract-address.json"),
    JSON.stringify({ certdao: certdao.address }, undefined, 2)
  );

  const certdaoArtifact = artifacts.readArtifactSync("CertDao");

  fs.writeFileSync(
    path.join(contractsDir, "certdao.json"),
    JSON.stringify(certdaoArtifact, null, 2)
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
