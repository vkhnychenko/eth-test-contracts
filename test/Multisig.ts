import {loadFixture, ethers, expect} from "./setup";
import type {Multisig, Demo} from "../typechain-types";
import {Multisig__factory} from "../typechain-types";

describe("Multisig", function () {
    async function deployFixture() {
      const [owner1, owner2, owner3] = await ethers.getSigners();

      const MultisigFactory = await ethers.getContractFactory("Multisig");
      const multisig: Multisig = await MultisigFactory.deploy(
        [owner1.address, owner2.address, owner3.address],
        2
      );
      await multisig.deployed();

      const multisigOwner2 = Multisig__factory.connect(multisig.address, owner2)

      const DemoFactory = await ethers.getContractFactory("Demo");
      const demo: Demo = await DemoFactory.deploy()
      await demo.deployed();

      return {owner1, multisig, multisigOwner2, demo}
    }

    async function queueFixture() {
        const {multisig, demo} = await loadFixture(deployFixture)
        const value = 100
        // const abiCoder = new ethers.utils.AbiCoder
        // const data = abiCoder.encode(["uint"], [123])

        const queueTx = await multisig.queue(demo.address, value, "0x")
        await queueTx.wait()
    
        return { queueTx, value };
    }

    it("allows to queue", async function(){
        const {multisig, demo} = await loadFixture(deployFixture)
        const {value} = await loadFixture(queueFixture)

        const currentTx = await multisig.transactions(0)

        expect(currentTx.to).to.eq(demo.address)
        expect(currentTx.value).to.eq(value)
    });

    it("allows to confirm and execute", async function(){
        const {owner1, demo, multisig, multisigOwner2} = await loadFixture(deployFixture)
        const {value} = await loadFixture(queueFixture)

        const confirm1 = await multisig.confirm(0)
        await confirm1.wait()

        const confirm2 = await multisigOwner2.confirm(0)
        await confirm2.wait()

        expect((await multisig.transactions(0)).confirmations).to.eq(2)

        const txData = {
            to: multisig.address,
            value: value
        }
        const txSend = await owner1.sendTransaction(txData)
        await txSend.wait()

        const txEx = await multisig.execute(0)
        await txEx.wait()

        await expect(txEx).to.changeEtherBalances([multisig, demo], [-value, value])
        expect((await multisig.transactions(0)).executed).to.be.true
    })
});