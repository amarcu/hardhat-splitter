pragma solidity ^0.7.0;

contract Splitter{

    // the minium % value a share holder can have is MIN_SHARES / TOTAL_SHARES which is 0.0001%.
    uint16 constant MIN_SHARE = 1; 
    uint16 constant TOTAL_SHARES = 10000;

    uint256 public bank;

    address public owner;

    struct ShareHolder{
        uint256  m_shares;
        address m_owner;
    }

    ShareHolder[] public sharesHolders;

    constructor() {
        // that is deploying the contract.
        owner = msg.sender;
    }

    function giveShares(address withAddress, uint256 amount) external {
        // transaction will revert.
        require(amount >= MIN_SHARE);
        for (uint256 index = 0; index<sharesHolders.length; ++index){
            if(sharesHolders[index].m_owner == msg.sender){
                require(sharesHolders[index].m_shares >= amount);
                if(sharesHolders[index].m_shares == amount){
                    sharesHolders[index].m_owner = withAddress;
                } else {
                    sharesHolders[index].m_shares -= amount;
                    addShareOwner(withAddress,amount);
                }
            }
        }
    }

    function addShareOwner(address shareHolderAdress, uint256 amount ) private {
        sharesHolders.push(ShareHolder(amount,shareHolderAdress));
    }
}