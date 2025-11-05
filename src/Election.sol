// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IBallot} from "./ballots/interface/IBallot.sol";
import {IResultCalculator} from "./resultCalculators/interface/IResultCalculator.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * @title Election Contract
 * @author KartikC137
 *
 * This Contract Manages each Election created by the ElectionFactory.
 * It handles the voting process, candidate management, and result calculation.
 *
 * @notice Cross - chain voting is not yet implemented
 */

contract Election is Initializable {
    //////////////////
    // Errors      ///
    //////////////////

    error Election_NotOwner();
    error Election_AlreadyVoted();
    error Election_InvalidVoteArrayLength();
    error Election_VotesUnavailable();
    error Election_ElectionInactive();
    error Election_ElectionActive();
    error Election_ElectionEnded();
    error Election_InvalidCandidateID();
    error Election_InvalidCandidatesLength();
    error Election_CandidateAlreadyRemoved(uint256 candidateId);
    error Election_ResultsHaveAlreadyBeenDeclared(uint256[] winners);

    ////////////////////////////
    // Types Declarations    ///
    ////////////////////////////

    struct ElectionInfo {
        uint64 startTime;
        uint64 endTime;
        string name;
        string description;
    }

    struct Candidate {
        uint256 candidateId;
        string name;
        string description;
    }

    ////////////////////////
    // State Variables   ///
    ////////////////////////

    IBallot private ballot;
    IResultCalculator private resultCalculator;

    ElectionInfo public electionInfo;
    Candidate[] public candidates;

    mapping(address user => bool isVoted) public usersToIsVoted;

    address public factoryContractAddress;
    address public owner;

    uint256[] public winners;
    uint256 public electionId;
    uint256 public resultType;
    uint256 public totalVoters;

    bool private isElectionEnded;
    bool public isResultsDeclared;
    bool private isBallotInitialized;

    //////////////
    // Events  ///
    //////////////

    event AddCandidate(string indexed name, string indexed description);
    event RemoveCandidate(uint256 indexed candidateId);
    event CastVote(address indexed voter);
    event CalculateFinalResult();
    event EndElection();

    //////////////////
    // Modifiers   ///
    //////////////////

    modifier onlyOwner() {
        if (msg.sender != owner) revert Election_NotOwner();
        _;
    }

    modifier electionInactiveCheck() {
        if (block.timestamp < electionInfo.startTime)
            revert Election_ElectionInactive();
        _;
    }

    modifier electionStartedCheck() {
        if (block.timestamp > electionInfo.startTime) revert Election_ElectionActive();
        _;
    }

    modifier electionEndedCheck() {
        if ((block.timestamp > electionInfo.endTime) || isElectionEnded)
            revert Election_ElectionEnded();
        _;
    }

    //////////////////
    // Functions   ///
    //////////////////

    ///////////////////////////
    // External Functions   ///
    ///////////////////////////

    function initialize(
        ElectionInfo memory _electionInfo,
        Candidate[] memory _candidates,
        uint256 _resultType,
        uint256 _electionId,
        address _ballot,
        address _owner,
        address _resultCalculator
    ) external initializer {
        electionInfo = _electionInfo;
        uint256 _totalCandidates = _candidates.length;

        if (_totalCandidates < 2) revert Election_InvalidCandidatesLength();

        for (uint256 i = 0; i < _totalCandidates; i++) {
            candidates.push(
                Candidate(i, _candidates[i].name, _candidates[i].description)
            );
        }
        resultType = _resultType;
        electionId = _electionId;
        owner = _owner;
        factoryContractAddress = msg.sender;
        ballot = IBallot(_ballot);
        resultCalculator = IResultCalculator(_resultCalculator);
    }

    function userVote(
        uint256[] memory voteArr
    ) external electionInactiveCheck electionEndedCheck {
        if(voteArr.length > candidates.length) revert Election_InvalidVoteArrayLength();
        if (usersToIsVoted[msg.sender]) revert Election_AlreadyVoted();
        if (isBallotInitialized == false) {
            ballot.init(candidates.length);
            isBallotInitialized = true;
        }
        
        usersToIsVoted[msg.sender] = true;
        totalVoters++;

        emit CastVote(msg.sender);
        
        ballot.vote(voteArr);
    }

    function addCandidate(
        string calldata _name,
        string calldata _description
    ) external onlyOwner electionStartedCheck electionEndedCheck {
        emit AddCandidate(_name, _description);

        Candidate memory newCandidate = Candidate(
            candidates.length,
            _name,
            _description
        );
        candidates.push(newCandidate);
    }

    function removeCandidate(
        uint256 _id
    ) external onlyOwner electionStartedCheck electionEndedCheck {
        uint256 totalCandidates = candidates.length;

        if (_id >= totalCandidates) revert Election_InvalidCandidateID();
        if (totalCandidates <= 2) revert Election_InvalidCandidatesLength();

        emit RemoveCandidate(_id);

        for (uint256 i = _id; i < totalCandidates - 1; i++) {
            candidates[i] = candidates[i + 1];
            candidates[i].candidateId = i;
        }

        candidates.pop();
    }

    function endElection() external onlyOwner {
        emit EndElection();
        _calculateResult();
        _endElection();
    }

    function calculateFinalResult() external electionEndedCheck {
        emit CalculateFinalResult();
        _calculateResult();
    }

    ///////////////////////////////////
    // Private & Internal Functions ///
    ///////////////////////////////////

    function _getTotalVotes() internal view returns (bytes memory) {

        bytes memory payload = abi.encodeWithSignature("getVotes()");

        (bool success, bytes memory totalVotes) = address(ballot).staticcall(
            payload
        );
        if (!success) revert Election_VotesUnavailable();

        return totalVotes;
    }

    function _calculateResult() internal {
        if (isResultsDeclared) revert Election_ResultsHaveAlreadyBeenDeclared(winners);
        bytes memory totalVotes = _getTotalVotes();
        uint256[] memory _winners = resultCalculator.getResults(
            totalVotes,
            resultType
        );
        winners = _winners;
        isResultsDeclared = true;
    }

    function _endElection() internal {
        isElectionEnded = true;
    }

    ////////////////////////////////////////
    // Public & External View Functions  ///
    ////////////////////////////////////////

    function getElectionStatus() external view returns (bool) {
        return isElectionEnded;
    }

    function getTotalNoOfVotes() external view returns (uint256) {
        return totalVoters;
    }

    function getElectionWinners() external view returns (uint256[] memory) {
        return winners;
    }

    function getCandidateList() external view returns (Candidate[] memory) {
        return candidates;
    }

    function getWinners() external view returns (uint256[] memory) {
        return winners;
    }
}
