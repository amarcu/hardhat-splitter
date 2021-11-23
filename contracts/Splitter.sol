// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "hardhat/console.sol"; 

/**
 * @dev Contract that manages an account that can receive funds and automaticaly split
 * them according to each user's share. The contract also supports basic share transfer manipulation
 * allowing users to move share's from one account to another.
 * Whenever funds are received the split is automatically triggered and funds are moved inside 
 * each user's private ballance from where he can retreive funds on demand.
 * 
 * Contract flow:
 * When the contract is created the creator will receive all the shares. 
 * Share management can be done off-chain and shares can be passed on by simply moving
 * them from the starting account to the any number of new accounts(new shareholders).
 * Only a valid account(shareholder) can add another shareholder to the user base by passing on shares.
 *
 * Total shares in the contract is 10.000. And the minimum an account can hold is 1 which translates to 0.01%
 * If at any point an account sends away all of his shares that account will be removed from the shareholders list.
 * Existing users can check their balance and also retrieve funds.
 */

contract Splitter{

    /**
     * @dev Event triggered for each shareholder when the bank is split between everyone.
     */
    event FundsReceived(address shareholderAddress, uint amount);

    /**
     * @dev Event triggered when a new shareholder is added.
     */
    event ShareholderAdded(address newshareHolderAddress,address parentShareHolder, uint shares);

    uint16 constant MIN_SHARE = 1; 
    uint16 constant TOTAL_SHARES = 10000;

    struct ShareHolder{
        uint256 shares;
        uint256 balance;
        address payable owner;
    }


    /**
     * @dev Holds the general funds that the contract receives.
     */
    uint256 private _bank;

    
    uint private _totalShareholders;

    /**
     * @dev Iteration of the array should be done using _totalShareholders as size because we can have deleted account at the end of the container.
     */
    ShareHolder[] private _shareholders;

    /**
     * @dev the mapping will hold id which are acually indexes offset by 1.
     * the id 0 is used for adresses that no longer are share holders
     * for eg: when a shareholder gives away all his shares to another account he will be erased from the shareholder list.
     *
    */
    mapping (address => uint) private _addressToID;

    constructor() {
        addShareholder(msg.sender,uint256(TOTAL_SHARES));
    }

    event Received(address, uint);
    /**
     * @dev function that performs the split after new funds are received, this is triggered automatically
     * It will compute the value% for each shareholder and transfer that amount to a private balance.
     * If there is any reminder that could not be split it will be left inside the bank.
    */
    receive() external payable {
        uint256 prevBank = _bank;
        _bank += msg.value;
        require(_bank > prevBank);
        split();

        emit Received(msg.sender, msg.value);
    }

    function shareholderCount() public view returns (uint256) {
        return _totalShareholders;
    }

    function getSharesOwnedBy(address shareholderAdress) public view returns (uint256) {
        return _shareholders[getIndexOfAddress(shareholderAdress)].shares;
    }

    function getBalanceFor(address shareholderAdress) public view returns (uint256) {
        return _shareholders[getIndexOfAddress(shareholderAdress)].balance;
    }

    /**
     * @dev function that performs the split after new funds are received, this is triggered automatically
     * It will compute the value% for each shareholder and transfer that amount to a private balance.
     * If there is any reminder that could not be split it will be left inside the bank.
    */
    function split() private {
        uint totalSH = _totalShareholders;
        uint transferedFunds = 0;
        uint currentBank = _bank;
        for (uint i=0; i<totalSH; ++i ){
            ShareHolder memory shareHolder = _shareholders[i];
            uint funds = (_bank / TOTAL_SHARES) * shareHolder.shares;
            require(_bank >= funds);
            currentBank -= funds;
            shareHolder.balance += funds;
            transferedFunds += funds;
            require(shareHolder.balance >= _shareholders[i].balance);
            _shareholders[i] = shareHolder;
        }

        require((currentBank + transferedFunds) == _bank);
        _bank = currentBank;
    }

    /**
    * @dev simple retrieve funds that can be called by each shareholder
    */
    function retrieveFunds(uint256 amount) external {
        uint index = getIndexOfAddress(msg.sender);
        ShareHolder memory shareHolder = _shareholders[index];
        require(shareHolder.owner == msg.sender,"Hello there general Kenobi!");
        require(shareHolder.balance >= amount, "Caller is trying to retrieve more than his current balance");
        shareHolder.balance -= amount;
        _shareholders[index] = shareHolder;
        shareHolder.owner.transfer(amount);
    }

    /**
     * @dev function called by shareholders to send shares to another account. If there is no 
     * account linked to the toAddress, a new account will be created.
     * If the sending account gives away all it's shares it will be removed from the sharehodler list.
    */
    function giveShares(address payable toAddress, uint256 amount) external {
        require(toAddress != address(0), "Cannot give shares to the 0 adress");
        require(amount >= MIN_SHARE,"Invalid transaction amount");

        uint fromIndex =  getIndexOfAddress(msg.sender);
        ShareHolder memory shareHolder = _shareholders[fromIndex];
        require(shareHolder.shares >= amount);
        shareHolder.shares -= amount;
        _shareholders[fromIndex] = shareHolder;

        uint receiverId = _addressToID[toAddress];
        //if the receiver does not have an account, create one.
        if(receiverId == 0){
            addShareholder(toAddress,amount);
        } else {
            uint receiverIndex = receiverId - 1;
            ShareHolder memory receiver = _shareholders[receiverIndex];
            uint receiverCurrent = receiver.shares;
            receiver.shares += amount;
            require(receiver.shares > receiverCurrent, "Give share invalid transaction.");
            _shareholders[receiverIndex] = receiver;
        }
        
        if(shareHolder.shares == 0){
            removeShareholder(shareHolder.owner);
        }
    }

    /**
     * @dev function that will add a new shareholder. 
     * if the container has a free slot at the end, the function will use that slot
     * if the container is full it will push a new item and the size will increase by 1.
     * note: we can have empty slots at the end of the container when we have deleted users.
    */
    function addShareholder(address payable shareholderAdress, uint256 amount ) private returns (uint) {
        uint currentTotal = _totalShareholders;
        if(currentTotal == _shareholders.length){
            _shareholders.push(ShareHolder(amount,0,shareholderAdress));
            currentTotal = _shareholders.length;
        } else {
            _shareholders[currentTotal] = ShareHolder(amount,0,shareholderAdress);
            currentTotal += 1;
        }

        require(currentTotal > _totalShareholders, "failed to add a new shareholder");
        _totalShareholders = currentTotal;
        _addressToID[shareholderAdress] = currentTotal;
        
        return currentTotal;
    }

    /* @dev function that will remove a shareholder
     * the remove funtion will swap the deleted shareholder with the last item in the container
     * and decrease the size by 1. 
     * If the deleted account is the last then only the size decrease happens.
    */
    function removeShareholder(address shareHolderAdress) private{
        assert(_totalShareholders > 1);
        require(msg.sender == shareHolderAdress, "Shareholders are removed only when they stop holding shares, this can only happen when you give away your shares");
        uint id = _addressToID[shareHolderAdress];
        require(id > 0, "Address must belong to a share holder");

        if(_totalShareholders > id){
            uint index = id - 1;
            uint lastIndex = _totalShareholders - 1;
            ShareHolder memory lastShareHolder = _shareholders[lastIndex];
            _shareholders[index] = lastShareHolder;
            _addressToID[lastShareHolder.owner] = id;
        }
        
        _addressToID[shareHolderAdress] = 0;
        _totalShareholders -=  1;
    }


    /* @dev utility function to map addresses to indexes in the container
    */
    function getIndexOfAddress(address shareHolderAdress) private view returns(uint) {
        uint id = _addressToID[shareHolderAdress];
        require(id > 0, "Caller is not a share holder");
        return id - 1;
    }
}