pragma solidity ^0.4.13;
import './BNBToken.sol';
import './Ownable.sol';
import './SafeMath.sol';

contract BNBOwnerWallet is Ownable{
  using SafeMath for uint256;

  uint256 constant public SUSPEND_PERIOD = 540 days; //18 months
  address public withdrawalAddress;
  BNBToken public bnbToken;
  uint256 public startTime;
  uint256 public totalWithdrawn;

  
  function BNBOwnerWallet() {    
  }

  function setup(address _bnbToken, address _withdrawalAddress)
    public
    onlyOwner
  {
    require(_bnbToken != 0x0);
    require(_withdrawalAddress != 0x0);

    bnbToken = BNBToken(_bnbToken);
    withdrawalAddress = _withdrawalAddress;
    startTime = now;
  }

  function withdraw(uint256 requestedAmount)
    public
    onlyOwner
    returns (uint256 amount)
  {
    uint256 limit = maxPossibleWithdrawal();
    uint256 withdrawalAmount = requestedAmount;
    if (requestedAmount > limit) {
      withdrawalAmount = limit;
    }

    if (withdrawalAmount > 0) {
      if (!bnbToken.transfer(withdrawalAddress, withdrawalAmount)) {
        revert();
      }
      totalWithdrawn = totalWithdrawn.add(withdrawalAmount);
    }

    return withdrawalAmount;
  }

  function maxPossibleWithdrawal()
    public
    constant
    returns (uint256)
  {
    if (now < startTime.add(SUSPEND_PERIOD)) {
      return 0;
    } else {
       return this.balance;
    }
  }

}
