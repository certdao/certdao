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
    uint256 public totalContractAddressMappings;

    address[] public contractAddresses;
    uint256 public totalContractAddresses;

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
    // Owner creation Event
    event OwnerCreated(
        address indexed contractAddress,
        address indexed owner,
        string indexed domainName,
        string domainStatus,
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
        contractAddresses.push(address(this));
        totalContractAddresses++;
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

        require(
            msg.value == PAY_AMOUNT,
            "Please send 0.05 ether to start the validation process."
        );

        require(
            compareStrings(
                contractAddressToDomainOwner[contractAddress].domainName,
                ""
            ),
            "Contract address already has a domain registered in the struct."
        );

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

        contractAddresses.push(contractAddress);
        totalContractAddresses++;

        // Send 0.05 ether to the owner of the contract
        (bool sent, bytes memory data) = owner().call{value: PAY_AMOUNT}("");
        require(sent, "Failed to send Ether!");

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

        domainOwnerInfo.ownerAddress = _newDomainOwner;
        ownerToContractAddresses[_newDomainOwner].push(_contractAddress);
        _removeContractFromOwnerArray(_contractAddress, msg.sender);

        // Send 0.05 ether to the owner of the contract
        (bool sent, bytes memory data) = owner().call{value: PAY_AMOUNT}("");
        require(sent, "Failed to send Ether!");
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
                contractAddressToDomainOwner[contractAddress].timestamp = block
                    .timestamp;

                (bool sent, bytes memory data) = owner().call{
                    value: PAY_AMOUNT
                }("");

                emit ContractRenewed(
                    contractAddress,
                    domainName,
                    DomainStatus.approved
                );
                require(sent, "Failed to send Ether!");
            } else {
                console.log("Domain is not expired yet.");
                return;
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
        DomainOwnerInfo storage domainInfo = contractAddressToDomainOwner[
            contractAddress
        ];
        return (
            domainInfo.domainName,
            domainInfo.ownerAddress,
            DomainStatusToString(domainInfo.status),
            domainInfo.timestamp,
            domainInfo.description
        );
    }

    function getDomainOwner(address contractAddress)
        external
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
        external
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
        external
        view
        returns (string memory)
    {
        require(contractAddress != address(0), "Contract address is empty");
        return contractAddressToDomainOwner[contractAddress].description;
    }

    function getDomainName(address contractAddress)
        external
        view
        returns (string memory)
    {
        require(contractAddress != address(0), "Contract address is empty");
        return contractAddressToDomainOwner[contractAddress].domainName;
    }

    function getDomainRegistrationTime(address contractAddress)
        external
        view
        returns (uint256)
    {
        require(contractAddress != address(0), "Contract address is empty");
        return contractAddressToDomainOwner[contractAddress].timestamp;
    }

    function getDomainExpirationTime(address contractAddress)
        external
        view
        returns (uint256)
    {
        require(contractAddress != address(0), "Contract address is empty");
        return
            contractAddressToDomainOwner[contractAddress].timestamp +
            EXPIRATION_PERIOD;
    }

    function getAllContracts() external view returns (address[] memory) {
        return contractAddresses;
    }

    function getAllContractsWithStatus(DomainStatus status)
        external
        view
        returns (address[] memory)
    {
        address[] memory statusToContractAddresses = new address[](
            totalContractAddresses
        );

        uint256 index = 0;
        for(uint256 i = 0; i < totalContractAddresses; i++) {
            if(contractAddressToDomainOwner[contractAddresses[i]].status == status) {
                statusToContractAddresses[index] = contractAddresses[i];
                index++;
            }
        }

        return statusToContractAddresses;
    }

    function getTotalContractCount() external view returns (uint256) {
        return totalContractAddresses;
    }

    function verify(address contractAddress, string memory domainName)
        external
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

    function _removeContractFromOwnerArray(
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

    function ownerCreation(
        address contractAddress,
        address owner,
        DomainStatus status,
        string memory domainName,
        string memory description
    ) public onlyOwner precheck(contractAddress, domainName) {
        require(
            compareStrings(
                contractAddressToDomainOwner[contractAddress].domainName,
                ""),
            "Contract address already has a domain registered in the struct."
        );

        // Add the domain name to the struct
        DomainOwnerInfo memory domainOwner = DomainOwnerInfo(
            domainName,
            owner,
            status,
            block.timestamp,
            description
        );
        contractAddressToDomainOwner[contractAddress] = domainOwner;

        ownerToContractAddresses[owner].push(contractAddress);
        totalContractAddressMappings++;

        contractAddresses.push(contractAddress);
        totalContractAddresses++;

        emit OwnerCreated(
            contractAddress,
            owner,
            domainName,
            DomainStatusToString(status),
            description
        );
    }

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
