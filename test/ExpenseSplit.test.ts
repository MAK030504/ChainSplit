import { expect } from "chai";
import { ethers } from "hardhat";
import { ExpenseSplit } from "../typechain-types";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

describe("ExpenseSplit", function () {
  let contract: ExpenseSplit;
  let owner: HardhatEthersSigner;
  let mustafa: HardhatEthersSigner;
  let ali: HardhatEthersSigner;
  let ahmed: HardhatEthersSigner;
  let sara: HardhatEthersSigner;

  const ONE_AVAX = ethers.parseEther("1");

  beforeEach(async function () {
    [owner, mustafa, ali, ahmed, sara] = await ethers.getSigners();
    const Factory = await ethers.getContractFactory("ExpenseSplit");
    contract = await Factory.deploy();
  });

  describe("createGroup", function () {
    it("creates a group and adds creator if not in member list", async function () {
      const tx = await contract
        .connect(mustafa)
        .createGroup("Trip to Hunza", "Friends trip", [ali.address, ahmed.address, sara.address]);

      await expect(tx)
        .to.emit(contract, "GroupCreated")
        .withArgs(1, mustafa.address, "Trip to Hunza", [
          ali.address,
          ahmed.address,
          sara.address,
          mustafa.address,
        ]);

      const group = await contract.getGroup(1);
      expect(group.name).to.equal("Trip to Hunza");
      expect(group.members).to.have.length(4);
      expect(await contract.groupCount()).to.equal(1);
    });

    it("rejects empty group name", async function () {
      await expect(
        contract.connect(mustafa).createGroup("", "desc", [ali.address])
      ).to.be.revertedWith("Name required");
    });

    it("rejects zero address members", async function () {
      await expect(
        contract
          .connect(mustafa)
          .createGroup("Test", "desc", [ethers.ZeroAddress])
      ).to.be.revertedWith("Invalid member address");
    });
  });

  describe("addExpense", function () {
    beforeEach(async function () {
      await contract
        .connect(mustafa)
        .createGroup("Trip", "desc", [ali.address, ahmed.address]);
    });

    it("splits expense equally among participants", async function () {
      const participants = [mustafa.address, ali.address, ahmed.address];
      const amount = ethers.parseEther("0.6");

      await contract
        .connect(mustafa)
        .addExpense(1, "Dinner", amount, mustafa.address, 0, participants, [], "Restaurant");

      expect(await contract.getDebt(1, ali.address, mustafa.address)).to.equal(
        ethers.parseEther("0.2")
      );
      expect(await contract.getDebt(1, ahmed.address, mustafa.address)).to.equal(
        ethers.parseEther("0.2")
      );
      expect(await contract.getDebt(1, mustafa.address, ali.address)).to.equal(0);

      const expenses = await contract.getExpenses(1);
      expect(expenses).to.have.length(1);
      expect(expenses[0].title).to.equal("Dinner");
    });

    it("splits by percentage", async function () {
      const participants = [mustafa.address, ali.address, ahmed.address];
      const amount = ethers.parseEther("1");
      const shares = [50, 30, 20];

      await contract
        .connect(mustafa)
        .addExpense(1, "Hotel", amount, mustafa.address, 1, participants, shares, "");

      expect(await contract.getDebt(1, ali.address, mustafa.address)).to.equal(
        ethers.parseEther("0.3")
      );
      expect(await contract.getDebt(1, ahmed.address, mustafa.address)).to.equal(
        ethers.parseEther("0.2")
      );
    });

    it("splits by custom amounts", async function () {
      const participants = [mustafa.address, ali.address];
      const amount = ethers.parseEther("0.5");
      const shares = [ethers.parseEther("0.3"), ethers.parseEther("0.2")];

      await contract
        .connect(mustafa)
        .addExpense(1, "Taxi", amount, ali.address, 2, participants, shares, "");

      expect(await contract.getDebt(1, mustafa.address, ali.address)).to.equal(
        ethers.parseEther("0.3")
      );
    });

    it("rejects non-member payer", async function () {
      await expect(
        contract
          .connect(mustafa)
          .addExpense(1, "Dinner", ONE_AVAX, sara.address, 0, [mustafa.address], [], "")
      ).to.be.revertedWith("Payer must be a group member");
    });

    it("rejects non-member participant", async function () {
      await expect(
        contract
          .connect(mustafa)
          .addExpense(
            1,
            "Dinner",
            ONE_AVAX,
            mustafa.address,
            0,
            [sara.address],
            [],
            ""
          )
      ).to.be.revertedWith("Participant not in group");
    });
  });

  describe("getBalances", function () {
    it("returns correct net balances", async function () {
      await contract
        .connect(mustafa)
        .createGroup("Trip", "desc", [ali.address, ahmed.address]);

      const participants = [mustafa.address, ali.address, ahmed.address];
      await contract
        .connect(mustafa)
        .addExpense(1, "Dinner", ethers.parseEther("0.6"), mustafa.address, 0, participants, [], "");

      const [members, totalOwed, totalReceivable, netBalance] = await contract.getBalances(1);

      const mustafaIdx = members.findIndex((m: string) => m === mustafa.address);
      const aliIdx = members.findIndex((m: string) => m === ali.address);

      expect(members).to.have.length(3);
      expect(totalOwed[mustafaIdx]).to.equal(0);
      expect(totalReceivable[mustafaIdx]).to.equal(ethers.parseEther("0.4"));
      expect(netBalance[mustafaIdx]).to.equal(ethers.parseEther("0.4"));
      expect(totalOwed[aliIdx]).to.equal(ethers.parseEther("0.2"));
      expect(netBalance[aliIdx]).to.equal(-ethers.parseEther("0.2"));
    });
  });

  describe("settleDebt", function () {
    beforeEach(async function () {
      await contract
        .connect(mustafa)
        .createGroup("Trip", "desc", [ali.address, ahmed.address]);

      await contract
        .connect(mustafa)
        .addExpense(
          1,
          "Dinner",
          ethers.parseEther("0.6"),
          mustafa.address,
          0,
          [mustafa.address, ali.address, ahmed.address],
          [],
          ""
        );
    });

    it("transfers AVAX and reduces debt", async function () {
      const amount = ethers.parseEther("0.2");
      const mustafaBefore = await ethers.provider.getBalance(mustafa.address);

      const tx = await contract.connect(ali).settleDebt(1, mustafa.address, ethers.ZeroHash, {
        value: amount,
      });

      await expect(tx)
        .to.emit(contract, "DebtSettled")
        .withArgs(1, 1, ali.address, mustafa.address, amount, ethers.ZeroHash);

      expect(await contract.getDebt(1, ali.address, mustafa.address)).to.equal(0);

      const mustafaAfter = await ethers.provider.getBalance(mustafa.address);
      expect(mustafaAfter - mustafaBefore).to.equal(amount);
    });

    it("rejects settlement exceeding debt", async function () {
      await expect(
        contract.connect(ali).settleDebt(1, mustafa.address, ethers.ZeroHash, {
          value: ethers.parseEther("1"),
        })
      ).to.be.revertedWith("Insufficient debt");
    });

    it("rejects zero value settlement", async function () {
      await expect(
        contract.connect(ali).settleDebt(1, mustafa.address, ethers.ZeroHash, { value: 0 })
      ).to.be.revertedWith("Must send AVAX");
    });
  });

  describe("settlement requests (QR flow)", function () {
    beforeEach(async function () {
      await contract.connect(mustafa).createGroup("Trip", "desc", [ali.address]);

      await contract
        .connect(mustafa)
        .addExpense(
          1,
          "Dinner",
          ethers.parseEther("0.4"),
          mustafa.address,
          0,
          [mustafa.address, ali.address],
          [],
          ""
        );
    });

    it("creates and fulfills a settlement request via ref", async function () {
      const ref = ethers.id("settlement-qr-1");
      const amount = ethers.parseEther("0.2");

      await contract.connect(ali).createSettlementRequest(1, mustafa.address, amount, ref, 0);

      const pending = await contract.getSettlement(1);
      expect(pending.status).to.equal(0); // Pending

      await contract.connect(ali).settleDebt(1, mustafa.address, ref, { value: amount });

      const confirmed = await contract.getSettlement(2);
      expect(confirmed.status).to.equal(2); // Confirmed
      expect(await contract.usedSettlementRefs(ref)).to.be.true;
    });

    it("prevents reusing settlement ref", async function () {
      const ref = ethers.id("settlement-qr-2");
      const amount = ethers.parseEther("0.2");

      await contract.connect(ali).createSettlementRequest(1, mustafa.address, amount, ref, 0);
      await contract.connect(ali).settleDebt(1, mustafa.address, ref, { value: amount });

      await expect(
        contract.connect(ali).createSettlementRequest(1, mustafa.address, amount, ref, 0)
      ).to.be.revertedWith("Settlement ref already used");
    });

    it("allows cancelling pending settlement", async function () {
      const ref = ethers.id("settlement-qr-3");
      await contract
        .connect(ali)
        .createSettlementRequest(1, mustafa.address, ethers.parseEther("0.2"), ref, 0);

      await contract.connect(ali).cancelSettlementRequest(1);

      const settlement = await contract.getSettlement(1);
      expect(settlement.status).to.equal(4); // Cancelled
    });
  });

  describe("debt netting", function () {
    it("nets opposing debts between members", async function () {
      await contract.connect(mustafa).createGroup("Trip", "desc", [ali.address]);

      await contract
        .connect(mustafa)
        .addExpense(
          1,
          "Dinner",
          ethers.parseEther("0.6"),
          mustafa.address,
          0,
          [mustafa.address, ali.address],
          [],
          ""
        );

      await contract
        .connect(mustafa)
        .addExpense(
          1,
          "Taxi",
          ethers.parseEther("0.2"),
          ali.address,
          0,
          [mustafa.address, ali.address],
          [],
          ""
        );

      expect(await contract.getDebt(1, ali.address, mustafa.address)).to.equal(
        ethers.parseEther("0.2")
      );
      expect(await contract.getDebt(1, mustafa.address, ali.address)).to.equal(0);
    });
  });

  describe("getMyGroups", function () {
    it("returns only groups the caller belongs to", async function () {
      await contract.connect(mustafa).createGroup("A", "desc", [ali.address]);
      await contract.connect(ahmed).createGroup("B", "desc", [sara.address]);

      const mustafaGroups = await contract.connect(mustafa).getMyGroups();
      expect(mustafaGroups).to.have.length(1);
      expect(mustafaGroups[0].name).to.equal("A");
    });
  });
});
