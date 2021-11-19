const { expect, assert } = require("chai");

describe("Splitter contract", function () {

    let SplitterFactory;
    let contractInstance;
    let alice;
    let bob;
    let chuck;
    let david;
  
    beforeEach(async function () {
      // Get the ContractFactory and Signers here.
      SplitterFactory = await ethers.getContractFactory("Splitter");
      [alice, bob, chuck, david, ...addrs] = await ethers.getSigners();
  
      contractInstance = await SplitterFactory.deploy();
      await contractInstance.deployed();
    });

    describe("Deployment", function () {
        it("Contract creator should hold all the shares.", async function () {
            expect(await contractInstance.totalShareholders()).to.equal(1);
            let ownerId = await contractInstance.addressToID(alice.address);
            expect(ownerId).to.equal(1);
            let ownerIndex = ownerId - 1;
            let account = await contractInstance.shareholders(ownerIndex);
            expect(account.owner).to.equal(alice.address);
        });

        it("Create contract and split the shares equally between two users.", async function () {
            let totalShares = 10000;
            let halfShares = totalShares / 2;
            await contractInstance.giveShares(bob.address, halfShares);
            expect(await contractInstance.totalShareholders()).to.equal(2);
            let aliceId = await contractInstance.addressToID(alice.address);
            let aliceIndex = aliceId - 1;
            let aliceAccount = await contractInstance.shareholders(aliceIndex);
            expect(aliceAccount.shares).to.equal(halfShares);
            let bobId = await contractInstance.addressToID(bob.address);
            let bobIndex = bobId - 1;
            let bobAccount = await contractInstance.shareholders(bobIndex);
            expect(aliceAccount.shares).to.equal(bobAccount.shares);
        });

        it("Create contract and give all the shares to a second user", async function () {
            let totalShares = 10000;
            expect(await contractInstance.totalShareholders()).to.equal(1);
            await contractInstance.connect(alice).giveShares(bob.address, totalShares);
            expect(await contractInstance.totalShareholders()).to.equal(1);
            
            let bobId = await contractInstance.addressToID(bob.address);
            let bobIndex = bobId - 1;
            let bobAccount = await contractInstance.shareholders(bobIndex);
            
            expect(bobAccount.shares).to.equal(totalShares);

            let aliceId = await contractInstance.addressToID(alice.address);

            expect(aliceId).to.equal(0);
        });

        it("Create the contract and split the shares 4 way between alice, bob , chuck and david", async function () {
            let totalShares = 10000;
            await contractInstance.connect(alice).giveShares(bob.address, totalShares / 2);
            let splitShares = totalShares / 2;
            await contractInstance.connect(alice).giveShares(chuck.address, splitShares / 2);
            await contractInstance.connect(bob).giveShares(david.address, splitShares / 2);
            let quarterShares = splitShares / 2;
            expect(await contractInstance.totalShareholders()).to.equal(4);
        });
    });

    describe("Payments", function () {
        it("Test payment with only one shareholder", async function () {
            let wei = ethers.utils.parseEther('1.0'); // Sends exactly 1.0 ether
            const transactionHash = await alice.sendTransaction({
                to: contractInstance.address,
                value: wei,
            });

            let aliceId = await contractInstance.addressToID(alice.address);
            let aliceIndex = aliceId - 1;
            let aliceAccount = await contractInstance.shareholders(aliceIndex);
            expect(aliceAccount.balance).to.equal(wei);
        });

        it("Test payment with only two shareholders with 50-50 split", async function () {
            let totalShares = 10000;
            await contractInstance.connect(alice).giveShares(bob.address, totalShares / 2);

            let wei = ethers.utils.parseEther('1.0'); // Sends exactly 1.0 ether
            let halfWei = ethers.utils.parseEther('0.5');
            const transactionHash = await alice.sendTransaction({
                to: contractInstance.address,
                value: wei,
            });

            let aliceId = await contractInstance.addressToID(alice.address);
            let aliceIndex = aliceId - 1;
            let aliceAccount = await contractInstance.shareholders(aliceIndex);
            expect(aliceAccount.balance).to.equal(halfWei);

            let bobId = await contractInstance.addressToID(bob.address);
            let bobIndex = bobId - 1;
            let bobAccount = await contractInstance.shareholders(bobIndex);
            expect(bobAccount.balance).to.equal(halfWei);
        });

        it("Test payment with three inequal shareholders that have 43-17-37-3", async function () {
            let totalShares = 10000;
            await contractInstance.connect(alice).giveShares(bob.address, (17*totalShares)/100);
            await contractInstance.connect(alice).giveShares(chuck.address, (37*totalShares)/100);
            await contractInstance.connect(alice).giveShares(david.address, (3*totalShares)/100);
            expect(await contractInstance.totalShareholders()).to.equal(4);

            let wei = ethers.utils.parseEther('1.0'); // Sends exactly 1.0 ether
            let aliceShareWei = ethers.utils.parseEther('0.43');
            let bobShareWei = ethers.utils.parseEther('0.17');
            let chuckShareWei = ethers.utils.parseEther('0.37');
            let davidShareWei = ethers.utils.parseEther('0.03');
            const transactionHash = await alice.sendTransaction({
                to: contractInstance.address,
                value: wei,
            });

            let aliceId = await contractInstance.addressToID(alice.address);
            let aliceIndex = aliceId - 1;
            let aliceAccount = await contractInstance.shareholders(aliceIndex);
            expect(aliceAccount.shares).to.equal(43*100);
            expect(aliceAccount.balance).to.equal(aliceShareWei);

            let bobId = await contractInstance.addressToID(bob.address);
            let bobIndex = bobId - 1;
            let bobAccount = await contractInstance.shareholders(bobIndex);
            expect(bobAccount.shares).to.equal(17*100);
            expect(bobAccount.balance).to.equal(bobShareWei);

            let chuckId = await contractInstance.addressToID(chuck.address);
            let chuckIndex = chuckId - 1;
            let chuckAccount = await contractInstance.shareholders(chuckIndex);
            expect(chuckAccount.shares).to.equal(37*100);
            expect(chuckAccount.balance).to.equal(chuckShareWei);

            let davidId = await contractInstance.addressToID(david.address);
            let davidIndex = davidId - 1;
            let davidAccount = await contractInstance.shareholders(davidIndex);
            expect(davidAccount.shares).to.equal(3*100);
            expect(davidAccount.balance).to.equal(davidShareWei);
        });
    });

    describe("Retrieving funds", function () {
        it("Retrieve for a single account", async function () {
            let wei = ethers.utils.parseEther('1.0'); // Sends exactly 1.0 ether
            
            let initialBalanceWei = ethers.utils.formatEther(await alice.getBalance());

            const transactionHash = await alice.sendTransaction({
                to: contractInstance.address,
                value: wei,
            });

            await contractInstance.connect(alice).retrieveFunds(wei);

            let finalBalanceWei = ethers.utils.formatEther(await alice.getBalance()) + await alice.getGasPrice();
            expect(initialBalanceWei).to.equal(finalBalanceWei);
        });
    });
});