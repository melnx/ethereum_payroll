# Payroll

## compile / test

the truffle test suite tests the basic workflow of the payroll contract

##### to run it, go to the root project directory

in one console window run the truffle test EVM
```
truffle develop
```

open a new tab and run the following commands to compile and deploy the contracts
```
truffle compile
truffle migrate
```

run the tests
```
truffle test
```

the result should look something like this
```
Using network 'development'.



  Contract: Payroll
    ✓ should deploy, set owner and oracle correctly (191ms)
    ✓ should deploy tokens and set their exchange rates (313ms)
    ✓ should deposit funds correctly (235ms)
    ✓ should deposit token funds correctly (407ms)
    ✓ should add an employee and set their token allocations (514ms)
    ✓ should calculate burn rate
    ✓ should calculate runway (323ms)
    ✓ should pay the employee correct amount (353ms)

  Contract: WidgetCoin
    ✓ should put 1000000 WidgetCoin in the first account
    ✓ should send coin correctly (157ms)
    ✓ should approve and transferFrom coin correctly (194ms)


  11 passing (3s)
``` 

## smart contract

```solidity
contract PayrollInterface {
    /* OWNER ONLY */
    function setOracle(address newOracle) public;
    function addEmployee(address accountAddress, address[] allowedTokens, uint256 initialYearlyEURSalary) public;
    function setEmployeeSalary(uint256 employeeId, uint256 yearlyEURSalary) public;
    function setEmployeeAllowedTokens(uint employeeId, address[] allowedTokens) public;
    function setEmployeeAllowedTokensForAll(address[] allowedTokens) public;
    function setEmployeeAllowedTokensToDeposited() public;
    function removeEmployee(uint256 employeeId) public;

    function addFunds() public payable;
    function scapeHatch() public;
    function addTokenFunds(address token, uint256 amount) public;

    function getEmployeeCount() public constant returns (uint256);
    function getActiveEmployeeCount() public constant returns (uint256);
    function getEmployee(uint256 employeeId) public constant returns (address accountAddress, address[] allowedTokens, uint yearlyEURSalar); // Return all important info too

    function calculatePayrollBurnrate() public constant returns (uint256); // Monthly EUR amount spent in salaries
    function calculatePayrollRunway() public constant returns (address, uint256); // Days until the contract can run out of funds
    function calculateBurnratesForTokens() public view returns (uint[] memory); // amount of token burned per day

    /* EMPLOYEE ONLY */
    function determineAllocation(address[] tokens, uint256[] distribution) public; // only callable once every 6 months
    function payday() public; // only callable once a month
    function getAllocation() public view returns (address[], uint[]);
    function getAllocationForAddress(address _address) public view returns (address[], uint[]);
    function getAllocationForEmployee(uint employeeId) public view returns (address[], uint[]);

    /* ORACLE ONLY */
    function setExchangeRate(address token, uint256 EURExchangeRate) public; // uses price in EUR wei
    function setExchangeRates(address[] tokens, uint256[] EURExchangeRates) public; // set multiple token exchange rates
}
```

There are 3 tiers of users: `owner` the contract creator, `employee` get paid into tokens, 
`oracle` at trusted Ethereum account which can set token exchange rates 

## Owner

#### setOracle
`setOracle(address owner)` used to set the oracle address, this allows another
Ethereum account to set exchange rates (token prices) in the payroll contract

#### addEmployee
`addEmployee(address accountAddress, address[] allowedTokens, uint256 initialYearlyEURSalary)`
adds an employee with the ETH address `accountAddress` allowed tokens `allowedTokens`
and initial yearly salary of `initialYearlyEURSalary` 
(this number has 18 decimals, i.e. multiplied by 10^18)

the owner can further change employee info by calling `setEmployeeSalary`, 
`setEmployeeAllowedTokens`, `setEmployeeAllowedTokensForAll`, `setEmployeeAllowedTokensToDeposited`

you can retrieve employees via `getEmployee(employeeId)`

you can remove employees by calling `removeEmployee(employeeId)` employeeId is 1-indexed
(i.e. the first user has user id of `1`)

#### addFunds
`addFunds() payable` call this with an ETH value to deposit ETH directly

#### addTokenFunds
`addTokenFunds(address token, uint256 amount)` the owner must first `approve()` the token funds
for the payroll contract so that there's sufficient allowance for the payroll contract 
to call `transferFrom()`
 
#### calculatePayrollBurnrate
`calculatePayrollBurnrate()` calculates how much EUR is required every month 
to pay all the employees, with 18 decimals (multiplied by 10^18)

#### calculatePayrollRunway
`calculatePayrollRunway()` tells you which token will run out the soonest, 
returns the token address and the number of days it will be depleted in 
 
#### scapeHatch
`scapeHatch()` drains all funds (tokens and ETH) from the payroll contract and returns them
to the owner. 
 
## Oracle

#### setExchangeRate
`setExchangeRate(address token, uint EURExchangeRate)` 
is used to set the token prices,
 
the provided exchange rate should be in the format of the token's price in EUR 
as an integer with 18 decimals (same as price in wei of ETHEUR)

e.g. the price of `0.25` EUR is represented as `250000000000000000`  

`setExchangeRates(address[] tokens uint256[] EURExchangeRates)` lets the oracle 
set token prices in batches

## Employee

#### determineAllocation
`determineAllocation(address[] tokens, uint256[] distribution)` tokens are token addresses
distribution is an array of integers that represent percentages.  They must range between
1-100 and have a sum of 100

to allocate being paid in ETH use the address `0x0000000000000000000000000000000000000000`

#### payday
`payday()` the employee can call this every 30 days to get paid 1/12 of their yearly salary
they get transferred tokens based on their allocation percentage. 

e.g. if they have 100% allocation for one token, they get paid entirely in that token. 
with 60%, 40% allocations they get paid 60% in token 1 and 40% in token 2