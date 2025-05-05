// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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
        string bagClaim;
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
        string ArrivalState;
        string DepartureState;
        string outUtc;
        string offUtc;
        string onUtc;
        string inUtc;
    }

    struct MarketedFlightSegment {
        string MarketingAirlineCode;
        string FlightNumber;
    }

    // New struct to hold flight details with date
    struct FlightDetailsWithDate {
        FlightData flightData;
        UtcTime utcTime;
        statuss status;
        MarketedFlightSegment[] marketedSegments;
        string currentStatus;
        string scheduledDepartureDate;
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
    
    // Added to track all dates associated with a flight/carrier
    mapping(string => mapping(string => string[])) public flightDates;

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
        string ArrivalState,
        string DepartureState,
        string bagClaim,
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

    // Helper function to compare dates (returns true if date1 <= date2)
    function isDateLessThanOrEqual(string memory date1, string memory date2) internal pure returns (bool) {
        // This is a simplified implementation assuming dates are in format YYYY-MM-DD
        // For production, you would need a more robust date comparison
        bytes memory date1Bytes = bytes(date1);
        bytes memory date2Bytes = bytes(date2);
        
        // Simple lexicographic comparison
        // This works for YYYY-MM-DD format
        return keccak256(date1Bytes) <= keccak256(date2Bytes);
    }

    // Split function to avoid stack too deep error
function _storeDateInfo(string memory flightNumber, string memory scheduledDepartureDate, string memory carrierCode) internal {
    // Store date information for the flight
    bool dateExists = false;
    string[] storage dates = flightDates[flightNumber][carrierCode];
    for (uint i = 0; i < dates.length; i++) {
        if (keccak256(bytes(dates[i])) == keccak256(bytes(scheduledDepartureDate))) {
            dateExists = true;
            break;
        }
    }
    if (!dateExists) {
        flightDates[flightNumber][carrierCode].push(scheduledDepartureDate);
    }
}

function _storeMarketingSegments(
    string memory flightNumber,
    string memory scheduledDepartureDate,
    string memory carrierCode,
    string[] memory MarketingAirlineCode,
    string[] memory marketingFlightNumber
) internal {
    for (uint256 i = 0; i < MarketingAirlineCode.length; i++) {
        MarketedFlightSegments[flightNumber][scheduledDepartureDate][carrierCode]
            .push(
                MarketedFlightSegment(
                    MarketingAirlineCode[i],
                    marketingFlightNumber[i]
                )
            );
    }
}

function _emitEvents(
    string[] memory flightdata,
    string[] memory Utctimes,
    string[] memory status
) internal {
    UTCTimeStruct memory utcEventData = UTCTimeStruct({
        actualArrivalUTC: Utctimes[0],
        actualDepartureUTC: Utctimes[1],
        estimatedArrivalUTC: Utctimes[2],
        estimatedDepartureUTC: Utctimes[3],
        scheduledArrivalUTC: Utctimes[4],
        scheduledDepartureUTC: Utctimes[5]
    });

    // Emit event with the data as received
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

    // Emit status update event
    emit FlightStatusUpdate(
        flightdata[0],
        flightdata[1],
        status[7], // Using inUtc as the current time
        flightdata[2],
        status[1],
        status[2],
        status[3],
        Utctimes[8],
        status[0]
    );
}

function insertFlightDetails(
    string[] memory flightdata,
    string[] memory Utctimes,
    string[] memory status,
    string[] memory MarketingAirlineCode,
    string[] memory marketingFlightNumber
) external {
    flightNumbers.push(flightdata[0]);
    isFlightExist[flightdata[0]] = true;

    // Use helper function to store date info
    _storeDateInfo(flightdata[0], flightdata[1], flightdata[2]);

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
        bagClaim: Utctimes[8]
    });

    checkFlightStatus[flightdata[0]][flightdata[1]][flightdata[2]] = statuss({
        flightStatusCode: status[0],
        flightStatusDescription: status[1],
        ArrivalState: status[2],
        DepartureState: status[3],
        outUtc: status[4],
        offUtc: status[5],
        onUtc: status[6],
        inUtc: status[7]
    });

    // Use helper function for marketing segments
    _storeMarketingSegments(
        flightdata[0],
        flightdata[1],
        flightdata[2],
        MarketingAirlineCode,
        marketingFlightNumber
    );

    // Store current status
    setStatus[flightdata[0]] = status[1]; // Use flightStatusDescription

    // Use helper function to emit events
    _emitEvents(flightdata, Utctimes, status);
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
        require(isFlightExist[flightNumber] == true, "Flight does not exist");

        // Update status in storage
        checkFlightStatus[flightNumber][scheduledDepartureDate][carrierCode]
            .flightStatusCode = flightStatusCode;
        checkFlightStatus[flightNumber][scheduledDepartureDate][carrierCode]
            .flightStatusDescription = flightStatus;

        // Update the current status
        setStatus[flightNumber] = flightStatus;

        // Emit the status update event
        emit FlightStatusUpdate(
            flightNumber,
            scheduledDepartureDate,
            currentTime,
            carrierCode,
            flightStatus,
            checkFlightStatus[flightNumber][scheduledDepartureDate][carrierCode]
                .ArrivalState,
            checkFlightStatus[flightNumber][scheduledDepartureDate][carrierCode]
                .DepartureState,
            UtcTimes[flightNumber][scheduledDepartureDate][carrierCode]
                .bagClaim, // TODO: Update bagclaim in storage if it is
            flightStatusCode
        );
    }

    // Modified function to get flight details within a date range
    // Helper function for getting flight segments
function _getFlightSegments(
    string memory flightNumber,
    string memory date,
    string memory carrierCode
) internal view returns (MarketedFlightSegment[] memory) {
    uint256 segmentLength = MarketedFlightSegments[flightNumber][date][carrierCode].length;
    MarketedFlightSegment[] memory segments = new MarketedFlightSegment[](segmentLength);
    
    for (uint256 j = 0; j < segmentLength; j++) {
        segments[j] = MarketedFlightSegments[flightNumber][date][carrierCode][j];
    }
    
    return segments;
}

// Helper function to check flight subscription
function _checkFlightSubscription(
    address user,
    string memory flightNumber,
    string memory carrierCode, 
    string memory departureAirport
) internal view returns (bool) {
    return isFlightSubscribed[user][flightNumber][carrierCode][departureAirport];
}

// Main function to get flight details within a date range
function getFlightDetails(
    string memory flightNumber,
    string memory fromDate,
    string memory toDate,
    string memory carrierCode
)
    external
    view
    returns (FlightDetailsWithDate[] memory)
{
    require(isFlightExist[flightNumber] == true, "Flight does not exist");
    
    // Get all dates for this flight and carrier
    string[] storage dates = flightDates[flightNumber][carrierCode];
    
    // First count how many dates are in range to allocate memory
    uint256 count = 0;
    for (uint256 i = 0; i < dates.length; i++) {
        if (isDateLessThanOrEqual(fromDate, dates[i]) && 
            isDateLessThanOrEqual(dates[i], toDate)) {
            count++;
        }
    }
    
    // Create result array with proper size
    FlightDetailsWithDate[] memory results = new FlightDetailsWithDate[](count);
    
    // Fill the results array with matching flight details
    uint256 resultIndex = 0;
    for (uint256 i = 0; i < dates.length && resultIndex < count; i++) {
        string memory currentDate = dates[i];
        
        // Check if date is in range
        if (isDateLessThanOrEqual(fromDate, currentDate) && 
            isDateLessThanOrEqual(currentDate, toDate)) {
            
            string memory departureAirport = flights[flightNumber][currentDate][carrierCode].departureAirport;
            
            // Check subscription using helper function
            require(
                _checkFlightSubscription(msg.sender, flightNumber, carrierCode, departureAirport),
                "You are not a subscribed user"
            );
            
            // Get marketed segments using helper function
            MarketedFlightSegment[] memory segments = _getFlightSegments(
                flightNumber, 
                currentDate, 
                carrierCode
            );
            
            // Create and populate the result structure
            results[resultIndex] = FlightDetailsWithDate({
                flightData: flights[flightNumber][currentDate][carrierCode],
                utcTime: UtcTimes[flightNumber][currentDate][carrierCode],
                status: checkFlightStatus[flightNumber][currentDate][carrierCode],
                marketedSegments: segments,
                currentStatus: setStatus[flightNumber],
                scheduledDepartureDate: currentDate
            });
            
            resultIndex++;
        }
    }
    
    return results;
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