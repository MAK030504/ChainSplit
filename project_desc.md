# ChainSplit

## Decentralized Expense Splitting dApp on Avalanche

**Version:** 1.0

**Target Blockchain:** Avalanche Fuji Testnet (Primary), Avalanche C-Chain (Optional)

---

# Project Overview

ChainSplit is a decentralized expense-sharing application inspired by Splitwise. It allows users to create groups, record shared expenses, automatically calculate who owes whom, and settle debts using AVAX on the Avalanche blockchain.

Unlike traditional expense-sharing apps, all expenses and settlements are stored transparently on-chain, ensuring trust, immutability, and verifiable payment history.

The application should focus on simplicity, speed, clean UI, and an excellent user experience.

---

# Project Objectives

* Demonstrate practical blockchain usage.
* Build a polished decentralized application.
* Showcase Solidity development.
* Integrate MetaMask.
* Deploy on Avalanche Fuji.
* Maintain clean architecture and documentation.
* Be suitable for submission to the Avalanche Pakistan Dev Bounty.

---

# Core Features

## 1. Wallet Authentication

Users connect using MetaMask.

Display:

* Wallet Address
* Network Status
* Connected Account
* Disconnect Button

Requirements:

* Detect wallet changes
* Detect network changes
* Prompt switch to Fuji if on another network

---

## 2. Dashboard

After login, users see:

* Total Groups
* Outstanding Balance
* Amount Owed
* Amount To Receive
* Recent Expenses

Quick actions:

* Create Group
* Add Expense
* Settle Debt

---

## 3. Groups

Users can:

Create Group

Fields:

* Group Name
* Description
* Member Wallet Addresses

Example:

Trip to Hunza

Members:

Mustafa

Ali

Ahmed

Sara

Each wallet can belong to multiple groups.

---

## 4. Add Expense

Fields

Expense Title

Amount

Currency (display PKR but settlement in AVAX)

Paid By

Split Method

Participants

Optional Note

Split Methods

Equal Split

Percentage Split

Custom Amount Split

Example

Dinner

6000 PKR

Paid by Mustafa

Participants:

Mustafa

Ali

Ahmed

Each owes 2000 PKR.

Balances update automatically.

---

## 5. Expense History

Each expense displays:

Title

Amount

Group

Paid By

Participants

Date

Transaction Hash

Status

Newest first.

---

## 6. Debt Calculation

For every member calculate:

Amount Owed

Amount Receivable

Net Balance

Example

Ali owes Mustafa

2000 PKR

Ahmed owes Mustafa

2000 PKR

Mustafa owes Sara

500 PKR

---

## 7. Settle Debt

User selects:

Person

Amount

Clicks:

Settle

MetaMask opens.

AVAX transfer occurs.

Settlement stored on-chain.

Balances update.

Store:

Sender

Receiver

Amount

Timestamp

Transaction Hash

---

## 8. Transaction Explorer

Every blockchain transaction links to Avalanche Explorer.

---

# Bonus Features (Priority)

## AI Receipt Scanner

User uploads receipt.

AI extracts:

Restaurant Name

Date

Total Amount

Items

Tax

Suggested Participants

Automatically fills Add Expense form.

This should reduce manual input.

---

## Analytics

Charts

Monthly Spending

Category Spending

Who You Owe Most

Who Owes You Most

---

## Dynamic QR Payment (High-Priority Feature)

ChainSplit will generate a unique QR code for every outstanding debt, allowing users to settle payments quickly and accurately using any compatible Web3 wallet.

### Workflow

1. User A records an expense.
2. The smart contract calculates the outstanding balances.
3. User B owes User A.
4. User B clicks **Pay via QR**.
5. The application generates a unique QR code containing:

   * Recipient wallet address
   * Amount in AVAX
   * Chain ID (Avalanche Fuji during development)
   * Settlement ID
   * Timestamp
6. User B scans the QR code with a compatible wallet.
7. The wallet opens with the recipient and amount already populated.
8. User B confirms the transaction.
9. The application automatically detects the successful transaction.
10. The corresponding debt is marked as **Settled**.

### QR Payload

Each QR should include:

* Recipient Wallet Address
* Amount (AVAX)
* Avalanche Chain ID
* Settlement Reference ID
* Optional Expiry Timestamp

### Settlement Verification

After payment, the frontend will:

* Wait for transaction confirmation.
* Verify the transaction on Avalanche.
* Match it with the Settlement ID.
* Update the smart contract and UI.
* Display a success notification with a link to the Avalanche Explorer.

### Settlement Status

Each settlement can have one of the following states:

* Pending
* Awaiting Confirmation
* Confirmed
* Failed
* Cancelled

### Security

* QR codes are generated only for active debts.
* Each QR code references a single settlement request.
* Expired or already settled requests cannot be reused.
* Transaction hashes are stored to prevent duplicate settlements.
* Smart contract validation ensures debts cannot be settled twice.

### User Experience

Each outstanding debt card should include:

* Amount owed
* Creditor
* "Pay Now" button
* "Show QR Code" button
* Real-time payment status
* Direct link to the confirmed blockchain transaction

The payment experience should require as few steps as possible while remaining secure and transparent.

---

## Export

CSV

PDF

---

## Dark Mode

Toggle theme.

---

## Notifications

Expense Added

Settlement Successful

Wallet Connected

Errors

---

# Technology Stack

Frontend

React

Vite

TypeScript

Tailwind CSS

React Router

React Query

Ethers.js

React Hook Form

Zod

Recharts

Backend

None

Everything interacts directly with smart contracts.

Blockchain

Solidity

Hardhat

OpenZeppelin

Avalanche Fuji

Storage

Blockchain

Optional IPFS

Hosting

Frontend:

Vercel

Smart Contracts:

Avalanche Fuji

Repository:

GitHub

---

# Folder Structure

chainsplit/

contracts/

ExpenseSplit.sol

scripts/

deploy.ts

test/

hardhat.config.ts

frontend/

src/

components/

pages/

hooks/

contexts/

services/

types/

utils/

assets/

README.md

---

# Smart Contract Design

Contract Name

ExpenseSplit

Data Structures

Group

Expense

Settlement

Functions

createGroup()

getGroups()

addExpense()

getExpenses()

getBalances()

settleDebt()

getSettlements()

Events

GroupCreated

ExpenseAdded

DebtSettled

---

# Solidity Considerations

Use OpenZeppelin where appropriate.

Validate inputs.

Prevent invalid wallet addresses.

Optimize gas usage.

Write NatSpec comments.

Include events for every state-changing action.

---

# Frontend Pages

Landing Page

Hero section

Features

How it Works

Connect Wallet

Footer

Dashboard

Statistics

Recent Activity

Quick Actions

Groups Page

Create

View

Delete (optional)

Expense Page

Add Expense

Expense List

Expense Details

Settlement Page

Pending Debts

Pay Debt

Settlement History

Profile

Wallet

Groups Joined

Payments Made

Payments Received

Settings

Theme

Network

About

---

# UI Guidelines

Modern fintech-inspired design.

Rounded cards.

Glassmorphism (optional).

Responsive layout.

Animations using Framer Motion.

Loading skeletons.

Empty states.

Toast notifications.

Minimal color palette.

Professional typography.

---

# Component List

Navbar

Sidebar

Wallet Button

Statistic Cards

Expense Card

Group Card

Settlement Card

Modal

Confirmation Dialog

Receipt Upload

Charts

Footer

Loader

Toast

---

# State Management

Wallet State

Groups

Expenses

Balances

Transactions

Theme

Loading

Errors

---

# Security

Validate wallet addresses.

Validate expense values.

Prevent duplicate settlements.

Check permissions.

Handle rejected MetaMask transactions.

Handle network mismatch.

---

# Error Handling

Wallet not installed

Wrong Network

Transaction Failed

Insufficient Funds

Invalid Members

Invalid Amount

Contract Errors

Friendly messages only.

---

# Testing

Unit Tests

Smart Contract Tests

Balance Calculations

Settlement Logic

Integration Tests

Wallet Connection

Expense Creation

Debt Settlement

Manual Testing

Desktop

Mobile

Chrome

Firefox

Edge

---

# Deployment

Deploy smart contract to Avalanche Fuji.

Verify contract.

Update frontend contract address.

Deploy frontend to Vercel.

Add screenshots.

Record demo video.

---

# README Requirements

Project Description

Architecture

Features

Installation

Running Locally

Environment Variables

Smart Contract Address

Deployment

Screenshots

Demo GIF

Future Improvements

License

---

# Future Roadmap

Recurring Expenses

Mobile App

Push Notifications

Cross-chain Settlement

USDC Payments

Multi-language Support

Expense Categories

Invite Links

Email Notifications

AI Spending Insights

---

# Deliverables

* Public GitHub repository.
* Clean commit history.
* Deployed smart contract on Avalanche Fuji.
* Live frontend.
* Comprehensive README.
* Demo video (2–3 minutes).
* Verified contract address.
* Submission form completed before the deadline.

---

# Development Plan

## Phase 1

* Initialize Hardhat project.
* Write and test the ExpenseSplit smart contract.
* Deploy to Avalanche Fuji.
* Verify contract.

## Phase 2

* Create the React frontend.
* Implement wallet connection.
* Integrate contract interactions.
* Build Dashboard, Groups, Expenses, and Settlements.

## Phase 3

* Polish UI and responsiveness.
* Add animations and notifications.
* Implement AI receipt scanning.
* Add analytics and export features.

## Phase 4

* Perform testing.
* Optimize performance.
* Write documentation.
* Deploy frontend.
* Record the demo.
* Submit the project.

---

# Cursor Instructions

You are an expert senior Full Stack Web3 engineer.

Your responsibilities are to:

* Follow clean architecture principles.
* Write production-quality TypeScript and Solidity.
* Use reusable React components.
* Keep code modular and well-documented.
* Explain each major implementation step.
* Never generate placeholder code when a complete implementation is possible.
* Maintain a consistent folder structure.
* Write unit tests for Solidity contracts.
* Use best security practices.
* Keep the UI modern and responsive.
* Commit code in logical milestones.
* Update documentation whenever new features are added.
* Ensure the project remains deployable at every stage.

The final product should feel like a polished startup MVP rather than a hackathon prototype.
