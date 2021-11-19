pragma solidity ^0.7.0;

import "hardhat/console.sol"; 

contract Splitter{

    // the minium % value a share holder can have is MIN_SHARES / TOTAL_SHARES which is 0.0001%.
    uint16 constant MIN_SHARE = 1; 
    uint16 constant TOTAL_SHARES = 10000;

    uint256 public bank;

    struct ShareHolder{
        uint256 shares;
        uint256 balance;
        address payable owner;
    }

    uint public totalShareholders;
    ShareHolder[] public shareholders;

    // the mapping will hold id which are acually indexes offset by 1.
    // the id 0 is used for adresses that no longer are share holders
    // for eg: when a shareholder gives away all his shares to another account he will be erased from the shareholder list.
    mapping (address => uint) public addressToID;

    constructor() {
        uint id = addShareholder(msg.sender,uint256(TOTAL_SHARES));
        addressToID[msg.sender] = id;
    }

    event Received(address, uint);
    receive() external payable {
        uint256 prevBank = bank;
        bank = bank + msg.value;
        require(bank > prevBank);
        emit Received(msg.sender, msg.value);
        split();
    }

    function split() private {
        //console.log("perform split");
        uint totalSH = totalShareholders;
        uint transferedFunds = 0;
        uint currentBank = bank;
        for (uint i=0; i<totalSH; ++i ){
            ShareHolder memory shareHolder = shareholders[i];
            uint funds = (bank / TOTAL_SHARES) * shareHolder.shares;
            //console.log(funds);
            require(bank >= funds);
            currentBank -= funds;
            shareHolder.balance += funds;
            transferedFunds += funds;
            require(shareHolder.balance >= shareholders[i].balance);
            shareholders[i] = shareHolder;
        }

        require((currentBank + transferedFunds) == bank);
        bank = currentBank;
    }

    function retrieveFunds(uint _amount) external {
        uint id = addressToID[msg.sender];
        require(id > 0, "Caller is not a share holder");
        uint index = id - 1;
        ShareHolder memory shareHolder = shareholders[index];
        require(shareHolder.owner == msg.sender,"Hello there general Kenobi!");
        require(shareHolder.balance >= _amount, "Caller is trying to retrieve more than his current balance");
        uint currentBalance = shareHolder.balance;
        shareHolder.balance -= _amount;
        require(currentBalance > shareHolder.balance, "Something when critticaly wrong with the transaction, them underflows");
        shareholders[index] = shareHolder;
        shareHolder.owner.transfer(_amount);
    }

    function giveShares(address payable _toAddress, uint256 _amount) external {
        uint id = addressToID[msg.sender];
        require(id > 0, "Caller is not a share holder");
        require(_amount >= MIN_SHARE,"Invalid transaction amount");
        uint fromIndex = id - 1;

        ShareHolder memory shareHolder = shareholders[fromIndex];
        uint shareHolderShares = shareHolder.shares;
        require(_amount <= shareHolderShares);
        uint currentShares = shareHolderShares;
        shareHolderShares = shareHolderShares - _amount;
        require(currentShares > shareHolderShares);
        shareHolder.shares = shareHolderShares;
        shareholders[fromIndex] = shareHolder;

        uint receiverId = addressToID[_toAddress];
        if(receiverId == 0){
            addShareholder(_toAddress,_amount);
        } else {
            uint receiverIndex = receiverId - 1;
            ShareHolder memory receiver = shareholders[receiverIndex];
            uint receiverCurrent = receiver.shares;
            uint newShares = receiverCurrent + _amount;
            require(newShares > receiverCurrent);
            receiver.shares = newShares;
            shareholders[receiverIndex] = receiver;
        }
        
        //console.log(shareHolderShares);
        if(shareHolderShares == 0){
            //console.log("no more shares detected, delete this user");
            removeShareholder(shareHolder.owner);
        }
    }

    function addShareholder(address payable _shareholderAdress, uint256 _amount ) private returns (uint) {
        uint currentTotal = totalShareholders;
        if(currentTotal == shareholders.length){
            shareholders.push(ShareHolder(_amount,0,_shareholderAdress));
            totalShareholders = shareholders.length;
        } else {
            ShareHolder memory newHolder = shareholders[currentTotal];
            newHolder = ShareHolder(_amount,0,_shareholderAdress);
            totalShareholders = totalShareholders + 1;
        }

        require(totalShareholders > currentTotal, "failed adding a new shareholder");
        addressToID[_shareholderAdress] = totalShareholders;
        
        return totalShareholders;
    }

    function removeShareholder(address shareHolderAdress) private{
        assert(totalShareholders > 0);
        require(msg.sender == shareHolderAdress, "Shareholders are removed only when they stop holding shares, this can only happen when you give away your shares");
        uint id = addressToID[shareHolderAdress];
        require(id > 0, "Address must belong to a share holder");

        //if we delete the last share owner, nothing needs to be done
        //only swap when the removed item is inside the container
        if(totalShareholders > id){
            uint index = id - 1;
            uint lastIndex = totalShareholders - 1;
            ShareHolder memory lastShareHolder = shareholders[lastIndex];
            shareholders[index] = lastShareHolder;
            addressToID[lastShareHolder.owner] = id;
        }
        
        addressToID[shareHolderAdress] = 0;
        totalShareholders = totalShareholders - 1;
    }
}