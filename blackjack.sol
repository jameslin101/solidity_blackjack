pragma solidity ^0.4.16;

contract owned {
    address public owner;

    function owned() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner public {
        owner = newOwner;
    }
}

contract mortal is owned{
  function close() onlyOwner {
        selfdestruct(owner);
    }
}
contract blackjack is mortal {
    
    enum Entity { Player, Dealer }
    enum GameResult { PlayerWins, DealerWins, Push, PlayerBlackJack }

    uint256 minBet;
    uint256 maxBet;
    
    mapping (address => uint) public playerBetValue;
    mapping (address => uint8) public dealersHandValue;
    mapping (address => uint8) public playersHandValue;
    mapping (address => bool) public dealerHasAce;
    mapping (address => bool) public playerHasAce;
    
    uint256 numberOfGamesInProgress;
    uint256 nonce;
    
    event onNewGame(address player, uint bet);
    event onDealCard(address player, Entity toEntity, uint8 card);
    event onGameOver(address player, uint8 playerScore, uint8 dealerScore, GameResult result);
    
    constructor () payable public {
        minBet = .009 ether;
        maxBet = 2 ether;
    }
    
    function () payable public {}
        
    function startGame() payable public {
        require(msg.value >= minBet);
        require(msg.value <= maxBet);
        require(this.balance >= (numberOfGamesInProgress + 1) * maxBet * 2);
        require(dealersHandValue[msg.sender] == 0);

        emit onNewGame(msg.sender, msg.value);
        playerBetValue[msg.sender] = msg.value;
        numberOfGamesInProgress++;
        
        dealCard(Entity.Dealer);
        dealCard(Entity.Player);
        dealCard(Entity.Player);
    }
    
    function dealCard(Entity entity) internal {
        uint8 card = randomNumber(13); //[1-13]
        uint8 cardValue = card;
        if (cardValue > 10) { //J, Q, K
            cardValue = 10;
        }
        if (entity == Entity.Player) {
            playersHandValue[msg.sender] += cardValue;
            
            if (cardValue == 1) { 
                playerHasAce[msg.sender];
            }

            if (doesPlayerHave21()) {
                gameOver(GameResult.PlayerBlackJack);
            }

        } else {
            dealersHandValue[msg.sender] += cardValue;
            
            if (cardValue == 1) { 
                dealerHasAce[msg.sender];
            }
            
        }
        
        emit onDealCard(msg.sender, entity, card);
    }
    
    function randomNumber(uint8 max) internal returns (uint8 result) {
        nonce++;
        uint256 value = uint(keccak256(now, blockhash(block.number - 1), nonce));
        return uint8(value % max + 1);
    }
    
    function hit() public {
        require(dealersHandValue[msg.sender] != 0);
        dealCard(Entity.Player);
        
        if(hasPlayerBusted()) {
            gameOver(GameResult.DealerWins);
        } else if(doesPlayerHave21()) {
            stand();
        }
    }
    
    function hasPlayerBusted() internal view returns (bool playerBusted) {
        return playersHandValue[msg.sender] > 21;
    }
    
    function doesPlayerHave21() internal view returns (bool playerHas21) {
        if(playersHandValue[msg.sender] == 21) {
            return true;
        }
        if(playersHandValue[msg.sender]==11
            && playerHasAce[msg.sender]) {
            return true;
        }
        return false;
    }
    
    function stand() public {
        require(dealersHandValue[msg.sender] != 0);
        
        while(dealersHandValue[msg.sender] <= 16) {
            if(dealerHasAce[msg.sender]
                && dealersHandValue[msg.sender] > 7
                && dealersHandValue[msg.sender] <= 11) {
                    break;
                }
            dealCard(Entity.Dealer);
        }
        uint8 dealerScore = dealersHandValue[msg.sender];
        if(dealerScore <= 11
            && dealerHasAce[msg.sender]) {
                dealerScore += 10;
            }
        if(dealerScore > 21) {
            gameOver(GameResult.PlayerWins);
        } else {
            uint8 playerScore = playersHandValue[msg.sender];
            if(playerScore <= 11
                && playerHasAce[msg.sender]) {
                    playerScore += 10;
                }
            if(playerScore > dealerScore) {
                gameOver(GameResult.PlayerWins);
            } else if (playerScore < dealerScore) {
                gameOver(GameResult.DealerWins);
            } else {
                gameOver(GameResult.Push);
            }
        }
    }
    function gameOver(GameResult result) internal {
        
        numberOfGamesInProgress--;
        
        if(result  == GameResult.PlayerWins) {
            msg.sender.transfer(playerBetValue[msg.sender] * 2);
        } else if(result == GameResult.Push) {
            msg.sender.transfer(playerBetValue[msg.sender]);
        } else if(result == GameResult.PlayerBlackJack) {
            //blackjack pays 1.5x
            uint256 half_bet = playerBetValue[msg.sender] / 2;
            msg.sender.transfer(playerBetValue[msg.sender] * 2 + half_bet);
        }
        
        emit onGameOver(msg.sender, playersHandValue[msg.sender], dealersHandValue[msg.sender], result);
        playerBetValue[msg.sender] = 0;
        dealersHandValue[msg.sender] = 0;
        playersHandValue[msg.sender] = 0;
        dealerHasAce[msg.sender] = false;
        playerHasAce[msg.sender] = false;
    }

    function withdraw(uint256 howMuchToWithdraw) public onlyOwner {
        require(this.balance >= numberOfGamesInProgress * maxBet * 2 + howMuchToWithdraw);
        owner.transfer(howMuchToWithdraw);
    }    
}
