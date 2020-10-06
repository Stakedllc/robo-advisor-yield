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


/// @notice  Standard interface for Opportunities in the RAY Protocol
///
/// Author:   Devan Purhar
/// Version:  1.0.0

interface Opportunity {


  /// @notice  Supply assets to the underlying Opportunity
  ///
  /// @param   tokenAddress - address of the token to supply, WETH in the
  ///                           case of ETH
  /// @param   amount - amount in the smallest unit of the token to supply
  /// @param   isERC20 - boolean if the token follows the ERC20 standard
  function supply(address tokenAddress, uint amount, bool isERC20) external payable;


  /// @notice  Withdraw assets to the underlying Opportunity
  ///
  /// @param   tokenAddress - address of the token to withdraw, WETH in the
  ///                           case of ETH
  /// @param   beneficiary - address to send the token too
  /// @param   amount - amount in the smallest unit of the token to supply
  /// @param   isERC20 - boolean if the token follows the ERC20 standard
  function withdraw(address tokenAddress, address beneficiary, uint amount, bool isERC20) external;


  /// @notice  The amount supplied + yield generated in the underlyng Opporutnity
  ///
  /// @param   tokenAddress - address of the token to get the balance of
  function getBalance(address tokenAddress) external view returns (uint);

}
