const { BigNumber } = require("@ethersproject/bignumber");
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
            expect(await contractInstance.shareholderCount()).to.equal(1);
        });

        it("Create contract and split the shares equally between two users.", async function () {
            let totalShares = 10000;
            let halfShares = totalShares / 2;
            await contractInstance.giveShares(bob.address, halfShares);
            expect(await contractInstance.shareholderCount()).to.equal(2);
            let aliceShares = await contractInstance.getSharesOwnedBy(alice.address);
            expect(aliceShares).to.equal(halfShares);
            let bobShares = await contractInstance.getSharesOwnedBy(bob.address);
            expect(aliceShares).to.equal(bobShares);
        });

        it("Create contract and give all the shares to a second user", async function () {
            let totalShares = 10000;
            expect(await contractInstance.shareholderCount()).to.equal(1);
            await contractInstance.connect(alice).giveShares(bob.address, totalShares);
            expect(await contractInstance.shareholderCount()).to.equal(1);
            
            let bobShares = await contractInstance.getSharesOwnedBy(bob.address);
            expect(bobShares).to.equal(totalShares);
        });

        it("Create the contract and split the shares 4 way between alice, bob , chuck and david", async function () {
            let totalShares = 10000;
            await contractInstance.connect(alice).giveShares(bob.address, totalShares / 2);
            let splitShares = totalShares / 2;
            await contractInstance.connect(alice).giveShares(chuck.address, splitShares / 2);
            await contractInstance.connect(bob).giveShares(david.address, splitShares / 2);
            let quarterShares = splitShares / 2;
            expect(await contractInstance.shareholderCount()).to.equal(4);
        });
    });

    describe("Payments", function () {
        it("Test payment with only one shareholder", async function () {
            let wei = ethers.utils.parseEther('1.0'); // Sends exactly 1.0 ether
            const transactionHash = await alice.sendTransaction({
                to: contractInstance.address,
                value: wei,
            });

            let aliceBalance = await contractInstance.getBalanceFor(alice.address);
            expect(aliceBalance).to.equal(wei);
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

            let aliceBalance = await contractInstance.getBalanceFor(alice.address);
            expect(aliceBalance).to.equal(halfWei);

            let bobBalance = await contractInstance.getBalanceFor(alice.address);
            expect(bobBalance).to.equal(halfWei);
        });

        it("Test payment with three inequal shareholders that have 43-17-37-3", async function () {
            let totalShares = 10000;
            await contractInstance.connect(alice).giveShares(bob.address, (17*totalShares)/100);
            await contractInstance.connect(alice).giveShares(chuck.address, (37*totalShares)/100);
            await contractInstance.connect(alice).giveShares(david.address, (3*totalShares)/100);
            expect(await contractInstance.shareholderCount()).to.equal(4);

            let wei = ethers.utils.parseEther('1.0'); // Sends exactly 1.0 ether
            let aliceShareWei = ethers.utils.parseEther('0.43');
            let bobShareWei = ethers.utils.parseEther('0.17');
            let chuckShareWei = ethers.utils.parseEther('0.37');
            let davidShareWei = ethers.utils.parseEther('0.03');
            const transactionHash = await alice.sendTransaction({
                to: contractInstance.address,
                value: wei,
            });

            expect(await contractInstance.getSharesOwnedBy(alice.address)).to.equal(43*100);
            expect(await contractInstance.getBalanceFor(alice.address)).to.equal(aliceShareWei);

            expect(await contractInstance.getSharesOwnedBy(bob.address)).to.equal(17*100);
            expect(await contractInstance.getBalanceFor(bob.address)).to.equal(bobShareWei);

            expect(await contractInstance.getSharesOwnedBy(chuck.address)).to.equal(37*100);
            expect(await contractInstance.getBalanceFor(chuck.address)).to.equal(chuckShareWei);

            expect(await contractInstance.getSharesOwnedBy(david.address)).to.equal(3*100);
            expect(await contractInstance.getBalanceFor(david.address)).to.equal(davidShareWei);
        });
    });

    describe("Retrieving funds", function () {
        it("Retrieve for a single account", async function () {
            let wei = ethers.utils.parseEther('1.0'); // Sends exactly 1.0 ether
            
            let initialBalanceWei = ethers.utils.formatEther(await alice.getBalance());

            const transactionHash = await bob.sendTransaction({
                to: contractInstance.address,
                value: wei,
            });

            const receipt = await contractInstance.connect(alice).retrieveFunds(wei);

            let finalBalanceWei = ethers.utils.formatEther(await alice.getBalance());
            expect(parseFloat(initialBalanceWei)).to.be.lessThan(parseFloat(finalBalanceWei));
        });

        it("Retrieve for a single account, big funds", async function () {
            let wei = ethers.utils.parseEther('9900.0');
            
            let initialBalanceWei = ethers.utils.formatEther(await alice.getBalance());

            const transactionHash = await bob.sendTransaction({
                to: contractInstance.address,
                value: wei,
            });

            const receipt = await contractInstance.connect(alice).retrieveFunds(wei);

            let finalBalanceWei = ethers.utils.formatEther(await alice.getBalance());
            expect(parseFloat(initialBalanceWei)).to.be.lessThan(parseFloat(finalBalanceWei));
        });

        it("Retrieve funds with 2 accounts", async function () {
            let totalShares = 10000;
            await contractInstance.connect(alice).giveShares(bob.address, totalShares / 2);

            let initialAliceWei = ethers.utils.formatEther(await alice.getBalance());
            let initialBobWei = ethers.utils.formatEther(await bob.getBalance());

            const transactionHash = await chuck.sendTransaction({
                to: contractInstance.address,
                value: ethers.utils.parseEther('1.0'),
            });
            const receiptAlice = await contractInstance.connect(alice).retrieveFunds( ethers.utils.parseEther("0.5") );
            const receiptBob = await contractInstance.connect(bob).retrieveFunds( ethers.utils.parseEther("0.5") );

            let finalAliceWei = ethers.utils.formatEther(await alice.getBalance());
            let finalBobWei = ethers.utils.formatEther(await bob.getBalance());
            expect(parseFloat(initialAliceWei)).to.be.lessThan(parseFloat(finalAliceWei));
            expect(parseFloat(initialBobWei)).to.be.lessThan(parseFloat(finalBobWei));
        });
    });
});