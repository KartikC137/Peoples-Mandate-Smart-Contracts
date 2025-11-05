// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IWorldID} from "./interface/IWorldID.sol";
import {Election} from "./Election.sol";
import {BallotGenerator} from "./ballots/BallotGenerator.sol";
import {ResultCalculator} from "./resultCalculators/ResultCalculator.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

/**
 * @title Election Factory Contract v1.0
 * @author
 * This Contract Handles Creation of Elections.
 *
 * @notice
 * 1. Cross - chain voting is not yet implemented
 *
 */
contract ElectionFactory {
    //////////////////
    // Errors      ///
    //////////////////

    error ElectionFactory_FactoryOwnerRestricted();
    error ElectionFactory_InvalidCandidatesLength(uint256 candidateLength);

    ////////////////////////
    // State Variables   ///
    ////////////////////////

    uint256 public electionCount = 0;
    address public factoryOwner;

    address[] public publicElections;

    mapping(uint256 electionId => address owner) private electionIdToOwner;
    mapping(address owner => address[] electionAddresses) public ownerToElections;

    address private immutable RESULT_CALCULATOR_ADDRESS;
    address private immutable ELECTION_GENERATOR_ADDRESS;
    BallotGenerator private immutable BALLOT_GENERATOR;
    IWorldID private immutable WORLD_ID;

    //////////////
    // Events  ///
    //////////////

    event ElectionCreated(
        address indexed creator, Election.ElectionInfo indexed electionInfo, Election.Candidate[] indexed candidates
    );

    //////////////////
    // Modifiers   ///
    //////////////////

    modifier onlyOwner() {
        if (msg.sender != factoryOwner) revert ElectionFactory_FactoryOwnerRestricted();
        _;
    }

    //////////////////
    // Functions   ///
    //////////////////

    constructor() {
        factoryOwner = msg.sender;
        ELECTION_GENERATOR_ADDRESS = address(new Election());
        BALLOT_GENERATOR = new BallotGenerator();
        RESULT_CALCULATOR_ADDRESS = address(new ResultCalculator());
        WORLD_ID = IWorldID(0x469449f251692E0779667583026b5A1E99512157);
    }

    ///////////////////////////
    // External Functions   ///
    ///////////////////////////

    function createElection(
        string memory _appId,
        string memory _action,
        Election.ElectionInfo memory _electionInfo,
        Election.Candidate[] memory _candidates,
        uint256 _ballotType,
        uint256 _resultType
    ) external returns (address) {
        if (_candidates.length < 2) {
            revert ElectionFactory_InvalidCandidatesLength(_candidates.length);
        }

        address electionAddress = Clones.clone(ELECTION_GENERATOR_ADDRESS);
        address _ballot = BALLOT_GENERATOR.generateBallot(_ballotType, electionAddress);

        Election election = Election(electionAddress);
        election.initialize(
            WORLD_ID,
            _appId,
            _action,
            _electionInfo,
            _candidates,
            _resultType,
            electionCount,
            _ballot,
            msg.sender,
            RESULT_CALCULATOR_ADDRESS
        );

        emit ElectionCreated(msg.sender, _electionInfo, _candidates);

        electionIdToOwner[electionCount] = msg.sender;
        publicElections.push(electionAddress);
        ownerToElections[msg.sender].push(electionAddress);
        electionCount++;

        return electionAddress;
    }

    //////////////////////////////////////////////////
    // Public & External Functions View Functions  ///
    //////////////////////////////////////////////////

    function getElectionCount() external view returns (uint256) {
        return electionCount;
    }

    function getFactoryOwner() external view returns (address) {
        return factoryOwner;
    }

    function getElectionOwner(uint256 electionId) external view returns (address) {
        return electionIdToOwner[electionId];
    }

    function getElectionAddress(uint256 electionId) external view returns (address) {
        return publicElections[electionId];
    }
}
