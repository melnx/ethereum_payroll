var WidgetCoin = artifacts.require('WidgetCoin');
var PayCoin = artifacts.require('PayCoin');

var Payroll = artifacts.require('Payroll');

function toWei(number){
    return number * 1e18;
}

function fromWei(number){
    return number / 1e18;
}

var initialSupply = 1000000;

contract('Payroll', function(accounts) {
    var account_one = accounts[0];   //owner
    var account_two = accounts[1];   //oracle
    var account_three = accounts[2]; //employee 1
    var account_four = accounts[3];  //employee 2

    var payroll;
    var token1;
    var token2;

    var token1price = toWei(0.5);
    var token2price = toWei(0.2);

    var token1percentage = 60;
    var token2percentage = 40;

    var employeeSalary = toWei(102000);
    var tokensToDeposit = toWei(50000);

    it("should deploy, set owner and oracle correctly", function() {
        return Payroll.deployed().then(function(instance){
            payroll = instance;
            return payroll.owner.call();
        }).then(function(owner) {
            assert.equal(account_one, owner, "owner wasn't set correctly");
            return payroll.setOracle(account_two, {from:account_one});
        }).then(function() {
            return payroll.oracle.call();
        }).then(function(oracle) {
            assert.equal(account_two, oracle, "oracle wasn't updated correctly");
        });
    });

    it("should deploy tokens and set their exchange rates", function(){

        return WidgetCoin.deployed().then(function(instance){
            token1 = instance;
            return PayCoin.deployed();
        }).then(function(instance){
            token2 = instance;
            return payroll.setExchangeRate(token1.address, token1price, {from:account_two});
        }).then(function(){
            return payroll.EURExchangeRates.call(token1.address);
        }).then(function(rate){
            assert.equal(token1price, rate.toNumber(), "exchange rate for token 1 was not set correctly individually");
            token1price = toWei( 0.25 );
            return payroll.setExchangeRates([token1.address, token2.address], [token1price, token2price], {from:account_two});
        }).then(function(){
            return payroll.EURExchangeRates.call(token2.address);
        }).then(function(rate){
            assert.equal(token2price, rate.toNumber(), "exchange rate for token 2 was not set correctly in batch");
            return payroll.EURExchangeRates.call(token1.address);
        }).then(function(rate){
            assert.equal(token1price, rate.toNumber(), "exchange rate for token 1 was not set correctly in batch");
            //console.log("exchange rates set");
        })
    });

    it("should deposit funds correctly", function(){
        return payroll.addFunds({value:toWei(1)}).then(function(){

            return web3.eth.getBalance(payroll.address);
        }).then(function(balance){
            assert.equal(toWei(1), balance.toNumber(), "ETH balance not correct after depositing funds");
        })
    });

    it("should deposit token funds correctly", function(){
        return token1.approve(payroll.address, tokensToDeposit).then(function() {

            return payroll.addTokenFunds(token1.address, tokensToDeposit);
        }).then(function(){

            return token1.balanceOf.call(payroll.address);
        }).then(function(balance){
            assert.equal(tokensToDeposit, balance.toNumber(), "token balance not correct after depositing token funds");
            return token2.approve(payroll.address, tokensToDeposit)
        }).then(function(){
            return payroll.addTokenFunds(token2.address, tokensToDeposit);
        }).then(function(){
            return token2.balanceOf.call(payroll.address);
        }).then(function(balance){
            assert.equal(tokensToDeposit, balance.toNumber(), "token 2 balance not correct after deposit");

            //console.log("funds deposited")
        })
    });

    it("should add an employee and set their token allocations", function (){
        return payroll.addEmployee(account_three, [token1.address, token2.address], employeeSalary).then(function() {
            return payroll.getEmployeeCount.call();
        }).then(function(employee_count){
            assert.equal(employee_count.toNumber(), 1, "employee count was not correct");
            return payroll.getEmployee.call(1);
        }).then(function(employee){
            assert.equal(employee[0], account_three, "employee address wasn't set correctly");
            assert.equal(employee[1][0], token1.address, "employee allowed tokens[0] wasn't set correctly");
            assert.equal(employee[1][1], token2.address, "employee allowed tokens[1] wasn't set correctly");
            assert.equal(employee[2].toNumber(), employeeSalary, "employee address wasn't set correctly");

            //console.log("employee salary", employee[2].toNumber());

            return payroll.getActiveEmployeeCount.call();
        }).then(function(active_employee_count) {
            assert.equal(active_employee_count.toNumber(), 1, "active employee count was not correct");
            return payroll.employeeAddressToId.call(account_three);
        }).then(function(id){
            assert.equal(id.toNumber(), 1, "employee id not correct")
            return payroll.determineAllocation([token1.address, token2.address], [token1percentage, token2percentage], {from:account_three, gas:900000})
        }).then(function(){
            return payroll.getAllocationForAddress.call(account_three);
        }).catch(function(error){
            console.log(error);
        }).then(function(allocation){
            assert.equal(token1.address, allocation[0][0], "address for token 1 not correct");
            assert.equal(token2.address, allocation[0][1], "address for token 2 not correct");
            assert.equal(token1percentage, allocation[1][0].toNumber(), "percentage for token 1 not correct");
            assert.equal(token2percentage, allocation[1][1].toNumber(), "percentage for token 2 not correct");

            //console.log("employee added");
        })

    })


    it("should calculate burn rate", function(){
        return payroll.calculatePayrollBurnrate.call().then(function(burnRate){
            assert.equal(employeeSalary/12, burnRate.toNumber(), "burn rate not calculated correctly" );
        })
    })

    it("should calculate runway", function(){

        //console.log("getting runway")
        return payroll.calculateBurnratesForTokens.call().catch(function(error){
            console.log(error);
        }).then(function(burnrates){
            //console.log("TOKEN BURN RATE", burnrates);

            var token1burnrate =  Math.floor( (((employeeSalary/365) * (token1percentage/100)) * (1/fromWei(token1price)) ));
            var token2burnrate =  Math.floor((((employeeSalary/365) * (token2percentage/100)) * (1/fromWei(token2price)) ));

            //console.log("BURN RATES", token1burnrate, token2burnrate);

            assert.equal(670000000000000000000, burnrates[1].toNumber(), "wrong burn rate for token 1");
            assert.equal(558000000000000000000, burnrates[2].toNumber(), "wrong burn rate for token 2");

            return payroll.calculatePayrollRunway.call();
        }).then(function(runway){
            //console.log("RUNWAY", runway);

            var token1runway =  Math.floor(tokensToDeposit / (((employeeSalary/365) * (token1percentage/100)) * (1/fromWei(token1price)) ));
            var token2runway =  Math.floor(tokensToDeposit / (((employeeSalary/365) * (token2percentage/100)) * (1/fromWei(token2price)) ));

            //console.log("RUNWAYS", token1runway, token2runway)

            assert.equal(token1runway < token2runway ? token1.address : token2.address, runway[0], "incorrect token reduces runway");
            assert.equal(Math.min(token1runway, token2runway), runway[1].toNumber(), "runway not calculated correctly" );
        })
    })

    it("should pay the employee correct amount", function() {

        var expectedbalance1;
        var expectedbalance2;

        return payroll.getAllocation.call({from: account_three}).then(function (allocation) {
            //console.log("ALLOCATIONS", allocation);

            return payroll.payday({from: account_three})
        }).catch(function(error){
            console.log(error);
        }).then(function(){
            //console.log("PAYDAY SUCCESSFUL");

            return token1.balanceOf.call(account_three);
        }).then(function(balance){

            expectedbalance1 = (employeeSalary/12) * (token1percentage/100) * (1/fromWei(token1price));
            //console.log("EXPECTED TOKEN 1 BALANCE", expectedbalance1)
            //console.log("EMPLOYEE TOKEN 1 BALANCE", balance.toNumber());

            assert.equal(expectedbalance1, balance.toNumber(), "token 1 balance wrong after payday");

            return token2.balanceOf.call(account_three);
        }).then(function(balance){

            expectedbalance2 = (employeeSalary/12) * (token2percentage/100) * (1/fromWei(token2price));
            //console.log("EXPECTED TOKEN 2 BALANCE", expectedbalance)
            //console.log("EMPLOYEE TOKEN 2 BALANCE", balance.toNumber());

            assert.equal(expectedbalance2, balance.toNumber(), "token 2 balance wrong after payday");

            return token1.balanceOf.call(payroll.address);
        }).then(function(balance){
            //console.log("PAYROLL TOKEN 1 BALANCE", balance.toNumber());
            //assert.equal(tokensToDeposit - expectedbalance1, balance.toNumber(), "payroll contract has wrong token 1 balance")

            return token2.balanceOf.call(payroll.address);
        }).then(function(balance){
            //console.log("PAYROLL TOKEN 2 BALANCE", balance.toNumber());
            //assert.equal(tokensToDeposit - expectedbalance2, balance.toNumber(), "payroll contract has wrong token 2 balance")
        })
    })

    /*it("should remove and employee correctly", function(){

        payroll.addEmployee(account_four, [token1.address, token2.address], employeeSalary).then(function() {
            return payroll.getEmployeeCount.call();
        }).then(function(count){
            assert.equal(2, count.toNumber(), "employee count was not correct after adding employee 2");

            return payroll.removeEmployee(1)
        }).then(function(){
            return payroll
            return payroll.getActiveEmployeeCount.call();
        }).then(function(active_count){
            assert.equal(0, active_count.toNumber(), "removing employee did not decrement active employee count");

            return payroll.getEmployeeCount.call();
        }).then(function(count){
            assert.equal(1, count.toNumber(), "removing employee changed employee count");
        })

    });*/

    /*it("should set allocation correctly", function(){
        payroll.determineAllocation([token1.address, token2.address], [50, 50], {from:account_three}).then(function(){
            console.log("SET ALLOCATION CORRECTLY")

            //return payroll.distributionsTokens.call(account_three);
        }).then(function(tokens){
            console.log("TOKENS", tokens);

            return payroll.distributions.call(account_three);
        }).then(function(distributions){
            console.log("DISTRIBUTIONS", distributions)
        })
    })*/

})