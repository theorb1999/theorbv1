// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.4;


// Standard Imports
import "./SafeMath.sol";
import "./Context.sol";
import "./IBEP20.sol";
import "./Ownable.sol";     // need owner because of transfer LP functions


// PancakeSwap 
import "./IPancakeFactory.sol";
import "./IPancakeRouter01.sol";
import "./IPancakeRouter02.sol";



// The reason why it is ownable is so the deployer can move LP to PancakeSwap after the PreSale.

contract TheORB is Context, IBEP20, Ownable {

    using SafeMath for uint256;

    IPancakeRouter02 public pancakeswapRouter;
    address public pancakeswapPair;
    address public routerAddressForDEX;

    string private nameOfToken;
    string private symbolOfToken;
    uint8 private decimalsOfToken;
    uint256 private totalSupplyOfToken;
    
    mapping (address => uint256) private tokenBalance;
    mapping (address => mapping (address => uint256)) public allowancesOfToken;

    mapping (address => uint256) public amountORBstaked;
    mapping (address => bool) public hasStakedORB;
    mapping (address => bool) public hasUnStakedORB;
    mapping (address => uint256) public timeStartedStaking;


    address public deadAddress;


    bool public isAllStakingUnlocked;
    uint256 public creationDateOfcContract;
    uint256 public preSaleRate;   
    bool public isPresaleEnabled; 
    mapping(address => uint256) public ORBAmountPurchasedInPresaleInJager; 
    uint256 public timePresaleEndedAndLiquidityProvided;
    uint256 public timeStakingIsEnabled;
    bool public isApproveEnabled;      // Approves are disabled until after the presale ends because otherwise people could provide liquidity on their own.


    
    uint256 oneDayTimer;       
    uint256 threeDaysTimer;
    uint256 fiveDaysTimer;



    
 

    // Events
    event PreSalePurchase(address indexed buyer, uint256 amountORBpurchased, uint256 amountBNBInJagerSold, uint256 totalORBAmountPurchasedInPresaleInJager);
    event AllStakingUnlocked(uint256 indexed timeAllStakingUnlocked);
    event ContractDeployed(string message);
    event MintedORB(address indexed accountMintedTo, uint256 indexed amountMinted);
    event ORBstaked(address indexed stakerAddress, uint256 indexed amountOfORBstaked, uint256 indexed timeStaked);
    event ORBunStaked(address indexed stakerAddress, uint256 indexed timeUnStaked);
    event EndedPresaleProvidedLiquidity(uint256 BNBprovidedToPancakeSwap, uint256 ORBprovidedToPancakeSwap, uint256 timePresaleEndedAndLiquidityProvided);


    constructor () {

        deadAddress = 0x0000000000000000000000000000000000000000;

        address msgSender = _msgSender();

        nameOfToken = "The ORB";
        symbolOfToken = "ORB";
        decimalsOfToken = 9;
        totalSupplyOfToken = 1 * 10**6 * 10**9; // the 10^9 is to get us past the decimal amount and the 2nd one gets us to 1 billion

        tokenBalance[address(this)] = totalSupplyOfToken;
        emit Transfer(address(0), msgSender, totalSupplyOfToken);    // emits event of the transfer of the supply from dead to owner

        emit OwnershipTransferred(address(0), msgSender);

        // routerAddressForDEX = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;       // CHANGEIT - change this to pancakeswap router v2
        routerAddressForDEX = 0x10ED43C718714eb63d5aA57B78B54704E256024E;       // v2 pancakeswap router
        IPancakeRouter02 pancakeswapRouterLocal = IPancakeRouter02(routerAddressForDEX);      // gets the router
        pancakeswapPair = IPancakeFactory(pancakeswapRouterLocal.factory()).createPair(address(this), pancakeswapRouterLocal.WETH());     // Creates the pancakeswap pair   
        pancakeswapRouter = pancakeswapRouterLocal; 





        // distribute team cut, 36,000 ORB given to team.
        uint256 tenThousandTokens = 10000 * 10**9;
        // uint256 oneThousandTokens = 1000 * 10**9;
        uint256 thirtyThousandTokens = 30000 * 10**9;
        // uint256 sixThousandTokens = 6000 * 10**9;
        // uint256 fourThousandTokens = 4000 * 10**9;
        // uint256 tokensToSubtractForDistribution = thirtyThousandTokens.add(sixThousandTokens);
        uint256 tokensToSubtractForDistribution = thirtyThousandTokens;

        tokenBalance[address(this)] = tokenBalance[address(this)].sub(tokensToSubtractForDistribution);


        tokenBalance[0x59ed330ca05bFfbaBd4fcE758234C71f8F08cBd9] = tenThousandTokens;   // Nox
        tokenBalance[0x0C2a98ace816259c0bB369f88Dd4bcb9135E0787] = tenThousandTokens;   // Yoshiko
        tokenBalance[0x87fCb413D80d56A02bAb6b8E7AD1736667eFe56e] = tenThousandTokens;   // YS

        isAllStakingUnlocked = false;
        creationDateOfcContract = block.timestamp;

        // CHANGEIT - correct it after test
        oneDayTimer = 1 days;       
        threeDaysTimer = 3 days;
        fiveDaysTimer = 5 days;

        // oneDayTimer = 1 minutes;       
        // threeDaysTimer = 2 minutes;
        // fiveDaysTimer = 3 minutes;


        
        isPresaleEnabled = true;
        preSaleRate = 1000;

        isApproveEnabled = false;


        emit ContractDeployed("The ORB Launched!");
    }

    function name() public view override returns (string memory) {
        return nameOfToken;
    }

    function symbol() public view override returns (string memory) {
        return symbolOfToken;
    }

    function decimals() public view override returns (uint8) {
        return decimalsOfToken;
    }

    function totalSupply() public view override returns (uint256) {
        return totalSupplyOfToken;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return tokenBalance[account];
    }


    function getOwner() external view override returns (address){
        return owner();     // gets current owner address
    }



    ////////////////////////////TRANSFER FUNCTIONS////////////////////////////
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        transferInternal(_msgSender(), recipient, amount);
        return true;
    }

    function transferInternal(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "BEP20: transfer from the zero address");
        require(recipient != address(0), "BEP20: transfer to the zero address");    
        require(amount != 0, "BEP20: transfer amount was 0");
        tokenBalance[sender] = tokenBalance[sender].sub(amount, "BEP20: transfer amount exceeds balance");
        tokenBalance[recipient] = tokenBalance[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        transferInternal(sender, recipient, amount);
        approveInternal(sender, _msgSender(), allowancesOfToken[sender][_msgSender()].sub(amount, "BEP20: transfer amount exceeds allowance"));
        return true;
    }
    ////////////////////////////TRANSFER FUNCTIONS////////////////////////////





    ////////////////////////////APPROVE FUNCTIONS////////////////////////////
    function approveInternal(address owner, address spender, uint256 amount) internal virtual {
        require(isApproveEnabled, "Approves must be enabled first after the PreSale is ended.");
        require(owner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");

        allowancesOfToken[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        approveInternal(_msgSender(), spender, amount);
        return true;
    }
    ////////////////////////////APPROVE FUNCTIONS////////////////////////////






    ////////////////////////////ALLOWANCE FUNCTIONS////////////////////////////
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return allowancesOfToken[owner][spender];
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        approveInternal(_msgSender(), spender, allowancesOfToken[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        approveInternal(_msgSender(), spender, allowancesOfToken[_msgSender()][spender].sub(subtractedValue, "BEP20: decreased allowance below zero"));
        return true;
    }
    ////////////////////////////ALLOWANCE FUNCTIONS////////////////////////////
    

    
    ////////////////////////////MINT FUNCTIONS////////////////////////////
    function mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "BEP20: mint to the zero address");

        totalSupplyOfToken = totalSupplyOfToken.add(amount);
        tokenBalance[account] = tokenBalance[account].add(amount);
        emit Transfer(address(0), account, amount);
        emit MintedORB(account, amount);
    }
    ////////////////////////////MINT FUNCTIONS////////////////////////////


    




    
    ////////////////////////////STAKING FUNCTIONS////////////////////////////
    function stakeORB(uint256 amountOfORBtoStake) public {

        require(timeStakingIsEnabled != 0, "Staking must be enabled first, check the website.");
        require(block.timestamp > timeStakingIsEnabled, "Staking is not yet enabled, check the website when staking is enabled.");
        require(!isAllStakingUnlocked, "Staking is over, you can unstake though.");

        address stakerAddress = _msgSender();

        require(!hasStakedORB[stakerAddress], "You have already staked ORB.");
        require(amountOfORBtoStake >= 1000000000, "Requires at least 1 ORB to Stake.");
        require(amountOfORBtoStake <= 1000000000000, "Maximum 1,000 ORB to Stake.");
        require(tokenBalance[stakerAddress] >= amountOfORBtoStake , "Not enough ORB in account.");

        hasStakedORB[stakerAddress] = true;
        amountORBstaked[stakerAddress] = amountOfORBtoStake;
        
        tokenBalance[stakerAddress] = tokenBalance[stakerAddress].sub(amountOfORBtoStake, "BEP20: transfer amount exceeds balance");
        tokenBalance[deadAddress] = tokenBalance[deadAddress].add(amountOfORBtoStake);
        timeStartedStaking[stakerAddress] = block.timestamp;

        emit ORBstaked(stakerAddress, amountOfORBtoStake, block.timestamp);
    }


    function unStakeORB() public {

        address stakerAddress = _msgSender();

        require(!hasUnStakedORB[stakerAddress], "You have already UnStaked ORB.");

        // TODO - require staking first, has to be in V2

        hasUnStakedORB[stakerAddress] = true;        // set it to false after calling so he can't re-enter

        if(!isAllStakingUnlocked){      // checks to see if the unlock has happened, if not do the normal timer check
            require(block.timestamp > timeStartedStaking[stakerAddress] + threeDaysTimer, "You cannot unstake, it has not been 3 days.");
        }
        
        tokenBalance[deadAddress] = tokenBalance[deadAddress].sub(amountORBstaked[stakerAddress], "BEP20: transfer amount exceeds balance");
        tokenBalance[stakerAddress] = tokenBalance[stakerAddress].add(amountORBstaked[stakerAddress]);

        uint256 amountToMint = howMuchORBhasBeenGeneratedSoFar(stakerAddress);

        mint(stakerAddress, amountToMint);

        amountORBstaked[stakerAddress] = 0;

        emit ORBunStaked(stakerAddress, block.timestamp);
    }


    


    function stakeUnlockTime(address stakerAddress) public view returns (uint256){
        if(timeStartedStaking[stakerAddress] == 0){
            return 0;       // returns 0 if the user hasn't started staking yet
        }
        uint256 stakeUnlockTimeForStaker = timeStartedStaking[stakerAddress] + threeDaysTimer;
        return stakeUnlockTimeForStaker;
    }

    function timeUntilStakingUnlocks(address stakerAddress) public view returns (uint256){
        if(timeStartedStaking[stakerAddress] == 0){
            return 3 days;      // returns 3 days if user hasn't started staking yet
        }

        if(block.timestamp > timeStartedStaking[stakerAddress] + threeDaysTimer){
            return 0;       // means the time is ready to go and unlock
        }

        uint256 timeUntilStakingUnlocksForAddress = stakeUnlockTime(stakerAddress).sub(block.timestamp);
        return timeUntilStakingUnlocksForAddress;
    }

    function unlockAllStaking() public onlyOwner {
        require(timeStakingIsEnabled != 0, "Staking must be enabled first.");
        require(block.timestamp > timeStakingIsEnabled + fiveDaysTimer, "Must be at least 5 days after staking has started.");
        isAllStakingUnlocked = true;
        emit AllStakingUnlocked(block.timestamp);
    }


    function isStakingReadyAfterSales() public view returns (bool){
        if(timeStakingIsEnabled == 0){
            return false;       
        }

        if(timeStakingIsEnabled > block.timestamp ){
            return false;   
        }

        return true;
    }


    function timeStampOfCurrentBlock() public view returns (uint256){
        return block.timestamp;
    }


    function howMuchORBafterStaking3days(uint256 amountOfOrbStaked) public pure returns (uint256){
        uint256 amountORBgenerated = amountOfOrbStaked.mul(calculateThreeDayRate());
        return amountORBgenerated;
    }

    function howMuchORBhasBeenGeneratedSoFar(address stakerAddress) public view returns (uint256) {
        uint256 totalAmountORBgenerated = howMuchORBafterStaking3days(amountORBstaked[stakerAddress]);

        uint256 timeUnlocked = stakeUnlockTime(stakerAddress);

        if(block.timestamp >= timeUnlocked){        // if the blockstamp is greater than the time unlocked, just return the total amount of orb to generate
            return totalAmountORBgenerated;
        }

        // uint256 timeUnlockedMul100 = timeUnlocked.mul(100);
        // uint256 percentOfTimeCompleted = timeUnlockedMul100.div(block.timestamp);

        uint256 timeUnlockedMul100 = block.timestamp.mul(100);
        uint256 percentOfTimeCompleted = timeUnlockedMul100.div(timeUnlocked);

        uint256 totalAmountMul100 = totalAmountORBgenerated.mul(percentOfTimeCompleted); 
        uint256 amountOrbGeneratedSoFar = totalAmountMul100.div(100);

        return amountOrbGeneratedSoFar;

    }


    ////////////////////////////STAKING FUNCTIONS////////////////////////////





    ////////////////////////////APY FUNCTIONS////////////////////////////
    function calculateAPY() public pure returns (uint256) {
        uint256 interestRate = 1000000;
        uint256 periodsInYear = 365;
        uint256 rateDivPeriods = interestRate.div(periodsInYear);
        uint256 rateAddedOne = rateDivPeriods.add(1);
        uint256 rateAddedMulPeriod = rateAddedOne.mul(periodsInYear);
        uint256 apyFiguredUp = rateAddedMulPeriod.sub(1);
        return apyFiguredUp;
    }

    function calculateThreeDayRate() public pure returns (uint256) {
        uint256 threeDayRate = calculateAPY().mul(3).div(365);
        return threeDayRate;
    }
    ////////////////////////////APY FUNCTIONS////////////////////////////








    ////////////////////////////PRESALE FUNCTIONS////////////////////////////
    function presaleBuy(uint256 keyCode) external payable {

        require(isPresaleEnabled, "Presale has ended");
        require(keyCode == 1337, "Don't use this contract presale function except through our website at https://theorb.finance ");

        address buyer = _msgSender();

        uint256 amountOfBNBtoInputInJager = msg.value;     // BNB input amount in Jager

        uint256 oneBNBAmountInJager = 1000000000000000000;      // 1 BNB in Jager

        require(amountOfBNBtoInputInJager >= oneBNBAmountInJager.div(100), "BNB must be at least 0.01 BNB");  
        require(amountOfBNBtoInputInJager <= oneBNBAmountInJager, "Capped at 1 BNB For This PreSale, please input less BNB.");

        uint256 amountPurchasedWithNewPurchase = ORBAmountPurchasedInPresaleInJager[buyer].add(amountOfBNBtoInputInJager);

        require(amountPurchasedWithNewPurchase <= oneBNBAmountInJager, 
            "Capped at 1 BNB (100,000,000 Jager) Per Account, please input less BNB. Check current Purchase Amount with ORBAmountPurchasedInPresaleInJager");  

        uint256 amountOfORBtoGive = amountOfBNBtoInputInJager.mul(preSaleRate).div(oneBNBAmountInJager);  // determin how much NIP to get

        uint256 totalBalanceOfORBinContract = balanceOf(address(this));
        uint256 totalBalanceAfterGive = totalBalanceOfORBinContract.sub(amountOfORBtoGive);

        uint256 amountORBminForLPCreation = 1 * 10**5 * 10**9;  // 100,000 ORB minimum should be in the contract

        require(totalBalanceAfterGive > amountORBminForLPCreation, ("Not enough ORB left in the Presale. Please check the ORB left in the contract itself and Adjust"));

        ORBAmountPurchasedInPresaleInJager[buyer] = amountPurchasedWithNewPurchase;     // sets the new nip amount an account has purchased

        // going to sub in my own transfer here because we need to get around the approvals.
        uint amount = amountOfORBtoGive.mul(10**9);
        tokenBalance[address(this)] = tokenBalance[address(this)].sub(amount, "BEP20: transfer amount exceeds balance");
        tokenBalance[buyer] = tokenBalance[buyer].add(amount);
        emit Transfer(address(this), buyer, amount);

        emit PreSalePurchase(buyer, amountOfORBtoGive, amountOfBNBtoInputInJager, ORBAmountPurchasedInPresaleInJager[buyer]);  
    }


    function endPresaleProvideLiquidity() external onlyOwner {

        // you will need to figure out amountMinToProvide, if you are the first provider then make it 0.
        // if you are not the 2nd provider you will need to calculate this amount by going to the pancakeswap address and 
        // using the "quote" function. 
        // amountA = the balanceOf(contract address) - the amount of ORB the contract has
        // reserveA = the amount of ORB in the LP token
        // reserveB = the amount of BNB in the LP token 
        // you can get reserveA and B from the LP token itself.

        // the variable isFirstProvider is for if liquidity already exists on PancakeSwap or not.
        // if there is liquidity, set this to false so you can provide proper amounts.

        require(block.timestamp > creationDateOfcContract + oneDayTimer, "You cannot end the presale yet because it has not been 1 day after the creation of the contract.");

        // this will take the ORB and BNB within the contract, and provide liquidity to PancakeSwap.

        uint256 ORBinContract = balanceOf(address(this));

        uint256 BNBinContract = address(this).balance;      // why doesn't this take all the BNB in the contract?

        isApproveEnabled = true;
        

        approveInternal(address(this), address(pancakeswapRouter), ORBinContract);    
        pancakeswapRouter.addLiquidityETH{value: BNBinContract}(address(this),ORBinContract, 0, 0, address(this), block.timestamp);     // adds the liquidity

        timePresaleEndedAndLiquidityProvided = block.timestamp;
        timeStakingIsEnabled = timePresaleEndedAndLiquidityProvided + oneDayTimer;

        isPresaleEnabled = false;

        emit EndedPresaleProvidedLiquidity(BNBinContract, ORBinContract, timePresaleEndedAndLiquidityProvided);  
    }
    ////////////////////////////PRESALE FUNCTIONS////////////////////////////





    receive() external payable { }      // oh it's payable alright

}







/*

The ORB, ORB, version 1.00, Mana Release

\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/

IN A CALAMITY,
PEOPLE AWAITED FOR A BRAVE
WITH THE SWORD.

THE SWORD REVEALED THE POWER
OF ITS TRUE NATURE TO
RETRIEVE THE PEACE.

EXCALIBUR, KUSANAGI, AND
ALL THE OTHER SWORDS TALKED
IN MYTH, LEGEND, AND SAGA...

PEOPLE NAMED THOSE
SWORDS IN MANY WAYS.

BUT...

THEY ALL MEANT ONE THING.
THE ONE AND ONLY...

THE SWORD OF MANA.

https://cdn.discordapp.com/attachments/763134325151236150/843031253464645642/2.mp4

\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/
\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/

Developer - Yoshiko Shinonome

Mana version 1.00 Developer Notes:

In August 2020 I witnessed DeFi summer in full swing. There was a project created called ORB. 
The project promised high yields, for a lock up period of a few days.
It was a high risk, high reward yield farming token. But.... as with most tokens, it was a scam.

Not only did the first one scam 50 ETH, the developer created 2 more ORB projects and rugpulled. 
For a total of 3 times the creator of ORB was able to rugpull.
It disturbs me greatly that someone is able to make rugpull tokens and still generated a massive amount of profit.

Thus, I want to create a rug-proof high yield farming money game.

I will take the original ORB project and form it into my own.
I created the solidity contract from scratch using basic staking ideas.
There has been no copied code in this. 
I developed the PreSale mechanism for another project I developed.
I created the website with my own VPS - theorb.finance
The audits are done by myself as well.

The goal of The ORB game is to be fast and remember to unstake at the first opportunity.

Seconds really do matter in The ORB. If you are too late then you may get far less BNB for your ORB.

So the only question really.... is this gambling?
Is this a form of gambling? 
I'm not so sure.
I think there is some luck involved, so it's a little gambling.

But really it's how fast you can get in and get out.
In the next version I hope I can expand upon these ideas and make it more of a game and less gambling.
But it requires this version to be successful first and only time will tell...

*/