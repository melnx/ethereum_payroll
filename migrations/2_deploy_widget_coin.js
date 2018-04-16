var Coin = artifacts.require("WidgetCoin");
var Coin2 = artifacts.require("PayCoin");
var Payroll = artifacts.require("Payroll");

module.exports = function(deployer) {
    //deploy 2 tokens and the payroll contract
    deployer.deploy(Coin).then(function(){
        return deployer.deploy(Coin2);
    }).then(function() {
        return deployer.deploy(Payroll);
    });
};
