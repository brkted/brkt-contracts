/// This module likely handles the routing logic for different types of competitions, 
/// directing operations to the appropriate competition modules.
module brkt_addr::competition_route {
    use brkt_addr::paid_predictable_competition;
    use brkt_addr::predictable_competition;
    use brkt_addr::competition_factory;
    use brkt_addr::competition;
    use std::string::{String, utf8};
    use std::signer;
    use std::option;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::{Self, AptosCoin};
    use aptos_framework::timestamp;
    
    // Errors
    const EUNSUPPORTED_COMPETITION_TYPE: u64 = 400;
    const EWRONG_BALANCE: u64 = 401;
    const EWRONG_BRACKET_SCORE: u64 = 402;
    const EWRONG_PENDING_REWARD: u64 = 403;

    struct CompetitionRoute has key, drop, store {
        competition_factory_address: address,
    }

    // Entry functions

    /*
     * Creates a new CompetitionRoute instance.
     *
     * @param brkt_signer - The signer of the transaction.
     * @param competition_factory_address - The address of the competition factory.
     */
    entry fun new(brkt_signer: &signer, competition_factory_address: address) {
        move_to(brkt_signer, CompetitionRoute { competition_factory_address });
    }

    /*
     * Creates a bracket prediction for a competition route.
     *
     * @param sender - The signer creating the bracket prediction.
     * @param route_owner_address - The address of the route owner.
     * @param competition_id - The ID of the competition.
     * @param match_predictions - The vector of match predictions.
     */
    public entry fun create_bracket_prediction<CoinType>(
        sender: &signer,
        route_owner_address:address, 
        competition_id : String, 
        match_predictions: vector<u8>
    ) acquires CompetitionRoute {
        let competition_factory_address = borrow_global<CompetitionRoute>(route_owner_address)
            .competition_factory_address;

        let competition_type = competition_factory::get_competition_implType(competition_factory_address, competition_id);
        let competition_owner_address = competition_factory::get_competition_address(competition_factory_address, competition_id);

        if(competition_type == competition_factory::get_predictable()) {
            predictable_competition::create_bracket_prediction(
                sender, 
                competition_owner_address, 
                competition_id, 
                signer::address_of(sender),
                match_predictions
            );
        } else if(competition_type == competition_factory::get_paid_predictable()) {
            let fee = paid_predictable_competition::get_fee(competition_owner_address, &competition_id);
            let has_user_registered = paid_predictable_competition::has_user_registered(
                competition_owner_address, 
                competition_id, 
                signer::address_of(sender)
            );
            if (fee > 0 && !has_user_registered) {
                let pool_addr = paid_predictable_competition::get_pool_addr(competition_owner_address, &competition_id);
                coin::transfer<CoinType>(sender, pool_addr, (fee as u64));
            };

            paid_predictable_competition::create_bracket_prediction<CoinType>(
                sender, 
                competition_owner_address, 
                competition_id, 
                signer::address_of(sender),
                match_predictions
            );
        } else {
            abort EUNSUPPORTED_COMPETITION_TYPE
        };
    }

    // View functions
    
    /*
     * Retrieves the team names for a given competition route.
     *
     * @param route_owner_address - The address of the route owner.
     * @param competition_id - The ID of the competition.
     * @return A vector of strings containing the team names.
     */
    #[view]
    public fun get_team_names(route_owner_address:address, competition_id : String) : vector<String> acquires CompetitionRoute {
        let competition_factory_address = borrow_global<CompetitionRoute>(route_owner_address)
            .competition_factory_address;

        let competition_type = competition_factory::get_competition_implType(competition_factory_address, competition_id);
        let competition_owner_address = competition_factory::get_competition_address(competition_factory_address, competition_id);

        if(competition_type == competition_factory::get_base()) {
            return competition::get_team_names(competition_owner_address, competition_id)
        } else if(competition_type == competition_factory::get_predictable()) {
            return predictable_competition::get_team_names(competition_owner_address, competition_id)
        } else if(competition_type == competition_factory::get_paid_predictable()) {
            return paid_predictable_competition::get_team_names(competition_owner_address, competition_id)
        };

        vector[]
    }

    // Test the paid predictable competition
    #[test(framework = @0x1)]
    fun claim_reward_in_paid_predictable_competition(framework: &signer) acquires CompetitionRoute {
        // Set up test environment
        timestamp::set_time_has_started_for_testing(framework);
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(framework);
        
        /***** SETUP ACCOUNTS *****/

        // Create test accounts
        let (alice, bob, eve) = create_test_accounts();
        let alice_addr = signer::address_of(&alice);
        let bob_addr = signer::address_of(&bob);
        let eve_addr = signer::address_of(&eve);
        
        // Initial balance setup for Alice
        let initial_amount = 1000000; // 1 APT = 100000000 octas
        setup_apt_balance(framework, &alice, initial_amount);
        setup_apt_balance(framework, &bob, initial_amount);
        setup_apt_balance(framework, &eve, initial_amount);

        // Check if the balance is correct
        assert!(coin::balance<AptosCoin>(alice_addr) == initial_amount, EWRONG_BALANCE);
        assert!(coin::balance<AptosCoin>(bob_addr) == initial_amount, EWRONG_BALANCE);
        assert!(coin::balance<AptosCoin>(eve_addr) == initial_amount, EWRONG_BALANCE);

        /***** CREATE PAID COMPETITION *****/

        // Alice creates a competition factory and a competition route
        // The competition factory is used to create competitions
        competition_factory::new(&alice);
        // The competition route is used to create bracket predictions for competitions
        new(&alice, alice_addr);

        // Paid predictable competition setup
        let _id = utf8(b"p01");
        let _name = utf8(b"Color Competition");
        let _nums = 2;
        let _start = 1800000000;
        let _expire = 2000000000;
        let _names = vector[utf8(b"Red"), utf8(b"Blue")];
        let _banner = option::some(utf8(b"http://www.example.com"));
        let _total_points_per_round = 32;
        let _fee = 500000; // 0.5 APT = 50000000 octas
        let _expected_protocol_rewards = _fee * 4 - ((_fee * 4) * (1000000 - 30000) / 1000000);

        competition_factory::set_protocol_fee(&alice, 30000); // 3% = 30000

        // Alice initializes a paid predictable competition with id "p01"
        // The competition is named "Color Competition"
        // There are only 2 teams: Red and Blue, so the competition has only 1 round with 1 match
        // The fee to become a participant is 0.5 APT
        competition_factory::create_paid_predictable_competition<AptosCoin>(
            &alice, 
            _id, 
            _name, 
            _nums, 
            _start, 
            _expire, 
            _names, 
            _banner, 
            _total_points_per_round, 
            _fee
        );

        // Get the competition pool address, where the fees are stored
        let competition_pool_addr = paid_predictable_competition::get_pool_addr(alice_addr, &_id);
        
        /***** CREATE BRACKET PREDICTIONS *****/

        // Get balance of the competition pool and Bob before Bob predicts
        let pool_balace_before_bob_bracket = coin::balance<AptosCoin>(competition_pool_addr);
        let bob_balace_before_predict = coin::balance<AptosCoin>(bob_addr);
        
        // Bob creates a bracket prediction for the competition with id "p01"
        // Bob predicts that the first team will win the match 
        let bob_prediction = vector[0];
        create_bracket_prediction<AptosCoin>(&bob, alice_addr, _id, bob_prediction);

        // Increase payment multiplier for Bob
        coin::transfer<AptosCoin>(&bob, competition_pool_addr, (_fee as u64));
        paid_predictable_competition::increase_prediction_payment_multiplier<AptosCoin>(&bob, alice_addr, _id, bob_addr);

        // Get balance of the competition pool and Bob after Bob predicts
        let bob_balace_after_predict = coin::balance<AptosCoin>(bob_addr);
        let pool_balace_after_bob_bracket = coin::balance<AptosCoin>(competition_pool_addr);
        
        // Check if Bob's balance has decreased by the fee amount after predicting
        assert!(bob_balace_before_predict > bob_balace_after_predict, EWRONG_BALANCE);
        assert!(bob_balace_before_predict - bob_balace_after_predict == (_fee*2 as u64), EWRONG_BALANCE);

        // Check if Alice's balance has increased by the fee amount after Bob's prediction
        assert!(pool_balace_before_bob_bracket < pool_balace_after_bob_bracket, EWRONG_BALANCE);
        assert!(pool_balace_after_bob_bracket - pool_balace_before_bob_bracket == (_fee*2 as u64), EWRONG_BALANCE);

        // Get balance of the competition pool and Eve before Eve predicts
        let pool_balace_before_eve_bracket = coin::balance<AptosCoin>(competition_pool_addr);
        let eve_balace_before = coin::balance<AptosCoin>(eve_addr);
        
        // Eve creates a bracket prediction for the competition with id "p01"
        // Eve predicts that the second team will win the match
        let eve_prediction = vector[1];
        create_bracket_prediction<AptosCoin>(&eve, alice_addr, _id, eve_prediction);

        // Increase payment multiplier for Eve
        coin::transfer<AptosCoin>(&eve, competition_pool_addr, (_fee as u64));
        paid_predictable_competition::increase_prediction_payment_multiplier<AptosCoin>(&eve, alice_addr, _id, eve_addr);

        // Get balance of the competition pool and Eve after Eve predicts
        let eve_balace_after = coin::balance<AptosCoin>(eve_addr);
        let pool_balace_after_eve_bracket = coin::balance<AptosCoin>(competition_pool_addr);

        // Check if Eve's balance has decreased by the fee amount after predicting
        assert!(eve_balace_before > eve_balace_after, EWRONG_BALANCE);
        assert!(eve_balace_before - eve_balace_after == (_fee*2 as u64), EWRONG_BALANCE);

        // Check if pool balance has increased by the fee amount after Eve's prediction
        assert!(pool_balace_before_eve_bracket < pool_balace_after_eve_bracket, EWRONG_BALANCE);
        assert!(pool_balace_after_eve_bracket - pool_balace_before_eve_bracket == (_fee*2 as u64), EWRONG_BALANCE);

        /***** START THE COMPETITION *****/

        // Alice starts the competition with id "p01"
        paid_predictable_competition::start(&alice, _id);

        /***** ADVANCE THE ROUND WITH RESULTS *****/

        // Alice advances the round with the results of the match
        // The first team wins the match
        let result = vector[0];
        paid_predictable_competition::advance_round_with_results(&alice, _id, result);

        /***** CALCULATE BRACKET SCORES *****/

        // Get the bracket score of Bob
        let bob_score = paid_predictable_competition::get_user_bracket_score(alice_addr, _id, bob_addr);
        // Check if Bob's bracket score is equal to the total points per round 
        // Because Bob is the only participant, who has predicted the correct result
        // multiply the total points by 2 because both participants doubled their fee which in turn doubles total points.
        assert!((bob_score as u16) == _total_points_per_round * 2, EWRONG_BRACKET_SCORE);
        
        // Get the bracket score of Eve
        let eve_score = paid_predictable_competition::get_user_bracket_score(alice_addr, _id, eve_addr);
        // Check if Eve's bracket score is 0
        // Because Eve has predicted the wrong result
        assert!(eve_score == 0, EWRONG_BRACKET_SCORE);

        /***** CALCULATE PENDING REWARDS *****/

        // Calculate pending rewards for Bob
        let bob_pending_reward = paid_predictable_competition::calculate_pending_rewards(alice_addr, bob_addr, _id);
        // Check if Bob's pending reward is equal to 2 times the fee amount
        // Because there are only 2 participants, Bob and Eve, 
        //          and Bob is the only one who has predicted the correct result
        assert!(bob_pending_reward == _fee*4 - _expected_protocol_rewards, EWRONG_PENDING_REWARD);

        // Calculate pending rewards for Eve
        let eve_pending_reward = paid_predictable_competition::calculate_pending_rewards(alice_addr, eve_addr, _id);
        // Check if Eve's pending reward is 0
        // Because Eve has predicted the wrong result
        assert!(eve_pending_reward == 0, EWRONG_PENDING_REWARD);

        /***** CLAIM REWARDS *****/

        // Get balance of the competition pool and Bob before Bob claims the reward
        let pool_balace_before_bob_claim_reward = coin::balance<AptosCoin>(competition_pool_addr);
        let bob_balace_before = coin::balance<AptosCoin>(bob_addr);
        let alice_balance_before = coin::balance<AptosCoin>(alice_addr);
        
        // Bob claims the rewards
        paid_predictable_competition::claim_rewards<AptosCoin>(&bob, alice_addr, _id);
        
        // Get balance of the competition pool and Bob after Bob claims the reward
        let pool_balace_after_bob_claim_reward = coin::balance<AptosCoin>(competition_pool_addr);
        let bob_balace_after = coin::balance<AptosCoin>(bob_addr);

        // Check if Bob's balance has increased by the fee amount after claiming the reward
        assert!(bob_balace_before < bob_balace_after, EWRONG_BALANCE);
        assert!(bob_balace_after - bob_balace_before == ((_fee*4 - _expected_protocol_rewards) as u64), EWRONG_BALANCE);

        // Check if pool balance has decreased by the fee amount after Bob's claim reward
        assert!(pool_balace_before_bob_claim_reward > pool_balace_after_bob_claim_reward, EWRONG_BALANCE);
        assert!(pool_balace_before_bob_claim_reward - pool_balace_after_bob_claim_reward == ((_fee*4 - _expected_protocol_rewards) as u64), EWRONG_BALANCE);

        // Check if Alice can claim the correct amount of protocol fees
        paid_predictable_competition::claim_protocol_fees<AptosCoin>(&alice, _id);
        let alice_balance_after = coin::balance<AptosCoin>(alice_addr);

        assert!(alice_balance_after - alice_balance_before == (_expected_protocol_rewards as u64), EWRONG_BALANCE);

        // Detroy the burn and mint cap
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);
    }
    
    // Create test accounts
    #[test_only]
    fun create_test_accounts(): (signer, signer, signer) {
        // Create test accounts
        let alice = account::create_account_for_test(@0xA11CE);
        let bob = account::create_account_for_test(@0xB0B);
        let eve = account::create_account_for_test(@0xEFE);
        
        // Register both accounts for APT
        coin::register<AptosCoin>(&alice);
        coin::register<AptosCoin>(&bob);
        coin::register<AptosCoin>(&eve);
        
        (alice, bob, eve)
    }
    
    // Setup APT balance for an account
    #[test_only]
    fun setup_apt_balance(framework: &signer, account: &signer, amount: u64) {
        coin::register<AptosCoin>(account);
        // Mint APT to the account
        aptos_coin::mint(framework, signer::address_of(account), amount);
    }
}
