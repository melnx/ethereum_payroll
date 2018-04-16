pragma solidity ^0.4.21;

// For the sake of simplicity lets assume EUR is a ERC20 token
// Also lets assume we can 100% trust the exchange rate oracle
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
    function setExchangeRate(address token, uint256 EURExchangeRate) public; // uses decimals from token
    function setExchangeRates(address[] tokens, uint256[] EURExchangeRate) public; // set multiple token exchange rates
}

contract ERC20 {
    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);
    uint8 public decimals;

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}


interface tokenRecipient { function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) external; }

contract TokenERC20 {
    using SafeMath for uint;
    // Public variables of the token
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    // 18 decimals is the strongly suggested default, avoid changing it
    uint256 public totalSupply;

    // This creates an array with all balances
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    // This generates a public event on the blockchain that will notify clients
    event Transfer(address indexed from, address indexed to, uint256 value);

    // This notifies clients about the amount burnt
    event Burn(address indexed from, uint256 value);

    /**
     * Constructor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    function TokenERC20(
        uint256 initialSupply,
        string tokenName,
        string tokenSymbol
    ) public {
        totalSupply = initialSupply * 10 ** uint256(decimals);  // Update total supply with the decimal amount
        balanceOf[msg.sender] = totalSupply;                // Give the creator all initial tokens
        name = tokenName;                                   // Set the name for display purposes
        symbol = tokenSymbol;                               // Set the symbol for display purposes
    }

    /**
     * Internal transfer, only can be called by this contract
     */
    function _transfer(address _from, address _to, uint _value) internal {
        // Prevent transfer to 0x0 address. Use burn() instead
        require(_to != 0x0);
        // Check if the sender has enough
        require(balanceOf[_from] >= _value);
        // Check for overflows
        require(balanceOf[_to].add(_value) > balanceOf[_to]);
        // Save this for an assertion in the future
        uint previousBalances = balanceOf[_from].add(balanceOf[_to]);
        // Subtract from the sender
        balanceOf[_from] = balanceOf[_from].sub(_value);
        // Add the same to the recipient
        balanceOf[_to] = balanceOf[_to].add(_value);
        emit Transfer(_from, _to, _value);
        // Asserts are used to use static analysis to find bugs in your code. They should never fail
        assert(balanceOf[_from].add(balanceOf[_to]) == previousBalances);
    }

    /**
     * Transfer tokens
     *
     * Send `_value` tokens to `_to` from your account
     *
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transfer(address _to, uint256 _value) public {
        _transfer(msg.sender, _to, _value);
    }

    /**
     * Transfer tokens from other address
     *
     * Send `_value` tokens to `_to` on behalf of `_from`
     *
     * @param _from The address of the sender
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_value <= allowance[_from][msg.sender]);     // Check allowance
        allowance[_from][msg.sender] = allowance[_from][msg.sender].sub(_value);
        _transfer(_from, _to, _value);
        return true;
    }

    /**
     * Set allowance for other address
     *
     * Allows `_spender` to spend no more than `_value` tokens on your behalf
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     */
    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        return true;
    }

    /**
     * Set allowance for other address and notify
     *
     * Allows `_spender` to spend no more than `_value` tokens on your behalf, and then ping the contract about it
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     * @param _extraData some extra information to send to the approved contract
     */
    function approveAndCall(address _spender, uint256 _value, bytes _extraData)
    public
    returns (bool success) {
        tokenRecipient spender = tokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, this, _extraData);
            return true;
        }
    }

    /**
     * Destroy tokens
     *
     * Remove `_value` tokens from the system irreversibly
     *
     * @param _value the amount of money to burn
     */
    function burn(uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value);   // Check if the sender has enough
        balanceOf[msg.sender] = balanceOf[msg.sender].sub(_value); // Subtract from the sender
        totalSupply = totalSupply.sub(_value);      // Updates totalSupply
        emit Burn(msg.sender, _value);
        return true;
    }

    /**
     * Destroy tokens from other account
     *
     * Remove `_value` tokens from the system irreversibly on behalf of `_from`.
     *
     * @param _from the address of the sender
     * @param _value the amount of money to burn
     */
    function burnFrom(address _from, uint256 _value) public returns (bool success) {
        require(balanceOf[_from] >= _value);                // Check if the targeted balance is enough
        require(_value <= allowance[_from][msg.sender]);    // Check allowance
        balanceOf[_from] = balanceOf[_from].sub(_value);    // Subtract from the targeted balance
        allowance[_from][msg.sender] = allowance[_from][msg.sender].sub(_value); // Subtract from the sender's allowance
        totalSupply = totalSupply.sub(_value);              // Update totalSupply
        emit Burn(_from, _value);
        return true;
    }

}

contract WidgetCoin is TokenERC20 {

    /**
     * Constrctor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    function WidgetCoin() TokenERC20(1000000, 'WidgetCoin', 'WIDG') public {}
}


contract PayCoin is TokenERC20 {

    /**
     * Constrctor function
     *
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    function PayCoin() TokenERC20(1000000, 'PayCoin', 'PAY') public {}
}

library SafeMath {
    function mul(uint a, uint b) internal pure returns (uint) {
        uint c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }
    function div(uint a, uint b) internal pure returns (uint) {
        assert(b > 0);
        uint c = a / b;
        assert(a == b * c + a % b);
        return c;
    }
    function sub(uint a, uint b) internal pure returns (uint) {
        assert(b <= a);
        return a - b;
    }
    function add(uint a, uint b) internal pure returns (uint) {
        uint c = a + b;
        assert(c >= a);
        return c;
    }
    function max64(uint64 a, uint64 b) internal pure returns (uint64) {
        return a >= b ? a : b;
    }
    function min64(uint64 a, uint64 b) internal pure returns (uint64) {
        return a < b ? a : b;
    }
    function max256(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }
    function min256(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

contract Payroll is PayrollInterface {
    using SafeMath for uint;

    address public owner;
    address public oracle;
    address constant ethAddress = 0x0000000000000000000000000000000000000000;
    uint constant oneEUR = 1000000000000000000;


    event OracleUpdated(address oracle) ;
    event EmployeeAdded(address accountAddress, address[] allowedTokens, uint initialYearlyEURSalary);
    event SalaryUpdated(uint employeeId, uint salary);
    event EmployeeRemoved(uint employeeId);
    event FundsDrained();
    event FundsAdded(uint amount);
    event TokenFundsAdded(address token, uint amount);
    event EmployeeAllowedTokensUpdated(uint employeeId, address[] tokens);
    event AllEmployeeAllowedTokensUpdated(address[] tokens);

    event AllocationUpdated(address user, address[] tokens, uint[] percentages);
    event Payday(address user, address[] tokens, uint[] amounts);

    event ExchangeRatesUpdated(address[] tokens, uint[] rates);
    event ExchangeRateUpdated(address token, uint rate);


    /**
     * creates a new payroll contract
     */
    function Payroll() public {
        owner = msg.sender;
    }

    //employee struct
    struct Employee {
        address accountAddress;
        address[] allowedTokens;
        uint256 yearlyEURSalary;
    }

    //access modifiers for owner, employee, and oracle
    modifier onlyOwner { require(msg.sender == owner); _; }
    modifier onlyOracle { require(msg.sender == oracle); _; }
    modifier onlyEmployee { require(employeeAddressToId[msg.sender] != 0 && employees[employeeAddressToId[msg.sender]-1].yearlyEURSalary != 0); _; }

    //employee info
    Employee[] public employees;

    //token info
    address[] public tokens;
    mapping(address => uint) public employeeAddressToId;
    mapping(address => bool) public tokenDeposited;
    mapping(address => uint) public EURExchangeRates;

    //employee token distribution info
    mapping(address => uint) public lastAllocationUpdate;
    mapping(address => uint) public lastPayday;
    mapping(address => address[]) public distributionsTokens;
    mapping(address => uint256[]) public distributions;
    mapping(address => mapping(address => uint256)) public distributionsMapping;

    /*------------------------------------------------------------------------*/
    /*--- OWNER ONLY ---------------------------------------------------------*/
    /*------------------------------------------------------------------------*/

    /**
     * update oracle
     * @param newOracle change which address can update token exchange rates
     */
    function setOracle(address newOracle) public onlyOwner {
        oracle = newOracle;

        emit OracleUpdated(oracle);
    }

    /**
     * add an employee
     * @param accountAddress employee's ethereum account address
     * @param allowedTokens initial tokens they are allowed to specify in their salary allocations
     * @param initialYearlyEURSalary initial salary in EUR with 18 decimals
     */
    function addEmployee(address accountAddress, address[] allowedTokens, uint256 initialYearlyEURSalary) public onlyOwner {

        require(employeeAddressToId[accountAddress] == 0);

        employees.push(Employee(
                accountAddress,
                allowedTokens,
                initialYearlyEURSalary
            ));

        employeeAddressToId[accountAddress] = employees.length;

        emit EmployeeAdded(accountAddress, allowedTokens, initialYearlyEURSalary);
    }

    /**
     * set employee yearly salary
     * @param employeeId id of employee
     * @param yearlyEURSalary yearly salary in EUR with 18 decimals
     */
    function setEmployeeSalary(uint256 employeeId, uint256 yearlyEURSalary) public onlyOwner {
        require(employeeId != 0);
        employees[employeeId-1].yearlyEURSalary = yearlyEURSalary;

        emit SalaryUpdated(employeeId, yearlyEURSalary);
    }

    /**
     * set allowed tokens for one employee
     * @param employeeId employee id
     * @param allowedTokens list of token addresses the employee is allowed to allocate for
     */
    function setEmployeeAllowedTokens(uint employeeId, address[] allowedTokens) public onlyOwner {
        require(employeeId != 0);
        Employee storage employee = employees[employeeId-1];
        employee.allowedTokens = allowedTokens;

        emit EmployeeAllowedTokensUpdated(employeeId, allowedTokens);
    }

    /**
     * updates all employees' allowed tokens to provided tokens
     * @param allowedTokens list of token addresses to overwrite all employees' allowedTokens
     */
    function setEmployeeAllowedTokensForAll(address[] allowedTokens) public onlyOwner {
        for(uint i = 0; i<employees.length; i++){
            Employee storage employee = employees[i];
            employee.allowedTokens = allowedTokens;
        }

        emit AllEmployeeAllowedTokensUpdated(allowedTokens);
    }

    /**
     * allows all employees to allocate tokens that are currently deposited,
     */
    function setEmployeeAllowedTokensToDeposited() public onlyOwner {
        for(uint i = 0; i<employees.length; i++){
            Employee storage employee = employees[i];
            employee.allowedTokens = tokens;
        }

        emit AllEmployeeAllowedTokensUpdated(tokens);
    }

    /**
     * remove employee
     * @param employeeId 1-indexed employee id, first employee has id:1
     */
    function removeEmployee(uint256 employeeId) public onlyOwner {
        require(employeeId != 0);
        employeeAddressToId[employees[employeeId-1].accountAddress] = 0;
        delete employees[employeeId-1];

        emit EmployeeRemoved(employeeId);
    }

    /**
     * deposit ETH to the contract
     * msg.value: the amount of ETH to deposit
     */
    function addFunds() public onlyOwner payable {
        require(msg.value > 0);

        if(!tokenDeposited[ethAddress]){
            tokens.push(ethAddress);
            tokenDeposited[ethAddress] = true;
        }

        emit FundsAdded(msg.value);
    }

    /**
     * deposit a token to the contract
     * @param token token address
     * @param amount of token to deposit, must be approved for allowance first
     */
    function addTokenFunds(address token, uint256 amount) public onlyOwner {
        require(amount > 0);

        ERC20(token).transferFrom(msg.sender, this, amount);

        //if not registered yet, add to list of tokens deposited
        if(!tokenDeposited[token]){
            tokens.push(token);
            tokenDeposited[token] = true;
        }

        emit TokenFundsAdded(token, amount);
    }

    /**
     * returns all tokens and ETH to the owner
     */
    function scapeHatch() public onlyOwner {
        //transfer back all the ETH to the owner
        owner.transfer(address(this).balance);
        delete tokenDeposited[ethAddress];

        //transfer back all the tokens to the owner and unregister them
        for(uint i = 0; i<tokens.length; i++){
            address token = tokens[i];
            ERC20 erc20 = ERC20(token);
            erc20.transfer(owner, erc20.balanceOf(this));
            delete tokenDeposited[token];
        }
        delete tokens;

        emit FundsDrained();
    }

    /**
     * gets employee count
     */
    function getEmployeeCount() public constant returns (uint256){
        return employees.length;
    }

    /**
     * get active employee count
     */
    function getActiveEmployeeCount() public constant returns (uint256) {
        uint result = 0;
        for(uint i = 0; i<employees.length; i++){
            if(employees[i].accountAddress != address(0)) result++;
        }
        return result;
    }

    /**
     * Get contents of Employee struct
     * @param employeeId employee index starting at 1
     */
    function getEmployee(uint256 employeeId) public constant
    returns (address accountAddress, address[] allowedTokens, uint yearlyEURSalary)
    {
        Employee storage employee = employees[employeeId-1];

        return (employee.accountAddress, employee.allowedTokens, employee.yearlyEURSalary);
    }

    /**
     * returns Monthly EUR amount spent in salaries
     */
    function calculatePayrollBurnrate() public constant returns (uint256){
        uint totalMonthlyEUR = 0;

        for(uint i = 0; i<employees.length; i++){
            uint montlyEURSalaryForEmployee = employees[i].yearlyEURSalary.div(12);
            totalMonthlyEUR = totalMonthlyEUR.add(montlyEURSalaryForEmployee);
        }

        return totalMonthlyEUR;
    }

    /**
     * Days until the contract can run out of funds for at least 1 token
     * returns token address and runway in days of token soonest to run out
     */
    function calculatePayrollRunway() public constant returns (address, uint256) {
        return calculateMinimumTokenRunway(calculateBurnratesForTokens());
    }

    /**
     * returns array of daily burn rates for each token in same order as this.tokens
     */
    function calculateBurnratesForTokens() public view returns (uint[] memory) {
        uint[] memory dailyTokenBurnrates = new uint[](tokens.length);

        for(uint t = 0; t<tokens.length; t++){
            address token = tokens[t];
            uint tokenAmountRequired = 0;

            uint tokenExchangeRate = EURExchangeRates[token];

            if(tokenExchangeRate == 0) continue;

            ERC20 erc20 = ERC20(token);
            uint decimals = uint(erc20.decimals());

            for(uint i = 0; i<employees.length; i++){
                Employee storage employee = employees[i];
                uint percentage = distributionsMapping[employee.accountAddress][token];

                //if user didn't allocate anything for this token, skip it
                //if(percentage == 0) continue;

                //calculate daily payment to this user in the token
                uint dailyEUR = employee.yearlyEURSalary.div(365);
                uint EURAllocatedForToken = (dailyEUR.mul(percentage)).div(100);
                uint dailyTokenAmount = EURAllocatedForToken.div( tokenExchangeRate ).mul( 10 ** decimals ); //.mul(oneEUR.div(tokenExchangeRate);



                //add token daily amount for this user to total daily token burn rate
                tokenAmountRequired = tokenAmountRequired.add(dailyTokenAmount);
            }

            //store the daily burn rate for the token at same index as token in this.tokens
            dailyTokenBurnrates[t] = tokenAmountRequired;
        }

        return dailyTokenBurnrates;
    }

    /**
     * @param dailyTokenBurnrates array of daily burn rates for each token in same order as this.tokens
     */
    function calculateMinimumTokenRunway(uint[] dailyTokenBurnrates) internal view returns(address, uint) {
        uint minimumTokenRunway = 0;
        address minimumRunwayToken = address(0);

        for(uint s = 0; s<tokens.length; s++){
            if(dailyTokenBurnrates[s] == 0) continue;

            address token = tokens[s];
            uint availableBalance = (token == ethAddress) ? address(this).balance : ERC20(token).balanceOf(this);
            uint runwayForToken = availableBalance.div(dailyTokenBurnrates[s]);

            if(minimumTokenRunway == 0 || runwayForToken < minimumTokenRunway){
                minimumTokenRunway = runwayForToken;
                minimumRunwayToken = token;
            }
        }

        return (minimumRunwayToken, minimumTokenRunway);
    }


    /*------------------------------------------------------------------------*/
    /*--- EMPLOYEE ONLY ------------------------------------------------------*/
    /*------------------------------------------------------------------------*/

    /**
     * gets token allocation of the caller
     */
    function getAllocation() public view returns (address[], uint[]){
        return (distributionsTokens[msg.sender], distributions[msg.sender]);
    }

    /**
     * gets allocation for an employee based on address
     * @param _address address of employee
     */
    function getAllocationForAddress(address _address) public view returns (address[], uint[]){
        return (distributionsTokens[_address], distributions[_address]);
    }

    /**
     * gets allocation for an employeeId
     * @param employeeId id of employee
     */
    function getAllocationForEmployee(uint employeeId) public view returns (address[], uint[]){
        Employee storage employee = employees[employeeId-1];
        address _address = employee.accountAddress;
        return (distributionsTokens[_address], distributions[_address]);
    }

    /**
     * updates employee's token distribution. only callable once every 6 months
     * @param distributionTokens token addresses for alloactions
     * @param distribution token percentages for allocations (1-100)
     */
    function determineAllocation(address[] distributionTokens, uint256[] distribution) public onlyEmployee {
        require(distributionTokens.length == distribution.length);
        //require(now - lastAllocationUpdate[msg.sender] < 6 * 30 days );

        Employee storage employee = employees[employeeAddressToId[msg.sender]-1];

        //check if all the tokens are allowed for the employee
        for(uint i = 0; i<distributionTokens.length; i++){
            require(tokenDeposited[distributionTokens[i]]);
            bool tokenAllowed = false;
            for(uint k = 0; k<employee.allowedTokens.length; k++){
                if(distributionTokens[i] == employee.allowedTokens[k]) tokenAllowed = true;
            }
            require(tokenAllowed);
            require(distribution[i] > 0 && distribution[i] <= 100);
        }

        //make sure percentage of distribution adds up to 100
        uint totalPercent = 0;
        for(uint j = 0; j<distribution.length; j++) totalPercent += distribution[j];
        require(totalPercent == 100);

        //update distribution info for the employee
        lastAllocationUpdate[msg.sender] = now;
        distributions[msg.sender] = distribution;
        distributionsTokens[msg.sender] = distributionTokens;

        for(uint d = 0; d<distribution.length; d++){
            distributionsMapping[msg.sender][distributionTokens[d]] = distribution[d];
        }

        emit AllocationUpdated(msg.sender, distributionTokens, distribution);
    }

    /**
     * Sends the employee all the tokens and ETH based on their yearly salary and allocations.
     * Only callable once a month
     */
    function payday() public onlyEmployee {

        require(employeeAddressToId[msg.sender] != 0);
        //require(now - lastPayday[msg.sender] < 30 days);

        Employee storage employee = employees[employeeAddressToId[msg.sender]-1];

        require(employee.yearlyEURSalary != 0);

        address[] storage distributionTokens = distributionsTokens[msg.sender];
        uint[] storage distribution = distributions[msg.sender];

        uint monthlyEUR = employee.yearlyEURSalary.div(12);

        uint[] memory amountsTransferred = new uint[](distributionTokens.length);

        for(uint i = 0; i<distributionTokens.length; i++){
            address token = distributionTokens[i];

            uint decimals = (token == ethAddress) ? 18 : uint(ERC20(token).decimals());

            uint percentage = distribution[i];
            uint tokenExchangeRate = EURExchangeRates[token];
            uint EURAllocatedForToken = (monthlyEUR.mul(percentage)).div(100);
            uint monthlyTokenAmount = EURAllocatedForToken.div(tokenExchangeRate).mul( 10 ** decimals );

            if(token == ethAddress){
                msg.sender.transfer(monthlyTokenAmount);
            }else{
                ERC20(token).transfer(msg.sender, monthlyTokenAmount);
            }

            amountsTransferred[i] = monthlyTokenAmount;
        }

        emit Payday(msg.sender, distributionTokens, amountsTransferred);
    }

    /*------------------------------------------------------------------------*/
    /*--- ORACLE ONLY --------------------------------------------------------*/
    /*------------------------------------------------------------------------*/

    /**
     * called by outside oracle service to set token exchange rate
     * @param token token address
     * @param EURExchangeRate the price of token in EUR, uses decimals from token
     */
    function setExchangeRate(address token, uint256 EURExchangeRate) public onlyOracle {
        EURExchangeRates[token] = EURExchangeRate;

        emit ExchangeRateUpdated(token, EURExchangeRate);
    }

    /**
     * called by outside oracle service to set token exchange rates
     * @param _tokens token address
     * @param _EURExchangeRates the price of token in EUR, uses decimals from token
     */
    function setExchangeRates(address[] _tokens, uint256[] _EURExchangeRates) public onlyOracle {
        require(_tokens.length > 0);
        require(_tokens.length == _EURExchangeRates.length);

        for(uint i = 0; i<_tokens.length; i++){
            EURExchangeRates[_tokens[i]] = _EURExchangeRates[i];
        }

        emit ExchangeRatesUpdated(_tokens, _EURExchangeRates);
    }

}