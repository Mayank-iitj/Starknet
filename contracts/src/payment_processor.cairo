use starknet::ContractAddress;

#[starknet::interface]
trait IPaymentProcessor<TContractState> {
    fn process_micro_payment(
        ref self: TContractState,
        recipient: ContractAddress,
        amount: u256,
        token: ContractAddress,
    ) -> bool;
    
    fn get_payment_fee(self: @TContractState, amount: u256) -> u256;
    fn get_total_volume(self: @TContractState) -> u256;
    fn get_user_balance(self: @TContractState, user: ContractAddress, token: ContractAddress) -> u256;
    fn deposit(ref self: TContractState, amount: u256, token: ContractAddress);
    fn withdraw(ref self: TContractState, amount: u256, token: ContractAddress);
}

#[starknet::contract]
mod PaymentProcessor {
    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, Map};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
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
        // Fee in basis points (1 bp = 0.01%)
        fee_rate: u256,
        // Total volume processed
        total_volume: u256,
        // User balances per token
        balances: Map<(ContractAddress, ContractAddress), u256>,
        // Fee treasury
        fee_treasury: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        reentrancy_guard: ReentrancyGuardComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        PaymentProcessed: PaymentProcessed,
        Deposit: Deposit,
        Withdrawal: Withdrawal,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct PaymentProcessed {
        sender: ContractAddress,
        recipient: ContractAddress,
        amount: u256,
        fee: u256,
        token: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct Deposit {
        user: ContractAddress,
        amount: u256,
        token: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct Withdrawal {
        user: ContractAddress,
        amount: u256,
        token: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        fee_rate: u256,
        fee_treasury: ContractAddress
    ) {
        self.ownable.initializer(owner);
        self.fee_rate.write(fee_rate); // Default: 25 basis points (0.25%)
        self.fee_treasury.write(fee_treasury);
    }

    #[abi(embed_v0)]
    impl PaymentProcessorImpl of super::IPaymentProcessor<ContractState> {
        fn process_micro_payment(
            ref self: ContractState,
            recipient: ContractAddress,
            amount: u256,
            token: ContractAddress,
        ) -> bool {
            self.reentrancy_guard.start();
            let sender = get_caller_address();
            
            // Calculate fee
            let fee = self.get_payment_fee(amount);
            let net_amount = amount - fee;
            
            // Check sender balance
            let sender_balance = self.balances.entry((sender, token)).read();
            assert(sender_balance >= amount, 'Insufficient balance');
            
            // Update balances
            self.balances.entry((sender, token)).write(sender_balance - amount);
            let recipient_balance = self.balances.entry((recipient, token)).read();
            self.balances.entry((recipient, token)).write(recipient_balance + net_amount);
            
            // Update treasury balance (fees)
            let treasury = self.fee_treasury.read();
            let treasury_balance = self.balances.entry((treasury, token)).read();
            self.balances.entry((treasury, token)).write(treasury_balance + fee);
            
            // Update total volume
            let current_volume = self.total_volume.read();
            self.total_volume.write(current_volume + amount);
            
            self.emit(PaymentProcessed {
                sender,
                recipient,
                amount,
                fee,
                token,
            });
            
            self.reentrancy_guard.end();
            true
        }

        fn get_payment_fee(self: @ContractState, amount: u256) -> u256 {
            let fee_rate = self.fee_rate.read();
            (amount * fee_rate) / 10000 // Convert basis points to percentage
        }

        fn get_total_volume(self: @ContractState) -> u256 {
            self.total_volume.read()
        }

        fn get_user_balance(self: @ContractState, user: ContractAddress, token: ContractAddress) -> u256 {
            self.balances.entry((user, token)).read()
        }

        fn deposit(ref self: ContractState, amount: u256, token: ContractAddress) {
            self.reentrancy_guard.start();
            let caller = get_caller_address();
            let contract_address = get_contract_address();
            
            // Transfer tokens from user to contract
            let token_contract = IERC20Dispatcher { contract_address: token };
            token_contract.transfer_from(caller, contract_address, amount);
            
            // Update user balance
            let current_balance = self.balances.entry((caller, token)).read();
            self.balances.entry((caller, token)).write(current_balance + amount);
            
            self.emit(Deposit {
                user: caller,
                amount,
                token,
            });
            
            self.reentrancy_guard.end();
        }

        fn withdraw(ref self: ContractState, amount: u256, token: ContractAddress) {
            self.reentrancy_guard.start();
            let caller = get_caller_address();
            
            // Check balance
            let current_balance = self.balances.entry((caller, token)).read();
            assert(current_balance >= amount, 'Insufficient balance');
            
            // Update balance
            self.balances.entry((caller, token)).write(current_balance - amount);
            
            // Transfer tokens to user
            let token_contract = IERC20Dispatcher { contract_address: token };
            token_contract.transfer(caller, amount);
            
            self.emit(Withdrawal {
                user: caller,
                amount,
                token,
            });
            
            self.reentrancy_guard.end();
        }
    }
}