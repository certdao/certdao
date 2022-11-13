// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "hardhat/console.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ICertDao.sol";

contract CertDao is ICertDao, Ownable {
    /* ============ Constants ============ */

    string public constant CERTDAO_DOMAIN = "certdao.net";
    uint32 public constant EXPIRATION_PERIOD = 365 days;
    uint64 public constant PAY_AMOUNT = 0.05 ether;

    /* ============ Structures ============ */

    enum DomainStatus {
        pending,
        expired,
        approved,
        rejected,
        revoked,
        manualFlag
    }

    struct DomainOwnerInfo {
        string domainName;
        address ownerAddress;
        DomainStatus status;
        uint256 timestamp;
        string description;
    }

    /* ============ State ============ */

    mapping(address => address[]) public ownerToContractAddresses;
    mapping(address => DomainOwnerInfo) public contractAddressToDomainOwner;
    uint64 public totalContractAddressMappings;

    /* ============ Events ============ */

    // Validation Event
    event ContractSubmittedForValidation(
        address indexed contractAddress,
        string indexed domainName
    );
    // Approval Event
    event ContractApproved(
        address indexed contractAddress,
        string indexed domainName,
        DomainStatus status
    );
    // Renewal Event
    event ContractRenewed(
        address indexed contractAddress,
        string indexed domainName,
        DomainStatus status
    );
    // Rejection Event
    event ContractRejected(
        address indexed contractAddress,
        string indexed domainName,
        string description
    );
    // Manual Flag Event
    event ContractManuallyFlag(
        address indexed contractAddress,
        string indexed domainName,
        string description
    );
    // Revocation Event
    event ContractRevoked(
        address indexed contractAddress,
        string indexed domainName,
        string description
    );
    // Expiration Event
    event ContractExpired(
        address indexed contractAddress,
        string indexed domainName,
        string description
    );

    /* ============ Internal ============ */

    constructor() {
        DomainOwnerInfo memory certDaoOwner = DomainOwnerInfo(
            CERTDAO_DOMAIN,
            owner(),
            DomainStatus.approved,
            block.timestamp + 36525 days,
            "CertDao Owner genesis"
        );
        // Assign the deployment address of the certdao contract as the owner of the certdao domain.
        contractAddressToDomainOwner[address(this)] = certDaoOwner;
    }

    modifier precheck(address contractAddress, string memory domainName) {
        require(bytes(domainName).length != 0, "Domain name is empty");
        require(contractAddress != address(0), "Contract address is empty");
        _;
    }

    /* ============ External Functions ============ */

    function submitForValidation(
        address contractAddress,
        string memory domainName,
        string memory description
    ) external payable precheck(contractAddress, domainName) {
        console.log(
            "Domain Name: %s, Contract: %s",
            domainName,
            contractAddress
        );

        require(
            msg.value == PAY_AMOUNT,
            "Please send 0.05 ether to start the validation process."
        );

        require(
            compareStrings(
                contractAddressToDomainOwner[contractAddress].domainName,
                ""
            ),
            "Domain name already registered in struct."
        );

        // Send 0.05 ether to the owner of the contract
        (bool sent, bytes memory data) = owner().call{value: PAY_AMOUNT}("");
        require(sent, "Failed to send Ether!");

        // Add the domain name to the struct
        DomainOwnerInfo memory domainOwner = DomainOwnerInfo(
            domainName,
            msg.sender,
            DomainStatus.pending,
            block.timestamp,
            description
        );
        contractAddressToDomainOwner[contractAddress] = domainOwner;
        ownerToContractAddresses[msg.sender].push(contractAddress);
        totalContractAddressMappings++;
        emit ContractSubmittedForValidation(contractAddress, domainName);
    }

    function updateOwner(address _contractAddress, address _newDomainOwner)
        external
        payable
    {
        DomainOwnerInfo storage domainOwnerInfo = contractAddressToDomainOwner[
            _contractAddress
        ];
        require(
            msg.sender == domainOwnerInfo.ownerAddress,
            "Only the owner of the domain can update the owner"
        );
        require(_contractAddress != address(0), "Contract address is empty");
        require(_newDomainOwner != address(0), "Domain name is empty");
        require(msg.value == PAY_AMOUNT, "updateOwner requieres 0.05 ether");

        // Send 0.05 ether to the owner of the contract
        (bool sent, bytes memory data) = owner().call{value: PAY_AMOUNT}("");
        require(sent, "Failed to send Ether!");

        domainOwnerInfo.ownerAddress = _newDomainOwner;
        ownerToContractAddresses[_newDomainOwner].push(_contractAddress);
        removeContractFromOwnerArray(_contractAddress, msg.sender);
    }

    function transferContractToNewDomain(
        address newContractAddress,
        string memory domainOwner
    ) external payable precheck(newContractAddress, domainOwner) {
        require(
            msg.sender ==
                contractAddressToDomainOwner[newContractAddress].ownerAddress,
            "You are not the owner of the contract to transfer domains."
        );
        require(
            contractAddressToDomainOwner[newContractAddress].status ==
                DomainStatus.approved,
            "Contract is not approved."
        );
        require(
            msg.value == PAY_AMOUNT,
            "Please send 0.05 ether to start transferContract process."
        );
    }

    function renew(address contractAddress, string memory domainName)
        external
        payable
        precheck(contractAddress, domainName)
    {
        require(
            msg.sender ==
                contractAddressToDomainOwner[contractAddress].ownerAddress ||
                msg.sender == owner(),
            "Only the owner of the contract or DAO can renew the domain mapping."
        );

        if (
            contractAddressToDomainOwner[contractAddress].status ==
            DomainStatus.approved
        ) {
            if (
                contractAddressToDomainOwner[contractAddress].timestamp +
                    EXPIRATION_PERIOD <
                block.timestamp
            ) {
                require(
                    msg.value == PAY_AMOUNT,
                    "Please send 0.05 ether to renew the domain."
                );
                (bool sent, bytes memory data) = owner().call{
                    value: PAY_AMOUNT
                }("");
                require(sent, "Failed to send Ether!");
                contractAddressToDomainOwner[contractAddress].timestamp = block
                    .timestamp;
                emit ContractRenewed(
                    contractAddress,
                    domainName,
                    DomainStatus.approved
                );
            } else {
                console.log("Domain is not expired yet.");
            }
        }
    }

    /* ============ External View Functions ============ */

    function getContractAddress(address _ownerAddress)
        public
        view
        returns (address[] memory)
    {
        return ownerToContractAddresses[_ownerAddress];
    }

    function returnAllContractInfo(address contractAddress)
        public
        view
        returns (
            string memory,
            address,
            string memory,
            uint256,
            string memory
        )
    {
        return (
            contractAddressToDomainOwner[contractAddress].domainName,
            contractAddressToDomainOwner[contractAddress].ownerAddress,
            DomainStatusToString(
                contractAddressToDomainOwner[contractAddress].status
            ),
            contractAddressToDomainOwner[contractAddress].timestamp,
            contractAddressToDomainOwner[contractAddress].description
        );
    }

    function getDomainOwner(address contractAddress)
        public
        view
        returns (address)
    {
        return contractAddressToDomainOwner[contractAddress].ownerAddress;
    }

    function compareStrings(string memory a, string memory b)
        public
        pure
        returns (bool)
    {
        return (keccak256(abi.encodePacked((a))) ==
            keccak256(abi.encodePacked((b))));
    }

    function DomainStatusToString(DomainStatus status)
        public
        pure
        returns (string memory)
    {
        if (status == DomainStatus.pending) {
            return "pending";
        } else if (status == DomainStatus.expired) {
            return "expired";
        } else if (status == DomainStatus.approved) {
            return "approved";
        } else if (status == DomainStatus.rejected) {
            return "rejected";
        } else if (status == DomainStatus.revoked) {
            return "revoked";
        } else if (status == DomainStatus.manualFlag) {
            return "manualFlag";
        } else {
            return "unknown";
        }
    }

    function getDomainStatus(address contractAddress)
        public
        view
        returns (string memory)
    {
        require(contractAddress != address(0), "Contract address is empty");
        DomainOwnerInfo memory domain = contractAddressToDomainOwner[
            contractAddress
        ];
        if (domain.timestamp + EXPIRATION_PERIOD < block.timestamp) {
            return DomainStatusToString(DomainStatus.expired);
        } else {
            return DomainStatusToString(domain.status);
        }
    }

    function getDomainDescription(address contractAddress)
        public
        view
        returns (string memory)
    {
        require(contractAddress != address(0), "Contract address is empty");
        return contractAddressToDomainOwner[contractAddress].description;
    }

    function getDomainName(address contractAddress)
        public
        view
        returns (string memory)
    {
        require(contractAddress != address(0), "Contract address is empty");
        return contractAddressToDomainOwner[contractAddress].domainName;
    }

    function verify(address contractAddress, string memory domainName)
        public
        view
        precheck(contractAddress, domainName)
        returns (bool)
    {
        console.log("Inputs: %s, %s", domainName, contractAddress);

        DomainOwnerInfo memory domainOwner = contractAddressToDomainOwner[
            contractAddress
        ];

        if (
            compareStrings(domainOwner.domainName, domainName) &&
            domainOwner.status == DomainStatus.approved
        ) {
            if (domainOwner.timestamp + EXPIRATION_PERIOD > block.timestamp) {
                console.log("Contract is verified");
                return true;
            } else {
                console.log(
                    "Domain name and contract address match but domain is expired"
                );
                return false;
            }
        } else {
            console.log(
                "Domain name and contract address do not match or contract is not approved. Check contract state"
            );
            return false;
        }
    }

    /* ============ Private Functions ============ */

    function removeContractFromOwnerArray(
        address contractAddress,
        address ownerAddress
    ) private {
        address[] storage contractAddresses = ownerToContractAddresses[
            ownerAddress
        ];
        for (uint256 i = 0; i < contractAddresses.length; i++) {
            if (contractAddresses[i] == contractAddress) {
                contractAddresses[i] = contractAddresses[
                    contractAddresses.length - 1
                ];
                contractAddresses.pop();
                break;
            }
        }
    }

    /* ============ External Owner Functions ============ */

    function manualFlag(
        address contractAddress,
        string memory domainName,
        string memory description
    ) public onlyOwner {
        // Manual flagging of a contract.
        require(contractAddress != address(0), "Contract address is empty");
        DomainOwnerInfo storage domainInfo = contractAddressToDomainOwner[
            contractAddress
        ];
        domainInfo.status = DomainStatus.manualFlag;
        if (bytes(domainName).length != 0) {
            domainInfo.domainName = domainName;
        }
        if (bytes(description).length != 0) {
            domainInfo.description = description;
        }
        emit ContractManuallyFlag(
            contractAddress,
            domainInfo.domainName,
            description
        );
    }

    function revoke(address contractAddress)
        public
        onlyOwner
        precheck(
            contractAddress,
            contractAddressToDomainOwner[contractAddress].domainName
        )
    {
        DomainOwnerInfo storage domainInfo = contractAddressToDomainOwner[
            contractAddress
        ];
        if (domainInfo.status != DomainStatus.revoked) {
            domainInfo.status = DomainStatus.revoked;
            emit ContractRevoked(
                contractAddress,
                domainInfo.domainName,
                "Contract revoked by DAO"
            );
        }
    }

    function approve(address contractAddress)
        public
        onlyOwner
        precheck(
            contractAddress,
            contractAddressToDomainOwner[contractAddress].domainName
        )
    {
        DomainOwnerInfo storage domainInfo = contractAddressToDomainOwner[
            contractAddress
        ];
        if (domainInfo.status != DomainStatus.approved) {
            domainInfo.status = DomainStatus.approved;
            emit ContractApproved(
                contractAddress,
                domainInfo.domainName,
                DomainStatus.approved
            );
        }
    }

    function batchApprove(address[] memory contractAddresses)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < contractAddresses.length; i++) {
            approve(contractAddresses[i]);
        }
    }

    function batchRevoke(address[] memory contractAddresses)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < contractAddresses.length; i++) {
            revoke(contractAddresses[i]);
        }
    }
}
