/// This module is responsible for creating and managing different types of competitions. 
/// It acts as a factory that initializes and configures new competition instances.
module brkt_addr::competition_factory {
    // Dependencies
    use brkt_addr::paid_predictable_competition;
    use brkt_addr::predictable_competition;
    use brkt_addr::competition;
    use std::simple_map::{SimpleMap, Self};
    use std::string::{String};
    use std::option::{Option};
    use std::signer;

    // Errors
    const ECOMPETITION_ALREADY_EXISTS: u64 = 0;

    // Definitions
    friend brkt_addr::competition_route;

    // Competition type
    const UNKOWN: u8 = 0;
    const BASE: u8 = 1;
    const PREDICTABLE: u8 = 2;
    const PAID_PREDICTABLE: u8 = 3;

    struct CompetitionInfo has drop, store, copy {
        addr: address,
        impl: u8
    }
    
    struct CompetitionFactory has key, drop, store {
        _competitions: SimpleMap<String, CompetitionInfo>,
        _contract_codes: SimpleMap<u8, address>, 
        _protocol_fee: u256,
    }

    // Entry functions

    // Create a new CompetitionFactory
    /*
    * @param _sender: the address of the sender
    * @return: a new CompetitionFactory
    */
    public entry fun new(_sender: &signer) {
        let newFactory = CompetitionFactory {
            _competitions: simple_map::new<String, CompetitionInfo>(),
            _contract_codes: simple_map::new<u8, address>(),
            _protocol_fee: 0,
        };
        move_to(_sender, newFactory);
    }

    // Create a new competition
    /*
    * @Description: Create a new competition with the given parameters and call the initialize_competition function
    * @param _sender: the address of the sender
    * @param _competition_id: the id of the competition
    * @param _competition_name: the name of the competition
    * @param _num_teams: the number of teams in the competition
    * @param _starting_epoch: the starting epoch of the competition
    * @param _expiration_epoch: the expiration epoch of the competition
    * @param _team_names: the names of the teams in the competition
    * @param _banner_URI: the URI of the banner of the competition
    */
    public entry fun create_competition(
        _sender: &signer,
        _competition_id: String,
        _competition_name: String,
        _num_teams: u16,
        _starting_epoch: u64,
        _expiration_epoch: u64,
        _team_names: vector<String>,
        _banner_URI: Option<String>,
    ) acquires CompetitionFactory {
        // Get the CompetitionFactory
        let _factory = borrow_global_mut<CompetitionFactory>(signer::address_of(_sender));
        // Check if competition already exists
        if (simple_map::contains_key<String, CompetitionInfo>(&_factory._competitions, &_competition_id)) {
            assert!(false, ECOMPETITION_ALREADY_EXISTS);
        };
        // Add the competition to the factory
        simple_map::add(&mut _factory._competitions, _competition_id, CompetitionInfo {
            addr: signer::address_of(_sender),
            impl: BASE
        });

        // Initialize the competition
        competition::initialize(
            _sender,
            _competition_id,
            _competition_name,
            _num_teams,
            _starting_epoch,
            _expiration_epoch,
            _team_names,
            _banner_URI
        );
    }

    // Set the protocol fee 
    /*
    *@description: Set the protocol fee for the competition.
    *@param account: the address of the account
    *@param fee: the fee to be set
    */

    public entry fun set_protocol_fee(account: &signer, fee: u256) acquires CompetitionFactory {
        let factory = borrow_global_mut<CompetitionFactory>(signer::address_of(account));
        factory._protocol_fee = fee;
    }

    /*
    *@description: Get the competition info for a given competition id
    *@param account: the address of the account
    *@param competition_id: the id of the competition
    *@return: the competition info
    */
    #[view]
    public fun get_competition_info(factory_owner_address : address, competition_id : String) : CompetitionInfo acquires CompetitionFactory {
        let factory = borrow_global_mut<CompetitionFactory>(factory_owner_address);
        let competition_info_ref = simple_map::borrow(&factory._competitions, &competition_id);
        *competition_info_ref
    }

    /*
    * @description: Get the address of the competition
    * @param account: the address of the account
    * @param competition_id: the id of the competition
    * @return: the address of the competition
    */
    #[view]
    public fun get_competition_address(factory_owner_address : address, competition_id : String) : address  acquires CompetitionFactory {
        let factory = borrow_global_mut<CompetitionFactory>(factory_owner_address);
        let competition_info_ref = simple_map::borrow(&factory._competitions, &competition_id);
        let competition_info = *competition_info_ref;
        return competition_info.addr
    }
    /*
    * @description: Get the implementation type of the competition
    * @param account: the address of the account
    * @param competition_id: the id of the competition
    * @return: the implementation type of the competition
    */
    #[view]
    public fun get_competition_implType(factory_owner_address : address, competition_id : String) : u8  acquires CompetitionFactory {
        let factory = borrow_global_mut<CompetitionFactory>(factory_owner_address);
        let competition_info_ref = simple_map::borrow(&factory._competitions, &competition_id);
        let competition_info = *competition_info_ref;
        return competition_info.impl
    }

    /*
    *@description: Create a new predictable competition with the given parameters and 
    call the initialize_predictable_competition function
    *@param account: the address of the account
    *@param competition_id: the id of the competition
    *@param competition_name: the name of the competition
    *@param num_teams: the number of teams in the competition
    *@param starting_epoch: the starting epoch of the competition
    *@param expiration_epoch: the expiration epoch of the competition
    *@param team_names: the names of the teams in the competition
    *@param banner_URI: the URI of the banner of the competition
    *@param total_points_per_round: the total points per round
    * call a function to initialize the predictable competition
    */
    public entry fun create_predictable_competition(
        _sender: &signer,
        _competition_id: String,
        _competition_name: String,
        _num_teams: u16,
        _starting_epoch: u64,
        _expiration_epoch: u64,
        _team_names: vector<String>,
        _banner_URI: Option<String>,
        _total_points_per_round: u16,
    ) acquires CompetitionFactory {
        // Get the CompetitionFactory
        let _factory = borrow_global_mut<CompetitionFactory>(signer::address_of(_sender));
        // Check if competition already exists
        if (simple_map::contains_key<String, CompetitionInfo>(&_factory._competitions, &_competition_id)) {
            assert!(false, ECOMPETITION_ALREADY_EXISTS);
        };
        // Add the competition to the factory
        simple_map::add(&mut _factory._competitions, _competition_id, CompetitionInfo {
            addr: signer::address_of(_sender),
            impl: PREDICTABLE
        });

        // Initialize the competition
        predictable_competition::initialize(
            _sender,
            _competition_id,
            _competition_name,
            _num_teams,
            _starting_epoch,
            _expiration_epoch,
            _team_names,
            _banner_URI,
            _total_points_per_round
        );
    }

    /*
     * Creates a paid predictable competition.
     *
     * @param _sender - The signer of the transaction.
     * @param _competition_id - The ID of the competition.
     * @param _competition_name - The name of the competition.
     * @param _num_teams - The number of teams in the competition.
     * @param _starting_epoch - The starting epoch of the competition.
     * @param _expiration_epoch - The expiration epoch of the competition.
     * @param _team_names - The names of the teams in the competition.
     * @param _banner_URI - The URI of the competition banner.
     * @param _total_points_per_round - The total points per round in the competition.
     * @param _registration_fee - The registration fee for the competition.
     */
    public entry fun create_paid_predictable_competition<CoinType>(
        _sender: &signer,
        _competition_id: String,
        _competition_name: String,
        _num_teams: u16,
        _starting_epoch: u64,
        _expiration_epoch: u64,
        _team_names: vector<String>,
        _banner_URI: Option<String>,
        _total_points_per_round: u16,
        _registration_fee: u256,
    ) acquires CompetitionFactory {
        // Get the CompetitionFactory
        let _factory = borrow_global_mut<CompetitionFactory>(signer::address_of(_sender));
        // Check if competition already exists
        if (simple_map::contains_key<String, CompetitionInfo>(&_factory._competitions, &_competition_id)) {
            assert!(false, ECOMPETITION_ALREADY_EXISTS);
        };
        // Add the competition to the factory
        simple_map::add(&mut _factory._competitions, _competition_id, CompetitionInfo {
            addr: signer::address_of(_sender),
            impl: PAID_PREDICTABLE
        });

        // Initialize the competition
        paid_predictable_competition::initialize<CoinType>(
            _sender,
            _competition_id,
            _competition_name,
            _num_teams,
            _starting_epoch,
            _expiration_epoch,
            _team_names,
            _banner_URI,
            _total_points_per_round,
            _registration_fee,
            _factory._protocol_fee,
        );
    }

    // Getters

    public(friend) fun get_base(): u8 {
        BASE
    }

    public(friend) fun get_predictable(): u8 {
        PREDICTABLE
    }

    public(friend) fun get_paid_predictable(): u8 {
        PAID_PREDICTABLE
    }
}
