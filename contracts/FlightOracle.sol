// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
        string arrivalDelayMinutes;
        string departureDelayMinutes;
        string baggageClaim;
    }

    struct UTCTimeStruct {
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
        string ArrivalStatus;
        string DepartureStatus;
        string outUtc;
        string offUtc;
        string onUtc;
        string inUtc;
    }

    struct MarketedFlightSegment {
        string MarketingAirlineCode;
        string FlightNumber;
    }

    mapping(string => mapping(string => mapping(string => FlightData)))
        public flights;
    mapping(string => mapping(string => mapping(string => UtcTime)))
        public UtcTimes;
    mapping(string => mapping(string => mapping(string => statuss)))
        public checkFlightStatus;
    mapping(string => mapping(string => mapping(string => MarketedFlightSegment[])))
        public MarketedFlightSegments;
    mapping(string => string) public setStatus;
    mapping(address => mapping(string => mapping(string => mapping(string => bool))))
        public isFlightSubscribed;
    mapping(string => bool) public isFlightExist;
    string[] public flightNumbers;

    // Event for flight data insertion
    event FlightDataSet(
        string flightNumber,
        string scheduledDepartureDate,
        string carrierCode,
        string arrivalCity,
        string departureCity,
        string arrivalAirport,
        string departureAirport,
        string arrivalGate,
        string departureGate,
        string CurrentFlightStatus,
        UTCTimeStruct utcTimes
    );

    // Event for flight status updates
    event FlightStatusUpdate(
        string flightNumber,
        string scheduledDepartureDate,
        string currentFlightStatusTime,
        string carrierCode,
        string FlightStatus,
        string FlightStatusCode
    );

    event SubscriptionDetails(
        string flightNumber,
        address indexed user,
        string carrierCode,
        string departureAirport,
        bool isSubscribe
    );

    event SubscriptionsRemoved(
        address indexed user,
        uint256 numberOfFlightsUnsubscribed
    );

    constructor() {}

    function insertFlightDetails(
        string[] memory flightdata,
        string[] memory Utctimes,
        string[] memory status,
        string[] memory MarketingAirlineCode,
        string[] memory marketingFlightNumber
    ) external {
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
            scheduledDepartureUTC: Utctimes[5],
            arrivalDelayMinutes: Utctimes[6],
            departureDelayMinutes: Utctimes[7],
            baggageClaim: Utctimes[8]
        });

        checkFlightStatus[flightdata[0]][flightdata[1]][
            flightdata[2]
        ] = statuss({
            flightStatusCode: status[0],
            flightStatusDescription: status[1],
            ArrivalStatus: status[2],
            DepartureStatus: status[3],
            outUtc: status[4],
            offUtc: status[5],
            onUtc: status[6],
            inUtc: status[7]
        });

        for (uint256 i = 0; i < MarketingAirlineCode.length; i++) {
            MarketedFlightSegments[flightdata[0]][flightdata[1]][flightdata[2]]
                .push(
                    MarketedFlightSegment(
                        MarketingAirlineCode[i],
                        marketingFlightNumber[i]
                    )
                );
        }

        UTCTimeStruct memory utcEventData = UTCTimeStruct({
            actualArrivalUTC: Utctimes[0],
            actualDepartureUTC: Utctimes[1],
            estimatedArrivalUTC: Utctimes[2],
            estimatedDepartureUTC: Utctimes[3],
            scheduledArrivalUTC: Utctimes[4],
            scheduledDepartureUTC: Utctimes[5]
        });

        // Emit event with the data as received (plain or encrypted)
        emit FlightDataSet(
            flightdata[0],
            flightdata[1],
            flightdata[2],
            flightdata[3],
            flightdata[4],
            flightdata[5],
            flightdata[6],
            flightdata[8],
            flightdata[9],
            flightdata[10],
            utcEventData
        );

        // Store current status
        setStatus[flightdata[0]] = status[1]; // Use flightStatusDescription

        // Emit status update event
        emit FlightStatusUpdate(
            flightdata[0],
            flightdata[1],
            status[7], // Using inUtc as the current time
            flightdata[2],
            status[1], // flightStatusDescription
            status[0]  // flightStatusCode
        );
    }

    // Function to update flight status
    function updateFlightStatus(
        string memory flightNumber,
        string memory scheduledDepartureDate,
        string memory carrierCode,
        string memory currentTime,
        string memory flightStatus,
        string memory flightStatusCode
    ) external {
        require(
            isFlightExist[flightNumber] == true,
            "Flight does not exist"
        );

        // Update status in storage
        checkFlightStatus[flightNumber][scheduledDepartureDate][carrierCode].flightStatusCode = flightStatusCode;
        checkFlightStatus[flightNumber][scheduledDepartureDate][carrierCode].flightStatusDescription = flightStatus;
        
        // Update the current status
        setStatus[flightNumber] = flightStatus;
        
        // Emit the status update event
        emit FlightStatusUpdate(
            flightNumber,
            scheduledDepartureDate,
            currentTime,
            carrierCode,
            flightStatus,
            flightStatusCode
        );
    }

    function getFlightDetails(
        string memory flightNumber,
        string memory scheduledDepartureDate,
        string memory carrierCode
    )
        external
        view
        returns (
            FlightData memory,
            UtcTime memory,
            statuss memory,
            MarketedFlightSegment[] memory,
            string memory
        )
    {
        string memory departureAirport = flights[flightNumber][
            scheduledDepartureDate
        ][carrierCode].departureAirport;
        require(
            isFlightSubscribed[msg.sender][flightNumber][carrierCode][
                departureAirport
            ] == true,
            "You are not a subscribed user"
        );
        uint256 segmentLength = MarketedFlightSegments[flightNumber][
            scheduledDepartureDate
        ][carrierCode].length;
        MarketedFlightSegment[]
            memory setFlightMarketingData = new MarketedFlightSegment[](
                segmentLength
            );
        for (uint256 i = 0; i < segmentLength; i++) {
            setFlightMarketingData[i] = MarketedFlightSegments[flightNumber][
                scheduledDepartureDate
            ][carrierCode][i];
        }
        return (
            flights[flightNumber][scheduledDepartureDate][carrierCode],
            UtcTimes[flightNumber][scheduledDepartureDate][carrierCode],
            checkFlightStatus[flightNumber][scheduledDepartureDate][
                carrierCode
            ],
            setFlightMarketingData,
            setStatus[flightNumber]
        );
    }

    function addFlightSubscription(
        string memory flightNumber,
        string memory carrierCode,
        string memory departureAirport
    ) public payable {
        require(
            isFlightSubscribed[msg.sender][flightNumber][carrierCode][
                departureAirport
            ] == false,
            "you are already Subscribed user"
        );
        require(
            isFlightExist[flightNumber] == true,
            "Flight is not Exist here"
        );
        isFlightSubscribed[msg.sender][flightNumber][carrierCode][
            departureAirport
        ] = true;
        emit SubscriptionDetails(
            flightNumber,
            msg.sender,
            carrierCode,
            departureAirport,
            true
        );
    }

    function removeFlightSubscription(
        string[] memory flightNum,
        string[] memory carrierCode,
        string[] memory departureAirport
    ) public {
        uint256 unsubscribedCount = 0;

        for (uint256 i = 0; i < flightNum.length; i++) {
            string memory flightNumber = flightNum[i];
            string memory carriercode = carrierCode[i];
            string memory departureairport = departureAirport[i];

            if (
                isFlightSubscribed[msg.sender][flightNumber][carriercode][
                    departureairport
                ]
            ) {
                isFlightSubscribed[msg.sender][flightNumber][carriercode][
                    departureairport
                ] = false;
                unsubscribedCount++;

                emit SubscriptionDetails(
                    flightNumber,
                    msg.sender,
                    carriercode,
                    departureairport,
                    false
                );
            }
        }
        emit SubscriptionsRemoved(msg.sender, unsubscribedCount);
    }
}