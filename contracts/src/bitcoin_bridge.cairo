use starknet::ContractAddress;

#[starknet::interface]
trait IBitcoinBridge<TContractState> {
    fn bridge_to_starknet(
        ref self: TContractState,
        bitcoin_tx_hash: felt252,
        amount: u256,
        recipient: ContractAddress,
    ) -> bool;
    
    fn bridge_to_bitcoin(
        ref self: TContractState,
        amount: u256,
        bitcoin_address: felt252,
    ) -> felt252;
    
    fn verify_bitcoin_transaction(
        self: @TContractState,
        tx_hash: felt252,
        block_hash: felt252,
        merkle_proof: Span<felt252>,
    ) -> bool;
    
    fn get_wrapped_btc_balance(self: @TContractState, user: ContractAddress) -> u256;
    fn get_bridge_fee(self: @TContractState) -> u256;
}

#[starknet::contract]
mod BitcoinBridge {
    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, Map};
    use starknet::{ContractAddress, get_caller_address};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::security::reentrancyguard::ReentrancyGuardComponent;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: ReentrancyGuardComponent, storage: reentrancy_guard, event: ReentrancyGuardEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl ReentrancyGuardInternalImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        // Wrapped BTC token contract
        wbtc_token: ContractAddress,
        // Bridge fee in basis points
        bridge_fee: u256,
        // Processed Bitcoin transactions
        processed_txs: Map<felt252, bool>,
        // Pending withdrawals to Bitcoin
        pending_withdrawals: Map<felt252, WithdrawalRequest>,
        // User wrapped BTC balances
        wbtc_balances: Map<ContractAddress, u256>,
        // Bitcoin block headers for verification
        bitcoin_headers: Map<felt252, BlockHeader>,
        // Next withdrawal ID
        next_withdrawal_id: felt252,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        reentrancy_guard: ReentrancyGuardComponent::Storage,
    }

    #[derive(Drop, Copy, Serde, starknet::Store)]
    struct WithdrawalRequest {
        amount: u256,
        bitcoin_address: felt252,
        user: ContractAddress,
        timestamp: u64,
        processed: bool,
    }

    #[derive(Drop, Copy, Serde, starknet::Store)]
    struct BlockHeader {
        prev_block_hash: felt252,
        merkle_root: felt252,
        timestamp: u64,
        bits: u32,
        nonce: u32,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        BridgeToStarknet: BridgeToStarknet,
        BridgeTobitcoin: BridgeTobitcoin,
        WithdrawalProcessed: WithdrawalProcessed,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct BridgeToStarknet {
        bitcoin_tx_hash: felt252,
        recipient: ContractAddress,
        amount: u256,
        wbtc_minted: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct BridgeTobitcoin {
        withdrawal_id: felt252,
        user: ContractAddress,
        amount: u256,
        bitcoin_address: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct WithdrawalProcessed {
        withdrawal_id: felt252,
        bitcoin_tx_hash: felt252,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        wbtc_token: ContractAddress,
        bridge_fee: u256,
    ) {
        self.ownable.initializer(owner);
        self.wbtc_token.write(wbtc_token);
        self.bridge_fee.write(bridge_fee);
        self.next_withdrawal_id.write(1);
    }

    #[abi(embed_v0)]
    impl BitcoinBridgeImpl of super::IBitcoinBridge<ContractState> {
        fn bridge_to_starknet(
            ref self: ContractState,
            bitcoin_tx_hash: felt252,
            amount: u256,
            recipient: ContractAddress,
        ) -> bool {
            self.reentrancy_guard.start();
            
            // Check if transaction already processed
            assert(!self.processed_txs.entry(bitcoin_tx_hash).read(), 'Transaction already processed');
            
            // Mark transaction as processed
            self.processed_txs.entry(bitcoin_tx_hash).write(true);
            
            // Calculate bridge fee
            let fee = (amount * self.bridge_fee.read()) / 10000;
            let net_amount = amount - fee;
            
            // Mint wrapped BTC to recipient
            let wbtc_token = IERC20Dispatcher { contract_address: self.wbtc_token.read() };
            // Note: This would require a mintable WBTC contract
            // wbtc_token.mint(recipient, net_amount);
            
            // Update user balance (simplified for demo)
            let current_balance = self.wbtc_balances.entry(recipient).read();
            self.wbtc_balances.entry(recipient).write(current_balance + net_amount);
            
            self.emit(BridgeToStarknet {
                bitcoin_tx_hash,
                recipient,
                amount,
                wbtc_minted: net_amount,
            });
            
            self.reentrancy_guard.end();
            true
        }

        fn bridge_to_bitcoin(
            ref self: ContractState,
            amount: u256,
            bitcoin_address: felt252,
        ) -> felt252 {
            self.reentrancy_guard.start();
            let caller = get_caller_address();
            
            // Check user balance
            let user_balance = self.wbtc_balances.entry(caller).read();
            assert(user_balance >= amount, 'Insufficient WBTC balance');
            
            // Calculate fee
            let fee = (amount * self.bridge_fee.read()) / 10000;
            let net_amount = amount - fee;
            
            // Update user balance
            self.wbtc_balances.entry(caller).write(user_balance - amount);
            
            // Create withdrawal request
            let withdrawal_id = self.next_withdrawal_id.read();
            let withdrawal = WithdrawalRequest {
                amount: net_amount,
                bitcoin_address,
                user: caller,
                timestamp: 0, // Would use get_block_timestamp() in real implementation
                processed: false,
            };
            
            self.pending_withdrawals.entry(withdrawal_id).write(withdrawal);
            self.next_withdrawal_id.write(withdrawal_id + 1);
            
            self.emit(BridgeTobitcoin {
                withdrawal_id,
                user: caller,
                amount: net_amount,
                bitcoin_address,
            });
            
            self.reentrancy_guard.end();
            withdrawal_id
        }

        fn verify_bitcoin_transaction(
            self: @ContractState,
            tx_hash: felt252,
            block_hash: felt252,
            merkle_proof: Span<felt252>,
        ) -> bool {
            // Simplified verification - in production this would implement full SPV verification
            let header = self.bitcoin_headers.entry(block_hash).read();
            
            // Verify merkle proof against header merkle root
            let mut current_hash = tx_hash;
            let mut i = 0;
            
            while i < merkle_proof.len() {
                let proof_element = *merkle_proof.at(i);
                // Simplified hash combination - would use actual Bitcoin hashing
                current_hash = current_hash + proof_element;
                i += 1;
            };
            
            current_hash == header.merkle_root
        }

        fn get_wrapped_btc_balance(self: @ContractState, user: ContractAddress) -> u256 {
            self.wbtc_balances.entry(user).read()
        }

        fn get_bridge_fee(self: @ContractState) -> u256 {
            self.bridge_fee.read()
        }
    }
}