var Token = artifacts.require("./CBNBToken.sol");
var CrowdSale = artifacts.require("./CBNBCrowdSale_v2.sol");

//var endtime = 1;
var holdingWallet = "0xfa2c3fa9a0aeaeafdf05502e6b3dc1d58dc78143";
var teamWallet = "0x20d5e032a2583c74e0cca06f0e252ef01d744d0b";
var remainingTokensWallet = "0x04038c1a5f95d4418a9cfcde4c2403655e2c3392";
//var cap = 200000000000000000000000;
//module.exports = function(deployer, network, accounts) {
module.exports = function(deployer) {
  deployer.deploy(Token).then(function() {
  	return deployer.deploy(CrowdSale, remainingTokensWallet, holdingWallet, Token.address, teamWallet);
  });
};
