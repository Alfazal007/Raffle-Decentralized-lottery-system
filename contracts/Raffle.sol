// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;


import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/automation/interfaces/KeeperCompatibleInterface.sol"; // for checkUpkeep and performUpKeep

error Raffle__NotEnoughEthEntered();
error Raffle__TransferFailed();
error Raffle__NotOpen();
error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);


contract Raffle is VRFConsumerBaseV2, KeeperCompatibleInterface {

    enum RaffleState {
        OPEN,
        CALCULATING
    }



    // State variables
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callBackGasLimit;
    uint32 private constant NUM_WORDS = 1;
    RaffleState private s_raffleState;


    address private s_recentWinner;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;
    
    event RaffleEnter(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);


    constructor(address vrfCoordinatorV2, uint256 entranceFee, bytes32 gasLane, uint64 subscriptionId, uint32 callBackGasLimit, uint256 interval) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callBackGasLimit = callBackGasLimit;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_interval = interval;
    }

    // pay money get added to players array if state is open
    function enterRaffle() public payable {
        // require(msg.value >= i_entranceFee, "Not enough eth")  string takes more gas
        if(msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthEntered();
        }
        if(s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEnter(msg.sender);
    }

    // this runs at specific timeframes (automated tasks)
    // used to select new winner of lottery
    function performUpkeep(bytes calldata /* performData */) external override { // will be called by the checkUpKeep
        // request random number
        // once we get it, do something with it
        // 2 transaction process
        (bool upkeepNeeded,) = checkUpkeep("");

        if(!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, // max price in gas in wei
            i_subscriptionId,
            REQUEST_CONFIRMATIONS, // reequest confirmations
            i_callBackGasLimit,
            NUM_WORDS
        ); // this function returns new winner0 via random number generation this internally calls
        // fulfillRandomWords which we have overriden
        // performUpkeep -> requestRandomWords -> fulfillRandomWords
        emit RequestedRaffleWinner(requestId);
    }

    // random number generated this will handle the rest
    // logic to reinitialize and send money and stuff
    function fulfillRandomWords( // will be called internally after user calls requestRandomWinner
        uint256 /*requestId*/, 
        uint256[] memory randomWords) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if(!success) {
            revert Raffle__TransferFailed();
        }
        emit WinnerPicked(recentWinner);
    }

    // if it returns true then re run lottery
    function checkUpkeep(bytes memory /* checkData */ ) public override returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool isOpen = (RaffleState.OPEN == s_raffleState);
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = (s_players.length > 0);
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
    }


    function getPlayer(uint256 index) public view returns(address) {
        return s_players[index];
    }


    function getRecentWinner() public view returns(address) {
        return s_recentWinner;
    }
    
    
    function getEntranceFee() public view returns(uint256) {
        return i_entranceFee;
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


    function getInterval() public view returns (uint256) {
        return i_interval;
    }

}