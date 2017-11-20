pragma solidity ^0.4.13;

import './StandardToken.sol';
import './Ownable.sol';

contract BNBToken is StandardToken, Ownable {

  string public constant name = "CryptoBNB";
  string public constant symbol = "CBnB";
  uint8 public constant decimals = 10;
  
  function BNBToken()
    public
  {
    // 1,000,000,000 total supply of CBnB tokens
    totalSupply = 1000000000 * 10**(decimals);                     
												 
	  balances[msg.sender] = totalSupply;
    Transfer(0, owner, totalSupply);

    // making sure the msg.sender and the owner are the same, and that the
		// address of the owner recieved the totalSupply of tokens.
    assert(balances[owner] == totalSupply);                
  }
}


