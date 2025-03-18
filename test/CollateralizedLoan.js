const { loadFixture, time } = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("CollateralizedLoan", function () {
  async function deployCollateralizedLoanFixture() {
    const [owner, borrower, lender] = await ethers.getSigners();
    const CollateralizedLoan = await ethers.getContractFactory("CollateralizedLoan");
    const collateralizedLoan = await CollateralizedLoan.deploy();
    await collateralizedLoan.waitForDeployment();

    return { collateralizedLoan, owner, borrower, lender };
  }

  describe("Loan Request", function () {
    it("Should let a borrower deposit collateral and request a loan", async function () {
      const { collateralizedLoan, borrower } = await loadFixture(deployCollateralizedLoanFixture);

      const collateralAmount = ethers.parseEther("2.0");
      const loanAmount = ethers.parseEther("1.0");
      const interestRate = 5; // 5%
      const duration = 30 * 24 * 60 * 60; // 30 days

      await expect(
        collateralizedLoan.connect(borrower).depositCollateralAndRequestLoan(loanAmount, interestRate, duration, {
          value: collateralAmount,
        })
      );

    });
  });

  describe("Funding a Loan", function () {
    it("Allows a lender to fund a requested loan", async function () {
      const { collateralizedLoan, borrower, lender } = await loadFixture(deployCollateralizedLoanFixture);

      const collateralAmount = ethers.parseEther("2.0");
      const loanAmount = ethers.parseEther("1.0");
      const interestRate = 5;
      const duration = 30 * 24 * 60 * 60;
      const loanId = 1;

      await collateralizedLoan.connect(borrower).depositCollateralAndRequestLoan(loanAmount, interestRate, duration, {
        value: collateralAmount,
      });

      await expect(
        //collateralizedLoan.connect(lender).fundLoan(borrower.address, { value: loanAmount })
        collateralizedLoan.connect(lender).fundLoan(loanId, { value: loanAmount })
      );

    });
  });

  describe("Repaying a Loan", function () {
    it("Enables the borrower to repay the loan fully", async function () {
      const { collateralizedLoan, borrower, lender } = await loadFixture(deployCollateralizedLoanFixture);

      const collateralAmount = ethers.parseEther("2.0");
      const loanAmount = ethers.parseEther("1.0");
      const interestRate = 5;
      const duration = 30 * 24 * 60 * 60;
      const totalRepayment = ethers.parseEther("1.05"); // Loan + interest
      const loanId = 1;

      await collateralizedLoan.connect(borrower).depositCollateralAndRequestLoan(loanAmount, interestRate, duration, {
        value: collateralAmount,
      });
      //await collateralizedLoan.connect(lender).fundLoan(borrower.address, { value: loanAmount });
      await collateralizedLoan.connect(lender).fundLoan(loanId, { value: loanAmount });

      await expect(
        //collateralizedLoan.connect(borrower).repayLoan({ value: totalRepayment })
        collateralizedLoan.connect(borrower).repayLoan(loanId, { value: totalRepayment })
      );

    });
  });

  describe("Claiming Collateral", function () {
    it("Permits the lender to claim collateral if the loan isn't repaid on time", async function () {
      const { collateralizedLoan, borrower, lender } = await loadFixture(deployCollateralizedLoanFixture);

      const collateralAmount = ethers.parseEther("2.0");
      const loanAmount = ethers.parseEther("1.0");
      const interestRate = 5;
      const duration = 30 * 24 * 60 * 60;
      const loanId = 1;


      await collateralizedLoan.connect(borrower).depositCollateralAndRequestLoan(loanAmount, interestRate, duration, {
        value: collateralAmount,
      });
      //await collateralizedLoan.connect(lender).fundLoan(borrower.address, { value: loanAmount });
      await collateralizedLoan.connect(lender).fundLoan(loanId, { value: loanAmount });

      // Simulate time passing beyond the loan term
      await time.increase(duration + 1);

      await expect(
        //collateralizedLoan.connect(lender).claimCollateral(borrower.address)
        collateralizedLoan.connect(lender).claimCollateral(loanId)
      );

    });
  });
});
