/// This module manages competitions where users can make predictions. 
/// It includes logic for handling user predictions, calculating scores, 
/// and determining winners based on the predictions.
module brkt_addr::predictable_competition {
    // Dependencies
    use brkt_addr::predictable_competition_state::{Self, PredictableCompetitionState};
    use brkt_addr::match_outcome::{MatchOutcome, Self};
    use brkt_addr::competition_state::Self;
    use brkt_addr::competition::Self;
    use aptos_framework::event;
    use aptos_std::fixed_point64::FixedPoint64;
    use std::simple_map::{Self, SimpleMap};
    use std::vector;
    use std::signer;
    use std::string::{String, utf8};
    use std::option::{Option, Self};

    // Errors
    const EINVALID_COMPETITION_PREDICTION_LENGTH: u64 = 201;
    const EINVALID_SENDER: u64 = 202;

    // Definitions
    friend brkt_addr::paid_predictable_competition;
    friend brkt_addr::paid_predictable_competition_state;
    friend brkt_addr::competition_factory;

    struct PredictableCompetitions has key {
        predictable_competitions: SimpleMap<String, PredictableCompetitionState> 
    }

    #[event]
    struct BracketPredictionSaved has store, drop, copy {
        sender: address,
        user: address,
    }

    // Friend functions

    public(friend) fun f_get_user_bracket_score(
        predictable_competition: &PredictableCompetitionState,
        user: address,
        use_multiplier: bool,
        user_multiplier: FixedPoint64,
    ): u256 {
        let num_teams: u256 = (predictable_competition_state::get_num_teams(predictable_competition) as u256);
        let total_points_per_round = (predictable_competition_state::get_total_points_per_round(predictable_competition) as u256);
        let competition_state = predictable_competition_state::get_competition(predictable_competition);

        let num_matches = num_teams / 2;
        let num_matches_prev = 0;

        let ending_match;

        if(predictable_competition_state::get_has_finished(predictable_competition)) {
            ending_match = num_teams - 1;
        } else {
            let cur_round_matches_num = competition::get_cur_round_matches_num(competition_state);
            ending_match = num_teams - cur_round_matches_num;
        };

        let points_per_match_cur = total_points_per_round / num_matches;
        let i : u256 = 0;
        let user_points : u256 = 0;

        while (i < ending_match) {
            let current_match_outcome = competition_state::get_a_bracket_progression(competition_state, (i as u64));
            let winning_team_id = match_outcome::get_winning_team_id(current_match_outcome);
            let predictors = &predictable_competition_state::get_predictors(predictable_competition, &i, &winning_team_id);
            if (match_outcome::get_is_completed(current_match_outcome) && 
                vector::contains(predictors, &user)
            ) {
                if(use_multiplier) {
                    let one = aptos_std::fixed_point64::create_from_raw_value((1 as u128));
                    let points_with_multiplier = aptos_std::math_fixed64::mul_div(user_multiplier, aptos_std::fixed_point64::create_from_raw_value((points_per_match_cur as u128)), one);
                    user_points = user_points + (aptos_std::fixed_point64::get_raw_value(points_with_multiplier) as u256);
                } else {
                    user_points = user_points + points_per_match_cur;
                };
            };

            if (i < ending_match - 1 && i + 1 == num_matches + num_matches_prev) {
                num_matches_prev = num_matches_prev + num_matches;
                num_matches = num_matches / 2;
                if (num_matches > 0) {
                    points_per_match_cur = total_points_per_round / num_matches;
                } else {
                    points_per_match_cur = 0;
                }
            };
            
            i = i + 1;
        };

        user_points
    }

    public(friend) fun f_get_total_score(
        predictable_competition: &PredictableCompetitionState,
        use_multiplier: bool,
        match_multipliers: SimpleMap<u256, SimpleMap<u8, FixedPoint64>>,
    ): u256 {
        let num_teams: u256 = (predictable_competition_state::get_num_teams(predictable_competition) as u256);
        let total_points_per_round = (predictable_competition_state::get_total_points_per_round(predictable_competition) as u256);
        let competition_state = predictable_competition_state::get_competition(predictable_competition);

        let num_matches = num_teams / 2;
        let num_matches_prev = 0;

        let ending_match;

        if(predictable_competition_state::get_has_finished(predictable_competition)) {
            ending_match = num_teams - 1;
        } else {
            let cur_round_matches_num = competition::get_cur_round_matches_num(competition_state);
            ending_match = num_teams - cur_round_matches_num;
        };

        let points_per_match_cur = total_points_per_round / num_matches;
        let i : u256 = 0;
        let total_scores : u256 = 0;
        while (i < ending_match) {
            let current_match_outcome = competition_state::get_a_bracket_progression(competition_state, (i as u64));
            if (match_outcome::get_is_completed(current_match_outcome)) {
                let winning_team_id = match_outcome::get_winning_team_id(current_match_outcome);
                let predictors = &predictable_competition_state::get_predictors(predictable_competition, &i, &winning_team_id);
                let num_winner = (vector::length(predictors) as u256);
                // Calculate total scores with multiplier
                if(use_multiplier) {
                    let one = aptos_std::fixed_point64::create_from_raw_value((1 as u128));
                    let base_points = aptos_std::fixed_point64::create_from_raw_value((points_per_match_cur * num_winner as u128));
                    let match_multiplier = simple_map::borrow<u256, SimpleMap<u8, FixedPoint64>>(&match_multipliers, &i);
                    let match_winner_multiplier = simple_map::borrow<u8, FixedPoint64>(match_multiplier, &winning_team_id);
                    let match_winner_multiplier_less_one = one;
                    // If there was not predictions for an outcome, the multiplier is 0 and needs to be at least 1
                    if(aptos_std::fixed_point64::get_raw_value(*match_winner_multiplier) > 0) {
                        match_winner_multiplier_less_one = aptos_std::fixed_point64::sub(*match_winner_multiplier, one);
                    };
                    let points_with_multiplier = aptos_std::math_fixed64::mul_div(match_winner_multiplier_less_one, aptos_std::fixed_point64::create_from_raw_value((points_per_match_cur as u128)), one);
                    let total_points_with_multiplier = aptos_std::fixed_point64::add(base_points, points_with_multiplier);
                    total_scores = total_scores + (aptos_std::fixed_point64::get_raw_value(total_points_with_multiplier) as u256);
                } else {
                    total_scores = total_scores + points_per_match_cur * num_winner;
                };
            };

            if (i < ending_match - 1 && i + 1 == num_matches + num_matches_prev) {
                num_matches_prev = num_matches_prev + num_matches;
                num_matches = num_matches / 2;
                points_per_match_cur = total_points_per_round / num_matches;
            };
            
            i = i + 1;
        };

        total_scores
    }



    /*
     * Initializes a predictable competition and stores it under the competition_owner address. 
     * This function can only call from competition_factory.
     * 
     * @param competition_id - a unique id for the competition.
     * @param competition_owner - address of sender who is the owner of competition.
     * @param competition_name - name of the competition.
     * @param num_teams - the number of teams participating in the competition.
     * @param starting_epoch - the epoch at which the competition begins.
     * @param expiration_epoch - the epoch after which the competition cannot be started 
     *      or its state can no longer be changed.
     * @param team_names - the list of names of the teams participating in the competition. 
     *      team_names size must equal to num_teams.
     * @param banner_URI - URI of banner image.
     * @param total_points_per_round - the total number of points 
     *      that participants can earn for making predictions in each round of the competition
     */
    public entry fun initialize(
        competition_owner: &signer,
        competition_id: String,
        competition_name: String,
        num_teams: u16,
        starting_epoch: u64,
        expiration_epoch: u64,
        team_names: vector<String>,
        banner_URI: Option<String>,
        total_points_per_round: u16,
    ) acquires PredictableCompetitions {
        let banner = *option::borrow_with_default(&banner_URI, &utf8(b""));
        
        let new_predictable_competition_state = initialize_predictable_competition_state(
            competition_name,
            num_teams,
            starting_epoch,
            expiration_epoch,
            team_names,
            banner,
            total_points_per_round,
        );

        /* 
         * Add new_predictable_competition_state to PredictableCompetitions resources.
         * If PredictableCompetitions resources is not exist, init one and store under 
         * competition_owner address.
         */
        if (exists<PredictableCompetitions>(signer::address_of(competition_owner))) {
            let predictable_competitions = 
                borrow_global_mut<PredictableCompetitions>(signer::address_of(competition_owner));

            simple_map::add<String, PredictableCompetitionState>(
                &mut predictable_competitions.predictable_competitions, 
                competition_id, 
                new_predictable_competition_state
            );
        } else {
            let new_predictable_competitions = simple_map::new<String, PredictableCompetitionState>();
            simple_map::add<String, PredictableCompetitionState>(
                &mut new_predictable_competitions, 
                competition_id, 
                new_predictable_competition_state
            );
            let predictable_competitions = PredictableCompetitions {
                predictable_competitions : new_predictable_competitions
            };
            move_to(competition_owner, predictable_competitions);
        };
    }

    /*
     * Initialize and return the state for a predictable competition. 
     * This function is used for creating new predictable competitions 
     * or paid predictable competitions.
     * 
     * @param competition_name - name of the competition.
     * @param num_teams - the number of teams participating in the competition.
     * @param starting_epoch - the epoch at which the competition begins.
     * @param expiration_epoch - the epoch after which the competition cannot be started 
     *      or its state can no longer be changed.
     * @param team_names - the list of names of the teams participating in the competition. 
     *      team_names size must equal to num_teams.
     * @param banner_URI - URI of banner image.
     * @param total_points_per_round - the total number of points 
     *      that participants can earn for making predictions in each round of the competition
     * 
     * @return PredictableCompetitionState.
     */
    public(friend) fun initialize_predictable_competition_state(
        competition_name: String,
        num_teams: u16,
        starting_epoch: u64,
        expiration_epoch: u64,
        team_names: vector<String>,
        banner_URI: String,
        total_points_per_round: u16,
    ) : PredictableCompetitionState {
        let new_competition_state = competition::initialize_competition_state(
            competition_name,
            num_teams,
            starting_epoch,
            expiration_epoch,
            team_names,
            banner_URI,
        );

        let total_rounds = competition_state::get_total_rounds(&new_competition_state);

        predictable_competition_state::new(
            new_competition_state,
            total_rounds * total_points_per_round,
            total_points_per_round,
            simple_map::new<u256, SimpleMap<u8, vector<address>>>(),
            simple_map::new<address, vector<u8>>(),
            vector::empty<address>(),
        )
    }

    public(friend) fun f_get_user_score_percent (
        predictable_competition: &PredictableCompetitionState, 
        user: address,
        use_multiplier: bool,
        user_multiplier: FixedPoint64,
        match_multipliers: SimpleMap<u256, SimpleMap<u8, FixedPoint64>>,
    ) : u256 { 
        let num_teams: u256 = (predictable_competition_state::get_num_teams(predictable_competition) as u256);
        let total_points_per_round = (predictable_competition_state::get_total_points_per_round(predictable_competition) as u256);
        let competition_state = predictable_competition_state::get_competition(predictable_competition);

        let num_matches = num_teams / 2;
        let num_matches_prev = 0;

        let ending_match;

        if(predictable_competition_state::get_has_finished(predictable_competition)) {
            ending_match = num_teams - 1;
        } else {
            let cur_round_matches_num = competition::get_cur_round_matches_num(competition_state);
            ending_match = num_teams - cur_round_matches_num;
        };

        let points_per_match_cur = total_points_per_round / num_matches;
        let i : u256 = 0;
        let total_points : u256 = 0;
        let user_points : u256 = 0;

        while (i < ending_match) {
            let current_match_outcome = competition_state::get_a_bracket_progression(competition_state, (i as u64));
            let winning_team_id = match_outcome::get_winning_team_id(current_match_outcome);
            let predictors = &predictable_competition_state::get_predictors(predictable_competition, &i, &winning_team_id);
            if (match_outcome::get_is_completed(current_match_outcome) && 
                vector::contains(predictors, &user)
            ) {
                if(use_multiplier) {
                    let one = aptos_std::fixed_point64::create_from_raw_value((1 as u128));
                    let points_with_multiplier = aptos_std::math_fixed64::mul_div(user_multiplier, aptos_std::fixed_point64::create_from_raw_value((points_per_match_cur as u128)), one);
                    user_points = user_points + (aptos_std::fixed_point64::get_raw_value(points_with_multiplier) as u256);
                } else {
                    user_points = user_points + points_per_match_cur;
                };
            };

            let num_winner = (vector::length(predictors) as u256);
            if(use_multiplier) {
                let one = aptos_std::fixed_point64::create_from_raw_value((1 as u128));
                let base_points = aptos_std::fixed_point64::create_from_raw_value((points_per_match_cur * num_winner as u128));
                let match_multiplier = simple_map::borrow<u256, SimpleMap<u8, FixedPoint64>>(&match_multipliers, &i);
                let match_winner_multiplier = simple_map::borrow<u8, FixedPoint64>(match_multiplier, &winning_team_id);
                let match_winner_multiplier_less_one = aptos_std::fixed_point64::create_from_raw_value((0 as u128));
                // If there was not predictions for an outcome, the multiplier is 0 and doesn't need one to be subtracted
                if(aptos_std::fixed_point64::get_raw_value(*match_winner_multiplier) > 0) {
                    match_winner_multiplier_less_one = aptos_std::fixed_point64::sub(*match_winner_multiplier, one);
                };
                let points_with_multiplier = aptos_std::math_fixed64::mul_div(match_winner_multiplier_less_one, aptos_std::fixed_point64::create_from_raw_value((points_per_match_cur as u128)), one);
                let total_points_with_multiplier = aptos_std::fixed_point64::add(base_points, points_with_multiplier);

                total_points = total_points + (aptos_std::fixed_point64::get_raw_value(total_points_with_multiplier) as u256);
            } else {
                total_points = total_points + points_per_match_cur * num_winner;
            };

            if (i < ending_match - 1 && i + 1 == num_matches + num_matches_prev) {
                num_matches_prev = num_matches_prev + num_matches;
                num_matches = num_matches / 2;
                if (num_matches > 0) {
                    points_per_match_cur = total_points_per_round / num_matches;
                } else {
                    points_per_match_cur = 0;
                }
            };

            i = i + 1;
        };

        if(total_points == 0 ) {
            return 0
        };

        (user_points * 1000000) / total_points
    }

    public fun when_not_live(predictable_competition: &PredictableCompetitionState) {
        let competition_state = predictable_competition_state::get_competition(predictable_competition);
        competition::when_not_live(competition_state);
    }

    // External functions
    
    /*
     * Creates and save bracket predictions for a given competition.
     * This function allow a user to submit their predictions for a bracket in a competition.
     * Add a new prediction if the user has not submitted one yet. 
     * Otherwise, update the previous prediction.
     * 
     * @param sender - The address of user submit the prediction.
     * @param owner_address - The address of the owner of the competition.
     * @param competition_id - The unique identifier for the competition.
     * @param registrant - The address of the user making the prediction.
     * @param match_predictions - A vector of predicted winning team id for each match.
     */
    public entry fun create_bracket_prediction(
        sender: &signer,
        owner_address: address,
        competition_id: String,
        registrant: address,
        match_predictions : vector<u8>
    ) acquires PredictableCompetitions {
        let predictable_competitions = borrow_global_mut<PredictableCompetitions>(owner_address);
        let predictable_competition = get_predictable_competition_as_mut(predictable_competitions, &competition_id);
        save_user_prediction(predictable_competition, sender, registrant, match_predictions);
    }

    public(friend) fun save_user_prediction(
            predictable_competition: &mut PredictableCompetitionState, 
            sender: &signer, 
            registrant: address, 
            match_predictions: vector<u8>
        ) {
        let comp_state = predictable_competition_state::get_competition(predictable_competition);
        competition::when_not_live(comp_state);

        let num_matches = vector::length(&match_predictions);

        let registered_users = predictable_competition_state::get_registered_users(predictable_competition);
        let has_bracket = has_bracket(&registrant, registered_users);

        // only allow the sender to change their own bracket
        assert!(!has_bracket || registrant == signer::address_of(sender), EINVALID_SENDER);

        let num_teams = predictable_competition_state::get_num_teams(predictable_competition);
  
        assert!((num_matches as u16) == num_teams - 1, EINVALID_COMPETITION_PREDICTION_LENGTH);

        let i = 0;
        while (i < num_matches) {
            let winning_team_id = vector::borrow(&match_predictions, i);
            // Add new match_predictions_to_user map if user not yet registered
            if(!has_bracket) {
                let match_predictions_to_user = predictable_competition_state::get_match_predictions_to_user_as_mut(predictable_competition);
                // If key match id not exist in map, init one
                if (!simple_map::contains_key(match_predictions_to_user, &(i as u256))) {
                    let winning_team_map = simple_map::new<u8, vector<address>>();
                    simple_map::add(match_predictions_to_user, (i as u256), winning_team_map);
                };

                let winning_team_map = simple_map::borrow_mut(match_predictions_to_user, &(i as u256));
                
                // If key predicted winning team id not exist in map, init one
                if (!simple_map::contains_key(winning_team_map, winning_team_id)) {
                    let bettors = vector::empty<address>();
                    simple_map::add(winning_team_map, *winning_team_id, bettors);
                };
                
                let bettors = simple_map::borrow_mut(winning_team_map, winning_team_id);
                vector::push_back(bettors, registrant);
            } 
            // if different from previous prediction, remove previous and save new prediction
            else if(!contains_address(
                predictable_competition_state::get_match_predictions_to_user(predictable_competition), 
                &(i as u256), 
                winning_team_id, 
                &registrant
            )) {
                // Remove old prediction
                let user_bracket_predictions = predictable_competition_state::get_user_bracket_predictions(predictable_competition);
                let user_bets = simple_map::borrow(&user_bracket_predictions, &registrant);
                let old_winning_team_id = vector::borrow(user_bets, i);

                let match_predictions_to_user = predictable_competition_state::get_match_predictions_to_user_as_mut(predictable_competition);
                let winning_team_map = simple_map::borrow_mut(match_predictions_to_user, &(i as u256));
                let bettors = simple_map::borrow_mut(winning_team_map, old_winning_team_id);
                let (_, index) = vector::index_of(bettors, &registrant);

                vector::remove(bettors, index);

                // Init new bettors vector if not exist
                if (!simple_map::contains_key(winning_team_map, winning_team_id)) {
                    let new = vector::empty<address>();
                    simple_map::add(winning_team_map, *winning_team_id, new);
                };
                // Save registrant to bettors list
                let new_bettors = simple_map::borrow_mut(winning_team_map, winning_team_id);
                vector::push_back(new_bettors, registrant);
            };

            i = i + 1
        };

        register_user_and_emit_event(predictable_competition, sender, registrant, match_predictions);
    }

    public(friend) fun register_user_and_emit_event(predictable_competition: &mut PredictableCompetitionState, sender: &signer, registrant: address, match_predictions: vector<u8>) {
        // Add user to registered list
        let registered_users_as_mut = predictable_competition_state::get_registered_users_as_mut(predictable_competition);
        if(!vector::contains(registered_users_as_mut, &registrant)) {
            vector::push_back(registered_users_as_mut, registrant)
        };

        // Update user_bracket_predictions
        let user_bracket_predictions = predictable_competition_state::get_user_bracket_predictions_as_mut(predictable_competition);
        simple_map::upsert(user_bracket_predictions, registrant, match_predictions);

        // Emit event
        let bracket_prediction_saved_event = BracketPredictionSaved {
            sender: signer::address_of(sender), 
            user: registrant,
        };

        event::emit(bracket_prediction_saved_event);
    }

    /*
     * Checks if a user has made a prediction for a given competition.
     * 
     * @param owner_address - The address of the owner of the competition.
     * @param competition_id - The unique identifier for the competition.
     * @param user - The address of the user.
     * 
     * @return bool
     */    
    #[view]
    public fun has_user_registered (
        owner_address: address, 
        competition_id: String, 
        user: address
    ) : bool acquires PredictableCompetitions {
        let predictable_competitions = borrow_global<PredictableCompetitions>(owner_address);
        let predictable_competition = get_predictable_competition(predictable_competitions, &competition_id);
        
        let registered_users = predictable_competition_state::get_registered_users(predictable_competition);
        has_bracket(&user, registered_users)
    }

    /*
     * Retrieves the bracket predictions for a specified user in a given competition.
     * 
     * @param owner_address - The address of the owner of the competition.
     * @param competition_id - The unique identifier for the competition.
     * @param user - The address of the user.
     * 
     * @return vector<u8> - The bracket predictions submitted by the user for the competition.
     */
    #[view]
    public fun get_user_bracket_prediction (
        owner_address: address, 
        competition_id: String, 
        user: address
    ) : vector<u8> acquires PredictableCompetitions {
        let predictable_competitions = borrow_global<PredictableCompetitions>(owner_address);
        let predictable_competition = get_predictable_competition(predictable_competitions, &competition_id);
        let user_bracket_predictions = predictable_competition_state::get_user_bracket_predictions(predictable_competition);
        if(simple_map::contains_key(&user_bracket_predictions, &user)) { 
            return *simple_map::borrow(&user_bracket_predictions, &user)
        };

        vector::empty<u8>()
    }

    /*
     * Calculates the total score accumulated in a competition based on completed matches.
     * This function computes the total score by summing up the points awarded for each completed match 
     * based on the predictions made by participants. The score is calculated for all completed matches 
     * up to the current state of the competition
     *
     * @param owner_address - The address of the owner of the competition.
     * @param competition_id - The unique identifier for the competition.
     * 
     * @return u256 - total score
     */
    #[view]
    public fun get_total_score (
        owner_address: address, 
        competition_id: String, 
    ) : u256 acquires PredictableCompetitions {
        let predictable_competitions = borrow_global<PredictableCompetitions>(owner_address);
        let predictable_competition = get_predictable_competition(predictable_competitions, &competition_id);
        let match_multipliers = simple_map::new<u256, SimpleMap<u8, FixedPoint64>>();
        f_get_total_score(predictable_competition, false, match_multipliers)
    }

    /*
     * Calculates the percentage of total points earned by a user in a given competition.
     *
     * @param owner_address - The address of the owner of the competition.
     * @param competition_id - The unique identifier for the competition.
     * @param user - The address of the user.
     * 
     * @return u256 - user score percent
     */
    #[view]
    public fun get_user_score_percent (
        owner_address: address, 
        competition_id: String, 
        user: address,
    ) : u256 acquires PredictableCompetitions { 
        if (!has_user_registered(owner_address, competition_id, user)) {
            return 0
        };
        let predictable_competitions = borrow_global<PredictableCompetitions>(owner_address);
        let predictable_competition = get_predictable_competition(predictable_competitions, &competition_id);
        let user_multiplier = aptos_std::fixed_point64::create_from_raw_value((0 as u128));
        let match_multipliers = simple_map::new<u256, SimpleMap<u8, FixedPoint64>>();
        f_get_user_score_percent(predictable_competition, user, false, user_multiplier, match_multipliers)
    }

    /*
     * Calculates the total score earned by a user in a given competition based on their predictions.
     *
     * @param owner_address - The address of the owner of the competition.
     * @param competition_id - The unique identifier for the competition.
     * @param user - The address of the user.
     * 
     * @return u256 - user score
     */
    #[view]
    public fun get_user_bracket_score (
        owner_address: address, 
        competition_id: String, 
        user: address,
        use_multiplier: bool,
        multiplier: FixedPoint64,
    ) : u256 acquires PredictableCompetitions { 
        if (!has_user_registered(owner_address, competition_id, user)) {
            return 0
        };
        let predictable_competitions = borrow_global<PredictableCompetitions>(owner_address);
        let predictable_competition = get_predictable_competition(predictable_competitions, &competition_id);
        return f_get_user_bracket_score(predictable_competition, user, use_multiplier, multiplier)
    }

    #[view]
    public fun get_match_outcome(
        owner_address: address, 
        competition_id: String, 
        match_id: u256
    ) : MatchOutcome acquires PredictableCompetitions {
        let predictable_competitions = borrow_global<PredictableCompetitions>(owner_address);
        let predictable_competition_state = get_predictable_competition(predictable_competitions, &competition_id);
        let competition_state = predictable_competition_state::get_competition(predictable_competition_state);
        return competition::f_get_match_outcome(competition_state, match_id)
    }


    #[view]
    public fun get_competition_progression(
        owner_address: address, 
        competition_id: String
    ) : vector<MatchOutcome> acquires PredictableCompetitions {
        let predictable_competitions = borrow_global<PredictableCompetitions>(owner_address);
        let predictable_competition_state = get_predictable_competition(predictable_competitions, &competition_id);
        let competition_state = predictable_competition_state::get_competition(predictable_competition_state);
        return competition_state::get_bracket_progression(competition_state)
    }

    // Internal functions
    fun has_bracket(addr: &address, registered_users: &vector<address>): bool {
        let len = vector::length(registered_users);
        let i = 0;
        while (i < len) {
            if (vector::borrow(registered_users, i) == addr) {
                return true
            };
            i = i + 1
        };
        false
    }

    public(friend) fun contains_address(
        match_predictions_to_user: &SimpleMap<u256, SimpleMap<u8, vector<address>>>,
        matchid: &u256,
        winning_team_id: &u8,
        registrant: &address
    ): bool {
        let winning_team_map = simple_map::borrow(match_predictions_to_user, matchid);
        if (!simple_map::contains_key(winning_team_map, winning_team_id)) {
            return false
        };
        let bettors = simple_map::borrow(winning_team_map, winning_team_id);
        vector::contains(bettors, registrant)
    }

    fun get_predictable_competition(
        predictable_competitions: &PredictableCompetitions, 
        competition_id: &String
    ): &PredictableCompetitionState {
        simple_map::borrow<String, PredictableCompetitionState>(
            &predictable_competitions.predictable_competitions, 
            competition_id
        )
    }

    fun get_predictable_competition_as_mut(
        predictable_competitions: &mut PredictableCompetitions, 
        competition_id: &String
    ): &mut PredictableCompetitionState {
        simple_map::borrow_mut<String, PredictableCompetitionState>(
            &mut predictable_competitions.predictable_competitions, 
            competition_id
        )
    }

    // From competition
    #[view]
    public fun has_started(owner_address: address, competition_id: String): bool acquires PredictableCompetitions {
        let predictable_competitions = borrow_global<PredictableCompetitions>(owner_address);
        let predictable_competition = get_predictable_competition(predictable_competitions, &competition_id);
        let competition_state = predictable_competition_state::get_competition(predictable_competition);
        
        competition::p_has_started(competition_state)
    }
    
    #[view]
    public fun get_team_names(owner_address: address, competition_id: String): vector<String> acquires PredictableCompetitions {
        let predictable_competitions = borrow_global<PredictableCompetitions>(owner_address);
        let predictable_competition = get_predictable_competition(predictable_competitions, &competition_id);
        let competition_state = predictable_competition_state::get_competition(predictable_competition);
        
        competition::p_get_team_names(competition_state)
    }

    public entry fun start(sender: &signer, competition_id: String) acquires PredictableCompetitions {
        let predictable_competitions = borrow_global_mut<PredictableCompetitions>(signer::address_of(sender));
        let predictable_competition = get_predictable_competition_as_mut(predictable_competitions, &competition_id);
        let competition_state = predictable_competition_state::get_competition_state_as_mut(predictable_competition);

        competition::start_competition(competition_state);
    }

    public entry fun set_team_names (
        sender: &signer, 
        competition_id: String, 
        names: vector<String>
    ) acquires PredictableCompetitions {
        let predictable_competitions = borrow_global_mut<PredictableCompetitions>(signer::address_of(sender));
        let predictable_competition = get_predictable_competition_as_mut(predictable_competitions, &competition_id);
        let competition_state = predictable_competition_state::get_competition_state_as_mut(predictable_competition);

        competition::set_team_name_for_competition(competition_state, &names);
    }

    public entry fun complete_match(
        _signer: &signer, 
        _competition_id: String, 
        _matchId: u256, 
        _winningId: u8
    ) acquires PredictableCompetitions {
        let _predictable_competitions = borrow_global_mut<PredictableCompetitions>(signer::address_of(_signer));
        let _predictable_competition = get_predictable_competition_as_mut(_predictable_competitions, &_competition_id);
        let _competition_state = predictable_competition_state::get_competition_state_as_mut(_predictable_competition);

        competition::complete_match_for_competition(_competition_state, _matchId, _winningId);
    }

    public entry fun advance_round(_signer: &signer, _competition_id: String) acquires PredictableCompetitions {
        let _predictable_competitions = borrow_global_mut<PredictableCompetitions>(signer::address_of(_signer));
        let _predictable_competition = get_predictable_competition_as_mut(_predictable_competitions, &_competition_id);
        let _competition_state = predictable_competition_state::get_competition_state_as_mut(_predictable_competition);

        competition::p_advance_round(_competition_state);      
    }

    public entry fun advance_round_with_results (
        _signer: &signer, 
        _competition_id: String, 
        _match_results: vector<u8>
    ) acquires PredictableCompetitions {
        let _predictable_competitions = borrow_global_mut<PredictableCompetitions>(signer::address_of(_signer));
        let _predictable_competition = get_predictable_competition_as_mut(_predictable_competitions, &_competition_id);
        let _competition_state = predictable_competition_state::get_competition_state_as_mut(_predictable_competition);

        competition::p_advance_round_with_results(_competition_state, _match_results);
    }
}
