// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "interfaces/Router.sol";
import "interfaces/FlashLoan.sol";

contract Pool is AccessControl, ReentrancyGuard, IFlashLoanPancakeV3Callback {
    mapping(address => address) public tokenPools;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier checkOrigin() {
        _checkRole(DEFAULT_ADMIN_ROLE, tx.origin);
        _;
    }

    receive() external payable {}
    fallback() external payable {}

    function setTokenPool(address _token, address _pool) public onlyRole(DEFAULT_ADMIN_ROLE) {
        tokenPools[_token] = _pool;
    }

    function execute(address _to, uint256 _amount, bytes calldata _data)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        (bool ok,) = payable(_to).call{value: _amount}(_data);
        require(ok, "!ok");
    }

    function flash(address _token, uint256 _amount, bytes calldata _data) public checkOrigin nonReentrant {
        IERC20 _tk = IERC20(_token);

        uint256 _beforeBalance = _tk.balanceOf(address(this));
        if (_beforeBalance >= _amount) {
            flashInternal(_tk, address(msg.sender), _amount, 0, _data);
            return;
        }

        uint256 _diffAmount = _amount - _beforeBalance;
        IFlashLoanPancakeV3 _pool = IFlashLoanPancakeV3(tokenPools[_token]);
        require(address(_pool) != address(0x0), "!pool");
        require(_tk.balanceOf(address(_pool)) >= _diffAmount, "!balance");

        bytes memory _flashData = abi.encode(_token, address(msg.sender), _amount, _diffAmount, _data);

        IUniswapPair _pair = IUniswapPair(address(_pool));
        if (_pair.token0() == _token) {
            _pool.flash(IFlashLoanPancakeV3Callback(address(this)), _diffAmount, 0, _flashData);
        } else {
            _pool.flash(IFlashLoanPancakeV3Callback(address(this)), 0, _diffAmount, _flashData);
        }
    }

    function pancakeV3FlashCallback(uint256 _fee0, uint256 _fee1, bytes calldata _flashData) external {
        IUniswapPair _pair = IUniswapPair(address(msg.sender));
        address _token0 = _pair.token0();
        address _token1 = _pair.token1();
        require(tokenPools[_token0] == address(_pair) || tokenPools[_token1] == address(_pair), "!pool");

        (address _token, address _to, uint256 _amount, uint256 _loanAmount, bytes memory _data) =
            abi.decode(_flashData, (address, address, uint256, uint256, bytes));

        uint256 _fee = _fee0 > 0 ? _fee0 : _fee1;
        require(_fee <= _loanAmount * 1 / 1e4, "!fee");

        flashInternal(IERC20(_token), _to, _amount, _fee, _data);

        IERC20(_token).transfer(address(_pair), _loanAmount + _fee);
    }

    function flashInternal(IERC20 _tk, address _to, uint256 _amount, uint256 _fee, bytes memory _data) internal {
        uint256 _beforeBalance = _tk.balanceOf(address(this));

        _tk.transfer(_to, _amount);

        IFlashPoolCallback(_to).flashCallback(_fee, _data);

        _tk.transferFrom(_to, address(this), _tk.balanceOf(_to));

        uint256 _afterBalance = _tk.balanceOf(address(this));
        require(_afterBalance >= _beforeBalance, "!repay");
    }
}
