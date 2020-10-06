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

interface IOpportunityManager {

  function buyPosition(
    bytes32 key,
    address beneficiary,
    address opportunity,
    address principalToken,
    uint value,
    bool isERC20
  )
    external
    payable
    returns (bytes32);

  function increasePosition(
    bytes32 key,
    bytes32 tokenId,
    address opportunity,
    address principalToken,
    uint value,
    bool isERC20
  )
    external
    payable;

  function withdrawPosition(
    bytes32 key,
    bytes32 tokenId,
    address opportunity,
    address principalToken,
    uint valueToWithdraw,
    bool isERC20)
    external;

}
