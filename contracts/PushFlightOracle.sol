// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
contract PushFlightOracle {
    address public oracle;
    mapping(string => Flight) public flights;
    struct Flight {
        bool exists;
        bool hasTakenOff;
        bool hasLanded;
        uint256 takeoffTime;
        uint256 landingTime;
    }
    event FlightUpdated(string flightId, string eventType, uint256 timestamp);
    modifier onlyOracle() {
        require(msg.sender == oracle, "Only the oracle can update the contract");
        _;
    }
    constructor() {
        oracle = msg.sender;
    }
    function registerFlight(string memory flightId) public onlyOracle {
        require(!flights[flightId].exists, "Flight already registered");
        flights[flightId] = Flight({
            exists: true,
            hasTakenOff: false,
            hasLanded: false,
            takeoffTime: 0,
            landingTime: 0
        });
    }
    function updateFlightEvent(string memory flightId, string memory eventType, uint256 timestamp) public onlyOracle {
        require(flights[flightId].exists, "Flight not registered");
        if (keccak256(bytes(eventType)) == keccak256(bytes("takeoff"))) {
            flights[flightId].hasTakenOff = true;
            flights[flightId].takeoffTime = timestamp;
        } else if (keccak256(bytes(eventType)) == keccak256(bytes("landed"))) {
            flights[flightId].hasLanded = true;
            flights[flightId].landingTime = timestamp;
        }
        emit FlightUpdated(flightId, eventType, timestamp);
    }
}
