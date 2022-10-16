
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "hardhat/console.sol";

contract CertDao {

    address public owner;
    string public constant CERTDAO_DOMAIN = "www.certdao.org";

    enum domainStatus {
        pending,
        expired,
        tempApproval,
        approved,
        rejected
    }

    struct domainOwnerInfo {
        string domainName;
        address ownerAddress;
        domainStatus status;
    }

    mapping(address => domainOwnerInfo) contractAddressTodomainOwner;

    constructor() {
        owner = msg.sender;
        domainOwnerInfo memory certDaoOwner = domainOwnerInfo(CERTDAO_DOMAIN, owner, domainStatus.approved);
        // Assign the deployment address of the certdao contract as the owner of the certdao domain.
        contractAddressTodomainOwner[address(this)] = certDaoOwner;
    }

    function compareStrings(string memory a, string memory b) public pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function verify(string memory domainName , address contractAddress) view public returns (bool) {
        console.log("Inputs: %s, %s", domainName, contractAddress);

        require(bytes(domainName).length != 0, "Domain name is empty");
        require(contractAddress != address(0), "Contract address is empty");

        domainOwnerInfo memory domainOwner = contractAddressTodomainOwner[contractAddress];

        // TODO: Add other conditions (is the domain expired, is the domain approved, etc.)
        if(compareStrings(domainOwner.domainName, domainName) && domainOwner.status == domainStatus.approved) {
            console.log("Domain name and contract address match");
            return true;
        } else {
            console.log("Domain name and contract address do not match");
            return false;
        }

    }

    function renew() public {}

    function revoke() public {}

    function transferOwnership() public {}

}
