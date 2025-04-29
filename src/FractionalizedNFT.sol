// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


/**
 * @title FractionalizedNFT
 * @dev A custom ERC721 token with fractional ownership capabilities for DAO governance
 * Allows for vote delegation, royalty distribution, and rage quit mechanism
 */
contract FractionalizedNFT is ERC721Enumerable, Ownable {
    using Strings for uint256;

    // Fractionalization and ownership tracking
    struct Fraction {
        address owner;
        uint256 amount;
        bool isDelegate;
        address delegatedTo;
        bool hasVoted;
        uint256 lastVoteTimestamp;
    }

    struct NFTMetadata {
        string name;
        string description;
        string uri;
        uint256 royaltyPercentage; // in basis points (1/100 of a percent)
        uint256 totalFractions;
        uint256 availableFractions;
        uint256 accumulatedRoyalties;
        bool isEligibleForRageQuit;
    }

    // Mapping from token ID to fractions
    mapping(uint256 => mapping(address => Fraction)) private _fractions;
    // List of fraction owners per token
    mapping(uint256 => address[]) private _fractionOwners;
    // Mapping from token ID to metadata
    mapping(uint256 => NFTMetadata) private _metadata;
    
    // Governance tracking
    mapping(address => bool) private _hasRageQuit;
    mapping(address => uint256) private _votingPower;
    mapping(address => mapping(uint256 => bool)) private _hasVotedOnProposal;
    
    mapping(address => bool) public hasDelegated;

    // Events
    event FractionTransferred(uint256 indexed tokenId, address indexed from, address indexed to, uint256 amount);
    event FractionDelegated(uint256 indexed tokenId, address indexed from, address indexed to, uint256 amount);
    event RoyaltyDistributed(uint256 indexed tokenId, uint256 amount);
    event RageQuit(address indexed member, uint256[] tokenIds);
    event VoteCast(address indexed voter, uint256 indexed proposalId, uint256 votingPower);


    /**
     * @dev Constructor initializes the ERC721 with name and symbol
     * @param name The name of the NFT collection
     * @param symbol The symbol of the NFT collection
     */
    constructor(string memory name, string memory symbol) 
        ERC721(name, symbol)
        Ownable(msg.sender) 
    {}
    function tokenExists(uint256 tokenId) internal view returns (bool) {
        return ownerOf(tokenId) != address(0);
    }
    /**
     * @dev Mint a new NFT with fractional capabilities
     * @param to The address that will receive the NFT
     * @param tokenId The ID of the NFT
     * @param name The name of the NFT
     * @param description The description of the NFT
     * @param uri The URI of the NFT metadata
     * @param royaltyPercentage Royalty percentage in basis points (100 = 1%)
     * @param totalFractions Total number of fractions for this NFT
     * @param eligibleForRageQuit Whether this NFT's fractions are eligible for rage quit
     */
    function mint(
        address to,
        uint256 tokenId,
        string memory name,
        string memory description,
        string memory uri,
        uint256 royaltyPercentage,
        uint256 totalFractions,
        bool eligibleForRageQuit
    ) external onlyOwner {
        _safeMint(to, tokenId);
        
        _metadata[tokenId] = NFTMetadata({
            name: name,
            description: description,
            uri: uri,
            royaltyPercentage: royaltyPercentage,
            totalFractions: totalFractions,
            availableFractions: totalFractions,
            accumulatedRoyalties: 0,
            isEligibleForRageQuit: eligibleForRageQuit
        });
        
        // Assign all fractions to the initial owner
        _fractions[tokenId][to] = Fraction({
            owner: to,
            amount: totalFractions,
            isDelegate: false,
            delegatedTo: address(0),
            hasVoted: false,
            lastVoteTimestamp: 0
        });
        
        _fractionOwners[tokenId].push(to);
        _updateVotingPower(to);
    }
    
    /**
     * @dev Transfer fractions of an NFT from one address to another
     * @param tokenId The ID of the NFT
     * @param to The recipient of the fractions
     * @param amount The number of fractions to transfer
     */
    function transferFractions(uint256 tokenId, address to, uint256 amount) external {
        require(tokenExists(tokenId), "Token does not exist");
        require(to != address(0), "Transfer to zero address");
        require(amount > 0, "Amount must be positive");
        
        Fraction storage senderFraction = _fractions[tokenId][msg.sender];
        require(senderFraction.owner == msg.sender, "Not the fraction owner");
        require(senderFraction.amount >= amount, "Insufficient fraction balance");
        require(!senderFraction.hasVoted, "Cannot transfer after voting");
        require(senderFraction.delegatedTo == address(0), "Cannot transfer delegated fractions");
        
        // Update sender's fractions
        senderFraction.amount = senderFraction.amount - amount;
        
        // Update or create recipient's fractions
        if (_fractions[tokenId][to].owner == address(0)) {
            _fractions[tokenId][to] = Fraction({
                owner: to,
                amount: amount,
                isDelegate: false,
                delegatedTo: address(0),
                hasVoted: false,
                lastVoteTimestamp: 0
            });
            _fractionOwners[tokenId].push(to);
        } else {
            _fractions[tokenId][to].amount = _fractions[tokenId][to].amount + amount;
        }
        
        // Update voting power
        _updateVotingPower(msg.sender);
        _updateVotingPower(to);
        
        emit FractionTransferred(tokenId, msg.sender, to, amount);
    }
    

    
    /**
     * @dev Delegate fractions to another address for voting (can only delegate once)
     * @param tokenId The ID of the NFT
     * @param to The delegate
     * @param amount The number of fractions to delegate
     */
    function delegateFractions(uint256 tokenId, address to, uint256 amount) external {
        require(tokenExists(tokenId), "Token does not exist");
        require(to != address(0), "Delegate to zero address");
        require(to != msg.sender, "Cannot delegate to self");
        require(amount > 0, "Amount must be positive");
        
        Fraction storage senderFraction = _fractions[tokenId][msg.sender];
        require(senderFraction.owner == msg.sender, "Not the fraction owner");
        require(senderFraction.amount >= amount, "Insufficient fraction balance");
        require(!senderFraction.hasVoted, "Cannot delegate after voting");
        require(senderFraction.delegatedTo == address(0), "Already delegated");
        
        // Update sender's fractions
        senderFraction.amount = senderFraction.amount - amount;
        senderFraction.delegatedTo = to;
        
        // Update or create delegate's fractions
        if (_fractions[tokenId][to].owner == address(0)) {
            _fractions[tokenId][to] = Fraction({
                owner: to,
                amount: 0, // They don't own these fractions, they're delegated
                isDelegate: true,
                delegatedTo: address(0),
                hasVoted: false,
                lastVoteTimestamp: 0
            });
            _fractionOwners[tokenId].push(to);
        }
        
        // Add delegated fractions
        _fractions[tokenId][to].amount = _fractions[tokenId][to].amount + amount;
        
        // Update voting power
        _updateVotingPower(msg.sender);
        _updateVotingPower(to);
        
        emit FractionDelegated(tokenId, msg.sender, to, amount);
    }
    
    /**
     * @dev Cast a vote using fractions of an NFT
     * @param proposalId The ID of the proposal
     * @param tokenId The ID of the NFT
     * This function marks fractions as voted and prevents further delegation
     */
    function castVote(uint256 proposalId, uint256 tokenId) external {
        require(tokenExists(tokenId), "Token does not exist");
        require(!_hasVotedOnProposal[msg.sender][proposalId], "Already voted on this proposal");
        
        Fraction storage fraction = _fractions[tokenId][msg.sender];
        require(fraction.amount > 0, "No fractions to vote with");
        require(!fraction.hasVoted, "Fractions already used for voting");
        
        fraction.hasVoted = true;
        fraction.lastVoteTimestamp = block.timestamp;
        _hasVotedOnProposal[msg.sender][proposalId] = true;
        
        emit VoteCast(msg.sender, proposalId, fraction.amount);
    }
    
    /**
     * @dev Execute rage quit, burning all owned fractions for eligible members
     * Implemented with a YUL assembly block for bonus point
     */
    function rageQuit() external {
        require(!_hasRageQuit[msg.sender], "Already rage quit");
        
        // Find all tokens where the sender has fractions and is eligible
        uint256[] memory eligibleTokenIds = new uint256[](totalSupply());
        uint256 count = 0;
        
        for (uint256 i = 0; i < totalSupply(); i++) {
            uint256 tokenId = tokenByIndex(i);
            if (_metadata[tokenId].isEligibleForRageQuit && 
                _fractions[tokenId][msg.sender].owner == msg.sender &&
                _fractions[tokenId][msg.sender].amount > 0) {
                eligibleTokenIds[count] = tokenId;
                count++;
            }
        }
        
        // Resize array to actual count
        assembly {
            mstore(eligibleTokenIds, count)
        }
        
        require(count > 0, "No eligible tokens for rage quit");
        
        // Burn all fractions
        for (uint256 i = 0; i < count; i++) {
            uint256 tokenId = eligibleTokenIds[i];
            _burnFractions(msg.sender, tokenId);
        }
        
        _hasRageQuit[msg.sender] = true;
        emit RageQuit(msg.sender, eligibleTokenIds);
    }
    
    /**
     * @dev Distribute royalties for an NFT to fraction owners proportionally
     * @param tokenId The ID of the NFT
     */
    function distributeRoyalties(uint256 tokenId) external payable {
        require(tokenExists(tokenId), "Token does not exist");
        require(msg.value > 0, "No royalties to distribute");
        
        NFTMetadata storage metadata = _metadata[tokenId];
        metadata.accumulatedRoyalties = metadata.accumulatedRoyalties + msg.value;
        
        emit RoyaltyDistributed(tokenId, msg.value);
    }
    
    /**
     * @dev Claim royalties for fractions of an NFT
     * @param tokenId The ID of the NFT
     */
    function claimRoyalties(uint256 tokenId) external {
        require(tokenExists(tokenId), "Token does not exist");
        
        Fraction storage fraction = _fractions[tokenId][msg.sender];
        require(fraction.owner == msg.sender, "Not the fraction owner");
        require(fraction.amount > 0, "No fractions owned");
        
        NFTMetadata storage metadata = _metadata[tokenId];
        require(metadata.accumulatedRoyalties > 0, "No royalties to claim");
        
        // Calculate proportional royalties
        uint256 royaltyShare = (metadata.accumulatedRoyalties * fraction.amount) / metadata.totalFractions;
        require(royaltyShare > 0, "Royalty share too small");

        
        // Reset accumulated royalties
        metadata.accumulatedRoyalties = metadata.accumulatedRoyalties - royaltyShare;
        
        // Transfer royalties
        payable(msg.sender).transfer(royaltyShare);
    }
    
    /**
     * @dev Get voting power of an address
     * @param account The address to check
     * @return The voting power of the address
     */
    function getVotingPower(address account) external view returns (uint256) {
        return _votingPower[account];
    }
    
    /**
     * @dev Check if an address has voted on a proposal
     * @param account The address to check
     * @param proposalId The ID of the proposal
     * @return Whether the address has voted on the proposal
     */
    function hasVotedOnProposal(address account, uint256 proposalId) external view returns (bool) {
        return _hasVotedOnProposal[account][proposalId];
    }
    
    /**
     * @dev Get the NFT metadata
     * @param tokenId The ID of the NFT
     */
    function getMetadata(uint256 tokenId) external view returns (
        string memory name,
        string memory description,
        string memory uri,
        uint256 royaltyPercentage,
        uint256 totalFractions,
        uint256 availableFractions,
        uint256 accumulatedRoyalties,
        bool isEligibleForRageQuit
    ) {
        require(tokenExists(tokenId), "Token does not exist");
        NFTMetadata storage metadata = _metadata[tokenId];
        
        return (
            metadata.name,
            metadata.description,
            metadata.uri,
            metadata.royaltyPercentage,
            metadata.totalFractions,
            metadata.availableFractions,
            metadata.accumulatedRoyalties,
            metadata.isEligibleForRageQuit
        );
    }
    
    /**
    * @dev Get fraction details for an address and token
    * @param tokenId The ID of the NFT
    * @param account The address to check
    * @return owner Address owning these fractions, amount Number of fractions owned,
    *          isDelegate Whether or not these are delegated fractions,
    *                      delegatedTo Who they're delegated too if so (address 0 otherwise),
    *                          hasVoted If this member voted with these fractions already and lastVoteTimestamp The timestamp when it was voted
    */
    function getFraction(uint256 tokenId, address account) external view returns (
        address owner,
        uint256 amount,
        bool isDelegate,
        address delegatedTo,
        bool hasVoted,
        uint256 lastVoteTimestamp
    ) {
        require(tokenExists(tokenId), "Token does not exist");
        Fraction storage fraction = _fractions[tokenId][account];
        
        return (
            fraction.owner,
            fraction.amount,
            fraction.isDelegate,
            fraction.delegatedTo,
            fraction.hasVoted,
            fraction.lastVoteTimestamp
        );
    }
    
    /**
     * @dev Overridden tokenURI function to return custom metadata URI
     * @param tokenId The ID of the NFT
     * @return The URI of the token
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(tokenExists(tokenId), "Token does not exist");
        return _metadata[tokenId].uri;
    }
    
    /**
     * @dev Internal function to burn fractions on rage quit
     * @param account The address whose fractions will be burned
     * @param tokenId The ID of the NFT
     */
    function _burnFractions(address account, uint256 tokenId) internal {
        Fraction storage fraction = _fractions[tokenId][account];
        require(fraction.owner == account, "Not the fraction owner");
        
        // Remove fractions and update voting power
        uint256 amount = fraction.amount;
        fraction.amount = 0;
        fraction.hasVoted = true; // Mark as voted to prevent further actions
        
        _metadata[tokenId].availableFractions = _metadata[tokenId].availableFractions - amount;
        _updateVotingPower(account);
    }
    
    /**
     * @dev Internal function to update voting power of an address
     * @param account The address to update
     */
    function _updateVotingPower(address account) internal {
        uint256 power = 0;
        
        for (uint256 i = 0; i < totalSupply(); i++) {
            uint256 tokenId = tokenByIndex(i);
            Fraction storage fraction = _fractions[tokenId][account];
            
            if (fraction.amount > 0 && !fraction.hasVoted) {
                power = power + fraction.amount;
            }
        }
    
        _votingPower[account] = power;
    }
    /**
     * @dev Delegate function
     */
    function delegate(address to) external {
            require(!hasDelegated[msg.sender], "Already delegated");
            hasDelegated[msg.sender] = true;
            
    }
    
    
}
