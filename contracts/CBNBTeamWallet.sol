pragma solidity ^0.4.13;
import './CBNBToken.sol';
import './Ownable.sol';
import './SafeMath.sol';

contract CBNBTeamWallet is Ownable{
  using SafeMath for uint256;

  uint256 constant public FREEZE_TIME = 365 days;
  
  address public withdrawalAddress;
  CBNBToken public bnbToken;
  uint256 public startTime;
  uint256 public totalWithdrawn;

  mapping (address => uint256) teamMember;
  
  event LogWithdrawal(address _teamMember, uint256 _tokenAmount);
  

  modifier withdrawalTime() { 
    require(now >= startTime.add(FREEZE_TIME)); 
    _; 
  }
  

  function CBNBTeamWallet(address _bnbToken)
    public
  {  
    require(_bnbToken != 0x0);

    startTime = now;
    bnbToken = CBNBToken(_bnbToken);
    owner = msg.sender;

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
    withdrawalTime
    returns (bool success)
  {
    uint256 sendValue = teamMember[msg.sender];
    teamMember[msg.sender] = 0;
    bnbToken.transferFrom(this, msg.sender, sendValue);
    LogWithdrawal(msg.sender, sendValue);
    return true;
  }

}
