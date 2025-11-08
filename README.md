# 🗳️ Decentralized Voter Registration Verification

Enable tamper-proof voter lists and identity proofs for elections without exposing private data.

## 🎯 Overview

This Clarity smart contract provides a decentralized system for voter registration and verification that ensures:
- 🔒 **Tamper-proof voter records** stored on blockchain
- 🛡️ **Privacy protection** using cryptographic hashes
- ✅ **Identity verification** without exposing personal data
- 🏛️ **Election management** with configurable periods
- 📊 **Transparent audit trail** of all registrations

## 🚀 Features

- **Voter Registration**: Register voters with hashed identity data
- **Identity Verification**: Verify voter identity using cryptographic proofs
- **Election Creation**: Create elections with custom duration and registration periods
- **Eligibility Management**: Register voters for specific elections
- **Status Tracking**: Monitor election phases and voter verification status
- **Admin Controls**: Revoke voter eligibility when necessary

## 📋 Contract Functions

### Public Functions

#### `register-voter`
```clarity
(register-voter (voter-id (buff 32)) (identity-hash (buff 32)))
```
Register a new voter with their hashed identity data.

#### `verify-voter`
```clarity
(verify-voter (voter-id (buff 32)) (verification-proof (buff 32)))
```
Verify a voter's identity using cryptographic proof.

#### `create-election`
```clarity
(create-election (name (string-ascii 50)) (duration uint) (registration-period uint))
```
Create a new election (contract owner only).

#### `register-for-election`
```clarity
(register-for-election (voter-id (buff 32)) (election-id uint))
```
Register a verified voter for a specific election.

#### `revoke-voter-eligibility`
```clarity
(revoke-voter-eligibility (voter-id (buff 32)) (election-id uint))
```
Revoke voter eligibility for an election (election admin only).

### Read-Only Functions

#### `get-voter-info`
Get comprehensive voter information including verification status.

#### `get-election-info`
Retrieve election details and metadata.

#### `is-voter-eligible`
Check if a voter is eligible for a specific election.

#### `verify-voter-identity`
Verify if a claimed identity hash matches the registered voter.

#### `get-election-status`
Get current election status: "registration", "active", or "ended".

## 🔧 Usage

### 1. Deploy Contract
Deploy the contract using Clarinet:
```bash
clarinet deploy
```

### 2. Register Voters
```clarity
(contract-call? .Decentralized-Voter-Registration-Verification register-voter 0x1234... 0xabcd...)
```

### 3. Verify Identity
```clarity
(contract-call? .Decentralized-Voter-Registration-Verification verify-voter 0x1234... 0xabcd...)
```

### 4. Create Election
```clarity
(contract-call? .Decentralized-Voter-Registration-Verification create-election "Presidential Election 2024" u1000 u200)
```

### 5. Register for Election
```clarity
(contract-call? .Decentralized-Voter-Registration-Verification register-for-election 0x1234... u1)
```

## 🏗️ Data Structures

### Voters Map
- `voter-id`: Unique 32-byte identifier
- `identity-hash`: Cryptographic hash of identity data
- `verified`: Boolean verification status
- `registration-block`: Block height of registration
- `verification-block`: Block height of verification (optional)

### Elections Map
- `election-id`: Unique election identifier
- `name`: Election name (max 50 characters)
- `start-block`: Election start block
- `end-block`: Election end block
- `registration-end`: Registration deadline block
- `total-registered`: Number of registered voters
- `admin`: Election administrator principal

## 🔐 Security Features

- **Identity Privacy**: Personal data never stored on-chain, only cryptographic hashes
- **Tamper Resistance**: All records immutably stored on Stacks blockchain
- **Access Control**: Role-based permissions for admin functions
- **Verification Proofs**: Cryptographic verification without data exposure
- **Audit Trail**: Complete history of all voter actions and election events

## 🧪 Testing

Run tests using Clarinet:
```bash
clarinet test
```

## 📦 Development

### Prerequisites
- Clarinet CLI
- Node.js (for additional tooling)

### Build
```bash
clarinet check
```

### Console Testing
```bash
clarinet console
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is open source and available under the MIT License.

## 🌟 Acknowledgments

Built with ❤️ using Stacks blockchain and Clarity smart contracts.
