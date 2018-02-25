pragma solidity 0.4.19;

import './CBNBToken.sol';
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';
import 'zeppelin-solidity/contracts/math/SafeMath.sol';

contract CBNBTeamWallet is Ownable{
  using SafeMath for uint256;

  uint256 constant public FREEZE_TIME = 365 days;
  
  CBNBToken public bnbToken;
  uint256 public startTime;
  uint256 public totalWithdrawn;
  address public crowdsaleContract;

  mapping (address => uint256) teamMember;
  
  event LogWithdrawal(address _teamMember, uint256 _tokenAmount);
  

  modifier withdrawalAvailable() { 
    require(now >= startTime.add(FREEZE_TIME)); 
    _; 
  }
  
  function CBNBTeamWallet(address _bnbToken)
    public
  {  
    require(_bnbToken != address(0));
    bnbToken = CBNBToken(_bnbToken);
    owner = msg.sender;

  }

  function setCrowdsaleContract(address _crowdsaleContract)
    public
    onlyOwner
  {
    crowdsaleContract = _crowdsaleContract;
  }

  function setFreezeTime(uint256 freezeStartTime)
    external
  {
    require(msg.sender == crowdsaleContract);
    require(crowdsaleContract != address(0));
    startTime = freezeStartTime;
  }

  function addTeamMember(address _teamMember, uint256 _tokenAmount)
    public
    onlyOwner
    returns(bool success)
  {
    teamMember[_teamMember] = _tokenAmount;
    return true;
  }

  function transferTeamTokens()
    public
    withdrawalAvailable
    returns (bool success)
  {
    uint256 sendValue = teamMember[msg.sender];
    teamMember[msg.sender] = 0;
    bnbToken.transfer(msg.sender, sendValue);
    LogWithdrawal(msg.sender, sendValue);
    return true;
  }

}
