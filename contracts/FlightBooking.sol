// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

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

    struct statuss {
        string flightStatusCode;
        string flightStatusDescription;
        string outUtc;
        string offUtc;
        string onUtc;
        string inUtc;
    }

    // New struct for combining flight details for the allSubscribedFlightDetails function
    struct CompleteFlightDetails {
        FlightData flightData;
        UtcTime utcTime;
        statuss status;
        string currentStatus;
    }

    mapping(string => mapping(string => mapping(string => FlightData)))
        public flights;
    mapping(string => mapping(string => mapping(string => UtcTime)))
        public UtcTimes;
    mapping(string => mapping(string => mapping(string => statuss)))
        public checkFlightStatus;
    mapping(string => string) public setStatus;
    mapping(address => mapping(string => bool)) public isFlightSubscribed;
    mapping(string => bool) public isFlightExist;
    string[] public flightNumbers;

    // New mapping to store flight parameters for each subscribed flight
    // address => flightNumber => (scheduledDepartureDate, carrierCode)
    mapping(address => mapping(string => string[]))
        private subscribedFlightParams;

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
        string flightStatus
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
        string currentFlightStatusTime,
        string carrierCode,
        string status,
        string statusCode
    );

    // New event for mass unsubscription
    event AllSubscriptionsRemoved(
        address indexed user,
        uint256 numberOfFlightsUnsubscribed
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
            outUtc: status[2],
            offUtc: status[3],
            onUtc: status[4],
            inUtc: status[5]
        });

        statuss memory st = checkFlightStatus[flightdata[0]][flightdata[1]][
            flightdata[2]
        ];
        string memory newStatus;

        if (
            keccak256(abi.encodePacked(st.flightStatusCode)) ==
            keccak256(abi.encodePacked("NDPT"))
        ) {
            newStatus = "Not Departed";
            emit currentFlightStatus(
                flightdata[0],
                flightdata[1],
                "",
                flightdata[2],
                "Not Departed",
                "NDPT"
            );
        } else if (
            keccak256(abi.encodePacked(st.flightStatusCode)) ==
            keccak256(abi.encodePacked("CNCL"))
        ) {
            newStatus = "Cancelled";
            emit currentFlightStatus(
                flightdata[0],
                flightdata[1],
                st.outUtc,
                flightdata[2],
                "Cancelled",
                "CNCL"
            );
        } else if (
            keccak256(abi.encodePacked(st.flightStatusCode)) ==
            keccak256(abi.encodePacked("OUT"))
        ) {
            newStatus = "Departed";
            emit currentFlightStatus(
                flightdata[0],
                flightdata[1],
                st.outUtc,
                flightdata[2],
                "Departed",
                "OUT"
            );
        } else if (
            keccak256(abi.encodePacked(st.flightStatusCode)) ==
            keccak256(abi.encodePacked("RTBL"))
        ) {
            newStatus = "Return To Gate";
            emit currentFlightStatus(
                flightdata[0],
                flightdata[1],
                st.outUtc,
                flightdata[2],
                "Return To Gate",
                "RTBL"
            );
        } else if (
            keccak256(abi.encodePacked(st.flightStatusCode)) ==
            keccak256(abi.encodePacked("OFF"))
        ) {
            newStatus = "In Flight";
            emit currentFlightStatus(
                flightdata[0],
                flightdata[1],
                st.outUtc,
                flightdata[2],
                "Departed",
                "OUT"
            );
            emit currentFlightStatus(
                flightdata[0],
                flightdata[1],
                st.offUtc,
                flightdata[2],
                "In Flight",
                "OFF"
            );
        } else if (
            keccak256(abi.encodePacked(st.flightStatusCode)) ==
            keccak256(abi.encodePacked("RTFL"))
        ) {
            newStatus = "Return To Airport";
            emit currentFlightStatus(
                flightdata[0],
                flightdata[1],
                st.outUtc,
                flightdata[2],
                "Departed",
                "OUT"
            );
            emit currentFlightStatus(
                flightdata[0],
                flightdata[1],
                st.offUtc,
                flightdata[2],
                "In Flight",
                "OFF"
            );
            emit currentFlightStatus(
                flightdata[0],
                flightdata[1],
                st.onUtc,
                flightdata[2],
                "Return To Airport",
                "RTFL"
            );
        } else if (
            keccak256(abi.encodePacked(st.flightStatusCode)) ==
            keccak256(abi.encodePacked("DVRT"))
        ) {
            newStatus = "Diverted";
            emit currentFlightStatus(
                flightdata[0],
                flightdata[1],
                st.outUtc,
                flightdata[2],
                "Departed",
                "OUT"
            );
            emit currentFlightStatus(
                flightdata[0],
                flightdata[1],
                st.offUtc,
                flightdata[2],
                "In Flight",
                "OFF"
            );
            emit currentFlightStatus(
                flightdata[0],
                flightdata[1],
                st.onUtc,
                flightdata[2],
                "Diverted",
                "DVRT"
            );
        } else if (
            keccak256(abi.encodePacked(st.flightStatusCode)) ==
            keccak256(abi.encodePacked("ON"))
        ) {
            newStatus = "Landed";
            emit currentFlightStatus(
                flightdata[0],
                flightdata[1],
                st.outUtc,
                flightdata[2],
                "Departed",
                "OUT"
            );
            emit currentFlightStatus(
                flightdata[0],
                flightdata[1],
                st.offUtc,
                flightdata[2],
                "In Flight",
                "OFF"
            );
            emit currentFlightStatus(
                flightdata[0],
                flightdata[1],
                st.onUtc,
                flightdata[2],
                "Landed",
                "ON"
            );
        } else if (
            keccak256(abi.encodePacked(st.flightStatusCode)) ==
            keccak256(abi.encodePacked("IN"))
        ) {
            newStatus = "Arrived At Gate";
            emit currentFlightStatus(
                flightdata[0],
                flightdata[1],
                st.outUtc,
                flightdata[2],
                "Departed",
                "OUT"
            );
            emit currentFlightStatus(
                flightdata[0],
                flightdata[1],
                st.offUtc,
                flightdata[2],
                "In Flight",
                "OFF"
            );
            emit currentFlightStatus(
                flightdata[0],
                flightdata[1],
                st.onUtc,
                flightdata[2],
                "Landed",
                "ON"
            );
            emit currentFlightStatus(
                flightdata[0],
                flightdata[1],
                st.inUtc,
                flightdata[2],
                "Arrived At Gate",
                "IN"
            );
        }

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
            flightdata[10]
        );

        emit UTCTimeSet(
            Utctimes[0],
            Utctimes[1],
            Utctimes[2],
            Utctimes[3],
            Utctimes[4],
            Utctimes[5]
        );

        setStatus[flightdata[0]] = newStatus;
    }

    function getFlightDetails(
        string memory flightNumber,
        string memory scheduledDepartureDate,
        string memory carrierCode
    )
        public
        view
        returns (
            FlightData memory,
            UtcTime memory,
            statuss memory,
            string memory
        )
    {
        require(
            isFlightSubscribed[msg.sender][flightNumber] == true,
            "You are not a subscribed user"
        );
        return (
            flights[flightNumber][scheduledDepartureDate][carrierCode],
            UtcTimes[flightNumber][scheduledDepartureDate][carrierCode],
            checkFlightStatus[flightNumber][scheduledDepartureDate][
                carrierCode
            ],
            setStatus[flightNumber]
        );
    }

    function addFlightSubscription(
        string memory flightNumber,
        string memory carrierCode,
        string memory departureAirport,
        string memory scheduledDepartureDate
    ) public payable {
        require(
            isFlightSubscribed[msg.sender][flightNumber] == false,
            "you are already Subscribed user"
        );
        require(
            isFlightExist[flightNumber] == true,
            "Flight is not Exist here"
        );
        isFlightSubscribed[msg.sender][flightNumber] = true;

        // Store the flight parameters for later retrieval
        string[] memory params = new string[](2);
        params[0] = scheduledDepartureDate;
        params[1] = carrierCode;
        subscribedFlightParams[msg.sender][flightNumber] = params;

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
            isFlightSubscribed[msg.sender][flightNumber] == true,
            "You are not a subscribed user"
        );
        isFlightSubscribed[msg.sender][flightNumber] = false;

        // Remove the flight parameters
        delete subscribedFlightParams[msg.sender][flightNumber];

        emit SubscriptionDetails(
            flightNumber,
            msg.sender,
            carrierCode,
            scheduledDepartureDate,
            departureAirport,
            false
        );
    }

    // Function to get all subscribed flight numbers for a user
    function getUserSubscribedFlights() public view returns (string[] memory) {
        uint256 count = 0;

        // Count number of subscribed flights
        for (uint256 i = 0; i < flightNumbers.length; i++) {
            if (isFlightSubscribed[msg.sender][flightNumbers[i]]) {
                count++;
            }
        }

        // Create array of proper size
        string[] memory userFlights = new string[](count);

        // Fill array with subscribed flight numbers
        uint256 index = 0;
        for (uint256 i = 0; i < flightNumbers.length; i++) {
            if (isFlightSubscribed[msg.sender][flightNumbers[i]]) {
                userFlights[index] = flightNumbers[i];
                index++;
            }
        }

        return userFlights;
    }

    // Function to get details of all flights a user has subscribed to
    function allSubscribedFlightDetails()
        public
        view
        returns (CompleteFlightDetails[] memory)
    {
        string[] memory userFlights = getUserSubscribedFlights();
        CompleteFlightDetails[] memory allDetails = new CompleteFlightDetails[](
            userFlights.length
        );

        for (uint256 i = 0; i < userFlights.length; i++) {
            string memory flightNumber = userFlights[i];
            string[] memory params = subscribedFlightParams[msg.sender][
                flightNumber
            ];

            // If we have the parameters stored
            if (params.length == 2) {
                string memory scheduledDepartureDate = params[0];
                string memory carrierCode = params[1];

                allDetails[i] = CompleteFlightDetails({
                    flightData: flights[flightNumber][scheduledDepartureDate][
                        carrierCode
                    ],
                    utcTime: UtcTimes[flightNumber][scheduledDepartureDate][
                        carrierCode
                    ],
                    status: checkFlightStatus[flightNumber][
                        scheduledDepartureDate
                    ][carrierCode],
                    currentStatus: setStatus[flightNumber]
                });
            }
        }

        return allDetails;
    }

 // Modified function to remove specific subscribed flights for a user
function removeAllSubscribedFlight(string[] memory flightNum) public {
    uint256 unsubscribedCount = 0;

    for (uint256 i = 0; i < flightNum.length; i++) {
        string memory flightNumber = flightNum[i];
        
        // Check if the user is subscribed to this flight
        if (isFlightSubscribed[msg.sender][flightNumber]) {
            // Get the parameters for the flight
            string[] memory params = subscribedFlightParams[msg.sender][flightNumber];

            // If parameters exist, use them to emit the unsubscription event
            if (params.length == 2) {
                string memory scheduledDepartureDate = params[0];
                string memory carrierCode = params[1];

                // Get the flight data for departureAirport (needed for the event)
                FlightData memory flightData = flights[flightNumber][
                    scheduledDepartureDate
                ][carrierCode];

                // Emit unsubscription event
                emit SubscriptionDetails(
                    flightNumber,
                    msg.sender,
                    carrierCode,
                    scheduledDepartureDate,
                    flightData.departureAirport,
                    false
                );

                // Remove the flight parameters
                delete subscribedFlightParams[msg.sender][flightNumber];
            }

            // Update the subscription status
            isFlightSubscribed[msg.sender][flightNumber] = false;
            unsubscribedCount++;
        }
    }

    // Emit event for mass unsubscription
    emit AllSubscriptionsRemoved(msg.sender, unsubscribedCount);
}
}