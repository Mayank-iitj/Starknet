use starknet::ContractAddress;

#[starknet::interface]
trait IDeFiProtocol<TContractState> {
    // Lending functions
    fn deposit_collateral(
        ref self: TContractState,
        token: ContractAddress,
        amount: u256,
    );
    
    fn borrow(
        ref self: TContractState,
        token: ContractAddress,
        amount: u256,
    ) -> bool;
    
    fn repay_loan(
        ref self: TContractState,
        loan_id: u256,
        amount: u256,
    ) -> bool;
    
    fn liquidate_loan(
        ref self: TContractState,
        loan_id: u256,
    ) -> bool;
    
    // Yield aggregation functions
    fn stake_tokens(
        ref self: TContractState,
        token: ContractAddress,
        amount: u256,
        pool_id: u256,
    ) -> u256; // Returns staking position ID
    
    fn unstake_tokens(
        ref self: TContractState,
        position_id: u256,
        amount: u256,
    ) -> u256; // Returns withdrawn amount
    
    fn claim_rewards(
        ref self: TContractState,
        position_id: u256,
    ) -> u256; // Returns reward amount
    
    // Liquid staking functions
    fn stake_eth(
        ref self: TContractState,
        amount: u256,
    ) -> u256; // Returns stETH amount
    
    fn unstake_eth(
        ref self: TContractState,
        st_eth_amount: u256,
    ) -> u256; // Returns ETH amount
    
    // Risk assessment functions
    fn get_risk_score(
        self: @TContractState,
        user: ContractAddress,
        loan_amount: u256,
        collateral_amount: u256,
    ) -> u256;
    
    fn get_liquidation_threshold(
        self: @ContractState,
        token: ContractAddress,
    ) -> u256;
    
    // View functions
    fn get_user_collateral(
        self: @TContractState,
        user: ContractAddress,
        token: ContractAddress,
    ) -> u256;
    
    fn get_user_debt(
        self: @TContractState,
        user: ContractAddress,
        token: ContractAddress,
    ) -> u256;
    
    fn get_staking_rewards(
        self: @TContractState,
        position_id: u256,
    ) -> u256;
}

#[starknet::contract]
mod DeFiProtocol {
    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, Map};
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
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
        // User collateral balances per token
        collateral: Map<(ContractAddress, ContractAddress), u256>,
        // User debt balances per token
        debt: Map<(ContractAddress, ContractAddress), u256>,
        // Loan information
        loans: Map<u256, LoanInfo>,
        // Staking positions
        staking_positions: Map<u256, StakingPosition>,
        // Staking pools
        staking_pools: Map<u256, StakingPool>,
        // Token prices (simplified oracle)
        token_prices: Map<ContractAddress, u256>,
        // Liquidation thresholds per token
        liquidation_thresholds: Map<ContractAddress, u256>,
        // Interest rates per token
        interest_rates: Map<ContractAddress, u256>,
        // Liquid staking info
        total_staked_eth: u256,
        total_st_eth_supply: u256,
        // Counters
        next_loan_id: u256,
        next_position_id: u256,
        // AI risk model parameters
        risk_model_weights: Map<u256, u256>,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        reentrancy_guard: ReentrancyGuardComponent::Storage,
    }

    #[derive(Drop, Copy, Serde, starknet::Store)]
    struct LoanInfo {
        borrower: ContractAddress,
        collateral_token: ContractAddress,
        collateral_amount: u256,
        debt_token: ContractAddress,
        debt_amount: u256,
        interest_rate: u256,
        created_at: u64,
        is_active: bool,
    }

    #[derive(Drop, Copy, Serde, starknet::Store)]
    struct StakingPosition {
        owner: ContractAddress,
        pool_id: u256,
        token: ContractAddress,
        amount: u256,
        rewards_accumulated: u256,
        created_at: u64,
        is_active: bool,
    }

    #[derive(Drop, Copy, Serde, starknet::Store)]
    struct StakingPool {
        token: ContractAddress,
        total_staked: u256,
        reward_rate: u256, // Rewards per second per token
        last_update_time: u64,
        accumulated_reward_per_token: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CollateralDeposited: CollateralDeposited,
        LoanCreated: LoanCreated,
        LoanRepaid: LoanRepaid,
        LoanLiquidated: LoanLiquidated,
        TokensStaked: TokensStaked,
        TokensUnstaked: TokensUnstaked,
        RewardsClaimed: RewardsClaimed,
        EthStaked: EthStaked,
        EthUnstaked: EthUnstaked,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct CollateralDeposited {
        user: ContractAddress,
        token: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct LoanCreated {
        loan_id: u256,
        borrower: ContractAddress,
        collateral_token: ContractAddress,
        collateral_amount: u256,
        debt_token: ContractAddress,
        debt_amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct LoanRepaid {
        loan_id: u256,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct LoanLiquidated {
        loan_id: u256,
        liquidator: ContractAddress,
        collateral_seized: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct TokensStaked {
        position_id: u256,
        user: ContractAddress,
        pool_id: u256,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct TokensUnstaked {
        position_id: u256,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct RewardsClaimed {
        position_id: u256,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct EthStaked {
        user: ContractAddress,
        eth_amount: u256,
        st_eth_amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct EthUnstaked {
        user: ContractAddress,
        st_eth_amount: u256,
        eth_amount: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
        self.next_loan_id.write(1);
        self.next_position_id.write(1);
        
        // Initialize default liquidation thresholds (75% for most tokens)
        // This would be set per token in production
        
        // Initialize AI risk model weights (simplified)
        self.risk_model_weights.entry(0).write(30); // Collateral ratio weight
        self.risk_model_weights.entry(1).write(25); // Credit history weight  
        self.risk_model_weights.entry(2).write(20); // Market volatility weight
        self.risk_model_weights.entry(3).write(15); // Liquidity weight
        self.risk_model_weights.entry(4).write(10); // Time factor weight
    }

    #[abi(embed_v0)]
    impl DeFiProtocolImpl of super::IDeFiProtocol<ContractState> {
        fn deposit_collateral(
            ref self: ContractState,
            token: ContractAddress,
            amount: u256,
        ) {
            self.reentrancy_guard.start();
            let caller = get_caller_address();
            
            // Transfer tokens from user
            let token_contract = IERC20Dispatcher { contract_address: token };
            token_contract.transfer_from(caller, starknet::get_contract_address(), amount);
            
            // Update collateral balance
            let current_collateral = self.collateral.entry((caller, token)).read();
            self.collateral.entry((caller, token)).write(current_collateral + amount);
            
            self.emit(CollateralDeposited {
                user: caller,
                token,
                amount,
            });
            
            self.reentrancy_guard.end();
        }

        fn borrow(
            ref self: ContractState,
            token: ContractAddress,
            amount: u256,
        ) -> bool {
            self.reentrancy_guard.start();
            let caller = get_caller_address();
            
            // Calculate required collateral based on liquidation threshold
            let threshold = self.liquidation_thresholds.entry(token).read();
            let token_price = self.token_prices.entry(token).read();
            let required_collateral_value = (amount * token_price * 100) / threshold;
            
            // Check if user has enough collateral
            // Simplified - would check multiple collateral tokens in production
            let user_collateral = self.collateral.entry((caller, token)).read();
            let collateral_value = user_collateral * token_price;
            
            assert(collateral_value >= required_collateral_value, 'Insufficient collateral');
            
            // AI risk assessment
            let risk_score = self.get_risk_score(caller, amount, user_collateral);
            assert(risk_score <= 80, 'Risk score too high'); // Max 80% risk
            
            // Create loan
            let loan_id = self.next_loan_id.read();
            let interest_rate = self.interest_rates.entry(token).read();
            
            let loan = LoanInfo {
                borrower: caller,
                collateral_token: token,
                collateral_amount: user_collateral,
                debt_token: token,
                debt_amount: amount,
                interest_rate,
                created_at: get_block_timestamp(),
                is_active: true,
            };
            
            self.loans.entry(loan_id).write(loan);
            self.next_loan_id.write(loan_id + 1);
            
            // Update debt balance
            let current_debt = self.debt.entry((caller, token)).read();
            self.debt.entry((caller, token)).write(current_debt + amount);
            
            // Transfer tokens to borrower
            let token_contract = IERC20Dispatcher { contract_address: token };
            token_contract.transfer(caller, amount);
            
            self.emit(LoanCreated {
                loan_id,
                borrower: caller,
                collateral_token: token,
                collateral_amount: user_collateral,
                debt_token: token,
                debt_amount: amount,
            });
            
            self.reentrancy_guard.end();
            true
        }

        fn repay_loan(
            ref self: ContractState,
            loan_id: u256,
            amount: u256,
        ) -> bool {
            self.reentrancy_guard.start();
            let caller = get_caller_address();
            
            let mut loan = self.loans.entry(loan_id).read();
            assert(loan.borrower == caller, 'Not loan owner');
            assert(loan.is_active, 'Loan not active');
            assert(amount <= loan.debt_amount, 'Amount exceeds debt');
            
            // Transfer repayment from user
            let token_contract = IERC20Dispatcher { contract_address: loan.debt_token };
            token_contract.transfer_from(caller, starknet::get_contract_address(), amount);
            
            // Update loan debt
            loan.debt_amount -= amount;
            if loan.debt_amount == 0 {
                loan.is_active = false;
            }
            self.loans.entry(loan_id).write(loan);
            
            // Update user debt balance
            let current_debt = self.debt.entry((caller, loan.debt_token)).read();
            self.debt.entry((caller, loan.debt_token)).write(current_debt - amount);
            
            self.emit(LoanRepaid { loan_id, amount });
            
            self.reentrancy_guard.end();
            true
        }

        fn liquidate_loan(ref self: ContractState, loan_id: u256) -> bool {
            self.reentrancy_guard.start();
            let caller = get_caller_address();
            
            let mut loan = self.loans.entry(loan_id).read();
            assert(loan.is_active, 'Loan not active');
            
            // Check if loan is underwater (simplified liquidation logic)
            let token_price = self.token_prices.entry(loan.collateral_token).read();
            let collateral_value = loan.collateral_amount * token_price;
            let debt_value = loan.debt_amount * token_price;
            let threshold = self.liquidation_thresholds.entry(loan.collateral_token).read();
            
            assert(collateral_value * threshold / 100 < debt_value, 'Loan not liquidatable');
            
            // Liquidate - seize collateral, pay off debt
            loan.is_active = false;
            self.loans.entry(loan_id).write(loan);
            
            // Transfer collateral to liquidator (simplified)
            let token_contract = IERC20Dispatcher { contract_address: loan.collateral_token };
            token_contract.transfer(caller, loan.collateral_amount);
            
            self.emit(LoanLiquidated {
                loan_id,
                liquidator: caller,
                collateral_seized: loan.collateral_amount,
            });
            
            self.reentrancy_guard.end();
            true
        }

        fn stake_tokens(
            ref self: ContractState,
            token: ContractAddress,
            amount: u256,
            pool_id: u256,
        ) -> u256 {
            self.reentrancy_guard.start();
            let caller = get_caller_address();
            
            // Transfer tokens from user
            let token_contract = IERC20Dispatcher { contract_address: token };
            token_contract.transfer_from(caller, starknet::get_contract_address(), amount);
            
            // Update staking pool
            let mut pool = self.staking_pools.entry(pool_id).read();
            pool.total_staked += amount;
            pool.last_update_time = get_block_timestamp();
            self.staking_pools.entry(pool_id).write(pool);
            
            // Create staking position
            let position_id = self.next_position_id.read();
            let position = StakingPosition {
                owner: caller,
                pool_id,
                token,
                amount,
                rewards_accumulated: 0,
                created_at: get_block_timestamp(),
                is_active: true,
            };
            
            self.staking_positions.entry(position_id).write(position);
            self.next_position_id.write(position_id + 1);
            
            self.emit(TokensStaked {
                position_id,
                user: caller,
                pool_id,
                amount,
            });
            
            self.reentrancy_guard.end();
            position_id
        }

        fn unstake_tokens(
            ref self: ContractState,
            position_id: u256,
            amount: u256,
        ) -> u256 {
            self.reentrancy_guard.start();
            let caller = get_caller_address();
            
            let mut position = self.staking_positions.entry(position_id).read();
            assert(position.owner == caller, 'Not position owner');
            assert(position.is_active, 'Position not active');
            assert(amount <= position.amount, 'Amount exceeds staked');
            
            // Calculate and claim rewards first
            let rewards = self._calculate_rewards(position_id);
            position.rewards_accumulated += rewards;
            
            // Update position
            position.amount -= amount;
            if position.amount == 0 {
                position.is_active = false;
            }
            self.staking_positions.entry(position_id).write(position);
            
            // Update pool
            let mut pool = self.staking_pools.entry(position.pool_id).read();
            pool.total_staked -= amount;
            self.staking_pools.entry(position.pool_id).write(pool);
            
            // Transfer tokens back to user
            let token_contract = IERC20Dispatcher { contract_address: position.token };
            token_contract.transfer(caller, amount);
            
            self.emit(TokensUnstaked { position_id, amount });
            
            self.reentrancy_guard.end();
            amount
        }

        fn claim_rewards(ref self: ContractState, position_id: u256) -> u256 {
            let caller = get_caller_address();
            
            let mut position = self.staking_positions.entry(position_id).read();
            assert(position.owner == caller, 'Not position owner');
            assert(position.is_active, 'Position not active');
            
            let rewards = self._calculate_rewards(position_id);
            let total_rewards = position.rewards_accumulated + rewards;
            
            // Reset accumulated rewards
            position.rewards_accumulated = 0;
            self.staking_positions.entry(position_id).write(position);
            
            // Transfer rewards (would be in reward token, simplified here)
            let token_contract = IERC20Dispatcher { contract_address: position.token };
            token_contract.transfer(caller, total_rewards);
            
            self.emit(RewardsClaimed {
                position_id,
                amount: total_rewards,
            });
            
            total_rewards
        }

        fn stake_eth(ref self: ContractState, amount: u256) -> u256 {
            self.reentrancy_guard.start();
            let caller = get_caller_address();
            
            // Calculate stETH to mint based on exchange rate
            let total_eth = self.total_staked_eth.read();
            let total_st_eth = self.total_st_eth_supply.read();
            
            let st_eth_amount = if total_st_eth == 0 {
                amount // 1:1 ratio initially
            } else {
                (amount * total_st_eth) / total_eth
            };
            
            // Update totals
            self.total_staked_eth.write(total_eth + amount);
            self.total_st_eth_supply.write(total_st_eth + st_eth_amount);
            
            // Mint stETH to user (simplified - would use actual stETH contract)
            
            self.emit(EthStaked {
                user: caller,
                eth_amount: amount,
                st_eth_amount,
            });
            
            self.reentrancy_guard.end();
            st_eth_amount
        }

        fn unstake_eth(ref self: ContractState, st_eth_amount: u256) -> u256 {
            self.reentrancy_guard.start();
            let caller = get_caller_address();
            
            // Calculate ETH to return based on exchange rate
            let total_eth = self.total_staked_eth.read();
            let total_st_eth = self.total_st_eth_supply.read();
            
            let eth_amount = (st_eth_amount * total_eth) / total_st_eth;
            
            // Update totals
            self.total_staked_eth.write(total_eth - eth_amount);
            self.total_st_eth_supply.write(total_st_eth - st_eth_amount);
            
            // Burn stETH and return ETH (simplified)
            
            self.emit(EthUnstaked {
                user: caller,
                st_eth_amount,
                eth_amount,
            });
            
            self.reentrancy_guard.end();
            eth_amount
        }

        fn get_risk_score(
            self: @ContractState,
            user: ContractAddress,
            loan_amount: u256,
            collateral_amount: u256,
        ) -> u256 {
            // AI-driven risk assessment (simplified model)
            let collateral_ratio = if loan_amount > 0 { (collateral_amount * 100) / loan_amount } else { 100 };
            
            // Risk factors (0-100 scale, lower is better)
            let collateral_risk = if collateral_ratio >= 150 { 10 } else if collateral_ratio >= 120 { 30 } else { 70 };
            
            let credit_risk = 40; // Would be based on user's history
            let market_risk = 25; // Would be based on market volatility
            let liquidity_risk = 20; // Would be based on token liquidity
            let time_risk = 15; // Would be based on loan duration
            
            // Weighted risk score
            let weights = (
                self.risk_model_weights.entry(0).read(),
                self.risk_model_weights.entry(1).read(),
                self.risk_model_weights.entry(2).read(),
                self.risk_model_weights.entry(3).read(),
                self.risk_model_weights.entry(4).read(),
            );
            
            let weighted_score = (collateral_risk * weights.0 +
                                credit_risk * weights.1 +
                                market_risk * weights.2 +
                                liquidity_risk * weights.3 +
                                time_risk * weights.4) / 100;
            
            weighted_score
        }

        fn get_liquidation_threshold(self: @ContractState, token: ContractAddress) -> u256 {
            let threshold = self.liquidation_thresholds.entry(token).read();
            if threshold == 0 { 75 } else { threshold } // Default 75%
        }

        fn get_user_collateral(
            self: @ContractState,
            user: ContractAddress,
            token: ContractAddress,
        ) -> u256 {
            self.collateral.entry((user, token)).read()
        }

        fn get_user_debt(
            self: @ContractState,
            user: ContractAddress,
            token: ContractAddress,
        ) -> u256 {
            self.debt.entry((user, token)).read()
        }

        fn get_staking_rewards(self: @ContractState, position_id: u256) -> u256 {
            let position = self.staking_positions.entry(position_id).read();
            position.rewards_accumulated + self._calculate_rewards(position_id)
        }
    }

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn _calculate_rewards(self: @ContractState, position_id: u256) -> u256 {
            let position = self.staking_positions.entry(position_id).read();
            let pool = self.staking_pools.entry(position.pool_id).read();
            
            let current_time = get_block_timestamp();
            let time_elapsed = current_time - position.created_at;
            
            // Simple reward calculation: amount * rate * time
            (position.amount * pool.reward_rate * time_elapsed.into()) / 86400 // Daily rewards
        }
    }
}