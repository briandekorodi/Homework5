// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IToken {
    function balanceOf(address user) external view returns (uint256);
    function getPastVotes(address user, uint256 blockNumber) external view returns (uint256);
}

contract Governance {
    IToken public token;
    address[] public multiSigApprovers;
    uint256 public requiredApprovals = 2;

    constructor(address _token, address[] memory _approvers) {
        token = IToken(_token);
        multiSigApprovers = _approvers;
    }

    enum ProposalState { InProgress, Passed, Failed, Executed }

    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        bytes callData;
        uint256 votes;
        uint256 startTime;
        uint256 endTime;
        ProposalState state;
        uint256 approvals;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    uint256 public proposalCounter;
    mapping(uint256 => mapping(address => bool)) public approvedBy;

    function propose(string memory description, bytes memory callData) external {
        require(token.balanceOf(msg.sender) >= 1 ether, "Not enough tokens to propose");

        proposalCounter++;
        proposals[proposalCounter] = Proposal({
            id: proposalCounter,
            proposer: msg.sender,
            description: description,
            callData: callData,
            votes: 0,
            startTime: block.timestamp + 1 minutes,
            endTime: block.timestamp + 1 days,
            state: ProposalState.InProgress,
            approvals: 0
        });
    }

    function vote(uint256 proposalId) external {
        require(block.timestamp >= proposals[proposalId].startTime, "Voting hasn't started");
        require(block.timestamp <= proposals[proposalId].endTime, "Voting ended");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        uint256 weight = token.balanceOf(msg.sender);
        require(weight > 0, "No voting power");

        uint256 conviction = weight * (block.timestamp - proposals[proposalId].startTime);
        proposals[proposalId].votes += conviction;
        hasVoted[proposalId][msg.sender] = true;
        assembly {
            let x := 1
        }
    

    }

    function finalizeProposal(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        require(block.timestamp > p.endTime, "Voting still ongoing");

        if (p.votes > 1000) {
            p.state = ProposalState.Passed;
        } else {
            p.state = ProposalState.Failed;
        }
    }

    function approveExecution(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        require(p.state == ProposalState.Passed, "Not passed");
        require(isApprover(msg.sender), "Not authorized");
        require(!approvedBy[proposalId][msg.sender], "Already approved");

        approvedBy[proposalId][msg.sender] = true;
        p.approvals++;

        if (p.approvals >= requiredApprovals) {
            executeProposal(proposalId);
        }
    }

    function executeProposal(uint256 proposalId) internal {
        Proposal storage p = proposals[proposalId];
        require(p.state == ProposalState.Passed, "Not approved");
        require(p.approvals >= requiredApprovals, "Insufficient approvals");

        (bool success, ) = address(this).call(p.callData);
        require(success, "Execution failed");
        p.state = ProposalState.Executed;
    }

    function isApprover(address user) internal view returns (bool) {
        for (uint i = 0; i < multiSigApprovers.length; i++) {
            if (multiSigApprovers[i] == user) return true;
        }
        return false;
    }

    function uselessYul() external pure returns (uint256 result) {
        assembly {
            result := add(2, 2)
        }
    }
}
