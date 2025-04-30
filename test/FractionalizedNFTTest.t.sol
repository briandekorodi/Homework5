// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {FractionalizedNFT} from "src/FractionalizedNFT.sol";
import {GovernanceDAO} from "src/GovernanceDAO.sol";

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
        nft.mint(address(this), 1, "Test", "Desc", "URI", 100, 10, true);
        nft.delegateFractions(1, address(0xBEEF), 5);

        (, uint256 amount,,,,) = nft.getFraction(1, address(0xBEEF));
        assertEq(amount, 5, "Delegated fraction amount does not match expected value");
    }

    function testRageQuit() public {
        nft.mint(address(this), 1, "Test", "Desc", "URI", 100, 10, true);
        nft.rageQuit();

        (, uint256 amount,,,,) = nft.getFraction(1, address(this));
        assertEq(amount, 0, "RageQuit did not correctly burn user fractions");
    }

    function testIntegration_DistributeAndClaimRoyalties() public {
        nft.mint(address(this), 1, "Test", "Desc", "URI", 500, 10, true);
        nft.delegateFractions(1, address(0xBEEF), 4);

        vm.deal(address(this), 1 ether);
        nft.distributeRoyalties{value: 1 ether}(1);

        vm.prank(address(0xBEEF));
        uint256 balanceBefore = address(0xBEEF).balance;
        nft.claimRoyalties(1);
        uint256 balanceAfter = address(0xBEEF).balance;

        assertEq(balanceAfter - balanceBefore, 0.4 ether, "Incorrect royalty claim amount");
    }

    function testFuzz_TransferFractions(uint256 amount) public {
        amount = bound(amount, 1, 10);
        nft.mint(address(this), 1, "Test", "Desc", "URI", 100, amount, true);
        nft.transferFractions(1, address(0xBEEF), amount);

        (, uint256 senderAmount,,,,) = nft.getFraction(1, address(this));
        (, uint256 receiverAmount,,,,) = nft.getFraction(1, address(0xBEEF));

        assertEq(senderAmount, 0, "Sender should have 0 fractions after transfer");
        assertEq(receiverAmount, amount, "Receiver should have all transferred fractions");
    }

    function testGovernanceFlow() public {
        GovernanceDAO dao = new GovernanceDAO(address(nft), 1, 5, 1);
        nft.mint(address(this), 1, "GovNFT", "Description", "URI", 500, 100, true);
        nft.transferFractions(1, address(0xBEEF), 10);
    
        vm.prank(address(this));
        dao.setTokenEligibility(1, true);
    
        vm.prank(address(0xBEEF));
        uint256 proposalId = dao.propose(1, "Enable feature X");
    
        vm.roll(block.number + dao.votingDelay() + 1);
    
        vm.prank(address(0xBEEF));
        dao.castVote(proposalId, true, 1);
    
        vm.roll(block.number + dao.votingPeriod());
    
        if (dao.state(proposalId) == GovernanceDAO.ProposalState.Succeeded) {
            dao.execute(proposalId);
        }
    
        GovernanceDAO.ProposalInfo memory info = dao.getProposal(proposalId);
        assertTrue(info.executed, "Proposal should be executed");
    }
    
    
}

