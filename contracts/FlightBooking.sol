// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract FlightStatusOracle {
    struct FlightData {
        string flightNumber;
        string ArrivalUTC;
        string DepartureUTC;
        string arrivalCity;
        string departureCity;
        string operatingAirline;
        string arrivalGate;
        string departureGate;
        string flightStatus;
        string equipmentModel;
    }

    struct statuss {
        string flightStatusCode;
        string flightStatusDescription;
        string outUtc;
        string offUtc;
        string onUtc;
        string inUtc;
    }

    mapping(string => FlightData) public flights;
    mapping(string => statuss) public checkFlightStatus;
    mapping(address => uint256) public subscriptions;
    string[] public flightNumbers;

    event FlightDataSet(
        string flightNumber,
        string ArrivalUTC,
        string DepartureUTC,
        string arrivalCity,
        string departureCity,
        string operatingAirline,
        string arrivalGate,
        string departureGate,
        string flightStatus,
        string equipmentModel
    );

    event Subscribed(address indexed user, uint256 expiry);
    event FlightStatusUpdated(
        string flightNumber,
        string flight_times,
        string status
    );

    constructor() {}

    function setFlightData(
        string memory flightNumber,
        string memory ArrivalUTC,
        string memory DepartureUTC,
        string memory arrivalCity,
        string memory departureCity,
        string memory operatingAirline,
        string memory arrivalGate,
        string memory departureGate,
        string memory flightStatus,
        string memory equipmentModel,
        string[] memory data
    ) public {
        flightNumbers.push(flightNumber);
        flights[flightNumber] = FlightData({
            flightNumber: flightNumber,
            ArrivalUTC: ArrivalUTC,
            DepartureUTC: DepartureUTC,
            arrivalCity: arrivalCity,
            departureCity: departureCity,
            operatingAirline: operatingAirline,
            arrivalGate: arrivalGate,
            departureGate: departureGate,
            flightStatus: flightStatus,
            equipmentModel: equipmentModel
        });

        checkFlightStatus[flightNumber] = statuss({
            flightStatusCode: data[0],
            flightStatusDescription: data[1],
            outUtc: data[2],
            offUtc: data[3],
            onUtc: data[4],
            inUtc: data[5]
        });

        emit FlightDataSet(
            flightNumber,
            ArrivalUTC,
            DepartureUTC,
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
        return flights[flightNumber];
    }

    function getFlightStatus(string memory flightNumber)
        public
        returns (string memory)
    {
        statuss memory status = checkFlightStatus[flightNumber];
        string memory newStatus;

        if (
            keccak256(abi.encodePacked(status.flightStatusCode)) ==
            keccak256(abi.encodePacked("NDPT"))
        ) {
            newStatus = "Not Departed";
            emit FlightStatusUpdated(flightNumber, "", "Not Departed");
        } else if (
            keccak256(abi.encodePacked(status.flightStatusCode)) ==
            keccak256(abi.encodePacked("CNCL"))
        ) {
            newStatus = "Cancelled";
            emit FlightStatusUpdated(flightNumber, status.outUtc, "Cancelled");
        } else if (
            keccak256(abi.encodePacked(status.flightStatusCode)) ==
            keccak256(abi.encodePacked("OUT"))
        ) {
            newStatus = "Departed";
            emit FlightStatusUpdated(
                flightNumber,
                status.outUtc,
                "Departed"
            );
        } else if (
            keccak256(abi.encodePacked(status.flightStatusCode)) ==
            keccak256(abi.encodePacked("RTBL"))
        ) {
            newStatus = "Return To Gate";
            emit FlightStatusUpdated(
                flightNumber,
                status.outUtc,
                "Return To Gate"
            );
        } else if (
            keccak256(abi.encodePacked(status.flightStatusCode)) ==
            keccak256(abi.encodePacked("OFF"))
        ) {
            newStatus = "In Flight";
            emit FlightStatusUpdated(flightNumber, status.outUtc, "Departed");
            emit FlightStatusUpdated(flightNumber, status.offUtc, "In Flight");
        } else if (
            keccak256(abi.encodePacked(status.flightStatusCode)) ==
            keccak256(abi.encodePacked("RTFL"))
        ) {
            newStatus = "Return To Airport";
            emit FlightStatusUpdated(flightNumber, status.outUtc, "Departed");
            emit FlightStatusUpdated(flightNumber, status.offUtc, "In Flight");
            emit FlightStatusUpdated(
                flightNumber,
                status.onUtc,
                "Return To Airport"
            );
        } else if (
            keccak256(abi.encodePacked(status.flightStatusCode)) ==
            keccak256(abi.encodePacked("DVRT"))
        ) {
            newStatus = "Diverted";
            emit FlightStatusUpdated(flightNumber, status.outUtc, "Departed");
            emit FlightStatusUpdated(flightNumber, status.offUtc, "In Flight");
            emit FlightStatusUpdated(flightNumber, status.onUtc, "Diverted");
        } else if (
            keccak256(abi.encodePacked(status.flightStatusCode)) ==
            keccak256(abi.encodePacked("ON"))
        ) {
            newStatus = "Landed";
            emit FlightStatusUpdated(flightNumber, status.outUtc, "Departed");
            emit FlightStatusUpdated(flightNumber, status.offUtc, "In Flight");
            emit FlightStatusUpdated(flightNumber, status.onUtc, "Landed");
        } else if (
            keccak256(abi.encodePacked(status.flightStatusCode)) ==
            keccak256(abi.encodePacked("IN"))
        ) {
            newStatus = "Arrived At Gate";
            emit FlightStatusUpdated(flightNumber, status.outUtc, "Departed");
            emit FlightStatusUpdated(flightNumber, status.offUtc, "In Flight");
            emit FlightStatusUpdated(flightNumber, status.onUtc, "Landed");
            emit FlightStatusUpdated(
                flightNumber,
                status.inUtc,
                "Arrived At Gate"
            );
        }

        return newStatus;
    }

    function subscribe(uint256 months) public payable {
        require(months > 0, "Subscription must be for at least 1 month");
        uint256 expiry = block.timestamp + (months * 30 days);
        subscriptions[msg.sender] = expiry;
        emit Subscribed(msg.sender, expiry);
    }
}
