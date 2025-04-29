// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Governance.sol";

contract DeployGovernance is Script {
    function run() external {
        address tokenAddress = 0xD7ACd2a9FD159E69Bb102A1ca21C9a3e3A5F771B;

        address[] memory approvers ;
        approvers[0] = 0x6D8f02C05D736fca6752c9BCe35DC87EB624d66E;
        approvers[1] = 0xB26356c1F4A10c93d74d446EDFC61C0520FfeA4B;

        vm.startBroadcast();
        new Governance(tokenAddress, approvers);
        vm.stopBroadcast();
    }
}



