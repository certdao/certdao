
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "hardhat/console.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

contract CertDao {

    address public owner;
    string public constant CERTDAO_DOMAIN = "www.certdao.net";
    uint32 public constant EXPIRATION_PERIOD = 365 days;
    uint64 public constant PAY_AMOUNT = 0.05 ether;

    enum domainStatus {
        pending,
        expired,
        approved,
        rejected,
        revoked,
        manualFlag
    }

    struct domainOwnerInfo {
        string domainName;
        address ownerAddress;
        domainStatus status;
        uint256 timestamp;
        string description;
    }

    mapping(address => domainOwnerInfo) contractAddressTodomainOwner;

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    // Add events
    // Validation Event
    // Approval Event
    // Rejection Event
    // Manual Flag Event

    constructor() {
        owner = msg.sender;
        domainOwnerInfo memory certDaoOwner = domainOwnerInfo(CERTDAO_DOMAIN, owner, domainStatus.approved, block.timestamp + 36525 days, "CertDao Owner genisis");
        // Assign the deployment address of the certdao contract as the owner of the certdaeo domain.
        contractAddressTodomainOwner[address(this)] = certDaoOwner;
    }

    function compareStrings(string memory a, string memory b) public pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function getDomainOwner(address contractAddress) public view returns (address) {
        return contractAddressTodomainOwner[contractAddress].ownerAddress;
    }

    function getDomainStatus(address contractAddress) public view returns (string memory) {
        require(contractAddress != address(0), "Contract address is empty");
        domainStatus status = contractAddressTodomainOwner[contractAddress].status;

        if (status == domainStatus.pending) {
            return "pending";
        }
        if (status == domainStatus.expired) {
            return "expired";
        }
        if(status == domainStatus.approved) {
            return "approved";
        }
        if(status == domainStatus.rejected) {
            return "rejected";
        }
        if(status == domainStatus.revoked) {
            return "revoked";
        }
        if(status == domainStatus.manualFlag) {
            return "manualFlag";
        }

        return "unknown";

    }

    function getDomainName(address contractAddress) public view returns (string memory) {
        require(contractAddress != address(0), "Contract address is empty");
        return contractAddressTodomainOwner[contractAddress].domainName;
    }

    function requireNotEmptyDomainAndContract(string memory domainName, address contractAddress) private pure {
        require(bytes(domainName).length != 0, "Domain name is empty");
        require(contractAddress != address(0), "Contract address is empty");
    }

    function submitForValidation(string memory domainName, address contractAddress) public payable {

        console.log("Domain Name: %s, Contract: %s", domainName, contractAddress);
        requireNotEmptyDomainAndContract(domainName, contractAddress);

        require(msg.value == PAY_AMOUNT, "Please send 0.05 ether to start the validation process.");

        require(compareStrings(contractAddressTodomainOwner[contractAddress].domainName, ""), "Domain name already registered in struct.");

        // Send 0.05 ether to the owner of the contract
        (bool sent, bytes memory data) = owner.call{value: msg.value}("");
        require(sent, "Failed to send Ether!");

        // Add the domain name to the struct
        domainOwnerInfo memory domainOwner = domainOwnerInfo(domainName, msg.sender, domainStatus.pending, block.timestamp, "");
        contractAddressTodomainOwner[contractAddress] = domainOwner;

    }

    function verify(string memory domainName , address contractAddress) view public returns (bool) {
        console.log("Inputs: %s, %s", domainName, contractAddress);

        requireNotEmptyDomainAndContract(domainName, contractAddress);

        domainOwnerInfo memory domainOwner = contractAddressTodomainOwner[contractAddress];

        if(compareStrings(domainOwner.domainName, domainName) && domainOwner.status == domainStatus.approved) {
            // TODO: Add other conditions (is the domain expired, is the domain approved, etc.)
            if(domainOwner.timestamp + EXPIRATION_PERIOD > block.timestamp) {
                console.log("Contract is verified");
                return true;
            }
            else {
                console.log("Domain name and contract address match but domain is expired");
                domainOwner.status = domainStatus.expired;
                return false;
            }
        } else {
            console.log("Domain name and contract address do not match or contract is not approved. Check contract state");
            return false;
        }

    }

    function renew() public payable {}
    function transferOwnership() public payable {}
    // function manualFlag() public onlyOwner {}

    function revoke() public onlyOwner {}
    function approve(address contractAddress) public onlyOwner {
        require(contractAddress != address(0), "Contract address is empty");
        contractAddressTodomainOwner[contractAddress].status = domainStatus.approved;
    }


    // TODO: Is this necessary?
    // function updateFields() public {}

}
