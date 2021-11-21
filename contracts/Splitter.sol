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
    ShareHolder[] private _shareholders;

    /**
     * @dev the mapping will hold id which are acually indexes offset by 1.
     * the id 0 is used for adresses that no longer are share holders
     * for eg: when a shareholder gives away all his shares to another account he will be erased from the shareholder list.
     *
    */
    mapping (address => uint) private _addressToID;

    constructor() {
        uint id = addShareholder(msg.sender,uint256(TOTAL_SHARES));
        _addressToID[msg.sender] = id;
    }

    event Received(address, uint);
    receive() external payable {
        uint256 prevBank = _bank;
        _bank += msg.value;
        require(_bank > prevBank);
        emit Received(msg.sender, msg.value);
        split();
    }

    function shareholderCount() public view returns (uint256) {
        return _totalShareholders;
    }

    function getShareCountFor(address shareholderAdress) public view returns (uint256) {
        uint id = _addressToID[shareholderAdress];
        require(id > 0, "Address not used by any shareholder");
        uint index = id - 1;
        return _shareholders[index].shares;
    }

    function getBalance(address shareholderAdress) public view returns (uint256) {
        uint id = _addressToID[shareholderAdress];
        require(id > 0, "Address not used by any shareholder");
        uint index = id - 1;
        return _shareholders[index].balance;
    }

    function split() private {
        uint totalSH = _totalShareholders;
        uint transferedFunds = 0;
        uint currentBank = _bank;
        for (uint i=0; i<totalSH; ++i ){
            ShareHolder memory shareHolder = _shareholders[i];
            uint funds = (_bank / TOTAL_SHARES) * shareHolder.shares;
            //console.log(funds);
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

    function retrieveFunds(uint256 amount) external {
        uint id = _addressToID[msg.sender];
        require(id > 0, "Caller is not a share holder");
        uint index = id - 1;
        ShareHolder memory shareHolder = _shareholders[index];
        require(shareHolder.owner == msg.sender,"Hello there general Kenobi!");
        require(shareHolder.balance >= amount, "Caller is trying to retrieve more than his current balance");
        uint currentBalance = shareHolder.balance;
        shareHolder.balance -= amount;
        require(currentBalance > shareHolder.balance, "Something when critticaly wrong with the transaction, them underflows");
        _shareholders[index] = shareHolder;
        shareHolder.owner.transfer(amount);
    }

    function giveShares(address payable toAddress, uint256 amount) external {
        uint id = _addressToID[msg.sender];
        require(id > 0, "Caller is not a share holder");
        require(amount >= MIN_SHARE,"Invalid transaction amount");
        uint fromIndex = id - 1;

        ShareHolder memory shareHolder = _shareholders[fromIndex];
        uint shareHolderShares = shareHolder.shares;
        require(amount <= shareHolderShares);
        uint currentShares = shareHolderShares;
        shareHolderShares = shareHolderShares - amount;
        require(currentShares > shareHolderShares);
        shareHolder.shares = shareHolderShares;
        _shareholders[fromIndex] = shareHolder;

        uint receiverId = _addressToID[toAddress];
        if(receiverId == 0){
            addShareholder(toAddress,amount);
        } else {
            uint receiverIndex = receiverId - 1;
            ShareHolder memory receiver = _shareholders[receiverIndex];
            uint receiverCurrent = receiver.shares;
            uint newShares = receiverCurrent + amount;
            require(newShares > receiverCurrent);
            receiver.shares = newShares;
            _shareholders[receiverIndex] = receiver;
        }
        
        //console.log(shareHolderShares);
        if(shareHolderShares == 0){
            //console.log("no more shares detected, delete this user");
            removeShareholder(shareHolder.owner);
        }
    }

    function addShareholder(address payable shareholderAdress, uint256 amount ) private returns (uint) {
        uint currentTotal = _totalShareholders;
        if(currentTotal == _shareholders.length){
            _shareholders.push(ShareHolder(amount,0,shareholderAdress));
            currentTotal = _shareholders.length;
        } else {
            ShareHolder memory newHolder = _shareholders[currentTotal];
            newHolder = ShareHolder(amount,0,shareholderAdress);
            currentTotal += 1;
        }

        require(currentTotal > _totalShareholders, "failed adding a new shareholder");
        _totalShareholders = currentTotal;
        _addressToID[shareholderAdress] = currentTotal;
        
        return currentTotal;
    }

    function removeShareholder(address shareHolderAdress) private{
        assert(_totalShareholders > 0);
        require(msg.sender == shareHolderAdress, "Shareholders are removed only when they stop holding shares, this can only happen when you give away your shares");
        uint id = _addressToID[shareHolderAdress];
        require(id > 0, "Address must belong to a share holder");

        //if we delete the last share owner, nothing needs to be done
        //only swap when the removed item is inside the container
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
}