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

interface INAVCalculator {

  function updateYield(bytes32 key, uint yield) external;

  function getPortfolioPricePerShare(bytes32 key) external view returns(uint);

  function getPortfolioUnrealizedYield(bytes32 portfolioKey) external view returns (uint);

  function getOpportunityPricePerShare(bytes32 opportunityKey) external view returns (uint);

  function getOpportunityYield(
    bytes32 key,
    bytes32 opportunityKey,
    uint amountToWithdraw
  )
    external
    view
    returns (uint);

 function getOpportunityBalance(bytes32 key, bytes32 opportunityKey) external view returns(uint);

 function calculatePayableAmount(address principalAddress, uint value) external view returns(bool, uint);

 function onlyTokenOwner(bytes32 tokenId, address origCaller, address msgSender) external view returns (address);

 function getTokenValue(bytes32 key, bytes32 tokenId) external view returns (uint, uint);

}
