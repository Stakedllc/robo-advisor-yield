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

interface IPositionManager {

  function updateTokenUponWithdrawal(
      bytes32 opportunityKey,
      bytes32 tokenId,
      uint valueToWithdraw,
      uint pricePerShare,
      uint shares,
      uint unrealizedYield
  )
      external;


    function createToken(
      bytes32 opportunityKey,
      address token,
      address beneficiary,
      uint value,
      uint pricePerShare
    )
      external
      returns (bytes32);

    function increaseTokenCapital(
        bytes32 opportunityKey,
        bytes32 tokenId,
        uint pricePerShare,
        uint value
    )
        external;

    function verifyWithdrawer(
      bytes32 opportunityKey,
      bytes32 tokenId,
      address token,
      address sender,
      uint pricePerShare,
      uint valueToWithdraw,
      uint totalValue
    )
      external
      returns (address);

}
