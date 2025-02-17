// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract FlightStatusOracle {
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
    event FlightDataUpdated(
        string flightNumber,
        string[] fieldsUpdated,
        string[] newValues
    );

    constructor() {}

    function compareStrings(string memory a, string memory b)
        internal
        pure
        returns (bool)
    {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

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
        require(
            !flights[flightNumber].exists,
            "Flight already exists. Use updateFlightData."
        );

        flightNumbers.push(flightNumber);
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

    function getFlightData(string memory flightNumber)
        public
        view
        returns (FlightData memory)
    {
        require(
            subscriptions[msg.sender] > block.timestamp,
            "You are not a subscribed user or subscription expired"
        );
        require(flights[flightNumber].exists, "Flight data not found");
        return flights[flightNumber];
    }

    function updateFlightData(
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
        require(
            flights[flightNumber].exists,
            "Flight does not exist. Use setFlightData."
        );

        FlightData storage flight = flights[flightNumber];
        string[] memory fieldsToUpdate = new string[](9);
        string[] memory newValues = new string[](9);
        uint256 updateCount = 0;

        if (!compareStrings(flight.estimatedArrivalUTC, estimatedArrivalUTC)) {
            fieldsToUpdate[updateCount] = "estimatedArrivalUTC";
            newValues[updateCount] = estimatedArrivalUTC;
            flight.estimatedArrivalUTC = estimatedArrivalUTC;
            updateCount++;
        }
        if (
            !compareStrings(flight.estimatedDepartureUTC, estimatedDepartureUTC)
        ) {
            fieldsToUpdate[updateCount] = "estimatedDepartureUTC";
            newValues[updateCount] = estimatedDepartureUTC;
            flight.estimatedDepartureUTC = estimatedDepartureUTC;
            updateCount++;
        }
        if (!compareStrings(flight.arrivalCity, arrivalCity)) {
            fieldsToUpdate[updateCount] = "arrivalCity";
            newValues[updateCount] = arrivalCity;
            flight.arrivalCity = arrivalCity;
            updateCount++;
        }
        if (!compareStrings(flight.departureCity, departureCity)) {
            fieldsToUpdate[updateCount] = "departureCity";
            newValues[updateCount] = departureCity;
            flight.departureCity = departureCity;
            updateCount++;
        }
        if (!compareStrings(flight.operatingAirline, operatingAirline)) {
            fieldsToUpdate[updateCount] = "operatingAirline";
            newValues[updateCount] = operatingAirline;
            flight.operatingAirline = operatingAirline;
            updateCount++;
        }
        if (!compareStrings(flight.departureGate, departureGate)) {
            fieldsToUpdate[updateCount] = "departureGate";
            newValues[updateCount] = departureGate;
            flight.departureGate = departureGate;
            updateCount++;
        }
        if (!compareStrings(flight.arrivalGate, arrivalGate)) {
            fieldsToUpdate[updateCount] = "arrivalGate";
            newValues[updateCount] = arrivalGate;
            flight.arrivalGate = arrivalGate;
            updateCount++;
        }
        if (!compareStrings(flight.flightStatus, flightStatus)) {
            fieldsToUpdate[updateCount] = "flightStatus";
            newValues[updateCount] = flightStatus;
            flight.flightStatus = flightStatus;
            updateCount++;
        }
        if (!compareStrings(flight.equipmentModel, equipmentModel)) {
            fieldsToUpdate[updateCount] = "equipmentModel";
            newValues[updateCount] = equipmentModel;
            flight.equipmentModel = equipmentModel;
            updateCount++;
        }

        if (updateCount > 0) {
            string[] memory trimmedFields = new string[](updateCount);
            string[] memory trimmedValues = new string[](updateCount);
            for (uint256 i = 0; i < updateCount; i++) {
                trimmedFields[i] = fieldsToUpdate[i];
                trimmedValues[i] = newValues[i];
            }
            emit FlightDataUpdated(
                flight.flightNumber,
                trimmedFields,
                trimmedValues
            );
        }
    }

    function subscribe(uint256 months) public payable {
        require(months > 0, "Subscription must be for at least 1 month");
        uint256 expiry = block.timestamp + (months * 30 days);
        subscriptions[msg.sender] = expiry;
        emit Subscribed(msg.sender, expiry);
    }
}
