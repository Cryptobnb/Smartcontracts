const BigNumber = require('bignumber.js');

require('chai')
    .use(require("chai-bignumber")(BigNumber))
    .use(require('chai-as-promised'))
    .should();

const {increaseTime, revert, snapshot, mine} = require('./evmMethods');
const {web3async} = require('./web3Utils');

const Token = artifacts.require("./CBNBToken.sol");
const Wallet = artifacts.require("./CBNBTeamWallet.sol");
const Crowdsale = artifacts.require("./CBNBCrowdSale_v2.sol");

const DAY = 24 * 3600;

contract('TemplateCrowdsale', accounts => {
    const BUYER_1 = accounts[1];

    let snapshotId;

    beforeEach(async () => {
        snapshotId = (await snapshot()).result;

        this.token = await Token.new();
        this.teamWallet = await Wallet.new(this.token.address);
        this.crowdsale = await Crowdsale.new(accounts[3], accounts[4], this.token.address, this.teamWallet.address);
        await this.token.setCrowdsaleContract(this.crowdsale.address);
        await this.teamWallet.setCrowdsaleContract(this.crowdsale.address);
        await this.crowdsale.setEtherPrice(1000);
        await this.token.approve(this.crowdsale.address, 1000000000 * 10**10);
    });

    afterEach(async () => {
        await revert(snapshotId);
    });

    it('#1. should refund ether for denied address', async () => {
        await this.crowdsale.approveAddressForWhitelist([BUYER_1]);
        await this.crowdsale.sendTransaction({from: BUYER_1, value: web3.toWei(100000, 'ether')});
        await this.crowdsale.finalize();
        await this.crowdsale.denyAddressForWhitelist([BUYER_1]);
        const balanceBeforeRefund = await web3async(web3.eth, web3.eth.getBalance, BUYER_1);
        await this.crowdsale.refundWithdrawal({from: BUYER_1});
        await this.token.balanceOf(BUYER_1).should.eventually.bignumber.be.zero;
        const balanceAfterRefund = await web3async(web3.eth, web3.eth.getBalance, BUYER_1);
        balanceAfterRefund.should.bignumber.be.greaterThan(balanceBeforeRefund);
    });

    it("#2. should refund ether for approved address if doesn't collected minLimit", async () => {
        await this.crowdsale.approveAddressForWhitelist([BUYER_1]);
        await this.crowdsale.sendTransaction({from: BUYER_1, value: web3.toWei(1, 'ether')});
        await increaseTime(91 * DAY);
        const balanceBeforeRefund = await web3async(web3.eth, web3.eth.getBalance, BUYER_1);
        await this.crowdsale.refundWithdrawal({from: BUYER_1});
        const balanceAfterRefund = await web3async(web3.eth, web3.eth.getBalance, BUYER_1);
        balanceAfterRefund.should.bignumber.be.greaterThan(balanceBeforeRefund);
    });

    it("#3. should refund ether for denied address if doesn't collected minLimit", async () => {
        await this.crowdsale.approveAddressForWhitelist([BUYER_1]);
        await this.crowdsale.sendTransaction({from: BUYER_1, value: web3.toWei(1, 'ether')});
        await increaseTime(91 * DAY);
        await this.crowdsale.denyAddressForWhitelist([BUYER_1]);
        const balanceBeforeRefund = await web3async(web3.eth, web3.eth.getBalance, BUYER_1);
        await this.crowdsale.refundWithdrawal({from: BUYER_1});
        const balanceAfterRefund = await web3async(web3.eth, web3.eth.getBalance, BUYER_1);
        balanceAfterRefund.should.bignumber.be.greaterThan(balanceBeforeRefund);
    });
});
 evmMethods.js
const mineBlock = () => {
    return new Promise((resolve, reject) => {
        web3.currentProvider.sendAsync(
            {jsonrpc: "2.0", method: "evm_mine", params: [], id: 0},
            function (error, result) {
                if (error) {
                    reject(error);
                } else {
                    resolve(result);
                }
            }
        );
    });
};

module.exports = {
    increaseTime: addSeconds => {
        return new Promise((resolve, reject) => {
            web3.currentProvider.sendAsync(
                [{jsonrpc: "2.0", method: "evm_increaseTime", params: [addSeconds], id: 0},
                    {jsonrpc: "2.0", method: "evm_mine", params: [], id: 0}],
                function (error, result) {
                    if (error) {
                        reject(error);
                    } else {
                        resolve(result);
                    }
                }
            );
        });
    },
    snapshot: () => {
        return new Promise((resolve, reject) => {
            web3.currentProvider.sendAsync(
                {jsonrpc: "2.0", method: "evm_snapshot", params: [], id: 0},
                function (error, result) {
                    if (error) {
                        reject(error);
                    } else {
                        resolve(result);
                    }
                }
            );
        });
    },
    revert: id => {
        return new Promise((resolve, reject) => {
            web3.currentProvider.sendAsync(
                {jsonrpc: "2.0", method: "evm_revert", params: [id], id: 0},
                function (error, result) {
                    if (error) {
                        reject(error);
                    } else {
                        resolve(result);
                    }
                }
            );
        });
    },
    mine: mineBlock
};
 web3Utils.js
const estimateConstructGasWithValue = (target, value, ...args) => {
    return new Promise((resolve, reject) => {
        const web3contract = target.web3.eth.contract(target.abi);
        args.push({
            data: target.unlinked_binary
        });
        const constructData = web3contract.new.getData.apply(web3contract.new, args);
        web3.eth.estimateGas({data: constructData, value: value}, function (err, gas) {
            if (err) {
                reject(err);
            }
            else {
                resolve(gas);
            }
        });
    });
};

module.exports = {
    web3async: (that, func, ...args) => {
        return new Promise((resolve, reject) => {
            args.push(
                function (error, result) {
                    if (error) {
                        reject(error);
                    } else {
                        resolve(result);
                    }
                }
            );
            func.apply(that, args);
        });
    },
    estimateConstructGas: (target, ...args) => {
        args.unshift(0);
        args.unshift(target);
        return estimateConstructGasWithValue.apply(this, args);
    },

    estimateConstructGasWithValue: estimateConstructGasWithValue
};