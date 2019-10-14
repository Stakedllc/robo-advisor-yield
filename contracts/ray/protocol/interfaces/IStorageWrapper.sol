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

interface IStorageWrapper {


  /********************* ACCESSOR FUNCTIONS ***********************/


  function getVerifier(bytes32 contractName) external view returns (address);


  function getContractAddress(bytes32 contractName) external view returns (address);


  function getStakedWallet() external view returns (address);


  function getIsOracle(address target) external view returns (bool);


  function getPrincipalAddress(bytes32 ray) external view returns (address);


  /********************* MUTATOR FUNCTIONS ***********************/


  function setMinAmount(address principalAddress, uint _minAmount) external;


  function setRaised(address principalAddress, uint _raised) external;


  function setGovernanceWallet(address newGovernanceWallet) external;


  function setOracle(address newOracle, bool action) external;


  function setContractAddress(bytes32 contractName, address contractAddress) external;


  function setStorageWrapperContract(address theStorageWrapper, bool action) external;


  function setVerifier(bytes32 ray, address contractAddress) external;


  function setTokenKey(bytes32 tokenId, bytes32 ray) external;


  function setIsERC20(address principalAddress, bool _isERC20) external;


  function deleteTokenValues(bytes32 ray, bytes32 tokenId) external;


  function addOpportunity(bytes32 ray, bytes32 opportunityKey, address principalAddress) external;


  function setPrincipalAddress(bytes32 ray, address principalAddress) external;


  function setValidOpportunity(bytes32 ray, bytes32 opportunityKey) external;


  function setTokenShares(bytes32 ray, bytes32 tokenId, uint tokenShares) external;


  function setTokenCapital(bytes32 ray, bytes32 tokenId, uint tokenCapital) external;


  function setTokenAllowance(bytes32 ray, bytes32 tokenId, uint tokenAllowance) external;


  function setEntryRate(bytes32 ray, bytes32 tokenId, uint entryRate) external;


  function setOpportunityToken(bytes32 ray, bytes32 opportunity, bytes32 tokenId) external;


  function setPrincipal(bytes32 opportunityKey, uint principalAmount) external;


  function setPausedOn(bytes32 ray) external;


  function setPausedOff(bytes32 ray) external;


  function setRealizedYield(bytes32 ray, uint newRealizedYield) external;


  function setWithdrawnYield(bytes32 ray, uint newWithdrawnYield) external;


  function setCumulativeRate(address principalAddress, uint newCumulativeRate) external;


  function setLastUpdatedRate(address principalAddress, uint newLastUpdatedRate) external;


  function setBenchmarkRate(address principalAddress, uint newRate) external;


  function setACPContribution(address principalAddress, uint newStakedProfit) external;


  function setAvailableCapital(bytes32 ray, uint newAvailableCapital) external;


  function setShareSupply(bytes32 ray, uint newShareSupply) external;


}
