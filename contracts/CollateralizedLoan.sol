// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract CollateralizedLoan {
    address public owner;
    uint256 public loanCounter;

    enum LoanState { Requested, Funded, Repaid, Defaulted }

    struct Loan {
        address borrower;
        address lender;
        uint256 collateralAmount;
        uint256 loanAmount;
        uint256 interestRate; // Interest rate in percentage
        uint256 interest; // Interest amount
        uint256 dueDate;
        LoanState state;
    }

    // Create a mapping to manage the loans
    mapping(uint256 => Loan) public loans;
    mapping(address => uint256[]) public borrowerLoans;
    mapping(address => uint256[]) public lenderLoans;

    // Define events for loan requested, funded, repaid, and collateral claimed
    event LoanRequested(uint256 loanId, address indexed borrower, uint256 collateralAmount, uint256 loanAmount, uint256 interestRate, uint256 interest, uint256 dueDate);
    event LoanFunded(uint256 loanId, address indexed lender);
    event LoanRepaid(uint256 loanId);
    event CollateralClaimed(uint256 loanId);

    // Reentrancy guard
    bool private locked;

    // Constructor
    constructor() {
        owner = msg.sender;
        locked = false; // Initialize reentrancy guard
        loanCounter = 0;
    }

    // Custom Modifiers

    // Modifier to check if the caller is the contract owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    // Modifier to check if a loan exists
    modifier loanExists(uint256 _loanId) {
        require(_loanId > 0 && _loanId <= loanCounter, "Loan does not exist");
        _;
    }

    // Modifier to ensure a loan is not already funded
    modifier notFunded(uint256 _loanId) {
        require(loans[_loanId].state == LoanState.Requested, "Loan already funded");
        _;
    }

    modifier noReentrancy() {
        require(!locked, "No reentrancy");
        locked = true;
        _;
        locked = false;
    }

    // Function to deposit collateral and request a loan
    function depositCollateralAndRequestLoan(uint256 _loanAmount, uint256 _interestRate, uint256 _duration) external payable noReentrancy {
        require(msg.value > 0, "Collateral required");
        require(_loanAmount > 0, "Loan amount must be greater than zero");
        require(_loanAmount <= msg.value, "Loan amount exceeds collateral value");
        require(_interestRate > 0, "Interest rate must be greater than zero");

        uint256 interest = (_loanAmount * _interestRate * _duration) / (100 * 365 days);
        loanCounter++;
        uint256 dueDate = block.timestamp + _duration;

        loans[loanCounter] = Loan({
            borrower: msg.sender,
            lender: address(0),
            collateralAmount: msg.value,
            loanAmount: _loanAmount,
            interestRate: _interestRate,
            interest: interest,
            dueDate: dueDate,
            state: LoanState.Requested
        });

        borrowerLoans[msg.sender].push(loanCounter);
        emit LoanRequested(loanCounter, msg.sender, msg.value, _loanAmount, _interestRate, interest, dueDate);
    }

    // Function to fund a loan
    function fundLoan(uint256 _loanId) external payable loanExists(_loanId) notFunded(_loanId) noReentrancy {
        Loan storage loan = loans[_loanId];
        require(msg.value == loan.loanAmount, "Incorrect loan amount");

        loan.lender = msg.sender;
        loan.state = LoanState.Funded;

        payable(loan.borrower).transfer(loan.loanAmount);
        lenderLoans[msg.sender].push(_loanId);

        emit LoanFunded(_loanId, msg.sender);
    }

    // Function to repay a loan
    function repayLoan(uint256 _loanId) external payable loanExists(_loanId) noReentrancy {
        Loan storage loan = loans[_loanId];
        require(msg.sender == loan.borrower, "Only borrower can repay");
        require(loan.state == LoanState.Funded, "Loan is not funded or already repaid/defaulted");

        uint256 repaymentAmount = loan.loanAmount + loan.interest;
        require(msg.value == repaymentAmount, "Incorrect repayment amount");

        loan.state = LoanState.Repaid;
        payable(loan.lender).transfer(repaymentAmount);
        payable(loan.borrower).transfer(loan.collateralAmount);

        emit LoanRepaid(_loanId);
    }

    // Function for lender to claim collateral if loan defaults
    function claimCollateral(uint256 _loanId) external loanExists(_loanId) noReentrancy {
        Loan storage loan = loans[_loanId];
        require(msg.sender == loan.lender, "Only lender can claim collateral");
        require(block.timestamp > loan.dueDate, "Loan is not overdue");
        require(loan.state == LoanState.Funded, "Loan is not eligible for collateral claim");

        loan.state = LoanState.Defaulted;
        payable(loan.lender).transfer(loan.collateralAmount);

        emit CollateralClaimed(_loanId);
    }

    // Function to automatically transfer collateral to lender if loan is overdue
    function autoLiquidate(uint256 _loanId) external loanExists(_loanId) onlyOwner {
        Loan storage loan = loans[_loanId];
        require(block.timestamp > loan.dueDate, "Loan is not overdue");
        require(loan.state == LoanState.Funded, "Loan is not eligible for liquidation");

        loan.state = LoanState.Defaulted;
        payable(loan.lender).transfer(loan.collateralAmount);

        emit CollateralClaimed(_loanId);
    }

    // View function to get loan details
    function getLoanDetails(uint256 _loanId) external view loanExists(_loanId) returns (Loan memory) {
        return loans[_loanId];
    }
}