
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "hardhat/console.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

contract CertDao is Ownable {

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

    // Validation Event
    event ContractSubmittedForValidation(address indexed contractAddress, string domainName);
    // Approval Event
    event ContractApproved(address indexed contractAddress, string domainName, domainStatus status);
    // Renewal Event
    event ContractRenewed(address indexed contractAddress, string domainName, domainStatus status);
    // Rejection Event
    event ContractRejected(address indexed contractAddress, string domainName, string description);
    // Manual Flag Event
    event ContractManuallyFlag(address indexed contractAddress, string domainName, string description);
    // Revocation Event
    event ContractRevoked(address indexed contractAddress, string domainName, string description);
    // Expiration Event
    event ContractExpired(address indexed contractAddress, string domainName, string description);

    constructor() {
        domainOwnerInfo memory certDaoOwner = domainOwnerInfo(CERTDAO_DOMAIN, owner(), domainStatus.approved, block.timestamp + 36525 days, "CertDao Owner genisis");
        // Assign the deployment address of the certdao contract as the owner of the certdaeo domain.
        contractAddressTodomainOwner[address(this)] = certDaoOwner;
    }

    function compareStrings(string memory a, string memory b) public pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function getDomainOwner(address contractAddress) public view returns (address) {
        return contractAddressTodomainOwner[contractAddress].ownerAddress;
    }

    function domainStatusToString(domainStatus status) public pure returns (string memory) {
        if (status == domainStatus.pending) {
            return "pending";
        } else if (status == domainStatus.expired) {
            return "expired";
        } else if (status == domainStatus.approved) {
            return "approved";
        } else if (status == domainStatus.rejected) {
            return "rejected";
        } else if (status == domainStatus.revoked) {
            return "revoked";
        } else if (status == domainStatus.manualFlag) {
            return "manualFlag";
        } else {
            return "unknown";
        }
    }

    function getDomainStatus(address contractAddress) public view returns (string memory) {
        require(contractAddress != address(0), "Contract address is empty");
        domainStatus status = contractAddressTodomainOwner[contractAddress].status;
        return domainStatusToString(status);
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
        (bool sent, bytes memory data) = owner().call{value: msg.value}("");
        require(sent, "Failed to send Ether!");

        // Add the domain name to the struct
        domainOwnerInfo memory domainOwner = domainOwnerInfo(domainName, msg.sender, domainStatus.pending, block.timestamp, "");
        contractAddressTodomainOwner[contractAddress] = domainOwner;
        emit ContractSubmittedForValidation(contractAddress, domainName);
    }

    function verify(string memory domainName , address contractAddress) view public returns (bool) {
        console.log("Inputs: %s, %s", domainName, contractAddress);

        requireNotEmptyDomainAndContract(domainName, contractAddress);

        domainOwnerInfo memory domainOwner = contractAddressTodomainOwner[contractAddress];

        if(compareStrings(domainOwner.domainName, domainName) && domainOwner.status == domainStatus.approved) {
            if(domainOwner.timestamp + EXPIRATION_PERIOD > block.timestamp) {
                console.log("Contract is verified");
                return true;
            }
            else {
                console.log("Domain name and contract address match but domain is expired");
                return false;
            }
        } else {
            console.log("Domain name and contract address do not match or contract is not approved. Check contract state");
            return false;
        }

    }

    function updateOwner(address contractAddress, string memory newDomainOwner) public payable {
        requireNotEmptyDomainAndContract(newDomainOwner, contractAddress);
        require(msg.value == PAY_AMOUNT, "Please send 0.05 ether to start updateOwner process.");
    }

    function transferContractToNewDomain(address newContractAddress, string memory domainOwner) public payable {
        requireNotEmptyDomainAndContract(domainOwner, newContractAddress);
        require(msg.sender == contractAddressTodomainOwner[newContractAddress].ownerAddress, "You are not the owner of the contract to transfer domains.");
        require(contractAddressTodomainOwner[newContractAddress].status == domainStatus.approved, "Contract is not approved.");
        require(msg.value == PAY_AMOUNT, "Please send 0.05 ether to start transferContract process.");
    }

    function renew(address contractAddress) public payable {
        requireNotEmptyDomainAndContract(contractAddressTodomainOwner[contractAddress].domainName, contractAddress);
        require(msg.sender == contractAddressTodomainOwner[contractAddress].ownerAddress, "Only the owner of the contract can renew the domain mapping.");
        if(contractAddressTodomainOwner[contractAddress].status == domainStatus.approved) {
            require(msg.value == PAY_AMOUNT, "Please send 0.05 ether to renew the domain.");
            (bool sent, bytes memory data) = owner().call{value: msg.value}("");
            require(sent, "Failed to send Ether!");
            contractAddressTodomainOwner[contractAddress].timestamp = block.timestamp;
            emit ContractApproved(contractAddress, contractAddressTodomainOwner[contractAddress].domainName, domainStatus.approved);
        }
    }

    function manualFlag() public onlyOwner {}

    function revoke(address contractAddress) public onlyOwner {
         requireNotEmptyDomainAndContract(contractAddressTodomainOwner[contractAddress].domainName, contractAddress);
        if(contractAddressTodomainOwner[contractAddress].status != domainStatus.revoked) {
            contractAddressTodomainOwner[contractAddress].status = domainStatus.revoked;
            emit ContractRevoked(contractAddress, contractAddressTodomainOwner[contractAddress].domainName, "Contract revoked by DAO");
        }
    }

    function approve(address contractAddress) public onlyOwner {
        requireNotEmptyDomainAndContract(contractAddressTodomainOwner[contractAddress].domainName, contractAddress);
        if(contractAddressTodomainOwner[contractAddress].status != domainStatus.approved) {
            contractAddressTodomainOwner[contractAddress].status = domainStatus.approved;
            emit ContractApproved(contractAddress, contractAddressTodomainOwner[contractAddress].domainName, domainStatus.approved);
        }
    }

    function batchApprove(address[] memory contractAddresses) public onlyOwner {
        for(uint i = 0; i < contractAddresses.length; i++) {
            approve(contractAddresses[i]);
        }
    }

    function batchRevoke(address[] memory contractAddresses) public onlyOwner {
        for(uint i = 0; i < contractAddresses.length; i++) {
            revoke(contractAddresses[i]);
        }
    }

    // TODO: Is this necessary?


}
