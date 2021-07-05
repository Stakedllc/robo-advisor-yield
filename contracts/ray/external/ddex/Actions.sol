/*

    Copyright 2020 The Hydro Protocol Foundation

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

*/

pragma solidity 0.4.25;
pragma experimental ABIEncoderV2;

library BatchActions {
    /**
     * All allowed actions types
     */
    enum ActionType {
        Deposit, // Move asset from your wallet to tradeable balance
        Withdraw, // Move asset from your tradeable balance to wallet
        Transfer, // Move asset between tradeable balance and margin account
        Borrow, // Borrow asset from pool
        Repay, // Repay asset to pool
        Supply, // Move asset from tradeable balance to pool to earn interest
        Unsupply // Move asset from pool back to tradeable balance
    }

    /**
     * Uniform parameter for an action
     */
    struct Action {
        ActionType actionType; // The action type
        bytes encodedParams; // Encoded params, it's different for each action
    }
}

interface IDDEX {
    function batch(BatchActions.Action[] actions) external payable;
    function getAmountSupplied(address, address)
        external
        view
        returns (uint256 amount);
}
