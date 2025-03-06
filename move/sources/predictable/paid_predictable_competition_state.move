/// This module manages the state of paid predictable competitions. 
/// It includes definitions for the PaidPredictableCompetitionState struct, 
/// which holds information such as total registration reserves, registration fee info, 
/// claimed rewards, and the predictable competition state. It also provides functions to
/// create new instances, get and set various state properties, and manage rewards.
module brkt_addr::paid_predictable_competition_state {
    // Dependencies
    //use brkt_addr::predictable_competition_state::PredictableCompetitionState;
    use brkt_addr::predictable_competition_state::{PredictableCompetitionState, Self};
    use brkt_addr::registration_fee_info::{RegistrationFeeInfo, Self};
    use std::simple_map::{SimpleMap, Self};
    use aptos_framework::account;
    use aptos_std::fixed_point64::FixedPoint64;
    use aptos_std::type_info::{TypeInfo};

    // Definitions
    struct PaidPredictableCompetitionState has store {
        total_registration_reserves: u256,
        registration_fee_info: RegistrationFeeInfo,
        claimed_rewards: SimpleMap<address, bool>,
        predict_competition_state: PredictableCompetitionState,
        pool_addr: address,
        pool_signer_cap: account::SignerCapability,
        protocol_fee: u256,
        user_to_payment_multiplier: SimpleMap<address, FixedPoint64>,
        match_predictions_to_multipliers: SimpleMap<u256, SimpleMap<u8, FixedPoint64>>,
    }

    // Public functions

    /*
     * Creates a new instance of PaidPredictableCompetitionState.
     *
     * @param total_registration_reserves - The total registration reserves.
     * @param registration_fee_info - The registration fee information.
     * @param claimed_rewards - The claimed rewards.
     * @param predict_competition - The predictable competition state.
     * @param pool_addr - The pool address.
     * @param pool_signer_cap - The pool signer capability.
     * @param protocol_fee - The protocol fee.
     * @return PaidPredictableCompetitionState - The new instance of PaidPredictableCompetitionState.
     */
    public fun new(
        total_registration_reserves: u256,
        registration_fee_info: RegistrationFeeInfo,
        claimed_rewards: SimpleMap<address, bool>,
        predict_competition: PredictableCompetitionState,
        pool_addr: address,
        pool_signer_cap: account::SignerCapability,
        protocol_fee: u256,
        user_to_payment_multiplier: SimpleMap<address, FixedPoint64>,
        match_predictions_to_multipliers: SimpleMap<u256, SimpleMap<u8, FixedPoint64>>,
    ): PaidPredictableCompetitionState {
        PaidPredictableCompetitionState {
            total_registration_reserves: total_registration_reserves,
            registration_fee_info: registration_fee_info,
            claimed_rewards: claimed_rewards,
            predict_competition_state: predict_competition,
            pool_addr,
            pool_signer_cap,
            protocol_fee,
            user_to_payment_multiplier,
            match_predictions_to_multipliers,
        }
    }

    // Getters and Setters

    public fun get_predict_competition_state(state: &PaidPredictableCompetitionState): &PredictableCompetitionState {
        &state.predict_competition_state
    }

    public fun get_predict_competition_state_as_mut(state: &mut PaidPredictableCompetitionState): &mut PredictableCompetitionState {
        &mut state.predict_competition_state
    }

    public fun get_registration_fee(state: &PaidPredictableCompetitionState): u256 {
        registration_fee_info::get_fee(&state.registration_fee_info)
    }

    public fun get_registration_coin_type(state: &PaidPredictableCompetitionState): TypeInfo {
        registration_fee_info::get_coin_type(&state.registration_fee_info)
    }

    public fun get_registration_fee_info(state: &PaidPredictableCompetitionState): &RegistrationFeeInfo {
        &state.registration_fee_info
    }

    public fun get_total_registration_reserves(state: &PaidPredictableCompetitionState): u256 {
        state.total_registration_reserves
    }

    public fun set_total_registration_reserves(state: &mut PaidPredictableCompetitionState, total_registration_reserves: u256) {
        state.total_registration_reserves = total_registration_reserves;
    }

    public fun did_claim_rewards(state: &PaidPredictableCompetitionState, user: address): bool {
        *simple_map::borrow(&state.claimed_rewards, &user)
    }

    public fun set_claim_rewards(state: &mut PaidPredictableCompetitionState, user: address, value: bool) {
        simple_map::upsert(&mut state.claimed_rewards, user, value);
    }

    public fun get_pool_addr(state: &PaidPredictableCompetitionState): address {
        state.pool_addr
    }
    
    public fun get_pool_signer_cap(state: &PaidPredictableCompetitionState): &account::SignerCapability {
        &state.pool_signer_cap
    }

    public fun get_protocol_fee(state: &PaidPredictableCompetitionState): u256 {
        state.protocol_fee
    }

    public fun get_user_to_payment_multiplier(state: &PaidPredictableCompetitionState): &SimpleMap<address, FixedPoint64> {
        &state.user_to_payment_multiplier
    }

    public fun get_user_payment_multiplier(state: &PaidPredictableCompetitionState, user: address): FixedPoint64 {
        let multiplier_ref = simple_map::borrow(&state.user_to_payment_multiplier, &user);
        *multiplier_ref
    }

    public fun get_user_payment_multiplier_as_raw(state: &PaidPredictableCompetitionState, user: address): u128 {
        let multiplier_ref = simple_map::borrow(&state.user_to_payment_multiplier, &user);
        let multiplier_copy = *multiplier_ref;
        aptos_std::fixed_point64::get_raw_value(multiplier_copy)
    }

    public fun get_user_payment_multiplier_as_mut(state: &mut PaidPredictableCompetitionState, user: address): &mut FixedPoint64 {
        simple_map::borrow_mut(&mut state.user_to_payment_multiplier, &user)
    }

    public fun remove_user_payment_multiplier(state: &mut PaidPredictableCompetitionState, user: address) {
        if (simple_map::contains_key(&state.user_to_payment_multiplier, &user)) {
            simple_map::remove(&mut state.user_to_payment_multiplier, &user);
        }
    }

    public fun get_user_to_payment_multiplier_as_mut(state: &mut PaidPredictableCompetitionState): &mut SimpleMap<address, FixedPoint64> {
        &mut state.user_to_payment_multiplier
    }

    public fun add_to_user_payment_multiplier(state: &mut PaidPredictableCompetitionState, user: address, value_to_add: FixedPoint64) {
        if (simple_map::contains_key(&state.user_to_payment_multiplier, &user)) {
            let (_key, current_multiplier) = simple_map::remove(&mut state.user_to_payment_multiplier, &user);
            let new_multiplier = aptos_std::fixed_point64::add(current_multiplier, value_to_add);
            simple_map::add(&mut state.user_to_payment_multiplier, user, new_multiplier);
        } else {
            simple_map::add(&mut state.user_to_payment_multiplier, user, value_to_add);
        }
    }

    public fun set_user_to_payment_multiplier(state: &mut PaidPredictableCompetitionState, user: address, value: FixedPoint64) {
        simple_map::upsert(&mut state.user_to_payment_multiplier, user, value);
    }

    public fun get_match_predictions_to_multipliers(state: &PaidPredictableCompetitionState): &SimpleMap<u256, SimpleMap<u8, FixedPoint64>> {
        &state.match_predictions_to_multipliers
    }

    public fun get_match_predictions_to_multipliers_as_mut(state: &mut PaidPredictableCompetitionState): &mut SimpleMap<u256, SimpleMap<u8, FixedPoint64>> {
        &mut state.match_predictions_to_multipliers
    }

    public fun sub_match_predictions_to_multipliers_for_match_and_team(state: &mut PaidPredictableCompetitionState, match_id: u256, winning_team_id: u8, multiplier: FixedPoint64) {
        if (!simple_map::contains_key<u256, SimpleMap<u8, FixedPoint64>>(&state.match_predictions_to_multipliers, &match_id)) {
            let new_map = simple_map::new<u8, FixedPoint64>();
            simple_map::add<u256, SimpleMap<u8, FixedPoint64>>(&mut state.match_predictions_to_multipliers, match_id, new_map);
        };

        // Get the map for the given match_id
        let team_multiplier_map = simple_map::borrow_mut<u256, SimpleMap<u8, FixedPoint64>>(&mut state.match_predictions_to_multipliers, &match_id);

        // Check if the inner map contains the winning_team_id
        if (simple_map::contains_key(team_multiplier_map, &winning_team_id)) {
            // Retrieve the current multiplier
            let current_multiplier_ref = simple_map::borrow_mut(team_multiplier_map, &winning_team_id);
            // Update the current multiplier by adding the new multiplier
            *current_multiplier_ref = aptos_std::fixed_point64::sub(*current_multiplier_ref, multiplier);
        } else {
            // do nothing, this shouldn't be possible but we shouldn't initialize it if it happened anyways.
        }
    }

    public fun add_match_predictions_to_multipliers_for_match_and_team(state: &mut PaidPredictableCompetitionState, match_id: u256, winning_team_id: u8, multiplier: FixedPoint64) {
        if (!simple_map::contains_key<u256, SimpleMap<u8, FixedPoint64>>(&state.match_predictions_to_multipliers, &match_id)) {
            let new_map = simple_map::new<u8, FixedPoint64>();
            simple_map::add<u256, SimpleMap<u8, FixedPoint64>>(&mut state.match_predictions_to_multipliers, match_id, new_map);
        };

        // Get the map for the given match_id
        let team_multiplier_map = simple_map::borrow_mut<u256, SimpleMap<u8, FixedPoint64>>(&mut state.match_predictions_to_multipliers, &match_id);

        // Check if the inner map contains the winning_team_id
        if (simple_map::contains_key(team_multiplier_map, &winning_team_id)) {
            // Retrieve the current multiplier
            let current_multiplier_ref = simple_map::borrow_mut(team_multiplier_map, &winning_team_id);
            // Update the current multiplier by adding the new multiplier
            *current_multiplier_ref = aptos_std::fixed_point64::add(*current_multiplier_ref, multiplier);
        } else {
            // If the team_id does not exist, add a new entry with the multiplier
            let one = aptos_std::fixed_point64::create_from_raw_value((1 as u128));
            simple_map::add(team_multiplier_map, winning_team_id, aptos_std::fixed_point64::add(multiplier, one));
        }
    }

    public fun set_match_predictions_to_multipliers_for_match_and_team(state: &mut PaidPredictableCompetitionState, match_id: u256, winning_team_id: u8, multiplier: FixedPoint64) {
        if (!simple_map::contains_key<u256, SimpleMap<u8, FixedPoint64>>(&state.match_predictions_to_multipliers, &match_id)) {
            let new_map = simple_map::new<u8, FixedPoint64>();
            simple_map::add<u256, SimpleMap<u8, FixedPoint64>>(&mut state.match_predictions_to_multipliers, match_id, new_map);
        };

        // Get the map for the given match_id
        let team_multiplier_map = simple_map::borrow_mut<u256, SimpleMap<u8, FixedPoint64>>(&mut state.match_predictions_to_multipliers, &match_id);
        simple_map::upsert(team_multiplier_map, winning_team_id, multiplier);
    }

    
    public fun get_match_predictions_to_user(state: &mut PaidPredictableCompetitionState)
            : &SimpleMap<u256, SimpleMap<u8, vector<address>>> {
        let predictable_competition = get_predict_competition_state_as_mut(state);

        predictable_competition_state::get_match_predictions_to_user(predictable_competition)
    }

}
