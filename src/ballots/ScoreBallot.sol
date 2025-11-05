// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IBallot} from "./interface/IBallot.sol";

contract ScoreBallot is IBallot {
    error InvalidScore(uint score);
    address public electionContract;

    uint[] private candidateScores;
    uint public constant MAX_SCORE = 10;

    modifier onlyOwner() {
        if (msg.sender != electionContract) revert UnathourizedBallot();
        _;
    }

    constructor(address _electionAddress) {
        electionContract = _electionAddress;
    }

    function init(uint totalCandidate) external onlyOwner {
        candidateScores = new uint[](totalCandidate);
    }

    // Assign scores on index
    function vote(uint[] memory voteArr) external onlyOwner {
        uint totalCandidates = candidateScores.length;
        if (voteArr.length != totalCandidates) revert VoteInputLength();

        for (uint i = 0; i < totalCandidates; i++) {
            uint preference = voteArr[i];
            if (preference > MAX_SCORE) {
                revert InvalidScore(preference);
            }
            candidateScores[i] += preference;
        }
    }

    function getVotes() external view onlyOwner returns (uint256[] memory) {
        return candidateScores;
    }
}
