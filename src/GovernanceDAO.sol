// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./FractionalizedNFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title GovernanceDAO
 * @dev A governance contract for a DAO using FractionalizedNFT for voting
 */
contract GovernanceDAO is Ownable {
    

    // Governance token
    FractionalizedNFT public governanceToken;
    
    // Proposal states
    enum ProposalState { Pending, Active, Defeated, Succeeded, Executed, Canceled }
    
    // Governance parameters
    uint256 public votingDelay; // Blocks after proposal creation until voting begins
    uint256 public votingPeriod; // Blocks for voting duration
    uint256 public quorumVotes; // Minimum votes required for a proposal to succeed
    
    // Proposal structure
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        bool canceled;
        mapping(address => bool) hasVoted;
    }

    // Struct for returning proposal info without stack too deep
    struct ProposalInfo {
        uint256 id;
        address proposer;
        string description;
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        bool canceled;
        ProposalState currentState;
    }
    
    // Mapping from proposal ID to proposal
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;
    
    // Eligible NFT tokens for governance
    mapping(uint256 => bool) public eligibleTokens;
    
    // Events
    event ProposalCreated(
        uint256 indexed proposalId, 
        address indexed proposer, 
        string description, 
        uint256 startBlock, 
        uint256 endBlock
    );
    event VoteCast(
        address indexed voter, 
        uint256 indexed proposalId, 
        bool support, 
        uint256 votes
    );
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);
    event TokenEligibilityChanged(uint256 indexed tokenId, bool eligible);
    
    /**
     * @dev Constructor initializes the governance contract
     * @param _governanceToken The ERC721 token used for governance
     * @param _votingDelay The delay before voting starts (in blocks)
     * @param _votingPeriod The voting duration (in blocks)
     * @param _quorumVotes The minimum votes required for a proposal to succeed
     */
    constructor(
        address _governanceToken,
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _quorumVotes
    ) Ownable(msg.sender) {
        governanceToken = FractionalizedNFT(_governanceToken);
        votingDelay = _votingDelay;
        votingPeriod = _votingPeriod;
        quorumVotes = _quorumVotes;
    }
    
    /**
     * @dev Set token eligibility for governance
     * @param tokenId The ID of the token
     * @param eligible Whether the token is eligible for governance
     */
    function setTokenEligibility(uint256 tokenId, bool eligible) external onlyOwner {
        eligibleTokens[tokenId] = eligible;
        emit TokenEligibilityChanged(tokenId, eligible);
    }
    
    /**
     * @dev Create a new proposal
     * @param description The description of the proposal
     * @return The ID of the created proposal
     */
    function propose(uint256 tokenId, string memory description) external returns (uint256) {
        require(eligibleTokens[tokenId], "Token not eligible for governance");
        require(governanceToken.getVotingPower(msg.sender) > 0, "Proposer votes below proposal threshold");
    
        uint256 proposalId = proposalCount++;
        Proposal storage proposal = proposals[proposalId];
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.description = description;
        proposal.startBlock = block.number + votingDelay;
        proposal.endBlock = proposal.startBlock + votingPeriod;
    
        emit ProposalCreated(
            proposalId,
            msg.sender,
            description,
            proposal.startBlock,
            proposal.endBlock
        );
    
        return proposalId;
    }
    
    
    /**
     * @dev Cast a vote on a proposal
     * @param proposalId The ID of the proposal
     * @param support Whether to support the proposal
     * @param tokenId The ID of the token to vote with
     */
    function castVote(uint256 proposalId, bool support, uint256 tokenId) external {
        require(proposalId < proposalCount, "Invalid proposal ID");
        require(eligibleTokens[tokenId], "Token not eligible for governance");
        
        Proposal storage proposal = proposals[proposalId];
        require(state(proposalId) == ProposalState.Active, "Voting is closed");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        
        // Mark as voted on the governance token
        governanceToken.castVote(proposalId, tokenId);
        
        uint256 votes = governanceToken.getVotingPower(msg.sender);
        require(votes > 0, "No voting power");
        
        if (support) {
            proposal.forVotes = proposal.forVotes + votes;
        } else {
            proposal.againstVotes = proposal.againstVotes + votes;
        }
        
        proposal.hasVoted[msg.sender] = true;
        
        emit VoteCast(msg.sender, proposalId, support, votes);
    }
    
    /**
     * @dev Execute a successful proposal
     * @param proposalId The ID of the proposal
     */
    function execute(uint256 proposalId) external {
        require(state(proposalId) == ProposalState.Succeeded, "Proposal cannot be executed");
        
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;
        
        emit ProposalExecuted(proposalId);
    }
    
    /**
     * @dev Cancel a proposal
     * @param proposalId The ID of the proposal
     */
    function cancel(uint256 proposalId) external {
        require(proposalId < proposalCount, "Invalid proposal ID");
        ProposalState currentState = state(proposalId);
        require(
            currentState == ProposalState.Pending || 
            currentState == ProposalState.Active, 
            "Cannot cancel executed proposal"
        );
        
        Proposal storage proposal = proposals[proposalId];
        require(msg.sender == proposal.proposer || msg.sender == owner(), "Only proposer or owner can cancel");
        
        proposal.canceled = true;
        
        emit ProposalCanceled(proposalId);
    }
    
    /**
     * @dev Get the state of a proposal
     * @param proposalId The ID of the proposal
     * @return The state of the proposal
     */
    function state(uint256 proposalId) public view returns (ProposalState) {
        require(proposalId < proposalCount, "Invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        
        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < quorumVotes) {
            return ProposalState.Defeated;
        } else {
            return ProposalState.Succeeded;
        }
    }
    
    /**
     * @dev Get proposal details
     * @param proposalId The ID of the proposal
     * @return ProposalInfo struct containing proposal details
     */
    function getProposal(uint256 proposalId) external view returns (ProposalInfo memory) {
        require(proposalId < proposalCount, "Invalid proposal ID");
        Proposal storage proposal = proposals[proposalId];
        
        return ProposalInfo({
            id: proposal.id,
            proposer: proposal.proposer,
            description: proposal.description,
            startBlock: proposal.startBlock,
            endBlock: proposal.endBlock,
            forVotes: proposal.forVotes,
            againstVotes: proposal.againstVotes,
            executed: proposal.executed,
            canceled: proposal.canceled,
            currentState: state(proposalId)
        });
    }
    
    /**
     * @dev Check if an address has voted on a proposal
     * @param proposalId The ID of the proposal
     * @param account The address to check
     * @return Whether the address has voted on the proposal
     */
    function hasVoted(uint256 proposalId, address account) external view returns (bool) {
        require(proposalId < proposalCount, "Invalid proposal ID");
        return proposals[proposalId].hasVoted[account];
    }
}
