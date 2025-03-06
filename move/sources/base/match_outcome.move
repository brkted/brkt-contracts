/// This module likely handles the outcomes of matches within competitions. 
/// It may include definitions and functions related to recording, validating, 
/// and retrieving match outcomes, although specific details are not provided in the excerpts.
module brkt_addr::match_outcome {
    // Definitions
    struct MatchOutcome has copy, drop, store {
        winning_team_id: u8,
        is_completed: bool
    }

    // Public functions

    /*
     * Creates a default match outcome.
     *
     * @return MatchOutcome - The default match outcome with winning team ID set to 0 and is_completed set to false.
     */
    public fun default_match_outcome(): MatchOutcome {
        MatchOutcome {
            winning_team_id: 0,
            is_completed: false
        }
    }

    /*
     * Creates a new MatchOutcome object.
     *
     * @param _winning_team_id - The ID of the winning team.
     * @param _is_completed - Indicates whether the match is completed or not.
     * @return MatchOutcome - The newly created MatchOutcome object.
     */
    public fun new(_winning_team_id: u8, _is_completed: bool): MatchOutcome {
        MatchOutcome {
            winning_team_id: _winning_team_id,
            is_completed: _is_completed
        }
    }

    // Getters and Setters
    
    public fun get_is_completed(_match_outcome: &MatchOutcome): bool {
        _match_outcome.is_completed
    }

    public fun set_is_completed(_match_outcome: &mut MatchOutcome, _is_completed: bool) {
        _match_outcome.is_completed = _is_completed;
    }

    public fun get_winning_team_id(_match_outcome: &MatchOutcome): u8 {
        _match_outcome.winning_team_id
    }

    public fun set_winning_team_id(_match_outcome: &mut MatchOutcome, _winning_team_id: u8) {
        _match_outcome.winning_team_id = _winning_team_id;
    }
}