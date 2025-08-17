# Hunt Lease Escrow Smart Contract

A decentralized escrow system for hunting land lease agreements built on the Stacks blockchain using Clarity smart contracts. This contract facilitates secure transactions between landowners and hunters by acting as a neutral third-party escrow service.

## 🎯 Overview

The Hunt Lease Escrow contract enables landowners to list their hunting properties for lease and hunters to securely fund these leases. The contract holds STX payments in escrow until both parties confirm successful completion of the lease terms, ensuring trust and security for all participants.

## ✨ Features

- **Secure Escrow**: Holds STX payments until lease completion is confirmed by both parties
- **Multi-stage Process**: Supports listing, funding, activation, and completion phases
- **Dispute Resolution**: Built-in dispute mechanism with admin resolution capability
- **Service Fees**: Configurable service fee percentage (default: 2%, max: 10%)
- **Cancellation Support**: Allows lease cancellation with automatic refunds
- **Comprehensive Validation**: Input validation and state management for security

## 🔧 Contract States

| State | Code | Description |
|-------|------|-------------|
| `LISTED` | `0` | Property is listed and available for funding |
| `FUNDED` | `1` | Hunter has funded the lease, awaiting landowner activation |
| `ACTIVE` | `2` | Lease is active and hunting period has begun |
| `COMPLETED` | `3` | Both parties confirmed completion, funds released |
| `DISPUTED` | `4` | Dispute raised, requires admin resolution |
| `CANCELED` | `5` | Lease canceled, funds refunded if applicable |

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) v0.31.1 or higher
- [Stacks CLI](https://docs.stacks.co/docs/cli)

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd hunt-lease-escrow
```

2. Check contract syntax:
```bash
clarinet check
```

3. Run tests:
```bash
clarinet test
```

## 📖 Usage Guide

### For Landowners

#### 1. List a Property
```clarity
(contract-call? .hunt-lease-escrow list-lease u1000000 "https://example.com/property-details")
```
- `amount-ustx`: Lease amount in microSTX (1 STX = 1,000,000 microSTX)
- `details-uri`: URL or IPFS hash containing property details

#### 2. Activate Funded Lease
```clarity
(contract-call? .hunt-lease-escrow activate-lease u1)
```
- Call this after a hunter has funded your lease

#### 3. Confirm Completion
```clarity
(contract-call? .hunt-lease-escrow confirm-completion u1)
```
- Confirm the hunting lease was completed successfully

### For Hunters

#### 1. Fund a Listed Property
```clarity
(contract-call? .hunt-lease-escrow fund-lease u1)
```
- This transfers the lease amount to the escrow contract

#### 2. Confirm Completion
```clarity
(contract-call? .hunt-lease-escrow confirm-completion u1)
```
- Confirm you completed the hunting lease successfully

### For Both Parties

#### Cancel Lease (Before Activation)
```clarity
(contract-call? .hunt-lease-escrow cancel-lease u1)
```
- Cancels the lease and refunds hunter if already funded

#### Raise Dispute
```clarity
(contract-call? .hunt-lease-escrow raise-dispute u1)
```
- Raises a dispute for admin resolution

## 🛠 Administrative Functions

### Set Service Fee
```clarity
(contract-call? .hunt-lease-escrow set-service-fee u3)
```
- Only contract owner can modify (max 10%)

### Resolve Dispute
```clarity
(contract-call? .hunt-lease-escrow resolve-dispute u1 true)
```
- `lease-id`: The disputed lease ID
- `release-to-landowner`: `true` for landowner, `false` for hunter

## 📊 Read-Only Functions

### Get Lease Details
```clarity
(contract-call? .hunt-lease-escrow get-lease-details u1)
```

### Check Lease Status
```clarity
(contract-call? .hunt-lease-escrow get-lease-status u1)
```

### Check if Ready for Completion
```clarity
(contract-call? .hunt-lease-escrow is-lease-ready-for-completion u1)
```

### Get Current Service Fee
```clarity
(contract-call? .hunt-lease-escrow get-service-fee)
```

### Get Last Lease ID
```clarity
(contract-call? .hunt-lease-escrow get-last-lease-id)
```

## 💰 Fee Structure

- **Service Fee**: 2% of lease amount (configurable, max 10%)
- **Network Fees**: Standard Stacks transaction fees apply
- **Gas Costs**: Optimized for minimal gas consumption

## 🔒 Security Features

- **Input Validation**: All user inputs are validated before processing
- **State Verification**: Strict state machine prevents invalid transitions
- **Authorization Checks**: Only authorized parties can perform specific actions
- **Overflow Protection**: Safe arithmetic operations prevent overflow attacks
- **Reentrancy Protection**: Contract design prevents reentrancy vulnerabilities

## 🏗 Contract Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Landowner     │    │     Hunter      │    │  Contract Owner │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │ 1. list-lease         │                       │
         ├──────────────────────────────────────────────►│
         │                       │                       │
         │                       │ 2. fund-lease         │
         │                       ├──────────────────────►│
         │                       │                       │
         │ 3. activate-lease     │                       │
         ├──────────────────────────────────────────────►│
         │                       │                       │
         │ 4. confirm-completion │                       │
         ├──────────────────────────────────────────────►│
         │                       │                       │
         │                       │ 5. confirm-completion │
         │                       ├──────────────────────►│
         │                       │                       │
         │ 6. Funds Released     │                       │
         │◄──────────────────────────────────────────────┤
```

## 🧪 Testing

The contract includes comprehensive test coverage:

```bash
# Run all tests
clarinet test

# Check contract syntax
clarinet check

# Console testing environment
clarinet console
```

## 📝 Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| `u101` | `ERR_NOT_AUTHORIZED` | Caller not authorized for this action |
| `u102` | `ERR_LEASE_NOT_FOUND` | Lease ID does not exist |
| `u103` | `ERR_INVALID_LEASE_STATE` | Invalid state transition |
| `u104` | `ERR_INVALID_AMOUNT` | Invalid amount specified |
| `u105` | `ERR_FUNDS_NOT_RECEIVED` | Expected funds not received |
| `u106` | `ERR_LEASE_ALREADY_CONFIRMED` | Party already confirmed |
| `u107` | `ERR_LEASE_EXPIRED` | Lease has expired |
| `u108` | `ERR_PAYMENT_FAILED` | Payment transaction failed |
| `u109` | `ERR_TRANSFER_FAILED` | STX transfer failed |

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes and add tests
4. Ensure all tests pass (`clarinet test`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: [Clarity Language Reference](https://docs.stacks.co/docs/clarity)
- **Issues**: Submit issues via GitHub Issues
- **Community**: Join the Stacks Discord community

## 🚨 Disclaimer

This smart contract is provided as-is for educational and development purposes. Always conduct thorough testing and audits before deploying to mainnet. The authors are not responsible for any losses incurred through the use of this contract.

## 🔄 Version History

- **v1.0.0**: Initial release with basic escrow functionality
- **v1.1.0**: Added dispute resolution and enhanced validation
- **v1.2.0**: Optimized for Clarinet 0.31.1 compatibility

---

**Built with ❤️ for the hunting and blockchain communities**