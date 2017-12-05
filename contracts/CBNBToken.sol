pragma solidity ^0.4.18;

import './StandardToken.sol';
import './Ownable.sol';

contract CBNBToken is StandardToken, Ownable {

  string public constant name = "CryptoBNB";
  string public constant symbol = "CBnB";
  uint8 public constant decimals = 10;
  
  function CBNBToken()
    public
  {
    // 1,000,000,000 total supply of CBnB tokens
    totalSupply = 1000000000 * 10**10;                     
												 
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
}


