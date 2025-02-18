// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// ------ Pancake ------

interface IFlashLoanPancakeV3 {
    function flash(IFlashLoanPancakeV3Callback recipient, uint256 amount0, uint256 amount1, bytes calldata data)
        external;
}

interface IFlashLoanPancakeV3Callback {
    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external;
}

// ------ Balancer ------

interface IFlashLoanBalancerCallback {
    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external;
}

interface IFlashLoanBalancer {
    function flashLoan(
        IFlashLoanBalancerCallback recipient,
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;
}
