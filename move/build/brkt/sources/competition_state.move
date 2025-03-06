
/// This module manages the state of a competition, including teams, rounds, and match outcomes. 
/// It defines the structure and behavior of a competition's state, 
/// ensuring that all relevant data is stored and updated correctly.
module brkt_addr::competition_state {
    // Dependencies
    use brkt_addr::match_outcome::{MatchOutcome, Self};
    use std::simple_map::{SimpleMap, Self};
    use std::string::String;
    use std::vector;

    // Definitions    
    friend brkt_addr::competition;
    friend brkt_addr::predictable_competition_state;
    friend brkt_addr::predictable_competition;
    friend brkt_addr::paid_predictable_competition;

    const MAX_TEAMS: u256 = 256;

    struct CompetitionState has drop, store, copy {
        max_teams: u256,
        competition_name: String,
        banner_URI: String,
        num_teams: u16,
        total_rounds: u16,
        rounds_remaining: u16,
        starting_epoch: u64,
        expiration_epoch: u64,
        has_started: bool,
        has_finished: bool,
        team_names: SimpleMap<u256, String>,
        bracket_progression: vector<MatchOutcome>,
    }

    // Friend functions

    
    /*
     * Creates a new instance of the CompetitionState struct.
     *
     * @param _competition_name - The name of the competition.
     * @param _banner_URI - The URI of the competition banner.
     * @param _num_teams - The number of teams in the competition.
     * @param _total_rounds - The total number of rounds in the competition.
     * @param _rounds_remaining - The number of rounds remaining in the competition.
     * @param _starting_epoch - The starting epoch of the competition.
     * @param _expiration_epoch - The expiration epoch of the competition.
     * @param _has_started - A boolean indicating whether the competition has started.
     * @param _has_finished - A boolean indicating whether the competition has finished.
     * @param _team_names - A map containing the team IDs and their corresponding names.
     * @param _bracket_progression - A vector containing the match outcomes in the competition bracket.
     * @return A new instance of the CompetitionState struct.
     */
    public(friend) fun new(
        _competition_name: String,
        _banner_URI: String,
        _num_teams: u16,
        _total_rounds: u16,
        _rounds_remaining: u16,
        _starting_epoch: u64,
        _expiration_epoch: u64,
        _has_started: bool,
        _has_finished: bool,
        _team_names: SimpleMap<u256, String>,
        _bracket_progression: vector<MatchOutcome>,
    ): CompetitionState {
        CompetitionState {
            max_teams: MAX_TEAMS,
            competition_name: _competition_name,
            banner_URI: _banner_URI,
            num_teams: _num_teams,
            total_rounds: _total_rounds,
            rounds_remaining: _rounds_remaining,
            starting_epoch: _starting_epoch,
            expiration_epoch: _expiration_epoch,
            has_started: _has_started,
            has_finished: _has_finished,
            team_names: _team_names,
            bracket_progression: _bracket_progression,
        }
    }

    
    // Getters and setters

    public(friend) fun set_has_started(_state: &mut CompetitionState) {
        _state.has_started = true;
    }

    public(friend) fun get_has_started(_state: &CompetitionState): bool {
        _state.has_started
    }

    public(friend) fun set_has_finished(_state: &mut CompetitionState) {
        _state.has_finished = true;
    }

    public(friend) fun get_has_finished(_state: &CompetitionState): bool {
        _state.has_finished
    }

    public(friend) fun set_starting_epoch(_state: &mut CompetitionState, _epoch: u64) {
        _state.starting_epoch = _epoch;
    }

    public(friend) fun get_starting_epoch(_state: &CompetitionState): u64 {
        _state.starting_epoch
    }

    public(friend) fun set_expiration_epoch(_state: &mut CompetitionState, _epoch: u64) {
        _state.expiration_epoch = _epoch;
    }

    public(friend) fun get_expiration_epoch(_state: &CompetitionState): u64 {
        _state.expiration_epoch
    }

    public(friend) fun get_num_teams(_state: &CompetitionState): u16 {
        return _state.num_teams
    }

    public(friend) fun set_team_names(_state: &mut CompetitionState, _team_names: SimpleMap<u256, String>) {
        _state.team_names = _team_names;
    }

    public(friend) fun get_rounds_remaining(_state: &CompetitionState): u16 {
        return _state.rounds_remaining
    }

    public(friend) fun set_rounds_remaining(_state: &mut CompetitionState, _rounds_remaining: u16) {
        _state.rounds_remaining = _rounds_remaining;
    }

    public(friend) fun get_a_bracket_progression(_state: &CompetitionState, _i: u64): &MatchOutcome {
        vector::borrow(&_state.bracket_progression, _i)
    }
    
    public(friend) fun set_a_bracket_progression(_state: &mut CompetitionState, _i: u64, _winning_team_id: u8, _is_completed: bool) {
        let bracket = vector::borrow_mut(&mut _state.bracket_progression, _i);
        match_outcome::set_winning_team_id(bracket, _winning_team_id);
        match_outcome::set_is_completed(bracket, _is_completed);
    }

    public(friend) fun get_bracket_progression(_state: &CompetitionState): vector<MatchOutcome> {
        return _state.bracket_progression
    }

    public(friend) fun get_bracket_progression_length(_state: &CompetitionState): u64 {
        return vector::length(&_state.bracket_progression)
    }

    public(friend) fun get_team_names(_state: &CompetitionState): vector<String> {
        return simple_map::values(&_state.team_names)
    }
    
    public (friend) fun get_total_rounds(_state: &CompetitionState): u16 {
        return _state.total_rounds
    }
}