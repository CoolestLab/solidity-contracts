// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "interfaces/WrappedNative.sol";
import "interfaces/Router.sol";
import "interfaces/FlashLoan.sol";

contract FlashSwap is Ownable, IFlashPoolCallback {
    IWBNB private wbnb;
    IERC20 private usdt;
    IFlashPool private pool;
    IUniswapRouter2 private pancake;
    uint256 private gasReserve = 0.001 ether;
    uint256 private bribePercent = 90;

    constructor(address _pool) Ownable(msg.sender) {
        wbnb = IWBNB(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
        usdt = IERC20(0x55d398326f99059fF775485246999027B3197955);
        pancake = IUniswapRouter2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        pool = IFlashPool(_pool);
    }

    function getAmountsOut(uint256 amountIn, address[] calldata _path) public view returns (uint256[] memory amounts) {
        return pancake.getAmountsOut(amountIn, _path);
    }

    function swap_1712bab50(address[] calldata _path, uint256 _amount) public onlyOwner {
        uint256[] memory _got = pancake.getAmountsOut(_amount, _path);
        require(_got[_path.length - 1] > _amount, "no profit");
        pool.flash(_path[0], _amount, abi.encode(_path, _amount));
    }

    function flashCallback(uint256 _fee, bytes calldata _data) external {
        require(msg.sender == address(pool), "unauthorized");

        (address[] memory _path, uint256 _amount) = abi.decode(_data, (address[], uint256));

        IERC20 _tk = IERC20(_path[0]);
        if (_tk.allowance(address(this), address(pancake)) != type(uint256).max) {
            _tk.approve(address(pancake), type(uint256).max);
        }

        uint256 _beforeBalance = _tk.balanceOf(address(this));
        pancake.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amount, 0, _path, address(this), block.timestamp + 60
        );
        uint256 _afterBalance = _tk.balanceOf(address(this));
        require(_afterBalance >= _beforeBalance + _fee, "flash failed");

        uint256 _netProfit = _afterBalance - _beforeBalance - _fee;

        if (_path[0] == address(wbnb) && _netProfit > gasReserve) {
            uint256 _bribe = (_netProfit - gasReserve) * bribePercent / 100;
            if (_bribe > 0) {
                wbnb.withdraw(_bribe);
                payable(0x4848489f0b2BEdd788c696e2D79b6b69D7484848).transfer(_bribe);
            }
        }
    }

    function withdraw(address _token, uint256 _amount) public onlyOwner {
        if (_token != address(0)) {
            IERC20(_token).transfer(msg.sender, _amount);
        } else {
            (bool ok,) = payable(msg.sender).call{value: _amount}("");
            require(ok);
        }
    }

    function setGasReserve(uint256 _gasReserve) public onlyOwner {
        gasReserve = _gasReserve;
    }

    function setBribePercent(uint256 _bribePercent) public onlyOwner {
        bribePercent = _bribePercent;
    }

    function setPool(address _pool) public onlyOwner {
        pool = IFlashPool(_pool);
    }

    receive() external payable {}
}
