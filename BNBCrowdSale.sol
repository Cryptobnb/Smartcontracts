pragma solidity ^0.4.13;

import './BNBToken.sol';
import './Ownable.sol';
import './SafeMath.sol';

contract BNBCrowdSale is Ownable{
  using SafeMath for uint256;

  uint256 public icoStartTime;
  uint256 public icoEndTime;
  address public multiSigWallet;
  address public teamWallet;
  uint256 public decimals;
  uint256 public weiRaised;
  uint256 public minLimit;
  address public owner;
  uint256 public cap;
  uint8 public tier;
  bool public paused;
  bool private lockTier;

  enum Status {
    New, Approved, Denied
  }

  struct WhitelistedInvestors {
    uint256 contrAmount; //amount in wei
    uint256 qtyTokens;
    Status whitelistStatus;
  }

  mapping(address => WhitelistedInvestors) investors;

  //The CryptoBnB token contract
  BNBToken public bnbToken; 

  /// @dev Sale tiers for Institution-ICO, public Pre-ICO, and ICO
  /// @dev Sets the time of start and finish, it will be time of pushing
  /// @dev to the mainnet plus days/hours etc.
  struct SaleTier { 
    uint256 startTime;      
    uint256 endTime;
    uint256 tokensToBeSold;  //amount of tokens to be sold in this SaleTier
    uint256 price;           //amount of tokens per wei
    uint256 tokensSold;      //amount of tokens sold in each SaleTier     
  }
   
  mapping(uint8 => SaleTier) saleTier;

  event TokensReserved(address _buyer, uint256 _amount);
  event LogWithdrawal(address _investor, uint256 _amount); 
 
  modifier isValidPayload() {
    require(msg.data.length == 0 || msg.data.length == 4); // double check this one
    _;
  }

  modifier validPurchase() { 
    require(now >= icoStartTime && now <= icoEndTime);
    require(weiRaised.add(msg.value) <= cap);
    require(msg.value >= 5*10**17);
    _; 
  }
  
  modifier checkTierEndTime() {
    require(!lockTier);
    if(saleTier[tier].endTime <= now){
        tier++;
    }
    _;
  }
  
  modifier checkTierIncrement(){
    uint256 qtns = (msg.value).div(saleTier[tier].price);
    if ((qtns.add(saleTier[tier].tokensSold)) >= (saleTier[tier].tokensToBeSold)){
        lockTier = true;
    }
    _;    
  }

  modifier refundOnly() {
    require(weiRaised < minLimit || investors[msg.sender].whitelistStatus == Status.Denied);
    _;
  }

  modifier icoHasEnded() {
    require(weiRaised >= cap);
    require(now > icoEndTime);
    _;
  }

  modifier onTheWhitelist() {
    require(investors[msg.sender].whitelistStatus == Status.Approved);
    _;
  }

  modifier contractPaused(){
    require(paused == false);
    _;
  }

  /// @dev confirm price thresholds and amounts
  ///  multiSigWallet for holding ether
  ///  bnbToken token address pushed to mainnet first
  function BNBCrowdSale(address _multiSigWallet, address _bnbToken, address _teamWallet) 
    public 
  {
    require(_multiSigWallet != 0x0);
    require(_bnbToken != 0x0);     

    multiSigWallet = _multiSigWallet;
    teamWallet = _teamWallet;
    icoStartTime = now;
    icoEndTime = now + 7 days;
    bnbToken = BNBToken(_bnbToken);    
    decimals = 10;
    minLimit = 15000 ether;
    lockTier = false;
    owner = msg.sender;
    cap = 165000 ether;

    /// @notice Pre-ICO
    saleTier[0].startTime = now;
    saleTier[0].endTime = now + 7 days;
    saleTier[0].tokensToBeSold = 10;
    saleTier[0].price = 23333 * 10**10; //$0.07
    saleTier[0].tokensSold = 0;
    
    /// @notice Tier 1 - ICO
    saleTier[1].startTime = now + 8 days; //unused
    saleTier[1].endTime = now + 14 days;
    saleTier[1].tokensToBeSold = 10;
    saleTier[1].price = 25000 * 10**10; // 0.075
    saleTier[1].tokensSold = 0;

    /// @notice Tier 2 - ICO
    saleTier[2].startTime = now + 15 days; //unused
    saleTier[2].endTime = now + 21 days;
    saleTier[2].tokensToBeSold = 10;
    saleTier[2].price = 26666 * 10**10; //0.08
    saleTier[2].tokensSold = 0;
    
    /// @notice Tier 3 - ICO 
    saleTier[3].startTime = now + 21 days; //unused
    saleTier[3].endTime = now + 28 days;
    saleTier[3].tokensToBeSold = 10;
    saleTier[3].price = 28333 * 10**10; // 0.085
    saleTier[3].tokensSold = 0;
    
    /// @notice Tier 4 - ICO
    saleTier[4].startTime = now + 29 days; //unused
    saleTier[4].endTime = now + 35 days;
    saleTier[4].tokensToBeSold = 10;
    saleTier[4].price = 30000 * 10**10; // 0.09
    saleTier[4].tokensSold = 0;

    /// @notice Tier 5 - ICO
    saleTier[5].startTime = now + 36 days; //unused
    saleTier[5].endTime = now + 42 days;
    saleTier[5].tokensToBeSold = 10;
    saleTier[5].price = 31666 * 10**10; //0.095
    saleTier[5].tokensSold = 0;
 }

  /// @dev Fallback function.
  /// @dev Reject random eth being sent to the contract.
  function()
    public
    payable
  {
    revert();
  }

  /// @notice buyer calls this function to order to get on the list for approval
  /// buyers must send the ether with their whitelist application
  function buyTokens()
    external
    payable
    validPurchase
    contractPaused
    isValidPayload
    checkTierEndTime
    checkTierIncrement
    
    returns (uint8)
  {
    uint256 qtyOfTokensRequested;
    uint256 tierRemainingTokens;
    uint256 remainingWei;
    
    qtyOfTokensRequested = (msg.value).div(saleTier[tier].price);
    
    if ((qtyOfTokensRequested.add(saleTier[tier].tokensSold)) >= (saleTier[tier].tokensToBeSold)){
      tierRemainingTokens = saleTier[tier].tokensToBeSold.sub(saleTier[tier].tokensSold);
      uint256 totalSold = saleTier[tier].tokensSold.add(tierRemainingTokens);

      if(qtyOfTokensRequested != tierRemainingTokens){
        remainingWei = msg.value.sub(tierRemainingTokens.mul(saleTier[tier].price));
      }

      qtyOfTokensRequested = tierRemainingTokens;
      assert(totalSold == saleTier[tier].tokensToBeSold);
      tier++; //Will allow to roll from one tier to the next.

      if (tier <= 5){
        uint256 buyTokensRemainingWei = remainingWei.div(saleTier[tier].price);
        qtyOfTokensRequested += buyTokensRemainingWei;
        
      } else {
        qtyOfTokensRequested = tierRemainingTokens; 
      }
    }

    uint256 amount = msg.value;
    multiSigWallet.transfer(msg.value);

    weiRaised += amount;
    
    saleTier[tier].tokensSold += qtyOfTokensRequested;

    investors[msg.sender].whitelistStatus = Status.New;
    investors[msg.sender].qtyTokens += qtyOfTokensRequested;
    investors[msg.sender].contrAmount += amount; //will I get my value to stay and the eth to go?
    
    TokensReserved(msg.sender, qtyOfTokensRequested);
    lockTier = false;
    return tier;
  }

  /// notice interface for founders to whitelist investors
  ///  addresses array of investors
  ///  tier tier Number
  ///  status enable or disable
  function whitelistAddresses(address[] _addresses, bool _status) 
    public 
    onlyOwner 
    {
        for (uint256 i = 0; i < _addresses.length; i++) {
            address investorAddress = _addresses[i];
            if(_status == true){
                approvedWhitelistAddress(investorAddress); 
            } else {
                deniedWhitelistAddress(investorAddress);  
            } 
        }
   }

  /// notice sends requested tokens to the whitelist person
  function approvedWhitelistAddress(address _investorAddress) 
    internal
  {
    require(_investorAddress != 0x0);
    investors[_investorAddress].whitelistStatus = Status.Approved;
    uint256 tkns = investors[_investorAddress].qtyTokens;
    investors[_investorAddress].qtyTokens = 0;
    bnbToken.transferFrom(owner, _investorAddress, tkns);
  }

  /// @notice allows denied buyers the ability to get their Ether back
  function deniedWhitelistAddress(address _investorAddress) 
    internal 
  {
    require(_investorAddress != 0x0);
    investors[_investorAddress].whitelistStatus = Status.Denied;     
  }

  /// @notice used to move tokens from the later tiers into the earlier tiers
  /// contract must be paused to do the move
  /// @param tier from later tier to subtract the tokens from
  /// @param tier to add the tokens to
  /// @param how many tokens to take
  function moveTokensForSale(uint8 _tierFrom, uint8 _tierTo, uint256 _tokens) 
    public
    onlyOwner
  {
    require(paused = true);
    require(_tierFrom > _tierTo);
    require(_tokens <= ((saleTier[_tierFrom].tokensToBeSold).sub(saleTier[_tierFrom.tokensSold])));

    saleTier[_tierFrom].tokensToBeSold.sub(_tokens);
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

  /// @notice users can withdraw the wei eth sent
  /// used for refund process, incase of not enough funds raised
  /// or denied in the approval process
  function RefundWithdrawal()
    external
    contractPaused
    icoHasEnded
    refundOnly
    returns (bool success)
  {
    uint256 sendValue = investors[msg.sender].contrAmount;
    investors[msg.sender].contrAmount = 0;
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
    bnbToken.transferFrom(owner, multiSigWallet, transferUnsoldICOTokens());
    bnbToken.transferFrom(owner, teamWallet, _internalTokens);   
  }
  
  /// @notice Transfer any ether accidentally left in this contract 
  function cleanup()
    internal
    onlyOwner
  {
    multiSigWallet.transfer(this.balance);
  }

  /// @notice transfer unsold tokens to multiSigWallet to be used at a later date
  function transferUnsoldICOTokens()
    internal
    returns (uint256)
  {
    uint256 remainingTokens;
    for(uint8 i = 0; i < 6; i++){
      if(saleTier[i].tokensSold < saleTier[i].tokensToBeSold){
        remainingTokens += saleTier[i].tokensToBeSold.sub(saleTier[i].tokensSold);
      }
    }
    return remainingTokens;
  }
