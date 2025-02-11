// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

contract FlightStatusOracle {
    uint256 private constant ORACLE_PAYMENT = (1 *100) / 10; // 0.1 LINK

    struct FlightData {
        string estimatedArrivalUTC;
        string estimatedDepartureUTC;
        string arrivalCity;
        string departureCity;
        string operatingAirline;
        string flightNumber;
        string departureGate;
        string arrivalGate;
        string flightStatus;
        string equipmentModel;
        bool exists;
    }

    mapping(string => FlightData) public flights;
    mapping(address => uint256) public subscriptions;
    string[] public flightNumbers;

    event FlightDataSet(
        string flightNumber,
        string estimatedArrivalUTC,
        string estimatedDepartureUTC,
        string arrivalCity,
        string departureCity,
        string operatingAirline,
        string departureGate,
        string arrivalGate,
        string flightStatus,
        string equipmentModel
    );

    event Subscribed(address indexed user, uint256 expiry);

    constructor() {}

    function setFlightData(
        string memory flightNumber,
        string memory estimatedArrivalUTC,
        string memory estimatedDepartureUTC,
        string memory arrivalCity,
        string memory departureCity,
        string memory operatingAirline,
        string memory departureGate,
        string memory arrivalGate,
        string memory flightStatus,
        string memory equipmentModel
    ) public {
        if (!flights[flightNumber].exists) {
            flightNumbers.push(flightNumber);
        }

        flights[flightNumber] = FlightData({
            estimatedArrivalUTC: estimatedArrivalUTC,
            estimatedDepartureUTC: estimatedDepartureUTC,
            arrivalCity: arrivalCity,
            departureCity: departureCity,
            operatingAirline: operatingAirline,
            flightNumber: flightNumber,
            departureGate: departureGate,
            arrivalGate: arrivalGate,
            flightStatus: flightStatus,
            equipmentModel: equipmentModel,
            exists: true
        });

        emit FlightDataSet(
            flightNumber,
            estimatedArrivalUTC,
            estimatedDepartureUTC,
            arrivalCity,
            departureCity,
            operatingAirline,
            departureGate,
            arrivalGate,
            flightStatus,
            equipmentModel
        );
    }

    function subscribe(uint256 months) public payable {
        require(months > 0, "Subscription must be for at least 1 month");
        uint256 expiry = block.timestamp + (months * 30 days);
        subscriptions[msg.sender] = expiry;
        emit Subscribed(msg.sender, expiry);
    }

    function getFlightData(string memory flightNumber)
        public
        view
        returns (
            string memory,
            string memory,
            string memory,
            string memory,
            string memory,
            string memory,
            string memory,
            string memory,
            string memory,
            string memory,
            bool
        )
    {
        require(subscriptions[msg.sender] > block.timestamp, "Subscription expired or not active");
        FlightData storage flight = flights[flightNumber];
        require(flight.exists, "Flight data not found");
        return (
            flight.estimatedArrivalUTC,
            flight.estimatedDepartureUTC,
            flight.arrivalCity,
            flight.departureCity,
            flight.operatingAirline,
            flight.flightNumber,
            flight.departureGate,
            flight.arrivalGate,
            flight.flightStatus,
            flight.equipmentModel,
            flight.exists
        );
    }
}
