// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title ExpenseSplit
/// @notice On-chain expense sharing with automatic balance tracking and AVAX settlements
contract ExpenseSplit is ReentrancyGuard {
    enum SplitMethod {
        Equal,
        Percentage,
        Custom
    }

    enum SettlementStatus {
        Pending,
        AwaitingConfirmation,
        Confirmed,
        Failed,
        Cancelled
    }

    struct Group {
        uint256 id;
        address creator;
        string name;
        string description;
        address[] members;
        uint256 createdAt;
        bool exists;
    }

    struct Expense {
        uint256 id;
        uint256 groupId;
        string title;
        uint256 amount;
        address paidBy;
        SplitMethod splitMethod;
        address[] participants;
        uint256[] shares;
        string note;
        uint256 createdAt;
    }

    struct Settlement {
        uint256 id;
        uint256 groupId;
        address from;
        address to;
        uint256 amount;
        bytes32 settlementRef;
        SettlementStatus status;
        uint256 createdAt;
        uint256 confirmedAt;
        bytes32 txHash;
    }

    uint256 private _groupIdCounter;
    uint256 private _expenseIdCounter;
    uint256 private _settlementIdCounter;

    mapping(uint256 => Group) private _groups;
    mapping(uint256 => Expense) private _expenses;
    mapping(uint256 => Settlement) private _settlements;
    mapping(uint256 => uint256[]) private _groupExpenseIds;
    mapping(uint256 => uint256[]) private _groupSettlementIds;
    mapping(bytes32 => bool) public usedSettlementRefs;
    mapping(bytes32 => bool) public usedTxHashes;

    /// @dev debts[groupId][debtor][creditor] = amount debtor owes creditor (in wei)
    mapping(uint256 => mapping(address => mapping(address => uint256))) public debts;

    event GroupCreated(
        uint256 indexed groupId,
        address indexed creator,
        string name,
        address[] members
    );

    event ExpenseAdded(
        uint256 indexed expenseId,
        uint256 indexed groupId,
        string title,
        uint256 amount,
        address indexed paidBy
    );

    event SettlementRequestCreated(
        uint256 indexed settlementId,
        uint256 indexed groupId,
        address indexed from,
        address to,
        uint256 amount,
        bytes32 settlementRef
    );

    event DebtSettled(
        uint256 indexed settlementId,
        uint256 indexed groupId,
        address indexed from,
        address to,
        uint256 amount,
        bytes32 settlementRef
    );

    /// @notice Create a new expense-sharing group
    /// @param name Group display name
    /// @param description Optional group description
    /// @param members Wallet addresses of group members (creator added automatically if missing)
    /// @return groupId The newly created group identifier
    function createGroup(
        string calldata name,
        string calldata description,
        address[] calldata members
    ) external returns (uint256 groupId) {
        require(bytes(name).length > 0, "Name required");
        require(members.length >= 1, "At least one member required");

        groupId = ++_groupIdCounter;
        address[] memory allMembers = _buildMemberList(members, msg.sender);

        Group storage group = _groups[groupId];
        group.id = groupId;
        group.creator = msg.sender;
        group.name = name;
        group.description = description;
        group.members = allMembers;
        group.createdAt = block.timestamp;
        group.exists = true;

        emit GroupCreated(groupId, msg.sender, name, allMembers);
    }

    /// @notice Record a shared expense and update member balances
    function addExpense(
        uint256 groupId,
        string calldata title,
        uint256 amount,
        address paidBy,
        SplitMethod splitMethod,
        address[] calldata participants,
        uint256[] calldata shares,
        string calldata note
    ) external groupExists(groupId) onlyGroupMember(groupId) returns (uint256 expenseId) {
        require(bytes(title).length > 0, "Title required");
        require(amount > 0, "Amount must be positive");
        require(participants.length >= 1, "At least one participant required");
        require(_isGroupMember(groupId, paidBy), "Payer must be a group member");

        _validateParticipants(groupId, participants);

        uint256[] memory owedAmounts = _calculateShares(
            amount,
            splitMethod,
            participants.length,
            shares
        );

        expenseId = ++_expenseIdCounter;

        Expense storage expense = _expenses[expenseId];
        expense.id = expenseId;
        expense.groupId = groupId;
        expense.title = title;
        expense.amount = amount;
        expense.paidBy = paidBy;
        expense.splitMethod = splitMethod;
        expense.participants = participants;
        expense.shares = owedAmounts;
        expense.note = note;
        expense.createdAt = block.timestamp;

        _groupExpenseIds[groupId].push(expenseId);

        for (uint256 i = 0; i < participants.length; i++) {
            address participant = participants[i];
            uint256 owed = owedAmounts[i];
            if (participant != paidBy && owed > 0) {
                _applyDebt(groupId, participant, paidBy, owed);
            }
        }

        emit ExpenseAdded(expenseId, groupId, title, amount, paidBy);
    }

    /// @notice Create a pending settlement request (used for QR-based payments)
    function createSettlementRequest(
        uint256 groupId,
        address to,
        uint256 amount,
        bytes32 settlementRef,
        uint256 expiry
    ) external groupExists(groupId) onlyGroupMember(groupId) returns (uint256 settlementId) {
        require(to != address(0), "Invalid recipient");
        require(to != msg.sender, "Cannot settle to self");
        require(amount > 0, "Amount must be positive");
        require(settlementRef != bytes32(0), "Settlement ref required");
        require(!usedSettlementRefs[settlementRef], "Settlement ref already used");
        require(debts[groupId][msg.sender][to] >= amount, "Insufficient debt");
        require(expiry == 0 || expiry > block.timestamp, "Settlement expired");

        settlementId = ++_settlementIdCounter;

        Settlement storage settlement = _settlements[settlementId];
        settlement.id = settlementId;
        settlement.groupId = groupId;
        settlement.from = msg.sender;
        settlement.to = to;
        settlement.amount = amount;
        settlement.settlementRef = settlementRef;
        settlement.status = SettlementStatus.Pending;
        settlement.createdAt = block.timestamp;

        _groupSettlementIds[groupId].push(settlementId);

        emit SettlementRequestCreated(
            settlementId,
            groupId,
            msg.sender,
            to,
            amount,
            settlementRef
        );
    }

    /// @notice Settle an outstanding debt by sending AVAX
    /// @param groupId The group context for the debt
    /// @param to The creditor receiving payment
    /// @param settlementRef Optional reference from a QR settlement request (bytes32(0) to skip)
    function settleDebt(
        uint256 groupId,
        address to,
        bytes32 settlementRef
    ) external payable nonReentrant groupExists(groupId) onlyGroupMember(groupId) {
        require(to != address(0), "Invalid recipient");
        require(to != msg.sender, "Cannot settle to self");
        require(msg.value > 0, "Must send AVAX");

        uint256 amount = msg.value;
        require(debts[groupId][msg.sender][to] >= amount, "Insufficient debt");

        if (settlementRef != bytes32(0)) {
            require(!usedSettlementRefs[settlementRef], "Settlement ref already used");
            usedSettlementRefs[settlementRef] = true;
            _matchPendingSettlement(settlementRef, amount, to);
        }

        _reduceDebt(groupId, msg.sender, to, amount);

        (bool success, ) = payable(to).call{value: amount}("");
        require(success, "AVAX transfer failed");

        uint256 settlementId = ++_settlementIdCounter;
        Settlement storage settlement = _settlements[settlementId];
        settlement.id = settlementId;
        settlement.groupId = groupId;
        settlement.from = msg.sender;
        settlement.to = to;
        settlement.amount = amount;
        settlement.settlementRef = settlementRef;
        settlement.status = SettlementStatus.Confirmed;
        settlement.createdAt = block.timestamp;
        settlement.confirmedAt = block.timestamp;

        _groupSettlementIds[groupId].push(settlementId);

        emit DebtSettled(settlementId, groupId, msg.sender, to, amount, settlementRef);
    }

    /// @notice Cancel a pending settlement request
    function cancelSettlementRequest(uint256 settlementId) external {
        Settlement storage settlement = _settlements[settlementId];
        require(settlement.id != 0, "Settlement not found");
        require(settlement.from == msg.sender, "Not settlement owner");
        require(
            settlement.status == SettlementStatus.Pending,
            "Can only cancel pending settlements"
        );

        settlement.status = SettlementStatus.Cancelled;
    }

    /// @notice Return all groups (empty slots filtered out)
    function getGroups() external view returns (Group[] memory) {
        if (_groupIdCounter == 0) return new Group[](0);

        uint256 count = 0;
        for (uint256 i = 1; i <= _groupIdCounter; i++) {
            if (_groups[i].exists) count++;
        }

        Group[] memory result = new Group[](count);
        uint256 index = 0;
        for (uint256 i = 1; i <= _groupIdCounter; i++) {
            if (_groups[i].exists) {
                result[index++] = _groups[i];
            }
        }
        return result;
    }

    /// @notice Return groups where the caller is a member
    function getMyGroups() external view returns (Group[] memory) {
        if (_groupIdCounter == 0) return new Group[](0);

        uint256 count = 0;
        for (uint256 i = 1; i <= _groupIdCounter; i++) {
            if (_groups[i].exists && _isGroupMember(i, msg.sender)) count++;
        }

        Group[] memory result = new Group[](count);
        uint256 index = 0;
        for (uint256 i = 1; i <= _groupIdCounter; i++) {
            if (_groups[i].exists && _isGroupMember(i, msg.sender)) {
                result[index++] = _groups[i];
            }
        }
        return result;
    }

    /// @notice Return a single group by ID
    function getGroup(uint256 groupId) external view groupExists(groupId) returns (Group memory) {
        return _groups[groupId];
    }

    /// @notice Return all expenses for a group
    function getExpenses(uint256 groupId) external view groupExists(groupId) returns (Expense[] memory) {
        uint256[] storage ids = _groupExpenseIds[groupId];
        Expense[] memory result = new Expense[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            result[i] = _expenses[ids[i]];
        }
        return result;
    }

    /// @notice Return all settlements for a group
    function getSettlements(uint256 groupId) external view groupExists(groupId) returns (Settlement[] memory) {
        uint256[] storage ids = _groupSettlementIds[groupId];
        Settlement[] memory result = new Settlement[](ids.length);
        for (uint256 i = 0; i < ids.length; i++) {
            result[i] = _settlements[ids[i]];
        }
        return result;
    }

    /// @notice Return net balance summary for every group member
    /// @return members Member addresses
    /// @return totalOwed Total amount each member owes across all creditors
    /// @return totalReceivable Total amount each member is owed across all debtors
    /// @return netBalance Positive means member is owed money, negative means they owe
    function getBalances(
        uint256 groupId
    )
        external
        view
        groupExists(groupId)
        returns (
            address[] memory members,
            uint256[] memory totalOwed,
            uint256[] memory totalReceivable,
            int256[] memory netBalance
        )
    {
        members = _groups[groupId].members;
        uint256 len = members.length;
        totalOwed = new uint256[](len);
        totalReceivable = new uint256[](len);
        netBalance = new int256[](len);

        for (uint256 i = 0; i < len; i++) {
            for (uint256 j = 0; j < len; j++) {
                if (i == j) continue;
                totalOwed[i] += debts[groupId][members[i]][members[j]];
                totalReceivable[i] += debts[groupId][members[j]][members[i]];
            }
            netBalance[i] = int256(totalReceivable[i]) - int256(totalOwed[i]);
        }
    }

    /// @notice Return how much `from` owes `to` within a group
    function getDebt(uint256 groupId, address from, address to) external view returns (uint256) {
        return debts[groupId][from][to];
    }

    /// @notice Return a single expense by ID
    function getExpense(uint256 expenseId) external view returns (Expense memory) {
        require(_expenses[expenseId].id != 0, "Expense not found");
        return _expenses[expenseId];
    }

    /// @notice Return a single settlement by ID
    function getSettlement(uint256 settlementId) external view returns (Settlement memory) {
        require(_settlements[settlementId].id != 0, "Settlement not found");
        return _settlements[settlementId];
    }

    /// @notice Total number of groups created
    function groupCount() external view returns (uint256) {
        return _groupIdCounter;
    }

    modifier groupExists(uint256 groupId) {
        require(_groups[groupId].exists, "Group does not exist");
        _;
    }

    modifier onlyGroupMember(uint256 groupId) {
        require(_isGroupMember(groupId, msg.sender), "Not a group member");
        _;
    }

    function _validateParticipants(uint256 groupId, address[] calldata participants) private view {
        for (uint256 i = 0; i < participants.length; i++) {
            require(participants[i] != address(0), "Invalid participant address");
            require(_isGroupMember(groupId, participants[i]), "Participant not in group");
        }
    }

    function _buildMemberList(
        address[] calldata members,
        address creator
    ) private pure returns (address[] memory) {
        bool creatorIncluded = false;
        for (uint256 i = 0; i < members.length; i++) {
            require(members[i] != address(0), "Invalid member address");
            if (members[i] == creator) creatorIncluded = true;
        }

        if (creatorIncluded) return members;

        address[] memory result = new address[](members.length + 1);
        for (uint256 i = 0; i < members.length; i++) {
            result[i] = members[i];
        }
        result[members.length] = creator;
        return result;
    }

    function _isGroupMember(uint256 groupId, address account) private view returns (bool) {
        address[] storage members = _groups[groupId].members;
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i] == account) return true;
        }
        return false;
    }

    function _calculateShares(
        uint256 amount,
        SplitMethod splitMethod,
        uint256 participantCount,
        uint256[] calldata shares
    ) private pure returns (uint256[] memory owedAmounts) {
        owedAmounts = new uint256[](participantCount);

        if (splitMethod == SplitMethod.Equal) {
            uint256 each = amount / participantCount;
            uint256 remainder = amount - (each * participantCount);
            for (uint256 i = 0; i < participantCount; i++) {
                owedAmounts[i] = each;
            }
            if (remainder > 0) {
                owedAmounts[0] += remainder;
            }
        } else if (splitMethod == SplitMethod.Percentage) {
            require(shares.length == participantCount, "Shares length mismatch");
            uint256 totalPercent = 0;
            for (uint256 i = 0; i < participantCount; i++) {
                totalPercent += shares[i];
            }
            require(totalPercent == 100, "Percentages must sum to 100");

            uint256 allocated = 0;
            for (uint256 i = 0; i < participantCount; i++) {
                if (i == participantCount - 1) {
                    owedAmounts[i] = amount - allocated;
                } else {
                    owedAmounts[i] = (amount * shares[i]) / 100;
                    allocated += owedAmounts[i];
                }
            }
        } else {
            require(shares.length == participantCount, "Shares length mismatch");
            uint256 total = 0;
            for (uint256 i = 0; i < participantCount; i++) {
                total += shares[i];
            }
            require(total == amount, "Custom shares must sum to amount");
            for (uint256 i = 0; i < participantCount; i++) {
                owedAmounts[i] = shares[i];
            }
        }
    }

    function _applyDebt(
        uint256 groupId,
        address debtor,
        address creditor,
        uint256 amount
    ) private {
        // Net bilateral debts: if creditor already owes debtor, offset first
        uint256 reverse = debts[groupId][creditor][debtor];
        if (reverse >= amount) {
            debts[groupId][creditor][debtor] = reverse - amount;
        } else {
            debts[groupId][creditor][debtor] = 0;
            debts[groupId][debtor][creditor] += amount - reverse;
        }
    }

    function _reduceDebt(
        uint256 groupId,
        address debtor,
        address creditor,
        uint256 amount
    ) private {
        uint256 current = debts[groupId][debtor][creditor];
        require(current >= amount, "Insufficient debt");
        debts[groupId][debtor][creditor] = current - amount;
    }

    function _matchPendingSettlement(
        bytes32 settlementRef,
        uint256 amount,
        address to
    ) private {
        for (uint256 i = 1; i <= _settlementIdCounter; i++) {
            Settlement storage s = _settlements[i];
            if (
                s.settlementRef == settlementRef &&
                s.status == SettlementStatus.Pending &&
                s.to == to &&
                s.amount == amount
            ) {
                s.status = SettlementStatus.Confirmed;
                s.confirmedAt = block.timestamp;
                return;
            }
        }
    }
}
