// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";



    error Raffle__NotEnoughEthEntered();
    error Raffle__TransferFailed();
    error Raffle__NotOpen();
    error t initRaffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);

contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
enum RaffleState {
OPEN,
CALCULATING
}

uint256 private immutable i_entranceFee;
VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
address payable[] private s_players;
bytes32 private immutable i_gasLane;
uint32 private immutable i_callbackGasLimit;
uint64 private immutable i_subscriptionId;
uint256 private immutable i_interval;
uint256 private s_lastTimeStamp;
uint16 private constant REQUEST_CONFIRMATIONS = 3;
uint32 private constant NUM_WORDS = 1;
RaffleState private s_raffleState;

address private s_recentWinner;

event RaffleEnter(address indexed player);
event RequestedRaffleWinner(uint256 indexed requestId);
event WinnerPicked(address indexed recentWinner);

constructor(address vrfCoordinatorV2, bytes32 gasLane, uint256 entranceFee, uint32 callbackGasLimit, uint64 subscriptionId, uint256 interval) VRFConsumerBaseV2(vrfCoordinatorV2) {
i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
i_gasLane = gasLane;
i_entranceFee = entranceFee;
i_callbackGasLimit = callbackGasLimit;
i_subscriptionId = subscriptionId;
s_raffleState = RaffleState.OPEN;
s_lastTimeStamp = block.timestamp;
i_interval = interval;
}

function enterRaffle() public payable {
if (msg.value < i_entranceFee) {
revert Raffle__NotEnoughEthEntered();
}
if (s_raffleState != RaffleState.OPEN) {
revert Raffle__NotOpen();
}

s_players.push(payable(msg.sender));

emit RaffleEnter(msg.sender);
}

function performUpkeep(bytes calldata /* performData */) external override {
(bool upkeepNeeded,) = checkUpkeep("");

if (!upkeepNeeded) {
revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
}
s_raffleState = RaffleState.CALCULATING;
uint256 requestId = i_vrfCoordinator.requestRandomWords(
i_gasLane,
i_subscriptionId,
REQUEST_CONFIRMATIONS,
i_callbackGasLimit,
NUM_WORDS
);

emit RequestedRaffleWinner(requestId);
}

function checkUpkeep(bytes memory /* checkdata */) public view override returns (bool upkeepNeeded, bytes memory /* performData */) {
bool isOpen = (RaffleState.OPEN == s_raffleState);
bool timePassed = (block.timestamp - s_lastTimeStamp) > i_interval;
bool hasPlayers = s_players.length > 0;
bool hasBalance = address(this).balance > 0;

upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
}


function fulfillRandomWords(uint256 /* requestId */, uint256[] memory randomWords) internal override {
uint256 indexOfWinner = randomWords[0] % s_players.length;
address payable recentWinner = s_players[indexOfWinner];
s_recentWinner = recentWinner;
s_raffleState = RaffleState.OPEN;
s_players = new address payable[](0);
s_lastTimeStamp = block.timestamp;

(bool success,) = recentWinner.call{value : address(this).balance}("");
if (!success) {
revert Raffle__TransferFailed();
}
emit WinnerPicked(recentWinner);
}

function getEntranceFee() public view returns (uint256)  {
return i_entranceFee;
}

function getPlayer(uint256 index) public view returns (address) {
return s_players[index];
}

function getRecentWinner() public view returns (address) {
return s_recentWinner;
}

function getRaffleState() public view returns (RaffleState) {
return s_raffleState;
}

function getNumWords() public pure returns (uint256) {
return NUM_WORDS;
}

function getNumberOfPlayers() public view returns (uint256) {
return s_players.length;
}

function getLastTimeStamp() public view returns (uint256) {
return s_lastTimeStamp;
}

function getRequestConfirmations() public pure returns (uint256) {
return REQUEST_CONFIRMATIONS;
}
}
