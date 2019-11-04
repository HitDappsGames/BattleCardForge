pragma solidity ^0.4.24;

contract KingStoneGame{

    using SafeMath for *;
    
    
    address public HOUSE_ADDRESS = 0x68EB4F9844db6DE41E5dfE89B1639569E90fadd5;
    address public ADMIN = 0x68EB4F9844db6DE41E5dfE89B1639569E90fadd5;
    address public owner;
  
    uint public totalMatchStarted;
    uint public totalMatchCompleted;
    
    uint matchFee = 1e14;
    

    // Match STATUS
    uint32 EMPTY_STATUS = 0;
    uint32 MATCH_CREATED = 1;
    uint32 MATCH_CONFIRMED = 2;
    uint32 MATCH_STARTED = 3;
    uint32 MATCH_COMPLETED = 4;
    uint32 MATCH_ABANDONED = 5;
    uint32 MATCH_REVOKED = 6;
    
    
    // MATCH TYPES
    uint32 FREE_MATCH = 1;
    uint32 PAID_MATCH = 2;
    
    
    constructor() public{
        owner = msg.sender;
    }

   
    struct Player{
        uint totalEarning;
        uint totalExpanse;
        uint totalFreeMatchPlayed;
        uint totalPaidMatchPlayed;
        uint matchCompleted;
        uint matchAbandoned;
    }
    
    
    struct Match{
        address player_1;
        address player_2;
        uint startTime;
        uint endTime;
        address winner;
        uint totalTurn;
        address currentTurn;
        uint32 matchStatus;
        uint32 matchType;
        uint32 confirmations;
        bool player_1_confirmed;
        bool player_2_confirmed;
        uint potAmount;
        address abandonedBy;
    }
    
   
    
    //data strcts
    mapping (address => Player) public Players;       
  

    //match mapping
    mapping (uint => Match) public Matches;
 
    
    event PaymentSuccess(address indexed beneficiary, uint amount,string sendfor);
    event FailedPayment(address indexed beneficiary, uint amount,string sendfor);
    event MatchFeeChanged(uint amount);
    event NewMatch(uint matchID,address indexed player_1,address indexed player_2);
    event EndTurn(uint matchID,address indexed endedBy);
    event MatchConfirmed(uint matchID,address indexed confirmedBy);
    event MatchStarted(uint matchID,uint32 tossResult);
    event MatchCompleted(uint matchID,address indexed winner);
    event MatchAbandoned(uint matchID,address indexed abandonedBy);
    event MatchRevoked(uint matchID);
    
    // Standard modifier on methods invokable only by contract owner.
    modifier onlyOwner {
        require (msg.sender == owner, "OnlyOwner methods called by non-owner.");
        _;
    }
    
    
   
   
   //external functions
    function confirmMatch(uint matchID) external payable{
         Match storage matchDetail = Matches[matchID];
         require(matchDetail.matchStatus==MATCH_CREATED,'This match has already been ended or hasn\'t been created yet');
         require(msg.sender==matchDetail.player_1||msg.sender==matchDetail.player_2,"you are not a player of this match");
         require(matchFee<=msg.value,'Please send enough amount to start the match');
         if(msg.sender==matchDetail.player_1){
            require(!matchDetail.player_1_confirmed,'You have already confirmed this match');
            matchDetail.player_1_confirmed = true;
         }else{
             require(!matchDetail.player_2_confirmed,'You have already confirmed this match');
             matchDetail.player_2_confirmed = true;
         }
         matchDetail.potAmount = matchDetail.potAmount.add(matchFee);    
         
         if(matchDetail.player_1_confirmed && matchDetail.player_2_confirmed){
             matchDetail.matchStatus = MATCH_CONFIRMED;
         }
         emit MatchConfirmed(matchID,msg.sender);
    }
    
    
      
    function endTurn(uint matchID) external{
         Match storage matchDetail = Matches[matchID];
         require(matchDetail.matchStatus==3,'This match has already been ended or hasn\'t started yet');
         require(msg.sender==matchDetail.player_1||msg.sender==matchDetail.player_2,"you are not a player of this match");
         require(matchDetail.currentTurn==msg.sender,'Opponent Turn in progress');
         
         if(msg.sender==matchDetail.player_1){
             matchDetail.currentTurn = matchDetail.player_2;
         }else{
             matchDetail.currentTurn = matchDetail.player_1;
         }
         
         matchDetail.totalTurn++;
         emit EndTurn(matchID,msg.sender);
    }
    
  
    
    // public functions only can be called by the owner
    //STATUS = 1 MATCH created
    //STATUS = 2 MATCH confirmed
    //STATUS = 3 MATCH started
    //STATUS = 4 MATCH completed
    //STATUS = 5 MATCH ABADONED
    //SATUS  = 6 MATCH REVOKED
    
    
    //Match Type 1 Free Match
    //MATCH Type 2 Paid Match
    function createMatch(uint matchID,uint32 matchType,address player_1,address player_2) public onlyOwner{
        
        Match storage newMatch = Matches[matchID];
        require(newMatch.matchStatus==EMPTY_STATUS,'This match has already been created');
        require(player_1!=player_2,"You can't play with yourself");
        require(matchType==FREE_MATCH || matchType==PAID_MATCH,"Invalid match type");
        
        newMatch.player_1 = player_1;
        newMatch.player_2 = player_2;
        newMatch.startTime = now;
        newMatch.matchStatus = MATCH_CREATED;
        newMatch.matchType = matchType;
        
        emit NewMatch(matchID,player_1,player_2);
    }
    
    
    function startMatch(uint matchID,uint pIndex) public onlyOwner{
        Match storage matchDetail = Matches[matchID];
        require(matchDetail.matchStatus==MATCH_CONFIRMED,"This match hasn't been confirmed by both players yet");
        require(pIndex==1 || pIndex==2,"Invalid Player Index");
        matchDetail.matchStatus = MATCH_STARTED;
        uint entropy = uint(keccak256(abi.encodePacked(matchID, now)));
        uint32 tossOutcome = uint32(entropy % 2)+1;
        if(tossOutcome==1){
            matchDetail.currentTurn = matchDetail.player_1;
        }else if(tossOutcome==2){
             matchDetail.currentTurn = matchDetail.player_2;
        }
        emit MatchStarted(matchID,tossOutcome);
    }
    
    
      
    function completeMatch(uint matchID,uint32 pIndex) public onlyOwner{
        
        Match storage matchDetail = Matches[matchID];
        require(matchDetail.matchStatus==MATCH_STARTED,"Can't complete. This match hasn't been started or already ended");
        require(pIndex==1 || pIndex==2,"Invalid Player Index");
        
        //match completed successfully
         matchDetail.matchStatus = MATCH_COMPLETED;
         
         if(pIndex==1){
              matchDetail.winner = matchDetail.player_1;
         }else{
              matchDetail.winner = matchDetail.player_2;
         }
         
        Player storage player_1 = Players[matchDetail.player_1];
        Player storage player_2 = Players[matchDetail.player_2];
         
        
        player_1.matchCompleted = player_1.matchCompleted+1; 
        player_2.matchCompleted = player_2.matchCompleted+1; 
         
         
         if(matchDetail.potAmount>0){
              uint winnerShare = calculatePercent(matchDetail.potAmount,90);
              uint devShare = calculatePercent(matchDetail.potAmount,10);
              //send share
              sendFunds(matchDetail.winner,winnerShare,'gameReward');
              sendFunds(HOUSE_ADDRESS,devShare,'devShare');
         }
         
         emit MatchCompleted(matchID,matchDetail.winner);
         
    }
    
    
    function abandonMatch(uint matchID,uint32 pIndex) public onlyOwner{
        
        Match storage matchDetail = Matches[matchID];
        require(matchDetail.matchStatus==MATCH_COMPLETED,"Can't abandon. This match hasn't been started or already ended");
        require(pIndex==1 || pIndex==2,"Invalid Player Index");
        
         //match abandoned 
         matchDetail.matchStatus = MATCH_ABANDONED;
         
         Player storage player_1 = Players[matchDetail.player_1];
         Player storage player_2 = Players[matchDetail.player_2];
         
         if(pIndex==1){
              matchDetail.abandonedBy = matchDetail.player_1;
              matchDetail.winner = matchDetail.player_2;
              player_1.matchAbandoned = player_1.matchAbandoned+1; 
              player_2.matchCompleted = player_2.matchCompleted+1; 
         }else{
              matchDetail.winner = matchDetail.player_1;
              matchDetail.abandonedBy = matchDetail.player_2;
              player_1.matchCompleted = player_1.matchCompleted+1; 
              player_2.matchAbandoned = player_2.matchAbandoned+1; 
         }
         
       
         if(matchDetail.potAmount>0){
              uint winnerShare = calculatePercent(matchDetail.potAmount,90);
              uint devShare = calculatePercent(matchDetail.potAmount,10);
            
              sendFunds(matchDetail.winner,winnerShare,'gameReward');
              sendFunds(HOUSE_ADDRESS,devShare,'devShare');
         }
         
         emit MatchAbandoned(matchID,matchDetail.abandonedBy);
        
    }
    
    
    
    
     function revokeMatch(uint matchID) public onlyOwner{
        
        Match storage matchDetail = Matches[matchID];
        require(matchDetail.matchStatus==MATCH_CREATED || matchDetail.matchStatus==MATCH_CONFIRMED 
        || matchDetail.matchStatus==MATCH_STARTED,"Can't revoke. This hasn't been created or already ended");
      
     
         if(matchFee>0 && matchDetail.potAmount>0){
              uint playerCount = matchDetail.matchStatus!=MATCH_STARTED?matchDetail.matchStatus:2;
              uint feeShare = matchDetail.potAmount.div(playerCount);
              if(matchDetail.player_1_confirmed){
                   sendFunds(matchDetail.player_1,feeShare,'revokePayment');
              }
               if(matchDetail.player_2_confirmed){
                  sendFunds(matchDetail.player_2,feeShare,'revokePayment');
              }
         }
         
         //forfield match
         matchDetail.matchStatus = MATCH_REVOKED;
    
         emit MatchRevoked(matchID);
        
    }
    
    
    function changeMatchFee(uint amount) public onlyOwner{
        matchFee = amount;
        emit MatchFeeChanged(amount);
    }
    

    // private pure functions 
    function calculatePercent(uint256 base,uint256 share) private pure returns(uint256 result){
        result = base.mul(share).div(100);
    }
    
    function generateRandomNumber(uint seed,uint range) private view returns (uint){
          uint entropy = uint(keccak256(abi.encodePacked(seed, now)));
          uint randNum = (entropy % range).add(1);
          return randNum;
    }
   
   
    function sendFunds(address reciever, uint amount,string sendFor) private {
        if (reciever.send(amount)) {
            emit PaymentSuccess(reciever, amount,sendFor);
        } else {
            emit FailedPayment(reciever, amount,sendFor);
        }
    }

    
}



library SafeMath {

    /**
    * @dev Multiplies two numbers, throws on overflow.
    */
    function mul(uint256 a, uint256 b)
    internal
    pure
    returns (uint256 c)
    {
        if (a == 0) {
            return 0;
        }
        c = a * b;
        require(c / a == b, "SafeMath mul failed");
        return c;
    }

    /**
    * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b)
    internal
    pure
    returns (uint256)
    {
        require(b <= a, "SafeMath sub failed");
        return a - b;
    }

    /**
    * @dev Adds two numbers, throws on overflow.
    */
    function add(uint256 a, uint256 b)
    internal
    pure
    returns (uint256 c)
    {
        c = a + b;
        require(c >= a, "SafeMath add failed");
        return c;
    }

    /**
  * @dev Integer division of two numbers truncating the quotient, reverts on division by zero.
  */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0); // Solidity only automatically asserts when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev gives square root of given x.
     */
    function sqrt(uint256 x)
    internal
    pure
    returns (uint256 y)
    {
        uint256 z = ((add(x,1)) / 2);
        y = x;
        while (z < y)
        {
            y = z;
            z = ((add((x / z),z)) / 2);
        }
    }

    /**
     * @dev gives square. multiplies x by x
     */
    function sq(uint256 x)
    internal
    pure
    returns (uint256)
    {
        return (mul(x,x));
    }

    /**
     * @dev x to the power of y
     */
    function pwr(uint256 x, uint256 y)
    internal
    pure
    returns (uint256)
    {
        if (x==0)
            return (0);
        else if (y==0)
            return (1);
        else
        {
            uint256 z = x;
            for (uint256 i=1; i < y; i++)
                z = mul(z,x);
            return (z);
        }
    }
    
     
    function abs(uint num1,uint num2) 
    internal 
    pure 
    returns (uint256){
        if(num1>num2){
            return num1-num2;
        }else if(num2>num1){
            return num2-num1;
        }else{
            return 0;
        }
    }
}