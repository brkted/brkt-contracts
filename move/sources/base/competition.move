/// This module manages the core logic of competitions, including 
/// error definitions and dependencies. 
/// It serves as the foundation for other competition-related modules.
module brkt_addr::competition {
   // Dependencies
    use brkt_addr::competition_state::{CompetitionState, Self};
    use brkt_addr::match_outcome::{MatchOutcome, Self};
    use std::simple_map::{SimpleMap, Self};
    use std::option::{Option, Self};
    use std::string::{String, utf8};
    use std::timestamp;
    use std::signer;
    use std::vector;
    use std::math64;
    use std::event;

    // Errors
    const EINVALID_START_TIME: u64 = 100;
    const ETEAM_NAMES_MISMATCH: u64 = 101;
    const ETOO_MANY_TEAMS: u64 = 102;
    const EINVALID_NUMBER_OF_TEAMS: u64 = 103;
    const EINVALID_MATCH_ID: u64 = 104;
    const EMATCH_ALREADY_COMPLETED: u64 = 105;
    const EROUND_ALREADY_AT_END: u64 = 106;
    const EMATCH_NOT_COMPLETED: u64 = 107;
    const EINVALID_COMPETITION_RESULTS_LENGTH: u64 = 108;
    const ECOMPETITION_HAS_EXPIRED: u64 = 109;
    const ECOMPETITION_IS_LIVE: u64 = 110;
    const ECOMPETITION_NOT_LIVE: u64 = 111;
    const ECOMPETITION_COMPLETED: u64 = 112;
    const ECOMPETITION_NOT_EXPIRED: u64 = 113;
    const ECOMPETITION_NOT_COMPLETED: u64 = 114;

    // Definitions
    friend brkt_addr::competition_factory;
    friend brkt_addr::predictable_competition;
    friend brkt_addr::paid_predictable_competition;

    const MAX_TEAMS: u256 = 256;
    const U64_MAX: u64 = 18446744073709551615;

    #[event]
    struct MatchCompleted has drop, store {
        match_id: u256,
        winning_team: u8
    }

    struct Competition has store {
        state: CompetitionState
    }

    struct Competitions has key {
        competitions: SimpleMap<String, Competition> 
    }
    
    // Friend functions
    
    /*
     * Initializes a new competition.
     *
     * @param _competition_owner - The address of the competition owner.
     * @param _competition_id - The ID of the competition.
     * @param _competition_name - The name of the competition.
     * @param _num_teams - The number of teams in the competition.
     * @param _starting_epoch - The starting epoch of the competition.
     * @param _expiration_epoch - The expiration epoch of the competition.
     * @param _team_names - The names of the teams in the competition.
     * @param _banner_URI - The URI of the competition banner.
     */
    public entry fun initialize(
        _competition_owner: &signer,
        _competition_id: String,
        _competition_name: String,
        _num_teams: u16,
        _starting_epoch: u64,
        _expiration_epoch: u64,
        _team_names: vector<String>,
        _banner_URI: Option<String>,
    ) acquires Competitions {
        // Get banner from user 
        let banner_URI = *option::borrow_with_default(&_banner_URI, &utf8(b""));
        
        // Create the competition state
        let new_competition_state = initialize_competition_state(
            _competition_name,
            _num_teams,
            _starting_epoch,
            _expiration_epoch,
            _team_names,
            banner_URI
        );

        // Create new competition
        let _new_competition = Competition {
            state: new_competition_state
        };

        // Add the competition to the owner's list of competitions
        if (exists<Competitions>(signer::address_of(_competition_owner))) {
            let _competitions = borrow_global_mut<Competitions>(signer::address_of(_competition_owner));
            simple_map::add<String, Competition>(&mut _competitions.competitions, _competition_id, _new_competition);
        } else {
            let _competitions = simple_map::new<String, Competition>();
            simple_map::add<String, Competition>(&mut _competitions, _competition_id, _new_competition);
            let _new_competitions = Competitions {
                competitions: _competitions
            };
            move_to(_competition_owner, _new_competitions);
        }
    }

    /*
     * Initializes the competition state with the given parameters.
     *
     * @param _competition_name - The name of the competition.
     * @param _num_teams - The number of teams participating in the competition.
     * @param _starting_epoch - The starting epoch of the competition.
     * @param _expiration_epoch - The expiration epoch of the competition.
     * @param _team_names - The names of the teams participating in the competition.
     * @param _banner_URI - The URI of the competition banner.
     * @return The initialized competition state.
     */
    public(friend) fun initialize_competition_state(
        _competition_name: String,
        _num_teams: u16,
        _starting_epoch: u64,
        _expiration_epoch: u64,
        _team_names: vector<String>,
        _banner_URI: String
    ): CompetitionState {
        if (_starting_epoch <= timestamp::now_seconds()) {
            assert!(false, EINVALID_START_TIME);
        };
        if ((vector::length<String>(&_team_names) as u16) != _num_teams) {
            assert!(false, ETEAM_NAMES_MISMATCH);
        };
        if (_num_teams > (MAX_TEAMS as u16)) {
            assert!(false, ETOO_MANY_TEAMS);
        };  

        let num_teams_cur: u256 = 2;
        let _num_rounds: u16 = 1;
        while (num_teams_cur < (_num_teams as u256)) {
            _num_rounds = _num_rounds + 1;
            num_teams_cur = (math64::pow(2, (_num_rounds as u64)) as u256);
        };
        if (num_teams_cur != (_num_teams as u256)) {
            assert!(false, EINVALID_NUMBER_OF_TEAMS);
        };

        let _bracket_progression: vector<MatchOutcome> = vector::empty<MatchOutcome>();
        let _temp_team_names: SimpleMap<u256, String> = simple_map::new<u256, String>();
        let i: u16 = 0;
        while (i < _num_teams - 1) {
            vector::push_back<MatchOutcome>(&mut _bracket_progression, match_outcome::default_match_outcome());
            simple_map::add<u256, String>(&mut _temp_team_names, (i as u256), *vector::borrow<String>(&_team_names, (i as u64)));
            i = i + 1;
        };
        let last_element = _num_teams-1;
        simple_map::add<u256, String>(&mut _temp_team_names, (last_element as u256), *vector::borrow<String>(&_team_names, (last_element as u64)));

        if (_expiration_epoch == 0) {
            _expiration_epoch = U64_MAX;
        };

        // Create the competition state
        return competition_state::new(
            _competition_name,
            _banner_URI,
            _num_teams,
            _num_rounds,
            _num_rounds,
            _starting_epoch,
            _expiration_epoch,
            false,
            false,
            _temp_team_names,
            _bracket_progression,
        )
    }

    /*
     * Retrieves the match outcome for a given match ID in the competition state.
     *
     * @param _state - The competition state
     * @param _match_id - The match ID
     * @return The match outcome for the given match ID
     */
    public(friend) fun f_get_match_outcome(_state: &CompetitionState, _match_id: u256): MatchOutcome {
        if (_match_id < (competition_state::get_bracket_progression_length(_state) as u256)) {
            return *competition_state::get_a_bracket_progression(_state, (_match_id as u64))
        };
        // Return a default MatchOutcome or handle the error appropriately
        return match_outcome::default_match_outcome()
    }

    // Entry functions
    
    /*
     * Starts a competition.
     *
     * @param _sender - the signer initiating the transaction
     * @param _competition_id - the ID of the competition to start
     */
    public entry fun start(_sender: &signer, _competition_id: String) acquires Competitions {
        let _competitions = borrow_global_mut<Competitions>(signer::address_of(_sender));
        let _competition = get_competition_as_mut(_competitions, &_competition_id);

        start_competition(&mut _competition.state);
    }

    /*
     * Sets the team names for a competition.
     *
     * @param _sender - the signer of the transaction
     * @param _competition_id - the ID of the competition
     * @param _names - a vector of team names
     */
    public entry fun set_team_names(_sender: &signer, _competition_id: String, _names: vector<String>) acquires Competitions {
        let _competitions = borrow_global_mut<Competitions>(signer::address_of(_sender));
        let _competition = get_competition_as_mut(_competitions, &_competition_id);
        
        set_team_name_for_competition(&mut _competition.state, &_names);
    }

    /*
     * Completes a match in a competition.
     *
     * @param _sender - the address of the signer
     * @param _competition_id - the ID of the competition
     * @param _matchId - the ID of the match
     * @param _winningId - the ID of the winning team
     */
    public entry fun complete_match(_sender: &signer, _competition_id: String, _matchId: u256, _winningId: u8) acquires Competitions {
        let _competitions = borrow_global_mut<Competitions>(signer::address_of(_sender));
        let _competition = get_competition_as_mut(_competitions, &_competition_id);
        when_in_progress(&_competition.state);

        p_complete_match(_competition, _matchId, _winningId);
    }

    
    /*
     * Advances the round of a competition.
     *
     * @param _sender - the signer of the transaction
     * @param _competition_id - the ID of the competition
     */
    public entry fun advance_round(_sender: &signer, _competition_id: String) acquires Competitions {
        let _competitions = borrow_global_mut<Competitions>(signer::address_of(_sender));
        let _competition = get_competition_as_mut(_competitions, &_competition_id);

        p_advance_round(&mut _competition.state);
    }

    /*
     * Advances the round of a competition with match results.
     *
     * @param _sender - the signer of the transaction
     * @param _competition_id - the ID of the competition
     * @param _match_results - the match results as a vector of u8
     */
    public entry fun advance_round_with_results(_sender: &signer, _competition_id: String, _match_results: vector<u8>) acquires Competitions {
        let _competitions = borrow_global_mut<Competitions>(signer::address_of(_sender));
        let _competition = get_competition_as_mut(_competitions, &_competition_id);
        
        p_advance_round_with_results(&mut _competition.state, _match_results);
    }

    // View functions

    /*
     * Retrieves the progression of a competition.
     *
     * @param addr - the address of the competition
     * @param competition_id - the ID of the competition
     * @return a vector of MatchOutcome representing the progression of the competition
     */
    
    #[view]
    public fun get_competition_progression(addr: address, competition_id: String): vector<MatchOutcome> acquires Competitions {
        let competitions = borrow_global<Competitions>(addr);
        let competition = get_competition(competitions, &competition_id);
        competition_state::get_bracket_progression(&competition.state)
    }

    
    /*
     * Checks if a competition has started.
     *
     * @param _sender - the address of the sender
     * @param _competition_id - the ID of the competition
     * @return true if the competition has started, false otherwise
     */
    #[view]
    public fun has_started(_sender: address, _competition_id: String): bool acquires Competitions {
        let _competitions = borrow_global<Competitions>(_sender);
        let _competition = get_competition(_competitions, &_competition_id);
        // let _competition = simple_map::borrow(&_competitions.competitions, &_competition_id);
        p_has_started(&_competition.state)
    }

    // Public Functions
    
    // Get MatchOutcome of a competition
    /*
     * Retrieves the match outcome for a given competition and match ID.
     *
     * @param _addr - the address of the competition
     * @param _competition_id - the ID of the competition
     * @param _match_id - the ID of the match
     * @return the match outcome
     */
    #[view]
    public fun get_match_outcome(_addr: address, _competition_id: String, _match_id: u256): MatchOutcome acquires Competitions {
        let _competitions = borrow_global<Competitions>(_addr);
        let _competition = get_competition(_competitions, &_competition_id);
        return f_get_match_outcome(&_competition.state, _match_id)
    }

    /*
     * Retrieves the team names for a given competition.
     *
     * @param _addr - the address of the competition contract
     * @param _competition_id - the ID of the competition
     * @return a vector of team names
     */
    #[view]
    public fun get_team_names(_addr: address, _competition_id: String): vector<String> acquires Competitions {
        let _competitions = borrow_global<Competitions>(_addr);
        let _competition = get_competition(_competitions, &_competition_id);
        p_get_team_names(&_competition.state)
    }

    // Public functions
    
    /*
     * Retrieves the team names from the competition state.
     *
     * @param _state - The competition state.
     * @return A vector of strings containing the team names.
     */
    public fun p_get_team_names(_state: &CompetitionState): vector<String> {
        return competition_state::get_team_names(_state)
    }

    /*
     * Returns the number of matches in the current round of the competition.
     *
     * @param _state - The competition state.
     * @return The number of matches in the current round.
     */
    public fun get_cur_round_matches_num(_state: &CompetitionState): u256 {
        get_team_size_cur(_state) / 2
    }

    /*
     * Checks if the competition is not live and throws an error if it has already started.
     *
     * @param _state - The competition state
     * @return None
     */
    public fun when_not_live(_state: &CompetitionState) {
        if (p_has_started(_state)) {
            assert!(false, ECOMPETITION_IS_LIVE);
        };
    }

    /*
     * Checks if the competition has started.
     *
     * @param _state - The competition state.
     * @return true if the competition has started, false otherwise.
     */
    public fun p_has_started(_state: &CompetitionState): bool {
        competition_state::get_has_started(_state) || 
            timestamp::now_seconds() >= competition_state::get_starting_epoch(_state)
    }
    
    /*
     * Starts the competition.
     *
     * @param _competition_state - a mutable reference to the competition state
     * @return None
     */
    public fun start_competition(_competition_state : &mut CompetitionState) {
        when_not_expired(_competition_state);

        competition_state::set_has_started(_competition_state);
        competition_state::set_starting_epoch(_competition_state, timestamp::now_seconds());
    }

    /*
     * Sets the team names for a competition.
     *
     * @param competition_state - The competition state
     * @param names - A vector of team names
     */
    public fun set_team_name_for_competition(competition_state: &mut CompetitionState, names: &vector<String> ) {
        when_not_live(competition_state);
        
        if (vector::length(names) != (competition_state::get_num_teams(competition_state) as u64)) {
            assert!(false, EINVALID_NUMBER_OF_TEAMS);
        };

        let i: u64 = 0;
        let len = vector::length(names);
        let _temp_team_names: SimpleMap<u256, String> = simple_map::new<u256, String>();
        while (i < len) {
            simple_map::add<u256, String>(&mut _temp_team_names, (i as u256), *vector::borrow<String>(names, i));
            i = i + 1;
        };
        competition_state::set_team_names(competition_state, _temp_team_names);
    }

    /*
     * Completes a match in a competition.
     *
     * @param _state - The competition state
     * @param _match_id - The ID of the match
     * @param _winning_id - The ID of the winning team
     */
    public fun complete_match_for_competition(_state: &mut CompetitionState, _match_id: u256, _winning_id: u8) {
        when_in_progress(_state);
        let matches_cur: u256 = get_cur_round_matches_num(_state);
        let starting_idx: u256 = (competition_state::get_num_teams(_state) as u256) - get_team_size_cur(_state);
        if (_match_id >= matches_cur + starting_idx || _match_id < starting_idx) {
            assert!(false, EINVALID_MATCH_ID);
        };
        if (match_outcome::get_is_completed(competition_state::get_a_bracket_progression(_state, (_match_id as u64)))) {
            assert!(false, EMATCH_ALREADY_COMPLETED);
        };
        
        // For trustlessness, we should check that the winning team is competing in this match
        competition_state::set_a_bracket_progression(_state, (_match_id as u64), _winning_id, true);
        
        // Emit event MatchCompleted
        let match_completed_event = MatchCompleted {
            match_id: _match_id,
            winning_team: _winning_id
        };

        event::emit(match_completed_event);
    }

    /*
     * Advances the round of a competition.
     *
     * @param _state - The competition state
     */
    public fun p_advance_round(_state: &mut CompetitionState) {
        when_in_progress(_state);
        
        if (competition_state::get_rounds_remaining(_state) == 0) {
            assert!(false, EROUND_ALREADY_AT_END);
        };
        
        let matches_cur: u256 = get_cur_round_matches_num(_state);
        let starting_idx: u256 = (competition_state::get_num_teams(_state) as u256) - get_team_size_cur(_state);
        let bracket_progression = competition_state::get_bracket_progression(_state);
        let i: u256 = 0;
        while (i < (matches_cur + starting_idx)) {
            if (!match_outcome::get_is_completed(vector::borrow(&bracket_progression, (i as u64)))) {
                assert!(false, EMATCH_NOT_COMPLETED);
            };
            i = i + 1;
        };

        let rounds_remaining = competition_state::get_rounds_remaining(_state) - 1;
        competition_state::set_rounds_remaining(_state, rounds_remaining);
        if (rounds_remaining == 0) {
            competition_state::set_has_finished(_state);
        };
    }

    /*
     * Advances the round of a competition with match results.
     *
     * @param _state - The competition state
     * @param _match_results - The match results as a vector of u8
     */
    public fun p_advance_round_with_results(_state: &mut CompetitionState, _match_results: vector<u8>) {
        when_in_progress(_state);
        
        if (competition_state::get_rounds_remaining(_state) == 0) {
            assert!(false, EMATCH_NOT_COMPLETED);
        };

        // _saveCompetitionProgress function
        let team_size_cur: u256 = get_team_size_cur(_state);
        let num_matches: u256 = (vector::length(&_match_results) as u256);
        if (num_matches != team_size_cur / 2) {
            assert!(false, EINVALID_COMPETITION_RESULTS_LENGTH);
        };
        // The starting index will always be the difference in starting team to current team size.
        // This is because the team size goes down 1/2 each round, which is proportionate with the number of matches
        let starting_idx: u256 = (competition_state::get_num_teams(_state) as u256) - team_size_cur;
        let bracket_progression = competition_state::get_bracket_progression(_state);
        let i: u256 = 0;
        while (i < num_matches) {
            if (!match_outcome::get_is_completed(vector::borrow(&bracket_progression, ((i + starting_idx) as u64)))) {
                competition_state::set_a_bracket_progression(_state, ((i + starting_idx) as u64), *vector::borrow(&_match_results, (i as u64)), true);
            };
            i = i + 1;
        };
        let rounds_remaining = competition_state::get_rounds_remaining(_state) - 1;
        competition_state::set_rounds_remaining(_state, rounds_remaining);
        if (rounds_remaining == 0) {
            competition_state::set_has_finished(_state);
        };
    }

    // Private Functions
    
    /*
     * Get a competition according to the competition ID.
     *
     * @param _competitions - The competitions
     * @param _competition_id - The ID of the competition
     * @return The competition
     */
    fun get_competition(_competitions: &Competitions, _competition_id: &String): &Competition {
        simple_map::borrow<String, Competition>(&_competitions.competitions, _competition_id)
    }

    /*
     * Get a mutable reference to a competition according to the competition ID.
     *
     * @param _competitions - The competitions
     * @param _competition_id - The ID of the competition
     * @return A mutable reference to the competition
     */
    fun get_competition_as_mut(_competitions: &mut Competitions, _competition_id: &String): &mut Competition {
        simple_map::borrow_mut<String, Competition>(&mut _competitions.competitions, _competition_id)
    }

    /*
     * Completes a match in a competition.
     *
     * @param _competition - The competition
     * @param _match_id - The ID of the match
     * @param _winning_id - The ID of the winning team
     */
    fun p_complete_match(_competition: &mut Competition, _match_id: u256, _winning_id: u8) {
        let _state = &mut _competition.state;
        let matches_cur: u256 = get_cur_round_matches_num(_state);
        let starting_idx: u256 = (competition_state::get_num_teams(_state) as u256) - get_team_size_cur(_state);
        if (_match_id >= matches_cur + starting_idx || _match_id < starting_idx) {
            assert!(false, EINVALID_MATCH_ID);
        };
        if (match_outcome::get_is_completed(competition_state::get_a_bracket_progression(_state, (_match_id as u64)))) {
            assert!(false, EMATCH_ALREADY_COMPLETED);
        };
        
        // For trustlessness, we should check that the winning team is competing in this match
        competition_state::set_a_bracket_progression(_state, (_match_id as u64), _winning_id, true);
        
        // Emit event MatchCompleted
        let match_completed_event = MatchCompleted {
            match_id: _match_id,
            winning_team: _winning_id
        };

        event::emit(match_completed_event);
    }

    /*
     * Returns the size of the current team.
     *
     * @param _state - The competition state
     * @return The size of the current team
     */
    fun get_team_size_cur(_state: &CompetitionState): u256 {
        (math64::pow(2, (competition_state::get_rounds_remaining(_state) as u64)) as u256)
    }

    /* 
     * Checks if the competition has expired and throws an error if it has.
     *
     * @param _state - The competition state
     */
    fun when_not_expired(_state: &CompetitionState) {
        if (!competition_state::get_has_finished(_state) &&
             timestamp::now_seconds() >= competition_state::get_expiration_epoch(_state)) 
        {
            assert!(false, ECOMPETITION_HAS_EXPIRED);
        };
    }

    /*
     * Checks if the competition has expired and throws an error if it has not.
     *
     * @param _state - The competition state
     */
    public fun when_expired(_state: &CompetitionState) {
        if (competition_state::get_has_finished(_state) ||
             timestamp::now_seconds() < competition_state::get_expiration_epoch(_state)) 
        {
            assert!(false, ECOMPETITION_NOT_EXPIRED);
        };
    }

    /*
     * Checks if the competition is in progress and throws an error if it is not.
     *
     * @param _state - The competition state
     */
    fun when_in_progress(_state: &CompetitionState) {
        if (!p_has_started(_state)) {
            assert!(false, ECOMPETITION_NOT_LIVE);
        };
        if (competition_state::get_has_finished(_state)) {
            assert!(false, ECOMPETITION_COMPLETED);
        };
        if (timestamp::now_seconds() >= competition_state::get_expiration_epoch(_state)) {
            assert!(false, ECOMPETITION_HAS_EXPIRED);
        };
    }

    /*
     * Function description
     *
     * @param _state - The competition state
     * @return None
     */
    public fun when_completed(_state: &CompetitionState) {
        if (!competition_state::get_has_finished(_state)) {
            assert!(false, ECOMPETITION_NOT_COMPLETED);
        };
    }

}