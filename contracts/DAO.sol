//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./Token.sol";

contract DAO {
    address owner;
    Token public token;
    uint256 public quorum;

    struct Proposal {
        uint256 id;
        string name;
        uint256 amount;
        address payable recipient;
        int256 votes;
        bool finalized;
    }

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;

    mapping(address => mapping(uint256 => bool)) votes;

    event Propose(
        uint id,
        uint256 amount,
        address recipient,
        address creator
    );
    event Vote(uint256 id, address investor);
    event Finalize(uint256 id);

    constructor(Token _token, uint256 _quorum) {
        owner = msg.sender;
        token = _token;
        quorum = _quorum;
    }

    // Allow contract to receive ether
    receive() external payable {}

    // Allow contract to receive tokens
    function receiveTokens(uint256 amount, address from) external {
        token.transferFrom(from, address(this), amount);
    }

    modifier onlyInvestor() {
        require(
            token.balanceOf(msg.sender) > 0,
            "must be token holder"
        );
        _;
    }


    // Create proposal
    function createProposal(
        string memory _name,
        uint256 _amount,
        address payable _recipient,
        string memory _description
    ) external onlyInvestor {
        require(token.balanceOf(address(this)) >= _amount);
        require((bytes(_description)).length != 0);

        proposalCount++;

        proposals[proposalCount] = Proposal(
            proposalCount,
            _name,
            _amount,
            _recipient,
            0,
            false
        );

        emit Propose(
            proposalCount,
            _amount,
            _recipient,
            msg.sender
        );
    }

    // Vote on proposal
    function vote(uint256 _id, bool aye) external onlyInvestor {
        // Fetch proposal from mapping by id
        Proposal storage proposal = proposals[_id];

        // Don't let investors vote twice
        require(!votes[msg.sender][_id], "already voted");

        // update votes
        if(aye){
            proposal.votes += int256(token.balanceOf(msg.sender));
        }
        else{
            proposal.votes -= int256(token.balanceOf(msg.sender));

        }

        // Track that user has voted
        votes[msg.sender][_id] = true;

        // Emit an event
        emit Vote(_id, msg.sender);
    }

    // Finalize proposal & tranfer funds
    function finalizeProposal(uint256 _id) external onlyInvestor {
        // Fetch proposal from mapping by id
        Proposal storage proposal = proposals[_id];

        // Ensure proposal is not already finalized
        require(proposal.finalized == false, "proposal already finalized");

        // Mark proposal as finalized
        proposal.finalized = true;

        // Check that proposal has enough votes
        require(proposal.votes >= int256(quorum), "must reach quorum to finalize proposal");

        // Check that the contract has enough ether
        require(token.balanceOf(address(this)) >= proposal.amount);

        // Transfer the funds to recipient
        bool sent = token.transfer(proposal.recipient, proposal.amount);
        require(sent);

        // Emit event
        emit Finalize(_id);
    }

}
