// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {FractionalizedNFT} from "src/FractionalizedNFT.sol";

contract FractionalizedNFTTest is Test {
    FractionalizedNFT public nft;

    function setUp() public {
        nft = new FractionalizedNFT("TestNFT", "TNFT");
    }

    function testMint() public {
        nft.mint(address(this), 1, "Name", "Description", "URI", 100, 10, true);
        assertEq(nft.ownerOf(1), address(this));
    }
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
    
    function testDelegate() public {
        // Mint a new NFT to the test contract address with 10 total fractions
        nft.mint(address(this), 1, "Test", "Desc", "URI", 100, 10, true);
    
        // Delegate 5 fractions to address 0xBEEF
        nft.delegateFractions(1, address(0xBEEF), 5);
    
        // Verify that 0xBEEF correctly received 5 delegated fractions
        (
            ,
            uint256 amount,
            ,
            ,
            ,
            
        ) = nft.getFraction(1, address(0xBEEF));
    
        assertEq(amount, 5, "Delegated fraction amount does not match expected value");
    }
    
    function testRageQuit() public {
        // Mint a rage-quit-eligible NFT with 10 fractions
        nft.mint(address(this), 1, "Test", "Desc", "URI", 100, 10, true);
    
        // Execute rageQuit from the test contract
        nft.rageQuit();
    
        // Verify that the user's fractions were burned (set to 0)
        (
            ,
            uint256 amount,
            ,
            ,
            ,
            
        ) = nft.getFraction(1, address(this));
    
        assertEq(amount, 0, "RageQuit did not correctly burn user fractions");
    }
    
    function testIntegration_DistributeAndClaimRoyalties() public {
        // Mint an NFT to the test contract with 10 fractions
        nft.mint(address(this), 1, "Test", "Desc", "URI", 500, 10, true);
    
        // Delegate 4 fractions to address(0xBEEF)
        nft.delegateFractions(1, address(0xBEEF), 4);
    
        // Simulate a royalty payment of 1 ether
        vm.deal(address(this), 1 ether);
        nft.distributeRoyalties{value: 1 ether}(1);
    
        // Simulate 0xBEEF claiming their share
        vm.prank(address(0xBEEF));
        uint256 balanceBefore = address(0xBEEF).balance;
        nft.claimRoyalties(1);
        uint256 balanceAfter = address(0xBEEF).balance;
    
        // Check that royalties were received (should be 0.4 ether)
        assertEq(balanceAfter - balanceBefore, 0.4 ether, "Incorrect royalty claim amount");
    }
    
    function testFuzz_TransferFractions(uint256 amount) public {
        // Bound fuzz input to a range [1, 10]
        amount = bound(amount, 1, 10);
    
        // Mint an NFT with exactly `amount` fractions
        nft.mint(address(this), 1, "Test", "Desc", "URI", 100, amount, true);
    
        // Transfer all fractions to address(0xBEEF)
        nft.transferFractions(1, address(0xBEEF), amount);
    
        // Verify that sender now has 0, and recipient has `amount`
        (, uint256 senderAmount,,,,) = nft.getFraction(1, address(this));
        (, uint256 receiverAmount,,,,) = nft.getFraction(1, address(0xBEEF));
    
        assertEq(senderAmount, 0, "Sender should have 0 fractions after transfer");
        assertEq(receiverAmount, amount, "Receiver should have all transferred fractions");
    }
    
}
