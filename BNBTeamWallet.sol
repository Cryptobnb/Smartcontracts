pragma solidity ^0.4.15;
import './BNBToken.sol';
import './Ownable.sol';
import './SafeMath.sol';

contract BNBTeamWallet is Ownable{
  using SafeMath for uint256;

  uint256 constant public FREEZE_TIME = 365 days;
  
  address public withdrawalAddress;
  BNBToken public bnbToken;
  uint256 public startTime;
  uint256 public totalWithdrawn;

  mapping (address => uint256) teamMember;
  
  event LogWithdrawal(address _teamMember, uint256 _tokenAmount);
  

  modifier withdrawalTime() { 
    require(now >= startTime + FREEZE_TIME); 
    _; 
  }
  

  function BNBTeamWallet(address _bnbToken)
    public
  {  
    require(_bnbToken != 0x0);

    startTime = now;
    bnbToken = BNBToken(_qcToken);
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

  function transferTeamTokens(uint256 _tokenAmount)
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
