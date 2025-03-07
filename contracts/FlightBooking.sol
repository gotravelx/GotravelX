// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract FlightStatusOracle {
    struct FlightData {
        string flightNumber;
        string scheduledDepartureDate;
        string carrierCode;
        string arrivalCity;
        string departureCity;
        string arrivalAirport;
        string departureAirport;
        string operatingAirlineCode;
        string arrivalGate;
        string departureGate;
        string flightStatus;
        string equipmentModel;
    }

    struct UtcTime {
        string actualArrivalUTC;
        string actualDepartureUTC;
        string estimatedArrivalUTC;
        string estimatedDepartureUTC;
        string scheduledArrivalUTC;
        string scheduledDepartureUTC;
    }

    struct statuss {
        string flightStatusCode;
        string flightStatusDescription;
        string outUtc;
        string offUtc;
        string onUtc;
        string inUtc;
    }

    mapping(string => mapping(string => mapping(string => FlightData)))
        public flights;
    mapping(string => mapping(string => mapping(string => UtcTime)))
        public UtcTimes;
    mapping(string => mapping(string => mapping(string => statuss)))
        public checkFlightStatus;
    mapping(string => mapping(string => mapping(string => mapping(string => bool))))
        public subscriptions;
    mapping(string => bool) public isFlightExist;
    string[] public flightNumbers;

    event FlightDataSet(
        string flightNumber,
        string scheduledDepartureDate,
        string carrierCode,
        string arrivalCity,
        string departureCity,
        string arrivalAirport,
        string departureAirport,
        string operatingAirlineCode,
        string arrivalGate,
        string departureGate,
        string flightStatus,
        string equipmentModel
    );

    event UTCTimeSet(
        string actualArrivalUTC,
        string actualDepartureUTC,
        string estimatedArrivalUTC,
        string estimatedDepartureUTC,
        string scheduledArrivalUTC,
        string scheduledDepartureUTC
    );

    event SubscriptionDetails(
        string flightNumber,
        address indexed user,
        string carrierCode,
        string scheduledDepartureDate,
        string departureAirport,
        bool isSubscribe
    );
    event currentFlightStatus(
        string flightNumber,
        string scheduledDepartureDate,
        string flight_times,
        string carrierCode,
        string status,
        string statusCode
    );

    constructor() {}

    function insertFlightDetails(
        string[] memory flightdata,
        string[] memory Utctimes,
        string[] memory status
    ) public {
        flightNumbers.push(flightdata[0]);
        isFlightExist[flightdata[0]] = true;
        flights[flightdata[0]][flightdata[1]][flightdata[2]] = FlightData({
            flightNumber: flightdata[0],
            scheduledDepartureDate: flightdata[1],
            carrierCode: flightdata[2],
            arrivalCity: flightdata[3],
            departureCity: flightdata[4],
            arrivalAirport: flightdata[5],
            departureAirport: flightdata[6],
            operatingAirlineCode: flightdata[7],
            arrivalGate: flightdata[8],
            departureGate: flightdata[9],
            flightStatus: flightdata[10],
            equipmentModel: flightdata[11]
        });

        UtcTimes[flightdata[0]][flightdata[1]][flightdata[2]] = UtcTime({
            actualArrivalUTC: Utctimes[0],
            actualDepartureUTC: Utctimes[1],
            estimatedArrivalUTC: Utctimes[2],
            estimatedDepartureUTC: Utctimes[3],
            scheduledArrivalUTC: Utctimes[4],
            scheduledDepartureUTC: Utctimes[5]
        });

        checkFlightStatus[flightdata[0]][flightdata[1]][
            flightdata[2]
        ] = statuss({
            flightStatusCode: status[0],
            flightStatusDescription: status[1],
            outUtc: status[2],
            offUtc: status[3],
            onUtc: status[4],
            inUtc: status[5]
        });

        emit FlightDataSet(
            flightdata[0],
            flightdata[1],
            flightdata[2],
            flightdata[3],
            flightdata[4],
            flightdata[5],
            flightdata[6],
            flightdata[7],
            flightdata[8],
            flightdata[9],
            flightdata[10],
            flightdata[11]
        );

        emit UTCTimeSet(
            Utctimes[0],
            Utctimes[1],
            Utctimes[2],
            Utctimes[3],
            Utctimes[4],
            Utctimes[5]
        );
    }

    function getFlightDetails(
        string memory flightNumber,
        string memory scheduledDepartureDate,
        string memory carrierCode
    ) public view returns (FlightData memory) {
        string memory departureAirport = flights[flightNumber][
            scheduledDepartureDate
        ][carrierCode].departureAirport;
        require(
            subscriptions[flightNumber][carrierCode][departureAirport][
                scheduledDepartureDate
            ] == true,
            "You are not a subscribed user"
        );
        return flights[flightNumber][scheduledDepartureDate][carrierCode];
    }

    function getFlightStatus(
        string memory flightNumber,
        string memory scheduledDepartureDate,
        string memory carrierCode
    ) public returns (string memory) {
        string memory departureAirport = flights[flightNumber][
            scheduledDepartureDate
        ][carrierCode].departureAirport;
        require(
            subscriptions[flightNumber][carrierCode][departureAirport][
                scheduledDepartureDate
            ] == true,
            "You are not a subscribed user"
        );
        statuss memory status = checkFlightStatus[flightNumber][
            scheduledDepartureDate
        ][carrierCode];
        string memory newStatus;

        if (
            keccak256(abi.encodePacked(status.flightStatusCode)) ==
            keccak256(abi.encodePacked("NDPT"))
        ) {
            newStatus = "Not Departed";
            emit currentFlightStatus(
                flightNumber,
                scheduledDepartureDate,
                "",
                carrierCode,
                "Not Departed",
                "NDPT"
            );
        } else if (
            keccak256(abi.encodePacked(status.flightStatusCode)) ==
            keccak256(abi.encodePacked("CNCL"))
        ) {
            newStatus = "Cancelled";
            emit currentFlightStatus(
                flightNumber,
                scheduledDepartureDate,
                status.outUtc,
                carrierCode,
                "Cancelled",
                "CNCL"
            );
        } else if (
            keccak256(abi.encodePacked(status.flightStatusCode)) ==
            keccak256(abi.encodePacked("OUT"))
        ) {
            newStatus = "Departed";
            emit currentFlightStatus(
                flightNumber,
                scheduledDepartureDate,
                status.outUtc,
                carrierCode,
                "Departed",
                "OUT"
            );
        } else if (
            keccak256(abi.encodePacked(status.flightStatusCode)) ==
            keccak256(abi.encodePacked("RTBL"))
        ) {
            newStatus = "Return To Gate";
            emit currentFlightStatus(
                flightNumber,
                scheduledDepartureDate,
                status.outUtc,
                carrierCode,
                "Return To Gate",
                "RTBL"
            );
        } else if (
            keccak256(abi.encodePacked(status.flightStatusCode)) ==
            keccak256(abi.encodePacked("OFF"))
        ) {
            newStatus = "In Flight";
            emit currentFlightStatus(
                flightNumber,
                scheduledDepartureDate,
                status.outUtc,
                carrierCode,
                "Departed",
                "OUT"
            );
            emit currentFlightStatus(
                flightNumber,
                scheduledDepartureDate,
                status.offUtc,
                carrierCode,
                "In Flight",
                "OFF"
            );
        } else if (
            keccak256(abi.encodePacked(status.flightStatusCode)) ==
            keccak256(abi.encodePacked("RTFL"))
        ) {
            newStatus = "Return To Airport";
            emit currentFlightStatus(
                flightNumber,
                scheduledDepartureDate,
                status.outUtc,
                carrierCode,
                "Departed",
                "OUT"
            );
            emit currentFlightStatus(
                flightNumber,
                scheduledDepartureDate,
                status.offUtc,
                carrierCode,
                "In Flight",
                "OFF"
            );
            emit currentFlightStatus(
                flightNumber,
                scheduledDepartureDate,
                status.onUtc,
                carrierCode,
                "Return To Airport",
                "RTFL"
            );
        } else if (
            keccak256(abi.encodePacked(status.flightStatusCode)) ==
            keccak256(abi.encodePacked("DVRT"))
        ) {
            newStatus = "Diverted";
            emit currentFlightStatus(
                flightNumber,
                scheduledDepartureDate,
                status.outUtc,
                carrierCode,
                "Departed",
                "OUT"
            );
            emit currentFlightStatus(
                flightNumber,
                scheduledDepartureDate,
                status.offUtc,
                carrierCode,
                "In Flight",
                "OFF"
            );
            emit currentFlightStatus(
                flightNumber,
                scheduledDepartureDate,
                status.onUtc,
                carrierCode,
                "Diverted",
                "DVRT"
            );
        } else if (
            keccak256(abi.encodePacked(status.flightStatusCode)) ==
            keccak256(abi.encodePacked("ON"))
        ) {
            newStatus = "Landed";
            emit currentFlightStatus(
                flightNumber,
                scheduledDepartureDate,
                status.outUtc,
                carrierCode,
                "Departed",
                "OUT"
            );
            emit currentFlightStatus(
                flightNumber,
                scheduledDepartureDate,
                status.offUtc,
                carrierCode,
                "In Flight",
                "OFF"
            );
            emit currentFlightStatus(
                flightNumber,
                scheduledDepartureDate,
                status.onUtc,
                carrierCode,
                "Landed",
                "ON"
            );
        } else if (
            keccak256(abi.encodePacked(status.flightStatusCode)) ==
            keccak256(abi.encodePacked("IN"))
        ) {
            newStatus = "Arrived At Gate";
            emit currentFlightStatus(
                flightNumber,
                scheduledDepartureDate,
                status.outUtc,
                carrierCode,
                "Departed",
                "OUT"
            );
            emit currentFlightStatus(
                flightNumber,
                scheduledDepartureDate,
                status.offUtc,
                carrierCode,
                "In Flight",
                "OFF"
            );
            emit currentFlightStatus(
                flightNumber,
                scheduledDepartureDate,
                status.onUtc,
                carrierCode,
                "Landed",
                "ON"
            );
            emit currentFlightStatus(
                flightNumber,
                scheduledDepartureDate,
                status.inUtc,
                carrierCode,
                "Arrived At Gate",
                "IN"
            );
        }

        return newStatus;
    }

    function addFlightSubscription(
        string memory flightNumber,
        string memory carrierCode,
        string memory departureAirport,
        string memory scheduledDepartureDate
    ) public payable {
        require(
            subscriptions[flightNumber][carrierCode][departureAirport][
                scheduledDepartureDate
            ] == false,
            "you are already Subscribed user"
        );
        require(
            isFlightExist[flightNumber] == true,
            "Flight is not Exist here"
        );
        subscriptions[flightNumber][carrierCode][departureAirport][
            scheduledDepartureDate
        ] = true;
        emit SubscriptionDetails(
            flightNumber,
            msg.sender,
            carrierCode,
            scheduledDepartureDate,
            departureAirport,
            true
        );
    }

    function removeFlightSubscription(
        string memory flightNumber,
        string memory carrierCode,
        string memory departureAirport,
        string memory scheduledDepartureDate
    ) public {
        require(
            subscriptions[flightNumber][carrierCode][departureAirport][
                scheduledDepartureDate
            ] == true,
            "You are not a subscribed user"
        );
        subscriptions[flightNumber][carrierCode][departureAirport][
            scheduledDepartureDate
        ] = false;
        emit SubscriptionDetails(
            flightNumber,
            msg.sender,
            carrierCode,
            scheduledDepartureDate,
            departureAirport,
            false
        );
    }
}
