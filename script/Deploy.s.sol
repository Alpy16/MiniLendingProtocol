// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/LendingPool.sol";

contract DeployScript is Script {
    function run() public {
        vm.startBroadcast();
        LendingPool pool = new LendingPool();
        console.log("LendingPool deployed to:", address(pool));
        vm.stopBroadcast();
    }
}
