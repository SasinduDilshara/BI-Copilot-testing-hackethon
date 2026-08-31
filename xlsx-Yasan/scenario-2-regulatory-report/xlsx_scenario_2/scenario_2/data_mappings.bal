# Simulated in-memory alert store. Spans APAC, EMEA and AMER regions and two
# different months (2026-07 and 2026-08) so that month-based filtering is meaningful.
final TransactionAlert[] alertStore = [
    {
        alertId: "ALT-1001",
        branchCode: "SG-001",
        region: APAC,
        alertType: STRUCTURING,
        amountUsd: 15750.50,
        raisedOn: {year: 2026, month: 8, day: 3},
        status: OPEN
    },
    {
        alertId: "ALT-1002",
        branchCode: "SG-002",
        region: APAC,
        alertType: VELOCITY,
        amountUsd: 8200.00,
        raisedOn: {year: 2026, month: 8, day: 10},
        status: ESCALATED
    },
    {
        alertId: "ALT-1003",
        branchCode: "HK-010",
        region: APAC,
        alertType: SANCTIONS_HIT,
        amountUsd: 42000.75,
        raisedOn: {year: 2026, month: 7, day: 22},
        status: CLOSED
    },
    {
        alertId: "ALT-1004",
        branchCode: "LN-100",
        region: EMEA,
        alertType: MANUAL,
        amountUsd: 5230.25,
        raisedOn: {year: 2026, month: 8, day: 5},
        status: OPEN
    },
    {
        alertId: "ALT-1005",
        branchCode: "LN-101",
        region: EMEA,
        alertType: STRUCTURING,
        amountUsd: 27890.00,
        raisedOn: {year: 2026, month: 8, day: 18},
        status: ESCALATED
    },
    {
        alertId: "ALT-1006",
        branchCode: "FR-050",
        region: EMEA,
        alertType: VELOCITY,
        amountUsd: 9600.40,
        raisedOn: {year: 2026, month: 7, day: 14},
        status: CLOSED
    },
    {
        alertId: "ALT-1007",
        branchCode: "DE-075",
        region: EMEA,
        alertType: SANCTIONS_HIT,
        amountUsd: 61250.00,
        raisedOn: {year: 2026, month: 8, day: 27},
        status: OPEN
    },
    {
        alertId: "ALT-1008",
        branchCode: "NY-200",
        region: AMER,
        alertType: STRUCTURING,
        amountUsd: 18400.60,
        raisedOn: {year: 2026, month: 8, day: 2},
        status: OPEN
    },
    {
        alertId: "ALT-1009",
        branchCode: "NY-201",
        region: AMER,
        alertType: VELOCITY,
        amountUsd: 7300.10,
        raisedOn: {year: 2026, month: 8, day: 12},
        status: CLOSED
    },
    {
        alertId: "ALT-1010",
        branchCode: "TO-300",
        region: AMER,
        alertType: MANUAL,
        amountUsd: 12980.00,
        raisedOn: {year: 2026, month: 7, day: 9},
        status: ESCALATED
    },
    {
        alertId: "ALT-1011",
        branchCode: "SG-003",
        region: APAC,
        alertType: MANUAL,
        amountUsd: 3400.00,
        raisedOn: {year: 2026, month: 8, day: 21},
        status: CLOSED
    },
    {
        alertId: "ALT-1012",
        branchCode: "SP-400",
        region: AMER,
        alertType: SANCTIONS_HIT,
        amountUsd: 55000.00,
        raisedOn: {year: 2026, month: 8, day: 29},
        status: ESCALATED
    },
    {
        alertId: "ALT-1013",
        branchCode: "HK-011",
        region: APAC,
        alertType: VELOCITY,
        amountUsd: 6100.30,
        raisedOn: {year: 2026, month: 7, day: 30},
        status: OPEN
    },
    {
        alertId: "ALT-1014",
        branchCode: "IT-060",
        region: EMEA,
        alertType: MANUAL,
        amountUsd: 4100.00,
        raisedOn: {year: 2026, month: 6, day: 15},
        status: CLOSED
    }
];
