pragma solidity 0.4.19;

import './CBNBToken.sol';
import './CBNBTeamWallet.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';

contract CBNBCrowdSale_v2 is Ownable{
  using SafeMath for uint256;

  uint256 constant internal MIN_CONTRIBUTION = 0.1 ether;
  uint256 constant internal TOKEN_DECIMALS = 10**10;
  uint256 constant internal ETH_DECIMALS = 10**18;
  uint8 constant internal TIER_COUNT = 5;


  address public remainingTokensWallet;
  uint256 public totalTokensSold;
  address public depositWallet;
  uint256 public teamTokens;
  uint256 public icoEndTime;
  uint256 public tokenPrice;
  uint256 public weiRaised;
  uint256 public ethPrice;
  uint256 public minLimit;
  address public owner;
  uint256 public cap;
  uint8 private tier;
  bool private paused;

  enum Status {
    New, Approved, Denied
  }

  struct Participant {
    uint256 contrAmount; //amount in wei
    uint256 qtyTokens;
    Status whitelistStatus;
    uint256 remainingWei;
    bool receivedAirdrop;
  }

  mapping(address => Participant) participants;

  //The CryptoBnB token contract
  CBNBToken public bnbToken;
  CBNBTeamWallet public bnbTeamWallet; 

  /// @dev Sale tiers for Institution-ICO, public Pre-ICO, and ICO
  /// @dev Sets the time of start and finish, it will be time of pushing
  /// @dev to the mainnet plus days/hours etc.
  struct SaleTier {      
    uint256 tokensToBeSold;  //amount of tokens to be sold in this SaleTier
    uint256 price;           //amount of tokens per wei
    uint256 tokensSold;      //amount of tokens sold in each SaleTier     
  }
   
  mapping(uint8 => SaleTier) saleTier;

  event LogTokensTransferedFrom(address _owner, address _msgsender, uint256 _qtyOfTokensRequested);
  event LogTokensReserved(address _buyer, uint256 _amount);
  event LogWithdrawal(address _investor, uint256 _amount); 
  event LogBalance(uint256 balance);

  modifier icoIsActive() {
    require(weiRaised < cap && now < icoEndTime && calculateUnsoldICOTokens() > 0);
    _;
  }

  modifier icoHasEnded() {
    require(weiRaised >= cap || now > icoEndTime || calculateUnsoldICOTokens() == 0);
    _;
  }

  modifier unpausedContract(){
    require(paused == false);
    _;
  }

  /// @dev confirm price thresholds and amounts
  ///  depositWallet for holding ether
  ///  bnbToken token address pushed to mainnet first
  function CBNBCrowdSale_v2(address _remainingTokensWallet, address _depositWallet, address _bnbToken, address _teamWallet) 
    public 
  {
    require(_depositWallet != 0x0);
    require(_bnbToken != 0x0);
    require(_teamWallet != 0x0);     

    remainingTokensWallet = _remainingTokensWallet;
    totalTokensSold;
    depositWallet = _depositWallet;
    bnbTeamWallet = CBNBTeamWallet(_teamWallet);
    teamTokens = 300000000*TOKEN_DECIMALS; //verify team owner advisors token amount
    tokenPrice;
    icoEndTime = now + 90 days; 
    weiRaised;
    bnbToken = CBNBToken(_bnbToken);    
    minLimit = 1500 ether; //verify
    owner = msg.sender;
    cap = 15000 ether; //verify

   for(uint8 i=0; i<TIER_COUNT; i++){ 
    saleTier[i].tokensToBeSold = (100000000-(i*20000000))*TOKEN_DECIMALS;
   }
 }

  /// @dev Fallback function.
  /// @dev Reject random ethereum being sent to the contract.
  /// @notice allows for owner to send ethereum to the contract in the event
  /// of a refund
  function()
    public
    payable
  {
    if(msg.sender == owner){
      LogBalance(this.balance);
    } else {
      buyTokens(msg.value, msg.sender);
    }
  }

  function transferTeamTokens()
    public
    onlyOwner
    returns(bool success)
  {
    bnbToken.transferFrom(owner, bnbTeamWallet, teamTokens);
    totalTokensSold += teamTokens;
    teamTokens = 0;
    return(true);
  }

  ///@notice feels risky
  ///param ethereum price will exclude decimals
  function setEtherPrice(uint256 _price)
    external
    onlyOwner
  {
    ethPrice = _price;
  }

  function getTokenPrice()
    external
  {
    tokenPrice = 40+(8*tier);
  }

  /// @notice buyer calls this function to order to get on the list for approval
  /// buyers must send the ethereum with their whitelist application
   /// @notice buyer calls this function to order to get on the list for approval
  /// buyers must send the ether with their whitelist application
  function buyTokens(uint256 sentWei, address tokenBuyer)
    internal
    icoIsActive
    unpausedContract
    
    returns (uint8)
  {
    
    Participant storage participant = participants[tokenBuyer];

    require(tokenBuyer != owner);
    require(ethPrice != 0);
    require(participant.whitelistStatus == Status.Approved);
    require(sentWei.add(participant.remainingWei) >= MIN_CONTRIBUTION);

    uint256 remainingWei = sentWei.add(participant.remainingWei);
    participant.remainingWei = 0;
    uint256 totalTokensRequested;
    uint256 price = (ETH_DECIMALS.mul(uint256(40+(8*tier))).div(1000)).div(ethPrice);
    uint256 tierRemainingTokens;
    uint256 tknsRequested;
  
    while(remainingWei >= price && tier != TIER_COUNT) {

      SaleTier storage tiers = saleTier[tier];
      price = (ETH_DECIMALS.mul(uint256(40+(8*tier))).div(1000)).div(ethPrice);
      tknsRequested = (remainingWei.div(price)).mul(TOKEN_DECIMALS);
      tierRemainingTokens = tiers.tokensToBeSold.sub(tiers.tokensSold);
      if(tknsRequested >= tierRemainingTokens){
        tknsRequested -= tierRemainingTokens;
        tiers.tokensSold += tierRemainingTokens;
        totalTokensRequested += tierRemainingTokens;
        remainingWei -= ((tierRemainingTokens.mul(price)).div(TOKEN_DECIMALS));
        tier++;
      } else{
        tiers.tokensSold += tknsRequested;
        totalTokensRequested += tknsRequested;
        remainingWei -= ((tknsRequested.mul(price)).div(TOKEN_DECIMALS));
      }  
    }

    uint256 amount = sentWei.sub(remainingWei);
    weiRaised += amount;

    participant.remainingWei += remainingWei;
    participant.contrAmount += amount;
    participant.qtyTokens += totalTokensRequested;
    totalTokensSold += totalTokensRequested;

    bnbToken.transferFrom(owner, tokenBuyer, totalTokensRequested);
    return tier;
  }
 
 ///@notice interface for founders to whitelist participants
  function approveAddressForWhitelist(address[] _address) 
    public 
    onlyOwner
  {
    for(uint256 i = 0; i < _address.length; i++){
      participants[_address[i]].whitelistStatus = Status.Approved;      
    }
  }

  ///@notice interface for founders to whitelist participants
  function denyAddressForWhitelist(address[] _address) 
    public 
    onlyOwner
  {
    for(uint256 i = 0; i < _address.length; i++){
      participants[_address[i]].whitelistStatus = Status.Denied;      
    }

  }

  ///@notice airdropAmount does not need decimal points put in as they are accounted for in the function
  ///address array should only be long enough to max out the gas limit about 50 or less at a time
  function sendAirdrop(address[] _address, uint256 airdropAmount)
    public
    onlyOwner
  {
    require(airdropAmount != 0);
    uint256 sendAmount = airdropAmount.mul(TOKEN_DECIMALS).div(_address.length);

    for(uint256 i = 0; i < _address.length; i++){
      if(!participants[_address[i]].receivedAirdrop){
        participants[_address[i]].receivedAirdrop = true;
        bnbToken.transferFrom(owner, _address[i], sendAmount); 
      }
    } 
  }

  /// @notice used to move tokens from the later tiers into the earlier tiers
  /// contract must be paused to do the move
  /// param tier from later tier to subtract the tokens from
  /// param tier to add the tokens to
  /// param how many tokens to take
  function moveTokensForSale(uint8 _tierFrom, uint8 _tierTo, uint256 _tokens) 
    view
    public
    onlyOwner
  {
    SaleTier storage tiers = saleTier[_tierFrom];
    require(paused == true);
    require(_tierFrom > _tierTo);
    require(_tokens <= ((tiers.tokensToBeSold).sub(tiers.tokensSold)));
    tiers.tokensToBeSold.sub(_tokens);
    saleTier[_tierTo].tokensToBeSold.add(_tokens);
  }

  /// @notice pause specific funtions of the contract
  function pauseContract() public onlyOwner {
    paused = true;
  }

  /// @notice to unpause functions
  function unpauseContract() public onlyOwner {
    paused = false;
  }

  function checkWhitelistStatus()
    view
    public
    returns (bool whitelisted)
  {
    return (participants[msg.sender].whitelistStatus == Status.Approved);
  }       

  /// @notice users can withdraw the wei etheum sent
  /// used for refund process incase not enough funds raised
  /// or denied in the approval process
  /// @notice no ethereum will be held in the crowdsale contract
  /// when refunds become available the amount of Ethererum needed will
  /// be manually transfered back to the crowdsale to be refunded
  function refundWithdrawal()
    external
    unpausedContract
    icoHasEnded
    returns (bool success)
  {
    Participant storage participant = participants[msg.sender];
    require(weiRaised < minLimit);
    uint256 sendValue = participant.contrAmount;
    participant.contrAmount = 0;
    participant.qtyTokens = 0;
    msg.sender.transfer(sendValue);
    LogWithdrawal(msg.sender, sendValue);
    return true;
  }
  
  ///@notice owner withdraws ether periodically from the crowdsale contract
  function ownerWithdrawal()
    public
    onlyOwner
    returns(bool success)
  {
    LogWithdrawal(msg.sender, this.balance);
    depositWallet.transfer(this.balance);
    return(true); 
  }

  /// @dev freeze unsold tokens for use at a later time
  /// and transfer team owner and other internally promised tokens
  /// param total number of tokens being transfered to the freeze wallet
  function finalize()
    public
    icoHasEnded
    onlyOwner
  {
    bnbToken.transferFrom(owner, remainingTokensWallet, calculateUnsoldICOTokens());
    bnbTeamWallet.setFreezeTime(now);   
  }

  /// @notice calculate unsold tokens for transfer to depositWallet to be used at a later date
  function calculateUnsoldICOTokens()
    view
    internal
    returns (uint256)
  {
    uint256 remainingTokens;
    for(uint8 i = 0; i < TIER_COUNT; i++){
      if(saleTier[i].tokensSold < saleTier[i].tokensToBeSold){
        remainingTokens += saleTier[i].tokensToBeSold.sub(saleTier[i].tokensSold);
      }
    }
    return remainingTokens;
  }

  /// @notice no ethereum will be held in the crowdsale contract
  /// when refunds become available the amount of Ethererum needed will
  /// be manually transfered back to the crowdsale to be refunded
  /// @notice only the last person that buys tokens if they deposited enought to buy more 
  /// tokens than what is available will be able to use this function
  function claimRemainingWei()
    external
    unpausedContract
    icoHasEnded
    returns (bool success)
  {
    Participant storage participant = participants[msg.sender];
    require(participant.whitelistStatus == Status.Approved);
    require(participant.remainingWei != 0);
    uint256 sendValue = participant.remainingWei;
    participant.remainingWei = 0;
    LogWithdrawal(msg.sender, sendValue);
    msg.sender.transfer(sendValue);
    return true;
  }
}