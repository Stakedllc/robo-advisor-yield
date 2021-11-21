/**

    The software and documentation available in this repository (the "Software") is
    protected by copyright law and accessible pursuant to the license set forth below.

    Copyright © 2020 Staked Securely, Inc. All rights reserved.

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

pragma solidity 0.5.11;


// internal dependencies
import "../interfaces/IRAYv2.sol";
import '../interfaces/IUpgradeable.sol';
import "../interfaces/IStorage.sol";


/// @notice  Admin controls all 'governance' or configuring of the system. We currently
///          hold singular access to Admin, controlled by our Governance Wallet.
///
///          Evenutally we look to upgrade Admin so it's controlled by decentralized
///          governance tokens similar to MakerDAO's model.
///
/// Author:   Devan Purhar
/// Version:  1.0.0

contract AdminTwo is IUpgradeable {


  /*************** STORAGE VARIABLE DECLARATIONS **************/


  // contracts used
  bytes32 internal constant RAY_V2_CONTRACT = keccak256("RAYv2Contract");

  IStorage public rayStorage;
  bool public deprecated;


  /*************** EVENT DECLARATIONS **************/


  event LogSetDeprecatedAdmin(
    bool value
  );


  event LogSetRoboTokens(
    address[] roboTokens,
    bool[] actions
  );


  event LogInitRoboTokens(
    address[] roboTokens
  );


  event LogSetupAssets(
    address[] underlyings
  );


  event LogSetPeriodLength(
    uint periodLength
  );


  /*************** MODIFIER DECLARATIONS **************/


  /// @notice  Checks the caller is our Governance Wallet
  modifier onlyGovernance()
  {
      require(
          msg.sender == rayStorage.getGovernanceWallet(),
          "#AdminTwo onlyGovernance Modifier: Only Governance can call this"
      );

      _;
  }


  /// @notice  Checks if the contract has been set to deprecated
  modifier notDeprecated()
  {
      require(
           deprecated == false,
          "#AdminTwo notDeprecated Modifier: In deprecated mode - this contract has been deprecated"
      );

      _;
  }


  /////////////////////// FUNCTION DECLARATIONS BEGIN ///////////////////////

  /******************* PUBLIC FUNCTIONS *******************/


  /// @notice  Sets the Storage contract instance
  ///
  /// @param   _rayStorage - The Storage contracts address
  constructor(
    address _rayStorage
  )
    public
  {

    require(
      _rayStorage != address(0),
      "#AdminTwo constructor: RAY Storage cannot be equal to the null address."
    );

    rayStorage = IStorage(_rayStorage);

  }


  /** ----------------- ONLY GOVERNANCE (WE ARE GOVERNANCE) MUTATORS ----------------- **/


    /// @notice  Set status of a contract address, giving it the recognization of a RoboToken
    ///
    /// @param  roboTokens - The addresses to modify access for
    /// @param  actions - Add or remove / true or false
    function setRoboTokens(
      address[] calldata roboTokens,
      bool[] calldata actions
    )
      external
      notDeprecated
      onlyGovernance
    {

      for (uint i = 0; i < roboTokens.length; i++) {

        IRAYv2(rayStorage.getContractAddress(RAY_V2_CONTRACT)).setRoboToken(roboTokens[i], actions[i]);

      }

      emit LogSetRoboTokens(roboTokens, actions);

    }


    /// @notice  Set status of a contract address, giving it the recognization of a RoboToken
    ///
    /// @param  roboTokens - The addresses to modify access for
    /// @param  portfolioIds - The portfolioId's lining up with the RoboTokens
    function initRoboTokens(
      address[] calldata roboTokens,
      bytes32[] calldata portfolioIds
    )
      external
      notDeprecated
      onlyGovernance
    {

      // validation is performed on the data input in the RAYv2 function this calls.

      for (uint i = 0; i < roboTokens.length; i++) {

        IRAYv2(rayStorage.getContractAddress(RAY_V2_CONTRACT)).initRoboToken(roboTokens[i], portfolioIds[i]);

      }

      emit LogInitRoboTokens(roboTokens);

    }


    /// @notice  Set status of a contract address, giving it the recognization of a RoboToken
    function setupAssets(
      address[] calldata underlyings,
      uint[] calldata coinStandards,
      uint[] calldata raiseds
    )
      external
      notDeprecated
      onlyGovernance
    {

      for (uint i = 0; i < underlyings.length; i++) {

        IRAYv2(rayStorage.getContractAddress(RAY_V2_CONTRACT)).setupAsset(underlyings[i], coinStandards[i], raiseds[i]);

      }

      emit LogSetupAssets(underlyings);

    }


    /// @notice  Set the time threshold in seconds
    ///
    /// @param  periodLength - The new value for max. time in seconds the NAV can be stale by
    function setPeriodLength(
      uint periodLength
    )
      external
      notDeprecated
      onlyGovernance
    {

      // any value is valid for this variable, considering different scenarios.

      IRAYv2(rayStorage.getContractAddress(RAY_V2_CONTRACT)).setPeriodLength(periodLength);

      emit LogSetPeriodLength(periodLength);

    }


    function setDeprecated(bool value) external onlyGovernance {

      deprecated = value;

      emit LogSetDeprecatedAdmin(value);

    }


}
