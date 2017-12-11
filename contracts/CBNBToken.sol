pragma solidity ^0.4.18;

import './StandardToken.sol';
import './Ownable.sol';

contract CBNBToken is StandardToken, Ownable {
  address public crowdsaleContract;
  string public constant symbol = "CBNB";
  string public constant name = "CryptoBNB";
  uint8 public constant decimals = 10;
  bool public paused;

  
  function CBNBToken()
    public
  {
    // 1,000,000,000 total supply of CBnB tokens
    totalSupply = 1000000000 * 10**10;
    paused = true;
                  
												 
	  balances[msg.sender] = totalSupply;
    Transfer(0, owner, totalSupply);

    // making sure the msg.sender and the owner are the same, and that the
		// address of the owner recieved the totalSupply of tokens.
    assert(balances[owner] == totalSupply);                
  }

  ///notice adds the ability to set the crowdsaleContract by the owner for transfer and transferfrom functions
  function setCrowdsaleContract(address _crowdsaleContract)
  public 
  onlyOwner {
  crowdsaleContract = _crowdsaleContract;
  }

  ///notice once activated the tokens will be transferable by token holders cannot be reverted
  function activate() 
  public
  onlyOwner {
  paused = false;
  }

  function transfer(address _to, uint256 _value) public returns (bool) {
    require (!paused || msg.sender == crowdsaleContract); //doesnt allow transfer until unpaused or crowdsaleContract calls it
    return super.transfer(_to, _value);
  }

  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    require (!paused || msg.sender == crowdsaleContract); //doesnt allow transferFrom until unpaused or crowdsaleContract calls it
    return super.transferFrom(_from, _to, _value);
  }
}


