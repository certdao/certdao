// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface ICertDao {

    /* ============ Enums ============ */
    enum DomainStatus {
        pending,
        expired,
        approved,
        rejected,
        revoked,
        manualFlag
    }

    /* ============ External Functions ============ */

    function submitForValidation(
        address contractAddress,
        string memory domainName,
        string memory description
    ) external payable;

    function transferContractToNewDomain(
        address newContractAddress,
        string memory domainOwner
    ) external payable;

    function renew(address contractAddress, string memory domainName)
        external
        payable;

    function updateOwner(address _contractAddress, address _newDomainOwner)
        external
        payable;

    /* ============ External View Functions ============ */

    function getContractAddress(address _ownerAddress)
        external
        view
        returns (address[] memory);

    function returnAllContractInfo(address contractAddress)
        external
        view
        returns (
            string memory,
            address,
            string memory,
            uint256,
            string memory
        );

    function getDomainOwner(address contractAddress)
        external
        view
        returns (address);

    function getDomainStatus(address contractAddress)
        external
        view
        returns (string memory);

    function getDomainDescription(address contractAddress)
        external
        view
        returns (string memory);

    function getDomainName(address contractAddress)
        external
        view
        returns (string memory);

    function getDomainRegistrationTime(address contractAddress)
        external
        view
        returns (uint256);

    function getDomainExpirationTime(address contractAddress)
        external
        view
        returns (uint256);

    function getAllContracts() external view returns (address[] memory);

    function getAllContractsWithStatus(DomainStatus status)
        external
        view
        returns (address[] memory);

    function getTotalContractCount() external view returns (uint256);

    function verify(address contractAddress, string memory domainName)
        external
        view
        returns (bool);

    /* ============ External Owner Functions ============ */

    function ownerCreation(
        address contractAddress,
        address owner,
        DomainStatus status,
        string memory domainName,
        string memory description
    ) external;

    function manualFlag(
        address contractAddress,
        string memory domainName,
        string memory description
    ) external;

    function revoke(address contractAddress) external;

    function approve(address contractAddress) external;

    function batchApprove(address[] memory contractAddresses) external;

    function batchRevoke(address[] memory contractAddresses) external;
}
