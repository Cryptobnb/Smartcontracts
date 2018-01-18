pragma solidity 0.4.18;
//version 0.2
import './CBNBToken.sol';
import './Ownable.sol';
import './SafeMath.sol';

contract CBNBCrowdSale is Ownable{
  using SafeMath for uint256;

  uint256 constant internal MIN_CONTRIBUTION = 0.1 ether;
  uint256 constant internal TOKEN_DECIMALS = 10**10;
  uint256 constant internal ETH_DECIMALS = 10**18;
  uint8 constant internal TIER_COUNT = 5;

  address public depositWallet;
  uint256 public icoStartTime;
  uint256 public icoEndTime;
  address public teamWallet;
  uint256 public weiRaised;
  uint256 public ethPrice;
  uint256 public decimals;
  uint256 public minLimit;
  address public owner;
  uint256 public cap;
  uint8 private tier;
  bool private paused;

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

  modifier pausedContract(){
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

    depositWallet = _depositWallet;
    icoStartTime = now; //pick a block number to start on
    icoEndTime = now + 90 days; //pick a block number to end on
    teamWallet = _teamWallet;
    weiRaised = 0;
    bnbToken = CBNBToken(_bnbToken);    
    decimals = 10;
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

  /// @notice buyer calls this function to order to get on the list for approval
  /// buyers must send the ethereum with their whitelist application
  function buyTokens()
    external
    payable
    icoIsActive
    pausedContract
    isValidPayload
    
    returns (uint8)
  {
    require(ethPrice != 0);
    require(investors[msg.sender].whitelistStatus != Status.Denied);
    require(msg.value >= MIN_CONTRIBUTION);

    uint256 price = (ETH_DECIMALS.mul(40+(8*tier)).div(1000)).div(ethPrice); //wei per token discluding decimals
    uint256 buyTokensRemainingWei;
    uint256 qtyOfTokensRequested = (msg.value.div(price)).mul(TOKEN_DECIMALS);
    uint256 tierRemainingTokens = saleTier[tier].tokensToBeSold.sub(saleTier[tier].tokensSold);
    uint256 remainingWei;
    uint256 amount; 
    
    if (qtyOfTokensRequested >= tierRemainingTokens){
      remainingWei = msg.value.sub((tierRemainingTokens.div(TOKEN_DECIMALS)).mul(price));
      qtyOfTokensRequested = tierRemainingTokens;
      tier++; 

      if (tier < TIER_COUNT){
        buyTokensRemainingWei = (remainingWei.mul(price)).mul(TOKEN_DECIMALS);
        qtyOfTokensRequested += buyTokensRemainingWei;
        saleTier[tier].tokensSold += buyTokensRemainingWei;
        remainingWei = 0;
      } else {
        msg.sender.transfer(remainingWei); 
      }

    } else {
      saleTier[tier].tokensSold += qtyOfTokensRequested;
    }

    amount = msg.value.sub(remainingWei);
    weiRaised += amount;
    depositWallet.transfer(amount);

    investors[msg.sender].contrAmount += amount;

    if(investors[msg.sender].whitelistStatus == Status.Approved){
      bnbToken.transferFrom(owner, msg.sender, qtyOfTokensRequested);
      LogTokensTransferedFrom(owner, msg.sender, qtyOfTokensRequested);     
    } else {
      investors[msg.sender].qtyTokens += qtyOfTokensRequested;
      LogTokensReserved(msg.sender, qtyOfTokensRequested);
    }

    return tier;
  }

  /// notice interface for founders to whitelist investors
  ///  addresses array of investors
  ///  tier Number
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
    LogTokensTransferedFrom(owner, msg.sender, tkns);
  }

  /// @notice allows denied buyers the ability to get their Ethereum back
  function deniedWhitelistAddress(address _investorAddress) 
    internal 
  {
    require(_investorAddress != 0x0);
    investors[_investorAddress].whitelistStatus = Status.Denied;
    investors[_investorAddress].qtyTokens = 0;     
  }

  /// @notice used to move tokens from the later tiers into the earlier tiers
  /// contract must be paused to do the move
  /// param tier from later tier to subtract the tokens from
  /// param tier to add the tokens to
  /// param how many tokens to take
  function moveTokensForSale(uint8 _tierFrom, uint8 _tierTo, uint256 _tokens) 
    public
    onlyOwner
  {
    require(paused = true);
    require(_tierFrom > _tierTo);
    require(_tokens <= ((saleTier[_tierFrom].tokensToBeSold).sub(saleTier[_tierFrom].tokensSold)));

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

  /// @notice users can withdraw the wei etheum sent
  /// used for refund process incase not enough funds raised
  /// or denied in the approval process
  /// @notice no ethereum will be held in the crowdsale contract
  /// when refunds become available the amount of Ethererum needed will
  /// be manually transfered back to the crowdsale to be refunded
  function RefundWithdrawal()
    external
    pausedContract
    icoHasEnded
    returns (bool success)
  {
    if(weiRaised >= minLimit){
      require(investors[msg.sender].whitelistStatus != Status.Approved);
    }

    uint256 sendValue = investors[msg.sender].contrAmount;
    investors[msg.sender].contrAmount = 0;
    investors[msg.sender].qtyTokens = 0;
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
}