// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract FlightStatusOracle {
    struct FlightData {
        string flightNumber;
        string arrivalCity;
        string departureCity;
        string operatingAirline;
        string arrivalGate;
        string departureGate;
        string flightStatus;
        string equipmentModel;
    }

    struct UtcTime {
        string ArrivalUTC;
        string DepartureUTC;
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

    mapping(string => FlightData) public flights;
    mapping(string => UtcTime) public UtcTimes;
    mapping(string => statuss) public checkFlightStatus;
    mapping(address => uint256) public subscriptions;
    string[] public flightNumbers;

    event FlightDataSet(
        string flightNumber,
        string arrivalCity,
        string departureCity,
        string operatingAirline,
        string arrivalGate,
        string departureGate,
        string flightStatus,
        string equipmentModel
    );

    event UTCTimeSet(
        string ArrivalUTC,
        string DepartureUTC,
        string estimatedArrivalUTC,
        string estimatedDepartureUTC,
        string scheduledArrivalUTC,
        string scheduledDepartureUTC
    );

    event Subscribed(address indexed user, uint256 expiry);
    event FlightStatusUpdated(
        string flightNumber,
        string flight_times,
        string status
    );

    constructor() {}

    function setFlightData(
        string[] memory flightdata,
        string[] memory Utctimes,
        string[] memory status
    ) public {
        flightNumbers.push(flightdata[0]);

        flights[flightdata[0]] = FlightData({
            flightNumber: flightdata[0],
            arrivalCity: flightdata[1],
            departureCity: flightdata[2],
            operatingAirline: flightdata[3],
            arrivalGate: flightdata[4],
            departureGate: flightdata[5],
            flightStatus: flightdata[6],
            equipmentModel: flightdata[7]
        });

        UtcTimes[flightdata[0]] = UtcTime({
            ArrivalUTC: Utctimes[0],
            DepartureUTC: Utctimes[1],
            estimatedArrivalUTC: Utctimes[2],
            estimatedDepartureUTC: Utctimes[3],
            scheduledArrivalUTC: Utctimes[4],
            scheduledDepartureUTC: Utctimes[5]
        });

        checkFlightStatus[flightdata[0]] = statuss({
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
            flightdata[7]
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
        require(
            subscriptions[msg.sender] > block.timestamp,
            "You are not a subscribed user or subscription expired"
        );
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
            emit FlightStatusUpdated(flightNumber, status.outUtc, "Departed");
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
