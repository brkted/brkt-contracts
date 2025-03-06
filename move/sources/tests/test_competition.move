/*
 * This module contains unit tests for the competition module.
 * These tests cover the simple flow of a competition, including:
 *      - Creating a competition
 *      - Starting a competition
 *      - Setting new team names
 *      - Completing a match
 *      - Advancing a round with results
 */

#[test_only]
module brkt_addr::unit_tests {
    use brkt_addr::competition;
    use brkt_addr::match_outcome;
    use aptos_framework::timestamp;
    use std::option;
    use std::vector;
    use std::signer;
    use std::string::utf8;

    const ESTART_FAIL: u64 = 400;
    const EINVAID_NAMES_LENGTH: u64 = 401;
    const EINCORRECT_TEAM_NAMES: u64 = 402;
    const EINVALID_MATCH_OUTCOMES: u64 = 403;
    const EFINISH_FAIL: u64 = 404;

    // Create a competition
    #[test(owner = @brkt_addr, framework = @0x1)]
    fun create_competition(owner: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        // Competition details
        let _id = utf8(b"c01");
        let _name = utf8(b"Color Competition");
        let _nums = 2;
        let _start = 1700000000;
        let _expire = 2000000000;
        let _names = vector[utf8(b"Red"), utf8(b"Blue")];
        let _banner = option::some(utf8(b"http:///www.example.com"));
        
        // Create a competition with the given details
        competition::initialize(owner, _id, _name, _nums, _start, _expire, _names, _banner);
    }

    // Start a competition
    #[test(owner = @brkt_addr, framework = @0x1)]
    fun start_competition(owner: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        // Competition details
        let _id = utf8(b"c01");
        let _name = utf8(b"Color Competition");
        let _nums = 2;
        let _start = 1700000000;
        let _expire = 2000000000;
        let _names = vector[utf8(b"Red"), utf8(b"Blue")];
        let _banner = option::some(utf8(b"http:///www.example.com"));
        
        // Create a competition with the given details
        competition::initialize(owner, _id, _name, _nums, _start, _expire, _names, _banner);
        
        // Start the competition with the given id
        competition::start(owner, _id);
        
        // Check if the competition has started
        assert!(competition::has_started(signer::address_of(owner), _id), ESTART_FAIL);
    }

    // Set new team names
    #[test(owner = @brkt_addr, framework = @0x1)]
    fun set_team_names(owner: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        // Competition details
        let _id = utf8(b"c01");
        let _name = utf8(b"Color Competition");
        let _nums = 2;
        let _start = 1700000000;
        let _expire = 2000000000;
        let _names = vector[utf8(b"Red"), utf8(b"Blue")];
        let _banner = option::some(utf8(b"http:///www.example.com"));

        // Create a competition with the given details
        competition::initialize(owner, _id, _name, _nums, _start, _expire, _names, _banner);

        // Set new team names for the competition
        let _new_names = vector[utf8(b"Green"), utf8(b"Yellow")];
        competition::set_team_names(owner, _id, _new_names);

        // Get the current names array
        let team_names = competition::get_team_names(signer::address_of(owner), _id);

        // Check if the team names are set correctly
        let length = vector::length(&team_names);
        // Check if the length of the team names is correct
        assert!(length == 2, EINVAID_NAMES_LENGTH);
        let i: u64 = 0;
        while (i < length) {
            // Check if the team names are set correctly
            assert!(vector::borrow(&team_names, i) == vector::borrow(&_new_names, i), EINCORRECT_TEAM_NAMES);
            i = i + 1;
        }
    }

    // Complete a match
    #[test(owner = @brkt_addr, framework = @0x1)]
    fun complete_match(owner: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        // Competition details
        let _id = utf8(b"c01");
        let _name = utf8(b"Color Competition");
        let _nums = 2;
        let _start = 1700000000;
        let _expire = 2000000000;
        let _names = vector[utf8(b"Red"), utf8(b"Blue")];
        let _banner = option::some(utf8(b"http:///www.example.com"));
        
        // Create a competition with the given details
        competition::initialize(owner, _id, _name, _nums, _start, _expire, _names, _banner);

        // Start the competition with the given id
        competition::start(owner, _id);

        // Complete the first match with the given id, and the winner team is the first team (Red)
        // (also the final match because there are only two teams)
        competition::complete_match(owner, _id, 0, 0);

        // Check if the match is completed
        let _match_outcome = competition::get_competition_progression(signer::address_of(owner), _id);
        
        // Check if the length of the match outcomes is correct
        assert!(vector::length(&_match_outcome) == 1, EINVALID_MATCH_OUTCOMES);
        
        // Check if the match is completed
        assert!(match_outcome::get_is_completed(vector::borrow(&_match_outcome, 0)), EFINISH_FAIL);
    }

    // Advance round with results
    #[test(owner = @brkt_addr, framework = @0x1)]
    fun advance_round_with_results(owner: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        // Competition details
        let _id = utf8(b"c01");
        let _name = utf8(b"Color Competition");
        let _nums = 4;
        let _start = 1700000000;
        let _expire = 2000000000;

        // Note that, this competition has 4 teams, so there are 2 rounds, 
        // and 2 matches in the first round, Red vs. Blue and Green vs. Yellow
        let _names = vector[utf8(b"Red"), utf8(b"Blue"), utf8(b"Green"), utf8(b"Yellow")];
        let _banner = option::some(utf8(b"http:///www.example.com"));

        // Create a competition with the given details
        competition::initialize(owner, _id, _name, _nums, _start, _expire, _names, _banner);

        // Start the competition with the given id
        competition::start(owner, _id);
        
        // Check states before advancing round (all matches are not completed)
        let _match_outcomes = competition::get_competition_progression(signer::address_of(owner), _id);
        let _length = vector::length(&_match_outcomes);
        let i = 0;
        while (i < _length) {
            let _outcome = vector::borrow(&_match_outcomes, i);
            let _is_completed = match_outcome::get_is_completed(_outcome);
            // Check if the match is not completed
            assert!(!_is_completed, EINVALID_MATCH_OUTCOMES);
            i = i + 1;
        };
        
        // Advance round with results (the first round)
        // The results of the first round are the first team (Red) and the third team (Green) win
        let _results = vector[0, 1];
        competition::advance_round_with_results(owner, _id, _results);

        // Check states after advancing round (all matches in the first round are completed)
        let _match_outcomes = competition::get_competition_progression(signer::address_of(owner), _id);
        
        // Get the first match and the second match in the first round
        let _first_match = vector::borrow(&_match_outcomes, 0);
        let _second_match = vector::borrow(&_match_outcomes, 1);

        // Check if the first match and the second match are completed
        assert!(match_outcome::get_is_completed(_first_match), EINVALID_MATCH_OUTCOMES);
        assert!(match_outcome::get_is_completed(_second_match), EINVALID_MATCH_OUTCOMES);
    }
}