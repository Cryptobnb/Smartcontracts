pragma solidity 0.4.18;

import './CBNBToken.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';

contract CBNBCrowdSale is Ownable{
  using SafeMath for uint256;

  uint256 constant internal MIN_CONTRIBUTION = 0.1 ether;
  uint256 constant internal TOKEN_DECIMALS = 10**10;
  uint256 constant internal ETH_DECIMALS = 10**18;
  uint8 constant internal TIER_COUNT = 5;

  uint256 public totalTokensSold;
  address public depositWallet;
  uint256 public icoEndTime;
  address public teamWallet;
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
  }

  mapping(address => Participant) participants;

  //The CryptoBnB token contract
  CBNBToken public bnbToken; 

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
 
  modifier isValidPayload() {
    require(msg.data.length == 0 || msg.data.length == 4); // double check this one
    _;
  }

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
  function CBNBCrowdSale(address _depositWallet, address _bnbToken, address _teamWallet) 
    public 
  {
    require(_depositWallet != 0x0);
    require(_bnbToken != 0x0);
    require(_teamWallet != 0x0);     

    totalTokensSold;
    depositWallet = _depositWallet;
    icoEndTime = now + 90 days; //pick a block number to end on
    teamWallet = _teamWallet;
    tokenPrice;
    weiRaised;
    bnbToken = CBNBToken(_bnbToken);    
    minLimit = 1500 ether;
    owner = msg.sender;
    cap = 15000 ether;

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
    require(msg.sender == owner);
  }

  ///@notice feels risky
  ///param ethereum price will exclude decimals
  function getEtherPrice(uint256 _price)
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
  function buyTokens()
    external
    payable
    icoIsActive
    unpausedContract
    isValidPayload
    
    returns (uint8)
  {
    
    Participant storage participant = participants[msg.sender];

    require(msg.sender != owner);
    require(ethPrice != 0);
    require(participant.whitelistStatus != Status.Denied);
    require(msg.value >= MIN_CONTRIBUTION);

    uint256 remainingWei = msg.value.add(participant.remainingWei);
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

    uint256 amount = msg.value.sub(remainingWei);
    weiRaised += amount;
    depositWallet.transfer(amount);

    participant.remainingWei += remainingWei;
    participant.contrAmount += amount;
    participant.qtyTokens += totalTokensRequested;
    totalTokensSold += totalTokensRequested;
    LogTokensReserved(msg.sender, totalTokensRequested);
    
    return tier;
  }
 
 ///@notice interface for founders to whitelist participants
  function approveAddressForWhitelist(address _address) 
    public 
    onlyOwner
    icoHasEnded 
  {
    participants[_address].whitelistStatus = Status.Approved;
  }

  ///@notice interface for founders to whitelist participants
  function denyAddressForWhitelist(address _address) 
    public 
    onlyOwner
    icoHasEnded 
  {
    participants[_address].whitelistStatus = Status.Denied;
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
    if(weiRaised >= minLimit){
      require(participant.whitelistStatus != Status.Approved);
    }

    uint256 sendValue = participant.contrAmount;
    participant.contrAmount = 0;
    participant.qtyTokens = 0;
    msg.sender.transfer(sendValue);
  
    LogWithdrawal(msg.sender, sendValue);
    return true;
  }

  /// @dev freeze unsold tokens for use at a later time
  /// and transfer team, owner and other internally promised tokens
  /// param total number of tokens being transfered to the freeze wallet
  function finalize(uint256 _internalTokens)
    public
    icoHasEnded
    onlyOwner
  {
    cleanup();
    bnbToken.transferFrom(owner, depositWallet, calculateUnsoldICOTokens());
    bnbToken.transferFrom(owner, teamWallet, _internalTokens);   
  }
  
  /// @notice Transfer any ethereum accidentally left in this contract 
  function cleanup()
    internal
  {
    depositWallet.transfer(this.balance);
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

  /// notice sends requested tokens to the whitelist person
  function claimTokens() 
    external
    unpausedContract
    icoHasEnded
  {
    Participant storage participant = participants[msg.sender];
    require(participant.whitelistStatus == Status.Approved);
    require(participant.qtyTokens != 0);
    uint256 tkns = participant.qtyTokens;
    participant.qtyTokens = 0;
    LogTokensTransferedFrom(owner, msg.sender, tkns);
    bnbToken.transferFrom(owner, msg.sender, tkns);
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