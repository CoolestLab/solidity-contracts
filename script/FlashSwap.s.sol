// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console, Script} from "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {FlashSwap} from "../src/FlashSwap.sol";

contract MyScript is Script {
    function setUp() public {
        vm.label(address(0x172fcD41E0913e95784454622d1c3724f546f849), "[FlashPool]");
        vm.label(address(0x10ED43C718714eb63d5aA57B78B54704E256024E), "[PancakeRouter]");
        vm.label(address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c), "[WBNB]");
        vm.label(address(0x55d398326f99059fF775485246999027B3197955), "[USDT]");
    }

    function run() public {
        address _signer = vm.envAddress("SIGNER_ADDRESS");

        vm.startBroadcast(_signer);
        console.log("[Signer] signer:", _signer);

        FlashSwap _fs = new FlashSwap();
        console.log("[Contract] FlashSwap:", address(_fs));

        vm.stopBroadcast();
    }
}
