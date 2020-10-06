/**

    The software and documentation available in this repository (the "Software") is
    protected by copyright law and accessible pursuant to the license set forth below.

    Copyright © 2019 Staked Securely, Inc. All rights reserved.

    Permission is hereby granted, free of charge, to any person or organization
    obtaining the Software (the “Licensee”) to privately study, review, and analyze
    the Software. Licensee shall not use the Software for any other purpose. Licensee
    shall not modify, transfer, assign, share, or sub-license the Software or any
    derivative works of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
    INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
    PARTICULAR PURPOSE, TITLE, AND NON-INFRINGEMENT. IN NO EVENT SHALL THE COPYRIGHT
    HOLDERS BE LIABLE FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT,
    OR OTHERWISE, ARISING FROM, OUT OF, OR IN CONNECTION WITH THE SOFTWARE.

*/

pragma solidity 0.4.25;

interface IStorage {

  function getIsOracle(address target) external view returns (bool);

  function getGovernanceWallet() external view returns (address);

  function isValidOpportunity(bytes32 ray, bytes32 opportunityKey) external view returns (bool);

  function getVerifier(bytes32 contractName) external view returns (address);

  function addOpportunity(bytes32 ray, bytes32 opportunityKey, address _principalAddress) external;

  function setValidOpportunity(bytes32 ray, bytes32 opportunityKey) external;

  function getTokenKey(bytes32 tokenId) external view returns (bytes32);

  function deleteTokenValues(bytes32 ray, bytes32 tokenId) external;

  function getOpportunityTokenContract() external view returns (address);

  function getPrincipalAddress(bytes32 ray) external view returns (address);

  function getIsERC20(address principalAddress) external view returns (bool);

  function getOpportunities(bytes32 ray) external view returns (bytes32[]);

  function getContractAddress(bytes32 contractId) external view returns (address);

  function setTokenKey(bytes32 tokenId, bytes32 ray) external;

  function setEntryRate(bytes32 ray, bytes32 tokenId, uint tokenMaturityTime) external;

  function setAvailableCapital(bytes32 ray, uint newAvailableCapital) external;

  function getAvailableCapital(bytes32 ray) external view returns (uint);

  function getWithdrawnYield(bytes32 ray) external view returns (uint);

  function getCumulativeRate(bytes32 ray) external view returns (uint);

  function getLastUpdatedRate(bytes32 ray) external view returns (uint);

  function setWithdrawnYield(bytes32 ray, uint newWithdrawnYield) external;

  function setCumulativeRate(bytes32 ray, uint newCumulativeRate) external;

  function setLastUpdatedRate(bytes32 ray, uint newLastUpdatedRate) external;

  function setRealizedYield(bytes32 ray, uint newRealizedYield) external;

  function getRealizedYield(bytes32 ray) external view returns (uint);

  function getOpportunityToken(bytes32 ray, bytes32 opportunity) external view returns (bytes32);

  function setOpportunityToken(bytes32 ray, bytes32 opportunity, bytes32 tokenId) external;

  function getEntryRate(bytes32 ray, bytes32 tokenId) external view returns (uint);

  function setTokenAllowance(bytes32 ray, bytes32 tokenId, uint tokenAllowance) external;

  function setTokenCapital(bytes32 ray, bytes32 tokenId, uint tokenCapital) external;

  function setACPContribution(bytes32 ray, uint newACPContribution) external;

  function getACPContribution(bytes32 ray) external view returns (uint);

  function getPausedMode(bytes32 ray) external view returns (bool);

  function getShareSupply(bytes32 ray) external view returns (uint);

  function getTokenShares(bytes32 ray, bytes32 tokenId) external view returns (uint);

  function getTokenCapital(bytes32 ray, bytes32 tokenId) external view returns (uint);

  function getTokenAllowance(bytes32 ray, bytes32 tokenId) external view returns (uint);

  function getRate(bytes32 ray) external view returns (uint);

  function setRate(bytes32 ray, uint newRate) external;

  function setPausedOn(bytes32 ray) external;

  function setPausedOff(bytes32 ray) external;

}
