// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "interfaces/WrappedNative.sol";
import "interfaces/Router.sol";
import "interfaces/FlashLoan.sol";

contract FlashSwap is Ownable, IFlashLoanPancakeV3Callback {
    IWBNB private wbnb;
    IERC20 private usdt;
    IFlashLoanPancakeV3 private flashPool;
    IUniswapRouter2 private pancake;
    uint256 private loanAmount;
    address[] private path;
    uint256 private gasReserve = 0.001 ether;
    uint256 private bribePercent = 80;

    constructor() Ownable(msg.sender) {
        wbnb = IWBNB(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
        usdt = IERC20(0x55d398326f99059fF775485246999027B3197955);
        flashPool = IFlashLoanPancakeV3(0x172fcD41E0913e95784454622d1c3724f546f849);
        pancake = IUniswapRouter2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    }

    function getAmountsOut(uint256 amountIn, address[] calldata _path) public view returns (uint256[] memory amounts) {
        return pancake.getAmountsOut(amountIn, _path);
    }

    function doSwap_2054c2c(address[] calldata _path, uint256 _amount) public onlyOwner {
        uint256[] memory _got = pancake.getAmountsOut(_amount, _path);
        require(_got[_path.length - 1] > _amount, "no profit");

        loanAmount = _amount;
        path = _path;

        uint256 _usdtAmount = _path[0] == address(usdt) ? _amount : 0;
        uint256 _wbnbAmount = _path[0] == address(wbnb) ? _amount : 0;

        flashPool.flash(IFlashLoanPancakeV3Callback(address(this)), _usdtAmount, _wbnbAmount, "");
    }

    function flashCallback(uint256 _usdtFee, uint256 _wbnbFee) internal {
        require(_usdtFee <= loanAmount * 1 / 1e4, "fee0 too high");
        require(_wbnbFee <= loanAmount * 1 / 1e4, "fee1 too high");

        uint256 _fee = _usdtFee == 0 ? _wbnbFee : _usdtFee;
        uint256 _shouldRepay = loanAmount + _fee;

        IERC20 _tk = IERC20(path[0]);
        if (_tk.allowance(address(this), address(pancake)) != type(uint256).max) {
            _tk.approve(address(pancake), type(uint256).max);
        }

        uint256 _beforeBalance = _tk.balanceOf(address(this));
        pancake.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            loanAmount, 0, path, address(this), block.timestamp + 60
        );
        uint256 _afterBalance = _tk.balanceOf(address(this));
        require(_afterBalance >= _beforeBalance + _fee, "flash failed");

        _tk.transfer(address(flashPool), _shouldRepay);

        // if profit can cover gas
        if (_wbnbFee > 0 && _afterBalance > _beforeBalance + _fee + gasReserve) {
            uint256 _profit = _afterBalance - _beforeBalance - _fee - gasReserve;
            uint256 _bribe = _profit * bribePercent / 100;
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

    function pancakeV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        data;
        flashCallback(fee0, fee1);
    }

    receive() external payable {}
}
