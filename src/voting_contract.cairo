//begins by registering voters thru the contract's constructor.
//3 voters are initialized at this stage and their addresses are passed to an internal func. _register_voters.
//this adds the voters to the contract's state marking them as registered and eligibleto vote

//within contract, constants yes and no are defined to represent the voting options 1 and 0, rep.
//these facilitate the voting process by standardizing the input values.

//once registred a voter is able to cast a vote using the vote func. selecting either the 1(yes) or No as their vote
//when voting the state of the contract is updated, recording  the vote and marking the voter as having voted.
//this enusres that the voter is not able to cast avote again within the same proposal.
//casting of avote triggers the VoteCast event, logging the action


//==contract also monitors unauthorised voting attempts. if an unauthorized action is detected, such as \
//non-registred user attempting to vote or a user trying to vote again, the UnauthorizedAttempt event is emitted

//@dev core library imports for the traits outside the starknet contract.
use starknet::ContractAddress;

/// @dev Trait defining the functions that can be implemented or called by the Starknet Contract
#[starknet::interface]
trait VoteTrait<T> {
    /// @dev Function that returns the current vote status
    fn get_vote_status(self: @T) -> (u8, u8, u8, u8);
    /// @dev Function that checks if the user at the specified address is allowed to vote
    fn voter_can_vote(self: @T, user_address: ContractAddress) -> bool;
    /// @dev Function that checks if the specified address is registered as a voter
    fn is_voter_registered(self: @T, address: ContractAddress) -> bool;
    /// @dev Function that allows a user to vote
    fn vote(ref self: T, vote: u8);
}

/// @dev Starknet Contract allowing three registered voters to vote on a proposal
#[starknet::contract]
mod Vote {
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    const YES: u8 = 1_u8;
    const NO: u8 = 0_u8;

    //@dev structure that stores vote counts and vote states
    #[storage]
    struct Storage {
        yes_votes: u8,
        no_votes: u8,
        can_vote: LegacyMap::<ContractAddress, bool>,
        registered_voter: LegacyMap::<ContractAddress, bool>,
    }

    /// @dev Contract constructor initializing the contract with a list of registered voters and 0 vote count
    #[constructor]
    fn constructor(
        ref self: ContractState,
        voter_1:ContractAddress,
        voter_2:ContractAddress,
        voter_3:ContractAddress
    ) {
        //register all voters by calling the _register_voters function
        self._register_voters(voter_1, voter_2, voter_3);

        //initialize the vote count to 0
        self.yes_votes.write(0_u8);
        self.no_votes.write(0_u8);
    }

    //@dev event that gets emitted when a vote is cast.
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        VoteCast: VoteCast,
        UnauthorizedAttempt: UnauthorizedAttempt,
    }

    ///@dev represents a vote that was cast.
    #[derive(Drop, starknet::Event)]
    struct VoteCast {
        vote:ContractAddress,
        vote:u8,
    }

    //@deve represents an unauhtorized attempt to vote.
    #[derive(Drop, starknet::Event)]
    struct UnauthorizedAttempt {
        unauthorized_address: ContractAddress,
    }

    ///@dev implementation of VoteTrait for ContractSTate
    #[abi(embed_v0)]
    impl VoteImpl of super::VoteTrait<ContractState> {
        ///@dev returns the voting results
        fn get_vote_status(self: @ContractState) -> (u8, u8,u8) {
            let (n_yes, n_no) = self._get_voting_result();
            let (yes_percentage, no_percentage) = self._get_voting_result_in_percentage();
            (n_yes, n_no, yes_percentage, no_percentage)
        }

        ///@dev check whether a voter is allowed to vote
        fn voter_can_vote(self:@ContractState, user_address:ContractAddress) -> bool {
            self.can_vote.read(user_address)
        }

        //@dev check whether an address is registred as avoter
        fn is_voter_registered(self:@ContractState, address:ContractAddress) -> bool {
            self.registered_voter.read(address)
        }

        //@dev submit a vote
        fn vote(ref self: ContractState, vote:u8) {
            assert!(vote == NO || vote == YES, "VOTE_0_OR_1");
            let caller:ContractAddress = get_caller_address();
            self._assert_allowed(caller);
            self.can_vote.write(caller, false);

            if (vote == NO) {
                self.no_votes.write(self.no_votes.read() + 1_u8);
            }
            if (vote == YES) {
                self.yes_votes.write(self.yes_votes.read() + 1_u8);
            }

            self.emit(VoteCast {voter:caller, vote:vote});
        }
    }

    ///@dev internal funcs implemenation for the vote contract
    #[generate_trait]
    impl InternalFunctions  of InternalFunctionsTrait {
        /// @dev Registers the voters and initializes their voting status to true (can vote)
        fn _register_voters(
            ref self: ContractState,
            voter_1: ContractAddress,
            voter_2: ContractAddress,
            voter_3: ContractAddress
        ) {
            self.registered_voter.write(voter_1, true);
            self.can_vote.write(voter_1, true);

            self.registered_voter.write(voter_1, true);
            self.can_vote.write(voter_1, true);

            self.registered_voter.write(voter_1, true);
            self.can_vote.write(voter_1, true);
        }
        
    }

    ///@dev asserts implementation for the vote contract
    #[generate_trait]
    impl AssertsImpl of AssertsTrait {
        //@dev Internal funcs that checks if an address is allowed to vote
        fn _assert_allowed(ref self: ContractState, address:ContractAddress) {
            let is_voter:bool = self.registered_voter.read((address));
            let can_vote:bool = self.can_vote.read((address));

            if(!can_vote) {
                self.emit(UnauthorizedAttempt {unauthorised_address:address, });
            }

            assert!(is_voter, "USER_NOT_REGISTERED");
            assert!(can_vote, "USER_ALREADY_VOTED");
        } 
    }

    ///@DEV Implement the VotingResultTrait for the Vote contract
    #[generate_trait]
    impl VoteResultFunctionsImpl of VoteResultFunctionsTrait {
        //@dev INternal function to get the voting results (yes and no vote counts)
        fn _get_voting_result(self:@ContractState) -> (u8,u8){
            let n_yes:u8 = self.yes_votes.read();
            let n_no:u8 = self.no_votes.read();

            (n_yes, n_no)
        }

        //@dev internal function to calculate the voting results in percentage
        fn _get_voting_result_in_percentage(self:@ContractState) -> (u8, u8) {
            let n_yes:u8 = self.yes_votes.read();
            let n_no:u8 = self.no_votes.read();

            let total_votes:u8 = n_yes + n_no;
            if (total_votes == 0_u8) {
                return (0,0);
            }
            let yes_percentage:u8 = (n_yes*100_u8) / (total_votes);
            let no_percentage:u8 = (n_no * 100_u8) / (total_votes);

            (yes_percentage, no_percentage)
        }
    }
}