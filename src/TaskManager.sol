// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24; // Specifies the compiler version. ^0.8.24 means compatible with 0.8.24 and up to <0.9.0.

contract TaskManager {
    ///////////////////////////////////////
    // STATE VARIABLES
    // These variables store the persistent data of your contract on the blockchain.
    // They define the contract's current state.
    ///////////////////////////////////////

    address public owner; // Declares a public state variable 'owner' of type 'address'.
        // 'public' automatically creates a getter function to read its value.
        // This will store the address of the contract deployer.

    uint256 public nextTaskId = 1; // Counter for tasks, ensuring unique IDs, starting from 1.

    // Pricing variables for different roles/actions.
    uint256 public createReaderPrice = 0.002 ether; // Price to create a 'reader' role/account.
    uint256 public createPosterPrice = 0.01 ether; // Price to create a 'poster' role/account.
    uint256 public createMiddlemanPrice = 0.005 ether; // Price to create a 'middleman' role/account.
    uint256 public whitelistMintPrice = 0.1 ether; // Price for a whitelisted mint.

    // Removed 'whitelisted' array as it's redundant if userWalletStatus is the source of truth.
    // If specific iteration over all whitelisted addresses is needed, consider other patterns
    // or acknowledge the gas cost.

    // Mappings: These are like hash tables, associating one data type with another.
    // Maps an address to an array of Tasks. Each user can have multiple tasks.
    mapping(address => Task[]) public userTasks;
    // Maps an address to their wallet status using the WALLET_STATUS enum.
    mapping(address => WALLET_STATUS) public userWalletStatus;
    // Tracks if the contract is paused.
    bool public paused = false;

    // For a simple token within this contract (assuming basic balances, not a full ERC-20)
    mapping(address => uint256) private _balances; // Store balances of your internal token.
    uint256 public totalSupply; // Total supply of your internal token.

    // For safe contract termination / withdrawal
    bool private _stopped = false; // Flag to stop new interactions for graceful shutdown.

    ///////////////////////////////////////
    // STRUCTS
    // Custom data types to group related variables together.
    // Think of them as blueprints for complex objects.
    ///////////////////////////////////////

    struct Task {
        // userId removed: 'personPostingTask' (address) serves as the primary user ID.
        uint256 taskId; // Unique identifier for the task.
        address personPostingTask;
        string nameOfPersonCreatingTask;
        string titleOfTask;
        string bodyOfTask;
        uint256 createdAt; // Unix timestamp when the task was created. Good.
        bool taskComplete; // Status of task completion.
        AD_STATE state; // Current state of the advertisement (task).
            // awaitingWhitelist removed: This is a global user status, not a task-specific status.
    }

    ///////////////////////////////////////
    // ENUMS
    // User-defined types that represent a set of named constants.
    // Useful for defining distinct states or categories.
    ///////////////////////////////////////

    enum AD_STATE {
        POSTED, // Task is active and looking for mediation/sale.
        MEDIATED, // Task is under mediation.
        MADE_SALE // Task has been completed with a sale.

    }

    enum WALLET_STATUS {
        NOT_WHITELISTED, // Wallet is not yet whitelisted (default).
        PENDING, // Wallet is waiting for verification/approval.
        WHITELISTED // Wallet is approved.

    }

    ///////////////////////////////////////
    // EVENTS
    // Signals emitted by the contract to the blockchain.
    // Off-chain applications (like your frontend) can listen for these.
    // They are crucial for providing real-time updates and historical logs.
    ///////////////////////////////////////

    event PostCreated(address indexed poster, uint256 indexed taskId, string title);
    event EventMediated(address indexed mediator, address indexed buyer, address indexed poster, uint256 taskId);
    event AssetsTransferred(address indexed payer, address indexed receiver, uint256 amount);
    event MintedForWhitelist(address indexed minter, string mintRarity, uint256 amountMinted);
    event TokensMinted(address indexed to, uint256 amount);
    event CoinsPurchased(address indexed buyer, uint256 ethPaid, uint256 coinsReceived);
    event CoinsStaked(address indexed staker, uint256 amount);
    event ContractPaused(address indexed by);
    event ContractUnpaused(address indexed by);
    event FundsWithdrawn(address indexed to, uint256 amount);

    ///////////////////////////////////////
    // CUSTOM ERRORS
    // A gas-efficient way to provide descriptive error messages when a transaction reverts.
    // Preferred over 'require(condition, "string message")' in modern Solidity.
    ///////////////////////////////////////

    error UnauthorizedCaller();
    error InsufficientPayment(uint256 required, uint256 provided);
    error NotWhitelisted();
    error AlreadyWhitelisted();
    error ContractIsPaused();
    error NoFundsToWithdraw();
    error EtherTransferFailed();
    error InvalidAmount();
    error ZeroAddress();
    error TaskNotFound(uint256 taskId);
    error InvalidStatusTransition();
    error AlreadyCompleted();

    ///////////////////////////////////////
    // CONSTRUCTOR
    // A special function executed ONLY ONCE when the contract is deployed.
    // Used to initialize state variables.
    ///////////////////////////////////////

    constructor(uint256 initialSupplyAmount) payable {
        // Sets the deployer of the contract as the owner. This is correct.
        owner = msg.sender;
        // Correctly initializes the total supply of your internal token.
        // This assumes this contract itself will manage a simple token supply.
        // If you are using a separate ERC-20 contract, this line would be removed
        // and initial token minting handled in that ERC-20 contract's constructor.
        totalSupply = initialSupplyAmount;
        _balances[msg.sender] = initialSupplyAmount; // Give initial supply to the deployer.
    }

    ///////////////////////////////////////
    // MODIFIERS
    // Reusable pieces of code that can be applied to functions.
    // Often used for access control or common pre-conditions.
    ///////////////////////////////////////

    // Ensures only the 'owner' can call the function it's applied to.
    modifier onlyOwner() {
        // CORRECTED: This ensures only the original owner can call.
        if (msg.sender != owner) revert UnauthorizedCaller();
        _; // Placeholder where the function's code will be inserted.
    }

    // Ensures the contract is not paused.
    modifier whenNotPaused() {
        if (paused) revert ContractIsPaused();
        _;
    }

    // Ensures the contract is paused.
    modifier whenPaused() {
        if (!paused) revert ContractIsPaused(); // Use the same error for simplicity, or a dedicated one.
        _;
    }

    ///////////////////////////////////////
    // ADMIN / OWNER FUNCTIONS
    // Functions callable only by the contract owner.
    // These typically involve administrative tasks or emergency controls.
    ///////////////////////////////////////

    /**
     * @dev Allows the owner to add a user to the whitelist.
     * @param _user The address to whitelist.
     */
    function addToWhitelist(address _user) public onlyOwner {
        if (_user == address(0)) revert ZeroAddress();
        if (userWalletStatus[_user] == WALLET_STATUS.WHITELISTED) revert AlreadyWhitelisted();
        userWalletStatus[_user] = WALLET_STATUS.WHITELISTED;
        // Optionally, if you keep the 'whitelisted' array for iteration, add to it here.
        // whitelisted.push(_user);
    }

    /**
     * @dev Allows the owner to remove a user from the whitelist.
     * @param _user The address to remove from the whitelist.
     */
    function removeFromWhitelist(address _user) public onlyOwner {
        if (_user == address(0)) revert ZeroAddress();
        if (userWalletStatus[_user] == WALLET_STATUS.NOT_WHITELISTED) revert NotWhitelisted(); // Or specific error like 'NotCurrentlyWhitelisted'
        userWalletStatus[_user] = WALLET_STATUS.NOT_WHITELISTED;
        // If you had the 'whitelisted' array, you'd need logic to remove from it (e.g., swapping with last element and popping).
    }

    /**
     * @dev Allows the owner to pause the contract, preventing certain operations.
     */
    function togglePause() public onlyOwner {
        paused = !paused; // Toggles the paused state
        if (paused) {
            emit ContractPaused(msg.sender);
        } else {
            emit ContractUnpaused(msg.sender);
        }
    }

    /**
     * @dev Allows the contract owner to withdraw accumulated Ether from the contract.
     * This is a critical function and should be carefully secured.
     */
    function emergencyWithdrawEther() external onlyOwner whenNotPaused {
        uint256 contractBalance = address(this).balance;
        if (contractBalance == 0) revert NoFundsToWithdraw();

        (bool success,) = payable(owner).call{value: contractBalance}("");
        if (!success) revert EtherTransferFailed();

        emit FundsWithdrawn(owner, contractBalance);
    }

    ///////////////////////////////////////
    // PUBLIC / EXTERNAL WRITE FUNCTIONS
    // Functions that modify the contract's state (cost gas).
    // Callable by anyone (public) or only from outside the contract (external).
    ///////////////////////////////////////

    /**
     * @dev Allows whitelisted users to mint tokens.
     * Assumes this contract has internal token management or interacts with an ERC-20.
     * If this contract IS an ERC-20, you'd need the IERC20 interface imported.
     * @param _minter The address to which the tokens will be minted.
     * @param mintRarity A string indicating the rarity (e.g., "common", "rare").
     * @return true on successful minting.
     */
    function mintForWhitelist(address _minter, string memory mintRarity) public payable whenNotPaused returns (bool) {
        // Checks: Ensure the correct amount of Ether is sent for the whitelist mint.
        if (msg.value != whitelistMintPrice) revert InsufficientPayment(whitelistMintPrice, msg.value);

        // Checks: Ensures that only WHITELISTED users can call this function.
        if (userWalletStatus[msg.sender] != WALLET_STATUS.WHITELISTED) revert NotWhitelisted();

        // Effects: Update internal token balances and total supply.
        // Assuming this contract holds the token logic.
        uint256 amountToMint = 100 * (10 ** 18); // Example fixed amount, could vary by mintRarity
        _balances[_minter] += amountToMint;
        totalSupply += amountToMint;

        // Events: Emit an event after successful minting.
        emit MintedForWhitelist(_minter, mintRarity, amountToMint);
        emit TokensMinted(_minter, amountToMint);

        return true;
    }

    /**
     * @dev Allows users to create a new task/post.
     * @param _nameOfPersonCreatingTask Name of the task creator.
     * @param _titleOfTask Title of the task.
     * @param _bodyOfTask Detailed description of the task.
     */
    function createPost(string memory _nameOfPersonCreatingTask, string memory _titleOfTask, string memory _bodyOfTask)
        public
        payable
        whenNotPaused
    {
        // Checks: Ensure payment for creating a post.
        if (msg.value != createPosterPrice) revert InsufficientPayment(createPosterPrice, msg.value);
        // Security: Add checks for string lengths, empty strings if critical.
        if (bytes(_titleOfTask).length == 0) revert InvalidAmount(); // Example of basic string validation

        // Effects: Create a new 'Task' struct instance and store it.
        userTasks[msg.sender].push(
            Task({
                taskId: nextTaskId,
                personPostingTask: msg.sender,
                nameOfPersonCreatingTask: _nameOfPersonCreatingTask,
                titleOfTask: _titleOfTask,
                bodyOfTask: _bodyOfTask,
                createdAt: block.timestamp,
                taskComplete: false,
                state: AD_STATE.POSTED
            })
        );
        nextTaskId++; // Increment the counter for the next task.

        // Events: Emit the 'postCreated' event.
        emit PostCreated(msg.sender, nextTaskId - 1, _titleOfTask);
    }

    /**
     * @dev Function for a middleman to mediate an event/task.
     * @param _taskId The ID of the task to mediate.
     * @param _buyer The address of the buyer.
     * @param _poster The address of the original poster.
     */
    function mediate(uint256 _taskId, address _buyer, address _poster) public whenNotPaused {
        // Checks: Ensure msg.sender is a middleman (you'd need a role system or mapping for this).
        // Example: require(isMiddleman[msg.sender], "Caller is not a middleman");

        // Effects: Update the state of a specific task.
        // This requires iterating through userTasks to find the specific task, which can be expensive.
        // A direct mapping `mapping(uint256 => Task)` for tasks would be more efficient if IDs are globally unique.
        bool found = false;
        for (uint256 i = 0; i < userTasks[_poster].length; i++) {
            if (userTasks[_poster][i].taskId == _taskId) {
                if (userTasks[_poster][i].state != AD_STATE.POSTED) revert InvalidStatusTransition();
                userTasks[_poster][i].state = AD_STATE.MEDIATED;
                found = true;
                break;
            }
        }
        if (!found) revert TaskNotFound(_taskId);

        // Events: Emit the 'eventMediated' event.
        emit EventMediated(msg.sender, _buyer, _poster, _taskId);
    }

    /**
     * @dev Transfers assets (your internal token) from one address to another.
     * This function now modifies state, so 'view' is removed.
     * @param _transferFrom The address to transfer tokens from.
     * @param _transferTo The address to transfer tokens to.
     * @param _amount The amount of tokens to transfer.
     * @return true on successful transfer.
     */
    function transferAssets(address _transferFrom, address _transferTo, uint256 _amount)
        public
        whenNotPaused
        returns (bool)
    {
        // Checks: Basic validations.
        if (_transferFrom == address(0) || _transferTo == address(0)) revert ZeroAddress();
        if (_amount == 0) revert InvalidAmount();
        if (_balances[_transferFrom] < _amount) revert InsufficientPayment(_amount, _balances[_transferFrom]); // Reusing error for balance

        // Effects: Update balances.
        _balances[_transferFrom] -= _amount;
        _balances[_transferTo] += _amount;

        // Events: Emit the transfer event.
        emit AssetsTransferred(_transferFrom, _transferTo, _amount);
        return true;
    }

    /**
     * @dev Mints a generic amount of tokens.
     * This is typically an owner-only function for controlled supply.
     * @param _to The address to mint tokens to.
     * @param _amount The amount of tokens to mint.
     */
    function mint(address _to, uint256 _amount) public onlyOwner whenNotPaused {
        // Checks: Basic validations.
        if (_to == address(0)) revert ZeroAddress();
        if (_amount == 0) revert InvalidAmount();

        // Effects: Update total supply and recipient balance.
        _balances[_to] += _amount;
        totalSupply += _amount;

        // Events: Emit event.
        emit TokensMinted(_to, _amount);
    }

    /**
     * @dev Allows users to buy internal coins with Ether.
     * This function is payable and modifies state.
     * @param _buyer The address of the buyer.
     * @param _amount The amount of internal coins to buy.
     * @return true on successful purchase.
     */
    function buyCoins(address _buyer, uint256 _amount) public payable whenNotPaused returns (bool) {
        // Checks: Basic validations and payment check.
        if (_buyer == address(0)) revert ZeroAddress();
        if (_amount == 0) revert InvalidAmount();
        // Assuming a simple 1 ETH = 1000 coins exchange rate for example:
        // You would define a conversion rate or connect to an AMM here.
        uint256 requiredEth = _amount / 1000 * (10 ** 18); // Example rate: 1000 coins per ETH
        if (msg.value < requiredEth) revert InsufficientPayment(requiredEth, msg.value);

        // Effects: Transfer tokens to buyer (internal token) and keep Ether.
        _balances[_buyer] += _amount; // Give coins to buyer

        // Events: Emit event.
        emit CoinsPurchased(_buyer, msg.value, _amount);
        return true;
    }

    /**
     * @dev Allows users to stake internal coins.
     * @param _staker The address of the staker.
     * @param _amount The amount of coins to stake.
     * @return true on successful staking.
     */
    function stakeCoins(address _staker, uint256 _amount) public whenNotPaused returns (bool) {
        // Checks: Basic validations.
        if (_staker == address(0)) revert ZeroAddress();
        if (_amount == 0) revert InvalidAmount();
        if (_balances[_staker] < _amount) revert InsufficientPayment(_amount, _balances[_staker]); // Reusing error for balance

        // Effects: Transfer tokens from staker to contract (conceptually)
        // In a real staking contract, you'd likely manage staked amounts in a separate mapping
        // and transfer actual tokens if this contract isn't the token itself.
        _balances[_staker] -= _amount; // Remove from staker's balance
        // A mapping to track staked amount, e.g.: mapping(address => uint256) public stakedBalances;
        // stakedBalances[_staker] += _amount;

        // Events: Emit event.
        emit CoinsStaked(_staker, _amount);
        return true;
    }

    ///////////////////////////////////////
    // PUBLIC / EXTERNAL VIEW FUNCTIONS
    // Functions that read the contract's state but do NOT modify it (do not cost gas for external calls).
    // These are typically used to retrieve information for the frontend.
    ///////////////////////////////////////

    /**
     * @dev Returns the balance of the internal token for a given address.
     * @param _account The address to query.
     * @return The token balance of the account.
     */
    function balanceOf(address _account) public view returns (uint256) {
        return _balances[_account];
    }

    /**
     * @dev Returns a specific task for a given user and task ID.
     * Note: This requires iterating through the user's tasks, which can be gas-expensive for many tasks.
     * If task IDs are globally unique and accessible, a direct mapping `mapping(uint256 => Task)`
     * would be more efficient.
     * @param _user The address of the user who posted the task.
     * @param _taskId The ID of the task to retrieve.
     * @return The Task struct.
     */
    function getTask(address _user, uint256 _taskId) public view returns (Task memory) {
        for (uint256 i = 0; i < userTasks[_user].length; i++) {
            if (userTasks[_user][i].taskId == _taskId) {
                return userTasks[_user][i];
            }
        }
        revert TaskNotFound(_taskId); // Revert if task not found.
    }

    /**
     * @dev Returns the total number of tasks for a given user.
     * @param _user The address of the user.
     * @return The number of tasks.
     */
    function getTaskCount(address _user) public view returns (uint256) {
        return userTasks[_user].length;
    }
}
