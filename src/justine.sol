// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Hooks} from "@uniswap/v4-core/contracts/libraries/Hooks.sol";
import {BaseHook} from "v4-periphery/BaseHook.sol";
import {IPoolManager} from "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import {Currency} from "@uniswap/v4-core/contracts/libraries/CurrencyLibrary.sol";
import {PoolId} from "@uniswap/v4-core/contracts/libraries/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/contracts/types/BalanceDelta.sol";
import {OptionManager} from "src/OptionManager.sol";

import "./khajit/IKhajit.sol";

error InexistentPosition();

contract Justine is BaseHook {
    using PoolId for IPoolManager.PoolKey;

    bool private isAmount0Eth = false;
    bool private gonnaBeEth = false;
    bool private hasActiveOption = false;
    uint256 private currentPositionId = 0;
    uint256 private currentActiveContracts = 0;
    
    address private kajhitAddress;

    constructor(address _kajhitAddress, bool _gonnaBeEth) BaseHook(_poolManager) {
        kajhitAddress = _kajhitAddress;
        gonnaBeEth = _gonnaBeEth;
    }

    function getHooksCalls() public pure override returns (Hooks.Calls memory) {
        return Hooks.Calls({
            beforeInitialize: true,
            afterInitialize: false,
            beforeModifyPosition: false,
            afterModifyPosition: true,
            beforeSwap: false,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: true
        });
    }

    function beforeInitialize(address sender, IPoolManager.PoolKey calldata key, uint160 sqrtPriceX96)
        external
        override
        returns (bytes4)
    {
        // TODO: fix this shit !
        // if (key.currency0 == Currency.wrap(address(0))) {
        //     isAmount0Eth = true;
        // }
        if (gonnaBeEth) {
            isAmount0Eth = true;
        }

        return BaseHook.beforeSwap.selector;
    }

    function afterDonate(address sender, IPoolManager.PoolKey calldata key, uint256 amount0, uint256 amount1)
        external
        override
        returns (bytes4)
    {
        _checkActive();

        // Get how much eth we're depositing so we can get how much contracts we need to buy
        uint256 contractAmount;
        if (isAmount0Eth) {
            contractAmount = amount0;
        } else {
            contractAmount = amount1;
        }

        // get how much eth we're depositing, since its going to be whole we need to truncate the decimals
        contractAmount = contractAmount / 1e18;

        uint256 positionId;
        uint256 amount;
        uint256 collateral;
        uint256 strikeId;

        buyOptions(
            contractAmount,
            whichStrike(),
            block.timestamp + 1 month,
            10,
            true
        );

        return BaseHook.beforeSwap.selector;
    }

    function afterModifyPosition(
        address sender,
        IPoolManager.PoolKey calldata key,
        IPoolManager.ModifyPositionParams calldata params,
        BalanceDelta delta
    ) external override returns (bytes4) {
        _checkActive();

        return BaseHook.beforeSwap.selector;
    }

    function _checkActive() internal {
        if (currentPositionId == 0) {
            revert InexistentPosition();
        }
        if (hasActiveOption) {
            // check if still active but should be inactive
            if (optionManager.isOptionExpired(currentPositionId)) {
                hasActiveOption = false;
            }
        }
    }
}
