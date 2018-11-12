pragma solidity ^0.4.23;

import './SafeMath.sol';

contract LuckyWallet {
    using SafeMath for uint256;

    uint256 public constant INTERVAL_TIME = 2 hours;
    uint256 public constant JACKPOT_INTERVAL_TIME = 1 days;
    uint256 public constant PERCENT_REWARD_TO_JACKPOT = 18;
    uint256 public constant PERCENT_REWARD_TO_DONATE = 2;
    uint256 public constant DEPOSIT_AMOUNT = 0.01 * (10 ** 18);

    address public owner;
    address public lastWinner;
    uint256 public lastWinnerAmount = 0;
    address public lastWinnerJackpot;
    uint256 public lastWinnerJackpotAmount = 0;
    uint256 public amountNTYRound = 0;
    uint256 public amountNTYJackpot = 0;
    uint256 public roundTime;
    uint256 public jackpotTime;
    uint256 public countPlayerRound = 0;
    uint256 public countPlayerJackpot = 0;
    uint256 public countRound = 0;
    uint256 public countJackpot = 0;
    uint256 private _seed;

    struct Player {
        address wallet;
        bool playing;
        bool playingJackpot;
    }

    Player[] public players;

    event DepositSuccess(address _from, uint256 _amount);
    event RewardRoundWiner(address _to, uint256 _amount);
    event RewardJackpotWiner(address _to, uint256 _amount);

    function LuckyWallet() public {
        owner = msg.sender;
        roundTime = now.add(INTERVAL_TIME);
        jackpotTime = now.add(JACKPOT_INTERVAL_TIME);
    }

    /**
    * Throws if called by any account other than the owner.
    */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    /**
    * Deposit from player
    */
    function deposit() external payable {
        require(msg.value >= DEPOSIT_AMOUNT);
        countPlayerRound = countPlayerRound.add(1);
        countPlayerJackpot = countPlayerJackpot.add(1);

        players.push(Player({
            wallet: msg.sender,
            playing: true,
            playingJackpot: true
        }));

        amountNTYRound = amountNTYRound.add(msg.value);
        emit DepositSuccess(msg.sender, msg.value);

        if (now >= roundTime && amountNTYRound > 0 && countPlayerRound > 1) {
            roundTime = now.add(INTERVAL_TIME);
            executeRound();
        }

        if (now >= jackpotTime && amountNTYJackpot > 0 && countPlayerJackpot > 1) {
            jackpotTime = now.add(JACKPOT_INTERVAL_TIME);
            executeJackpot();
        }
    }

    function executeRound() private {
        uint256 count = 0;
        address winner;
        uint256 luckyNumber = generateLuckyNumber(countPlayerRound);

        for (uint256 i = 0; i < players.length; i++) {
            if (players[i].playing) {
                count = count.add(1);
                if (count == luckyNumber) {
                    winner = players[i].wallet;
                }
                players[i].playing = false;
            }
        }

        countRound = countRound.add(1);
        uint256 donate = amountNTYRound.mul(PERCENT_REWARD_TO_DONATE).div(100);
        uint256 amountToJackpot = amountNTYRound.mul(PERCENT_REWARD_TO_JACKPOT).div(100);
        uint256 reward = amountNTYRound.sub(donate.add(amountToJackpot));

        amountNTYJackpot = amountNTYJackpot.add(amountToJackpot);
        lastWinnerAmount = reward;
        lastWinner = winner;
        amountNTYRound = 0;
        countPlayerRound = 0;

        winner.transfer(reward);
        owner.transfer(donate);
        emit RewardRoundWiner(lastWinner, lastWinnerAmount);
    }

    function executeJackpot() private {
        uint256 count = 0;
        address winner;
        uint256 luckyNumber = generateLuckyNumber(countPlayerJackpot);

        for (uint256 i = 0; i < players.length; i++) {
            if (players[i].playingJackpot) {
                count = count.add(1);
                if (count == luckyNumber) {
                    winner = players[i].wallet;
                }
                players[i].playing = false;
            }
        }

        uint256 donate = amountNTYJackpot.mul(PERCENT_REWARD_TO_DONATE).div(100);
        uint256 reward = amountNTYJackpot.sub(donate);

        lastWinnerJackpotAmount = reward;
        lastWinnerJackpot = winner;
        countJackpot = countJackpot.add(1);
        amountNTYJackpot = 0;
        countPlayerJackpot = 0;
        delete players;

        owner.transfer(donate);
        winner.transfer(reward);
        emit RewardJackpotWiner(lastWinnerJackpot, lastWinnerJackpotAmount);
    }

    function maxRandom() public returns (uint256 number) {
        _seed = uint256(keccak256(
            _seed,
            block.blockhash(block.number - 1),
            block.coinbase,
            block.difficulty,
            players.length,
            countPlayerJackpot,
            countPlayerRound,
            lastWinnerJackpotAmount,
            lastWinnerJackpot,
            lastWinnerAmount,
            lastWinner,
            now
        ));

        return _seed;
    }

    function generateLuckyNumber(uint256 maxNumber) private returns (uint256 number) {
        return (maxRandom() % maxNumber) + 1;
    }

    /**
    * Allows the current owner to transfer control of the contract to a newOwner.
    * _newOwner The address to transfer ownership to.
    */
    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != owner);
        require(_newOwner != address(0x0));

        owner = _newOwner;
    }
}
