// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/FractionalizedNFT.sol";
import "../src/GovernanceDAO.sol";

contract DeployAll is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy FractionalizedNFT
        FractionalizedNFT nft = new FractionalizedNFT("MyDAO NFT", "MNFT");
        console.log(" FractionalizedNFT deployed at:", address(nft));

        // Deploy GovernanceDAO
        GovernanceDAO dao = new GovernanceDAO(
            address(nft),
            1,    // votingDelay (blocks)
            5,    // votingPeriod (blocks)
            1     // quorumVotes
        );
        console.log(" GovernanceDAO deployed at:", address(dao));

        vm.stopBroadcast();
    }
}





