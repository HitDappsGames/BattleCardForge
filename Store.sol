pragma solidity ^0.4.23;

contract KingStoneStore{

    using SafeMath for *;
    
    uint public CARD_PRICE = 1e14;
    uint public PACK_PRICE = 1e14;
    uint public DECK_PRICE = 1e14;
    uint public ITEM_ADD_PRICE = 1e14;
    uint public STORE_ITEM_TYPE = 3;
    uint public MINION_ABILITIES=8;
    uint public SPELL_ABILITIES=3;
    
    address public HOUSE_ADDRESS = 0x68EB4F9844db6DE41E5dfE89B1639569E90fadd5;
    address public ADMIN = 0x68EB4F9844db6DE41E5dfE89B1639569E90fadd5;
    address public owner;
    uint public totalCard;
    uint public totalStoreItem;
    uint public totalPlayer;
   

    constructor() public{
        owner = msg.sender;
    }

    
    struct Card{
        uint32 cardType;
        uint32 health;
        uint32 attackPower;
        uint32 manaCost;
        uint32 levelPoint;
        uint32 abilityID;
        uint32 abilityValue;
        address createdBy;
        uint totalSell;
        uint totalIncome;
        uint lID;
    }
    
    struct CardPack{
        uint[] cards;
        uint purchasedOn;
    }
   
    struct Player{
        uint vaultBalance;
        uint totalEarning;
        uint totalExpanse;
        uint joinedOn;
        uint levelPoint;
        uint currentRank;
        address referral;
        uint[] ownedCards;
        uint[] extraCards;
        uint[] generatedCards;
        uint ownedPacks;
        uint ownedDecks;
        uint[] ownedItems;
        uint[] addedItems;
    }
    
    
    
    //store items uploaded by users
    // type 1 is Artwork, type 2 is Frame, type 3 is board
    struct StoreItem{
        uint32 itemType;
        uint itemPrice;
        uint totalLike;
        uint totalSell;
        uint lastSaledOn;
        uint addedOn;
        address addedBy;
    }
    
    
    //data strcts
    mapping (uint => Card) public Cards;
    mapping (address => Player) public Players;       
    mapping(address=>mapping(uint => CardPack)) CardPacks;
    mapping(uint=>StoreItem) public StoreItems;
    mapping(uint32=>mapping(uint => bool)) GenerateAbilityValue;  
    
    
    //indexing localID to the blockchain ID
    mapping(address=>mapping(uint=>uint32)) public OwnedCardCounter;
    mapping(address=>mapping(uint=>uint)) public PackTracker;
    mapping(uint=>uint) public CardTracker;
    mapping(address=>mapping(uint=>bool)) public PlayerPurchasedItemTracker;
    
  
    
    event PaymentSuccess(address indexed beneficiary, uint amount,string sendfor);
    event FailedPayment(address indexed beneficiary, uint amount,string sendfor);
    event GenerateCard(address indexed publisher, uint cardID);
    event GeneratePack(address indexed buyer, uint packID);
    event CardPublish(address indexed publisher, uint bID,uint lID);
    event CardPurchase(address indexed buyer,uint packID);
    event AbilityAdded(uint abilityFor,uint abilityID);
    event DeckUnlocked(address indexed player,uint unlockID);
    event StoreItemTypeChanged(uint newTypeCount);
    event StoreItemAdded(address indexed addedBy,uint itemID);
    event StoreItemPurchased(address indexed purchasedBy,uint itemID);
    event StoreItemPriceChanged(uint itemID,uint oldPrice,uint newPrice);
    event CardSold(address indexed soldBy,uint cardSold);
  
    
    // Standard modifier on methods invokable only by contract owner.
    modifier onlyOwner {
        require (msg.sender == owner, "OnlyOwner methods called by non-owner.");
        _;
    }
    
    
    //public view functions
    
    function getPlayerCards(address _player) public view returns(uint[]){
        Player memory player = Players[_player];
        return player.ownedCards;
    }
    function getExtraCards(address _player) public view returns(uint[]){
        Player memory player = Players[_player];
        return player.extraCards;
    }
    function getCardPack(address _player,uint _pack) public view returns(uint[],uint){
        CardPack memory pack = CardPacks[_player][_pack];
        return (pack.cards,pack.purchasedOn);
    }
    
    function getPlayerItems(address _player) public view returns(uint[]){
        Player memory player = Players[_player];
        return player.ownedItems;
    }
    
    function getPlayerGeneratedCards(address _player) public view returns(uint[]){
        Player memory player = Players[_player];
        return player.generatedCards;
    }
    
    function getPlayerAddedItems(address _player) public view returns(uint[]){
        Player memory player = Players[_player];
        return player.addedItems;
    }
    
    
    // external functions
    
    function buyCards(uint lID,uint seed) external payable{
        
         require(msg.value>=PACK_PRICE,"Not enough amount to purchase this cardPack");
         require(PackTracker[msg.sender][lID]==0,'Invalid local ID');
     
        
         Player storage player =  Players[msg.sender];
         
         if(player.joinedOn==0){
            registerUser(msg.sender);
         }
         
         player.ownedPacks++;
         
         player.totalExpanse = player.totalExpanse.add(msg.value);
         
         
         CardPack storage newPack = CardPacks[msg.sender][player.ownedPacks];
         newPack.purchasedOn = now;
        
    
         uint halfShare = msg.value.div(2);
         uint cardSellShare = halfShare.div(5);
         uint differ = 20;
         
    
         for(uint i=0;i<5;i++){
             
             uint cardID = generateRandomNumber(seed.add(differ),totalCard);
          
             Card storage card = Cards[cardID];
             card.totalSell = card.totalSell.add(1);
             card.totalIncome = card.totalIncome.add(cardSellShare);
             
             player.levelPoint = player.levelPoint.add(card.levelPoint);
             
             Player storage cardCreator = Players[card.createdBy];
             cardCreator.vaultBalance = cardCreator.vaultBalance.add(cardSellShare);
             cardCreator.totalEarning = cardCreator.totalEarning.add(cardSellShare);
             
             uint32 ownedCounter = OwnedCardCounter[msg.sender][cardID];
             
             if(ownedCounter<2){
                 OwnedCardCounter[msg.sender][cardID] = ownedCounter+1;
                 player.ownedCards.push(cardID);
             }else{
                 player.extraCards.push(cardID);
             }
        
             newPack.cards.push(cardID);
             
             differ = differ.add(2000);
         }
         
         PackTracker[msg.sender][lID] = player.ownedPacks;
      
         sendFunds(HOUSE_ADDRESS,halfShare,"devFee");
         
         emit CardPurchase(msg.sender,player.ownedPacks);
         
    }
    
    
    function generateCard(uint lID,uint seed) external payable{
        
    
        require(msg.value>=CARD_PRICE,"Not enough amount to publish this card");
        require(CardTracker[lID]==0,"Local id is Invalid");
     
        totalCard++;
        
        Card storage newCard = Cards[totalCard];
        CardTracker[lID] = totalCard;
        
        
        Player storage player =  Players[msg.sender];
         
         if(player.joinedOn==0){
            registerUser(msg.sender);
         }
         
        player.totalExpanse = player.totalExpanse.add(msg.value);
        player.generatedCards.push(totalCard);
    
        newCard.cardType = uint32(generateRandomNumber(seed,2));
        
        
        if(newCard.cardType==1){
            newCard.health = uint32(generateRandomNumber(seed.add(100),15)); 
            newCard.attackPower = uint32(generateRandomNumber(seed.add(200),15)); 
            
            uint32 shouldHaveAbility =  uint32(generateRandomNumber(seed.add(10010),2)); 
            
            if(shouldHaveAbility==2){
                 newCard.abilityID = uint32(generateRandomNumber(seed.add(500),MINION_ABILITIES)); 
                 if(GenerateAbilityValue[newCard.cardType][newCard.abilityID]){
                      newCard.abilityValue = uint32(generateRandomNumber(seed.add(2000),10)); 
                 }
            }
        }else{
             newCard.abilityID = uint32(generateRandomNumber(seed.add(100),SPELL_ABILITIES)); 
             newCard.abilityValue = uint32(generateRandomNumber(seed.add(2000),10)); 
        }
    
        
        uint totalSum = (newCard.health.add(newCard.attackPower)).add(newCard.abilityValue);
        
        
        if(totalSum<=5){
            newCard.manaCost = 1;
        }else if(totalSum<=10){
            newCard.manaCost = 2;
        }else if(totalSum<=16){
            newCard.manaCost = 3;
        }else if(totalSum<=22){
            newCard.manaCost = 4;
        }else if(totalSum<=29){
            newCard.manaCost = 5;
        }else if(totalSum<=35){
            newCard.manaCost = 6;
        }else if(totalSum<=41){
            newCard.manaCost = 7;
        }else if(totalSum<=47){
            newCard.manaCost = 8;
        }else if(totalSum<=54){
            newCard.manaCost = 9;
        }else if(totalSum<=60 || totalSum>60){
            newCard.manaCost = 10;
        }
        
        
        newCard.lID = lID;
        newCard.createdBy = msg.sender;
        newCard.levelPoint = uint32(((newCard.health.add(newCard.attackPower)).add(newCard.manaCost)).add(newCard.abilityValue));
    

        sendFunds(HOUSE_ADDRESS,msg.value,"devFee");
        
        emit CardPublish(msg.sender,lID,totalCard);
        
    }
    
    //type 1 is Artwork
    //type 2 is cardFrame
    //type 3 is board
    function addItem(uint itemID,uint32 itemType,uint price) external payable{
        
        require(itemType<=STORE_ITEM_TYPE,"Item is out of range");
            
            if(msg.sender!=ADMIN){
              require(msg.value>=ITEM_ADD_PRICE,"Not enough amount to add items");
            }        
         
          
          StoreItem storage sItem = StoreItems[itemID];
          
          require(sItem.itemType==0,"This Item has already been added");
          
          sItem.itemType = itemType;
          sItem.itemPrice = price;
          sItem.addedBy = msg.sender;
          sItem.addedOn = now;
          
          Player storage uploader = Players[msg.sender];
          
           if(uploader.joinedOn==0){
            registerUser(msg.sender);
          }
          
          uploader.addedItems.push(itemID);
          
          
          totalStoreItem++;
          
          
          emit StoreItemAdded(msg.sender,itemID);
    }
    
    
    function purchaseItem(uint itemID) external payable{
        
        StoreItem storage item = StoreItems[itemID];
        
        require(item.addedOn!=0,"No item found regarding this Id");
        require(msg.value>=item.itemPrice,"Not enough amount to purchase this item");
        require(!PlayerPurchasedItemTracker[msg.sender][itemID],"you've already purchased this item");
        
        Player storage buyer =  Players[msg.sender];
         
         if(buyer.joinedOn==0){
            registerUser(msg.sender);
         }
         
        buyer.totalExpanse = buyer.totalExpanse.add(msg.value);
        
        buyer.ownedItems.push(itemID);
        
        PlayerPurchasedItemTracker[msg.sender][itemID] = true;
        
        item.totalSell++;
        item.lastSaledOn = now;
        
        
        //distribute item price
         uint uploaderShare = calculatePercent(item.itemPrice,90);
         uint devShare = calculatePercent(item.itemPrice,10);
         
         
         //get uploader
         Player storage uploader =  Players[item.addedBy];
         uploader.vaultBalance  = uploader.vaultBalance.add(uploaderShare);
         
         
         //send dev share
         sendFunds(HOUSE_ADDRESS,devShare,"devFee");
        
    
        emit StoreItemPurchased(msg.sender,itemID);
    }
    
    function updateItemPrice(uint itemID,uint newPrice) external payable{
        
        StoreItem storage item = StoreItems[itemID];
        require(item.addedOn!=0,"No item found regarding this Id");
        require(msg.value>=item.itemPrice.div(2),"Not enough amount to update item price");
        require(item.addedBy==msg.sender,"Only creater of this item can update the price");
        
        uint oldPrice = item.itemPrice;
        
        item.itemPrice = newPrice;
        
        emit StoreItemPriceChanged(itemID,oldPrice,newPrice);
    }
    

    
    function unlockDeck() external payable{
         require(msg.value>=DECK_PRICE,"Not enough amount to unlock deck");
         Player storage player =  Players[msg.sender];
         if(player.joinedOn==0){
            registerUser(msg.sender);
         }
         player.totalExpanse = player.totalExpanse.add(msg.value);
         player.ownedDecks = player.ownedDecks.add(1);
         
         //send dev share
         sendFunds(HOUSE_ADDRESS,msg.value,"devFee");
         
         emit DeckUnlocked(msg.sender,player.ownedDecks);
    }
    
    function sellCards() external{
        Player storage _player = Players[msg.sender];
       require(_player.extraCards.length>0,"You don't have any extra cards to sell");
       uint cardWillbeSell = _player.extraCards.length;
       delete _player.extraCards;
       emit CardSold(msg.sender,cardWillbeSell);
    }
    
    
    function withdraw() external{
       Player storage _player = Players[msg.sender];
       require(_player.vaultBalance>0,"You don't have enough amount to withdraw");
       uint withdrawAmount = _player.vaultBalance;
       _player.vaultBalance = 0;
       sendFunds(msg.sender,withdrawAmount,"withdraw");  
    }
    
    
 
      
 
    
    // public functions only can be called by the owner

    
    function addAbility(uint32 abilityFor,uint serialNo,uint32 generateValue) public onlyOwner{
        GenerateAbilityValue[abilityFor][serialNo] = generateValue==1?true:false;
        emit AbilityAdded(abilityFor,serialNo);
    }
    
    function updateAbilityRange(uint minionRange,uint spellRange) public onlyOwner{
        MINION_ABILITIES = minionRange;
        SPELL_ABILITIES = spellRange;
    }
    
    function updateStoreItemType(uint32 newTypeCount) public onlyOwner{
        STORE_ITEM_TYPE = newTypeCount;
        emit StoreItemTypeChanged(STORE_ITEM_TYPE);
    }
    
    
  
    // private pure functions 
    function calculatePercent(uint256 base,uint256 share) private pure returns(uint256 result){
        result = base.mul(share).div(100);
    }
    
    function generateRandomNumber(uint seed,uint range) private view returns (uint){
          uint entropy = uint(keccak256(abi.encodePacked(seed, now)));
          uint randNum = (entropy % range).add(1);
         // uint randNum = (uint(blockhash(block.number-1))%range + 1);
          return randNum;
    }
    
    function registerUser(address _address) private {
        Player storage player =  Players[_address];
        player.joinedOn = now;
        player.ownedDecks = 2;
        totalPlayer++;
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