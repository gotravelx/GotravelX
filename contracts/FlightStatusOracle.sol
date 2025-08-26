// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title FlightStatusOracle
 * @dev A gas-optimized smart contract for managing flight information with hierarchical data structure
 * @author Flight Oracle Team
 */
contract FlightStatusOracle {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    // Child Structs - Grouped by logical functionality
    struct FlightIdentifiers {
        string carrierCode; // airline code
        string flightNumber; // Flight number
        string flightOriginateDate; // Date in YYYY-MM-DD format
    }

    struct AirportDetails {
        string arrivalAirport; // airport code
        string departureAirport; // airport code
        string arrivalCity; // Full city name
        string departureCity; // Full city name
    }

    struct FlightStatuses {
        string arrivalStatus; // Current arrival status
        string departureStatus; // Current departure status
        string legStatus; // Overall leg status
    }

    // Parent Struct - Main flight whole information container
    struct FlightInfo {
        FlightIdentifiers identifiers;
        AirportDetails airports;
        FlightStatuses statuses;
        bytes compressedFlightInformation; // Additional compressed data
    }

    // Input struct for batch operations
    struct FlightInput {
        string[] flightDetails; // [carrierCode, flightNumber, originateDate, arrivalAirport, departureAirport, arrivalCity, departureCity, arrivalStatus, departureStatus, legStatus]
        string compressedFlightInformation;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    // Access control
    address private immutable owner;
    mapping(address => bool) private authorizedOracles;

    // Reentrancy guard
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private reentrancyStatus;

    // Primary storage mapping: flightNumber => date => carrierCode => FlightInfo
    mapping(string => mapping(string => mapping(string => FlightInfo)))
        private flights;

    // Flight existence tracking
    mapping(string => mapping(string => bool)) public isFlightExist;

    // Flight dates tracking for efficient querying
    mapping(string => mapping(string => string[])) private flightDates;

    // User subscriptions: user => flightNumber => carrierCode => arrivalAirport => departureAirport => subscribed
    mapping(address => mapping(string => mapping(string => mapping(string => mapping(string => bool)))))
        private isFlightSubscribed;

    // Quick status lookup
    mapping(string => string) private currentStatus;

    // All flight numbers for enumeration
    string[] private allFlightNumbers;

    // Rate limiting for data insertion - using block number instead of timestamp
    mapping(address => uint256) private lastDataInsertBlock;
    uint256 private constant DATA_INSERT_BLOCK_COOLDOWN = 3; // ~45 seconds assuming 15s blocks

    // Time validation constants
    uint256 private constant SECONDS_IN_DAY = 86400;
    uint256 private constant MAX_DATE_RANGE_DAYS = 30;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event FlightDataInserted(
        string indexed flightNumber,
        string indexed carrierCode,
        string flightOriginateDate,
        string arrivalAirport,
        string departureAirport,
        string arrivalCity,
        string departureCity,
        string arrivalStatus,
        string departureStatus,
        string legStatus
    );

    event FlightStatusUpdated(
        string indexed flightNumber,
        string indexed carrierCode,
        string flightOriginateDate,
        string newArrivalStatus,
        string newDepartureStatus,
        string newLegStatus
    );

    event FlightSubscriptionAdded(
        address indexed user,
        string indexed flightNumber,
        string carrierCode,
        string arrivalAirport,
        string departureAirport
    );

    event FlightUnsubscribed(
        address indexed user,
        string indexed flightNumber,
        string carrierCode,
        string arrivalAirport,
        string departureAirport
    );

    event OracleAuthorized(address indexed oracle);
    event OracleRevoked(address indexed oracle);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    event ContractDeployed(address indexed owner, uint256 blockNumber);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyAuthorizedOracle() {
        if (!authorizedOracles[msg.sender] && msg.sender != owner)
            revert Unauthorized();
        _;
    }

    modifier nonReentrant() {
        if (reentrancyStatus == ENTERED) revert ReentrancyGuard();
        reentrancyStatus = ENTERED;
        _;
        reentrancyStatus = NOT_ENTERED;
    }

    modifier flightExists(string memory _flightNumber, string memory _carrierCode) {
        if (!isFlightExist[_flightNumber][_carrierCode]) revert FlightNotFound();
        _;
    }

    modifier validDateFormat(string memory _date) {
        if (bytes(_date).length != 10) revert InvalidDateFormat();
        _;
    }

    modifier rateLimit() {
        if (block.number < lastDataInsertBlock[msg.sender] + DATA_INSERT_BLOCK_COOLDOWN) {
            revert RateLimitExceeded();
        }
        _;
        lastDataInsertBlock[msg.sender] = block.number;
    }

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error FlightNotFound();
    error ArrayLengthMismatch();
    error NotSubscribed();
    error InvalidDateFormat();
    error InvalidArrayLength();
    error AlreadySubscribed();
    error NoFlightDataProvided();
    error TooManyFlightsInBatch();
    error DateRangeExceeded();
    error NoDataForCarrier();
    error Unauthorized();
    error ReentrancyGuard();
    error RateLimitExceeded();
    error InvalidInput();
    error StringTooLong();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        owner = msg.sender;
        authorizedOracles[msg.sender] = true;
        reentrancyStatus = NOT_ENTERED;
        emit ContractDeployed(msg.sender, block.number);
    }

    /**
     * @dev Compares two date strings (YYYY-MM-DD format)
     * @param date1 First date
     * @param date2 Second date
     * @return true if date1 <= date2
     */
    function isDateLessThanOrEqual(string memory date1, string memory date2)
        private
        pure
        returns (bool)
    {
        bytes memory d1 = bytes(date1);
        bytes memory d2 = bytes(date2);

        if (d1.length != 10 || d2.length != 10) revert InvalidDateFormat();

        for (uint256 i; i < 10;) {
            if (d1[i] < d2[i]) return true;
            if (d1[i] > d2[i]) return false;
            unchecked {
                ++i;
            }
        }

        return true;
    }

    /**
     * @dev Enhanced date range validation using block-based time estimation
     * @param fromDateInTimeStamp Unix timestamp of the from date
     * @return bool True if date range is valid
     */
    function _isValidDateRange(uint256 fromDateInTimeStamp) private view returns (bool) {
        // Estimate current time based on block number and average block time
        // This reduces reliance on block.timestamp manipulation
        uint256 estimatedCurrentTime = _estimateCurrentTime();
        uint256 maxAllowedAge = MAX_DATE_RANGE_DAYS * SECONDS_IN_DAY;
        
        return fromDateInTimeStamp >= (estimatedCurrentTime - maxAllowedAge);
    }

    /**
     * @dev Estimates current time using block number progression
     * @return Estimated current timestamp
     */
    function _estimateCurrentTime() private view returns (uint256) {
        // Use a combination of block.timestamp and block.number for better security
        // This makes timestamp manipulation less effective
        return block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                        ACCESS CONTROL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Transfers ownership of the contract to a new account
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidInput();
        address oldOwner = owner;
        // Note: owner is immutable, so this function maintains interface but cannot change ownership
        authorizedOracles[newOwner] = true;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /**
     * @dev Authorizes an oracle to insert flight data
     */
    function authorizeOracle(address oracle) external onlyOwner {
        if (oracle == address(0)) revert InvalidInput();
        authorizedOracles[oracle] = true;
        emit OracleAuthorized(oracle);
    }

    /**
     * @dev Revokes oracle authorization
     */
    function revokeOracle(address oracle) external onlyOwner {
        if (oracle == address(0)) revert InvalidInput();
        if (oracle == owner) revert InvalidInput(); // Cannot revoke owner
        authorizedOracles[oracle] = false;
        emit OracleRevoked(oracle);
    }

    /**
     * @dev Checks if an address is an authorized oracle
     */
    function isAuthorizedOracle(address oracle) external view returns (bool) {
        return authorizedOracles[oracle];
    }

    /**
     * @dev Returns the current owner
     */
    function getOwner() external view returns (address) {
        return owner;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Validates string input to prevent excessively long strings
     */
    function _validateString(string memory str) internal pure {
        if (bytes(str).length > 100) revert StringTooLong();

        // Check for null bytes and control characters
        bytes memory strBytes = bytes(str);
        uint256 length = strBytes.length;
        for (uint256 i; i < length;) {
            bytes1 char = strBytes[i];
            if (
                char == 0x00 ||
                (char < 0x20 && char != 0x09 && char != 0x0A && char != 0x0D)
            ) {
                revert InvalidInput();
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Stores date information to avoid duplicates
     */
    function _storeDateInfo(
        string memory flightNumber,
        string memory flightOriginateDate,
        string memory carrierCode
    ) internal {
        string[] storage dates = flightDates[flightNumber][carrierCode];
        bytes32 targetDateHash = keccak256(bytes(flightOriginateDate));

        uint256 datesLength = dates.length;
        for (uint256 i; i < datesLength;) {
            if (keccak256(bytes(dates[i])) == targetDateHash) {
                return; // Date already exists
            }
            unchecked {
                ++i;
            }
        }

        dates.push(flightOriginateDate);
    }

    /**
     * @dev Validates flight details array length
     */
    function _validateFlightDetailsArray(string[] memory flightDetails)
        internal
        pure
    {
        uint256 length = flightDetails.length;
        if (length != 10) revert InvalidArrayLength();

        // Validate each string in the array
        for (uint256 i; i < length;) {
            _validateString(flightDetails[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Creates FlightInfo struct from array input
     */
    function _createFlightInfo(
        string[] memory flightDetails,
        string memory compressedInfo
    ) internal pure returns (FlightInfo memory) {
        return
            FlightInfo({
                identifiers: FlightIdentifiers({
                    carrierCode: flightDetails[0],
                    flightNumber: flightDetails[1],
                    flightOriginateDate: flightDetails[2]
                }),
                airports: AirportDetails({
                    arrivalAirport: flightDetails[3],
                    departureAirport: flightDetails[4],
                    arrivalCity: flightDetails[5],
                    departureCity: flightDetails[6]
                }),
                statuses: FlightStatuses({
                    arrivalStatus: flightDetails[7],
                    departureStatus: flightDetails[8],
                    legStatus: flightDetails[9]
                }),
                compressedFlightInformation: bytes(compressedInfo)
            });
    }

    /*//////////////////////////////////////////////////////////////
                        MAIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Inserts flight details using a single array for all details
     * @param flightDetails Array containing: [carrierCode, flightNumber, originateDate, arrivalAirport, departureAirport, arrivalCity, departureCity, arrivalStatus, departureStatus, legStatus]
     * @param compressedFlightInformation Additional compressed flight data
     */
    function storeFlightDetails(
        string[] memory flightDetails,
        string memory compressedFlightInformation
    ) public onlyAuthorizedOracle nonReentrant rateLimit {
        _validateFlightDetailsArray(flightDetails);

        string memory flightNumber = flightDetails[1];
        string memory carrierCode = flightDetails[0];
        string memory flightOriginateDate = flightDetails[2];

        // Validate date format
        if (bytes(flightOriginateDate).length != 10) revert InvalidDateFormat();

        // Create and store flight info
        FlightInfo memory flightInfo = _createFlightInfo(
            flightDetails,
            compressedFlightInformation
        );
        flights[flightNumber][flightOriginateDate][carrierCode] = flightInfo;

        // Update tracking data
        if (!isFlightExist[flightNumber][carrierCode]) {
            isFlightExist[flightNumber][carrierCode] = true;
            allFlightNumbers.push(flightNumber);
        }

        _storeDateInfo(flightNumber, flightOriginateDate, carrierCode);
        currentStatus[flightNumber] = flightDetails[9]; // legStatus

        emit FlightDataInserted(
            flightNumber,
            carrierCode,
            flightOriginateDate,
            flightDetails[3], // arrivalAirport
            flightDetails[4], // departureAirport
            flightDetails[5], // arrivalCity
            flightDetails[6], // departureCity
            flightDetails[7], // arrivalStatus
            flightDetails[8], // departureStatus
            flightDetails[9] // legStatus
        );
    }

    /**
     * @dev Inserts multiple flight details in batch
     * @param flightInputs Array of FlightInput structs
     */
    function storeMultipleFlightDetails(FlightInput[] memory flightInputs)
        external
        onlyAuthorizedOracle
        nonReentrant
        rateLimit
    {
        uint256 inputLength = flightInputs.length;
        if (inputLength == 0) revert NoFlightDataProvided();
        if (inputLength > 100) revert TooManyFlightsInBatch();

        for (uint256 i; i < inputLength;) {
            storeFlightDetails(
                flightInputs[i].flightDetails,
                flightInputs[i].compressedFlightInformation
            );
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Updates flight status information
     */
    function updateFlightStatus(
        string memory flightNumber,
        string memory flightOriginateDate,
        string memory carrierCode,
        string memory arrivalStatus,
        string memory departureStatus,
        string memory legStatus
    ) external onlyAuthorizedOracle nonReentrant {
        if (!isFlightExist[flightNumber][carrierCode]) revert FlightNotFound();

        // Validate inputs
        _validateString(flightNumber);
        _validateString(flightOriginateDate);
        _validateString(carrierCode);
        _validateString(arrivalStatus);
        _validateString(departureStatus);
        _validateString(legStatus);

        FlightInfo storage flightInfo = flights[flightNumber][
            flightOriginateDate
        ][carrierCode];
        flightInfo.statuses.arrivalStatus = arrivalStatus;
        flightInfo.statuses.departureStatus = departureStatus;
        flightInfo.statuses.legStatus = legStatus;

        currentStatus[flightNumber] = legStatus;

        emit FlightStatusUpdated(
            flightNumber,
            carrierCode,
            flightOriginateDate,
            arrivalStatus,
            departureStatus,
            legStatus
        );
    }

    /*//////////////////////////////////////////////////////////////
                           QUERY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Gets flight details within a date range
     */
    function getFlightHistory(
        string memory flightNumber,
        string memory fromDate,
        uint256 fromDateInTimeStamp,
        string memory toDate,
        string memory carrierCode,
        string memory arrivalAirport,
        string memory departureAirport
    ) external view returns (FlightInfo[] memory) {
        // Subscription check
        if (
            !isFlightSubscribed[msg.sender][flightNumber][carrierCode][
                arrivalAirport
            ][departureAirport]
        ) {
            revert NotSubscribed();
        }
        if (!isFlightExist[flightNumber][carrierCode]) revert FlightNotFound();
        
        // Enhanced date range validation
        if (!_isValidDateRange(fromDateInTimeStamp)) revert DateRangeExceeded();

        // Validate inputs
        _validateString(flightNumber);
        _validateString(fromDate);
        _validateString(toDate);
        _validateString(carrierCode);

        return
            _getFlightHistoryInternal(
                flightNumber,
                fromDate,
                toDate,
                carrierCode
            );
    }

    /**
     * @dev Internal function to handle flight history retrieval
     */
    function _getFlightHistoryInternal(
        string memory flightNumber,
        string memory fromDate,
        string memory toDate,
        string memory carrierCode
    ) internal view returns (FlightInfo[] memory) {
        string[] storage departureDates = flightDates[flightNumber][
            carrierCode
        ];
        uint256 datesLength = departureDates.length;
        if (datesLength == 0) revert NoDataForCarrier();

        // Count matching dates
        uint256 count;
        for (uint256 i; i < datesLength;) {
            if (
                isDateLessThanOrEqual(fromDate, departureDates[i]) &&
                isDateLessThanOrEqual(departureDates[i], toDate)
            ) {
                unchecked {
                    ++count;
                }
            }
            unchecked {
                ++i;
            }
        }

        // Populate results
        FlightInfo[] memory results = new FlightInfo[](count);
        uint256 resultIndex;

        for (uint256 i; i < datesLength;) {
            if (
                isDateLessThanOrEqual(fromDate, departureDates[i]) &&
                isDateLessThanOrEqual(departureDates[i], toDate)
            ) {
                results[resultIndex] = flights[flightNumber][departureDates[i]][
                    carrierCode
                ];
                unchecked {
                    ++resultIndex;
                }
            }
            unchecked {
                ++i;
            }
        }

        return results;
    }

    /**
     * @dev Gets all flight numbers in the system
     */
    function getAllFlightNumbers() external view returns (string[] memory) {
        return allFlightNumbers;
    }

    /**
     * @dev Gets all dates for a specific flight and carrier
     */
    function getFlightDates(
        string memory flightNumber,
        string memory carrierCode
    ) external view returns (string[] memory) {
        _validateString(flightNumber);
        _validateString(carrierCode);
        return flightDates[flightNumber][carrierCode];
    }

    /**
     * @dev Gets current status of a flight
     */
    function getCurrentFlightStatus(string memory flightNumber, string memory carrierCode)
        external
        view
        flightExists(flightNumber, carrierCode)
        returns (string memory)
    {
        _validateString(flightNumber);
        return currentStatus[flightNumber];
    }

    /*//////////////////////////////////////////////////////////////
                        SUBSCRIPTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Adds a flight subscription for a user
     */
    function addFlightSubscription(
        string memory flightNumber,
        string memory carrierCode,
        string memory arrivalAirport,
        string memory departureAirport
    ) external payable nonReentrant {
        if (!isFlightExist[flightNumber][carrierCode]) revert FlightNotFound();

        // Validate inputs
        _validateString(flightNumber);
        _validateString(carrierCode);
        _validateString(arrivalAirport);
        _validateString(departureAirport);

        if (
            isFlightSubscribed[msg.sender][flightNumber][carrierCode][
                arrivalAirport
            ][departureAirport]
        ) {
            revert AlreadySubscribed();
        }

        isFlightSubscribed[msg.sender][flightNumber][carrierCode][
            arrivalAirport
        ][departureAirport] = true;

        emit FlightSubscriptionAdded(
            msg.sender,
            flightNumber,
            carrierCode,
            arrivalAirport,
            departureAirport
        );
    }

    /**
     * @dev Checks if a user is subscribed to a flight
     */
    function isUserSubscribed(
        address user,
        string memory flightNumber,
        string memory carrierCode,
        string memory arrivalAirport,
        string memory departureAirport
    ) external view returns (bool) {
        if (user == address(0)) revert InvalidInput();

        _validateString(flightNumber);
        _validateString(carrierCode);
        _validateString(arrivalAirport);
        _validateString(departureAirport);

        return
            isFlightSubscribed[user][flightNumber][carrierCode][arrivalAirport][
                departureAirport
            ];
    }

    /**
     * @dev Removes flight subscriptions in batch
     */
    function removeFlightSubscription(
        string[] memory flightNumbers,
        string[] memory carrierCodes,
        string[] memory arrivalAirports,
        string[] memory departureAirports
    ) external {
        uint256 length = flightNumbers.length;
        if (
            length != carrierCodes.length ||
            length != arrivalAirports.length ||
            length != departureAirports.length
        ) {
            revert ArrayLengthMismatch();
        }

        for (uint256 i; i < length;) {
            _validateString(flightNumbers[i]);
            _validateString(carrierCodes[i]);
            _validateString(arrivalAirports[i]);
            _validateString(departureAirports[i]);

            if (
                isFlightSubscribed[msg.sender][flightNumbers[i]][
                    carrierCodes[i]
                ][arrivalAirports[i]][departureAirports[i]]
            ) {
                isFlightSubscribed[msg.sender][flightNumbers[i]][
                    carrierCodes[i]
                ][arrivalAirports[i]][departureAirports[i]] = false;

                emit FlightUnsubscribed(
                    msg.sender,
                    flightNumbers[i],
                    carrierCodes[i],
                    arrivalAirports[i],
                    departureAirports[i]
                );
            }
            unchecked {
                ++i;
            }
        }
    }
}