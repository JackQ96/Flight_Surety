pragma solidity ^0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false


    struct Airline {
        bool isRegistered;
        bool isFunded;
        uint256 fund;
    }

    mapping(address => Airline) public airlines;

    struct Flight {
        address airline;
        string flightID;
        uint256 timestamp;
        bool credited;
    }

    mapping(bytes32 => Flight) private flights;

    mapping(address => bool) private authorisedContracts;
    mapping(address => uint256) private votes;
    mapping(address => address[]) private voters;

    mapping(bytes32 => address[]) private insuranceAirlines;
    mapping(bytes32 =>mapping(address => uint256)) private payouts;
    mapping(address => uint256) private passengerBal;
    mapping(address =>mapping(bytes32 => uint256)) private insuranceAmount;

    address[] airlinesRegistered;
    uint256 numAirlinesReg = 0;
    string[] flightsRegistered;
    uint256 numFlightsReg = 0;

    

    // uint256 numOfAirlines = 0;





    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                    address airline
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        airlines[airline] = Airline(true, false, 0);
        numAirlinesReg = numAirlinesReg.add(1);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireAuthorisedCaller()
    {
        require(authorisedContracts[msg.sender], "Unauthorised Caller");
        _;
    }

    modifier requireisAirlineRegistered(address airline)
    {
        require(airlines[airline].isRegistered, "Not a registered Airline");
        _;
    }

    modifier requireisAirlineFunded(address airline)
    {
        require(airlines[airline].isFunded, "Airline not funded");
        _;
    }


    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    function isRegistered(address airline)
                            public
                            view
                            requireIsOperational
                            returns(bool)
    {
        return airlines[airline].isRegistered;
    }

    function isFunded(address airline)
                            public
                            view
                            requireIsOperational
                            returns(bool)
    {
        return airlines[airline].isFunded;
    }


    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
                            (   address airline
                            )
                            external
                            requireIsOperational
                            requireAuthorisedCaller
    {
        require(!airlines[airline].isRegistered, "Already registered");
        airlines[airline] = Airline(true, false, 0);
        numAirlinesReg += 1;
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (   address airline,
                                string flight,
                                uint256 timestamp,
                                address passenger,
                                uint amount
                            )
                            external
                            payable
                            requireIsOperational
                            requireAuthorisedCaller
                            requireisAirlineRegistered(airline)
    {
        bytes32 key = getFlightKey(airline, flight, timestamp);
        insuranceAirlines[key].push(passenger);
        insuranceAmount[passenger][key] = amount;
        payouts[key][passenger] = 0;


    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (   address airline,
                                    string flight,
                                    uint256 timestamp
                                )
                                external
                                requireIsOperational
                                requireAuthorisedCaller
    {
        bytes32 key = getFlightKey(airline, flight, timestamp);
        address[] storage insurees = insuranceAirlines[key];

        for(uint8 i = 0; i < insurees.length; i++) {
            address passenger = insurees[i];
            uint256 pay;
            uint amount = insuranceAmount[passenger][key];

            if (payouts[key][passenger] == 0){
                pay = amount.mul(3).div(2); // using 3/2 as an arbitrary fraction due to payout being 150% of the amount insured
                payouts[key][passenger] = pay;
                passengerBal[passenger] += pay;
                
            }
        }
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (   address airline,
                                string flight,
                                uint256 timestamp,
                                address passenger
                            )
                            external
                            requireIsOperational
                            requireAuthorisedCaller
    {
        bytes32 key = getFlightKey(airline, flight, timestamp);
        uint256 payment = payouts[key][passenger];

        if(payment > 0) {
            payouts[key][passenger] = 0;
            passenger.transfer(payment);
        }
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (   address airline,
                                uint256 funding
                            )
                            public
                            payable
                            requireIsOperational
    {
        airlines[airline].fund = funding;
        airlines[airline].isFunded = true;
    }

    function authoriseCaller
                        (
                            address contractAddress
                        )
                        external
                        requireAuthorisedCaller
    {
        authorisedContracts[contractAddress] = true;
    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    function registerFlight
                        (
                            address airline,
                            string flightID,
                            uint256 timestamp
                        )
                        external
                        requireIsOperational
                        requireAuthorisedCaller
                        requireisAirlineFunded(airline)
                        returns(bytes32)
    {
        bytes32 key = getFlightKey(airline, flightID, timestamp);
        flights[key] = Flight(airline, flightID, timestamp, false);
        flightsRegistered.push(flightID);
        numFlightsReg += 1;
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {

    }


}