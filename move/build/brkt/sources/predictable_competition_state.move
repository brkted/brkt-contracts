/// This module extends `CompetitionState` to include prediction-related data. 
/// It adds additional fields and functions to handle user predictions and their outcomes.
module brkt_addr::predictable_competition_state {
    // Dependencies
    use brkt_addr::competition_state::{Self, CompetitionState};
    use std::simple_map::{Self, SimpleMap};
    use std::vector;

    // Definitions
    friend brkt_addr::predictable_competition;
    friend brkt_addr::paid_predictable_competition;
    friend brkt_addr::paid_predictable_competition_state;

    struct PredictableCompetitionState has drop, store, copy {
        competition: CompetitionState,
        total_points_available: u16,
        total_points_per_round: u16,
        match_predictions_to_user: SimpleMap<u256, SimpleMap<u8, vector<address>>>,
        user_bracket_predictions: SimpleMap<address, vector<u8>>,
        registered_users: vector<address>,
    }

    // Friend functions

    public(friend) fun new(
        competition: CompetitionState,
        total_points_available: u16,
        total_points_per_round: u16,
        match_predictions_to_user: SimpleMap<u256, SimpleMap<u8, vector<address>>>,
        user_bracket_predictions: SimpleMap<address, vector<u8>>,
        registered_users: vector<address>,
    ) : PredictableCompetitionState {
        PredictableCompetitionState {
            competition,
            total_points_available,
            total_points_per_round,
            match_predictions_to_user,
            user_bracket_predictions,
            registered_users,
        }
    }

    // Getters and setters

    public(friend) fun set_competition(state: &mut PredictableCompetitionState, competition: CompetitionState) {
        state.competition = competition;
    }

    public(friend) fun get_competition(state: &PredictableCompetitionState): &CompetitionState {
        &state.competition
    }

    public(friend) fun get_competition_state_as_mut(state: &mut PredictableCompetitionState): &mut CompetitionState {
        &mut state.competition
    }

    public(friend) fun get_registered_users(state: &PredictableCompetitionState): &vector<address> {
        &state.registered_users
    }

    public(friend) fun get_registered_users_as_mut(state: &mut PredictableCompetitionState): &mut vector<address> {
        &mut state.registered_users
    }
    
    public(friend) fun get_user_bracket_predictions(state: &PredictableCompetitionState): SimpleMap<address, vector<u8>> {
        state.user_bracket_predictions
    }
    
    public(friend) fun get_user_bracket_predictions_as_mut(state: &mut PredictableCompetitionState): &mut SimpleMap<address, vector<u8>> {
        &mut  state.user_bracket_predictions
    }

    public(friend) fun get_match_predictions_to_user(state: &PredictableCompetitionState)
            : &SimpleMap<u256, SimpleMap<u8, vector<address>>> {
        &state.match_predictions_to_user
    }
    
    public(friend) fun get_match_predictions_to_user_as_mut(state: &mut PredictableCompetitionState)
            : &mut SimpleMap<u256, SimpleMap<u8, vector<address>>> {
        &mut state.match_predictions_to_user
    }

    public(friend) fun get_predictors(
        state: &PredictableCompetitionState, 
        match_id: &u256, 
        team_id: &u8
    ) : vector<address> {
        if(simple_map::contains_key(&state.match_predictions_to_user, match_id)) {
            let team_predictions = simple_map::borrow(&state.match_predictions_to_user, match_id);
            if(simple_map::contains_key(team_predictions, team_id)) {
                return *simple_map::borrow(team_predictions, team_id)
            };
        };
        vector::empty<address>()
    }
    
    public(friend) fun get_total_points_per_round(state: &PredictableCompetitionState) : u16 {
        state.total_points_per_round
    }

    //
    public(friend) fun get_num_teams(state: &PredictableCompetitionState): u16 {
        let competition = &state.competition;
        competition_state::get_num_teams(competition)
    }
    
    public(friend) fun get_has_finished(state: &PredictableCompetitionState): bool {
        let competition = &state.competition;
        competition_state::get_has_finished(competition)
    }
}
