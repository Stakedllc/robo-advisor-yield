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


/// @notice  Basic interface for integration with RAY - The Robo-Advisor for Yield.
///
/// Author:   Devan Purhar
/// Version:  1.0.0

interface RAY {


  /// @notice  Mints a RAY token of the associated basket of opportunities to the portfolioId
  ///
  /// @param   portfolioId - the id of the portfolio to associate the RAY token with
  /// @param   beneficiary - the owner and beneficiary of the RAY token
  /// @param   value - the amount in the smallest units in-kind to deposit into RAY
  ///
  /// @return  the unique RAY token id, used to reference anything in the RAY system
  function mint(bytes32 portfolioId, address beneficiary, uint value) external payable returns(bytes32);


  /// @notice  Deposits assets into an existing RAY token
  ///
  /// @dev     Anybody can deposit into a RAY token, not just the owner
  ///
  /// @param   tokenId - the id of the RAY token to add value too
  /// @param   value - the amount in the smallest units in-kind to deposit into the RAY
  function deposit(bytes32 tokenId, uint value) external payable;


  /// @notice  Redeems a RAY token for the underlying value
  ///
  /// @dev     Can partially or fully redeem the RAY token
  ///
  ///          Only the owner of the RAY token can call this, or the Staked
  ///          'GasFunder' smart contract
  ///
  /// @param   tokenId - the id of the RAY token to redeem value from
  /// @param   valueToWithdraw - the amount in the smallest units in-kind to redeem from the RAY
  /// @param   originalCaller - only relevant for our `GasFunder` smart contract,
  ///                           for everyone else, can be set to anything
  ///
  /// @return  the amount transferred to the owner of the RAY token after fees
  function redeem(bytes32 tokenId, uint valueToWithdraw, address originalCaller) external returns(uint);


  /// @notice  Get the underlying value of a RAY token (principal + yield earnt)
  ///
  /// @dev     The implementation of this function exists in NAVCalculator
  ///
  /// @param   portfolioId - the id of the portfolio associated with the RAY token
  /// @param   tokenId - the id of the RAY token to get the value of
  ///
  /// @return  an array of two, the first value is the current token value, the
  ///          second value is the current price per share of the portfolio
  function getTokenValue(bytes32 portfolioId, bytes32 tokenId) external view returns(uint, uint);

}
