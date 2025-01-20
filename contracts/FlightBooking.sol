// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FlightBooking {
    struct Flight {
        uint256 id;
        string origin;
        string destination;
        uint256 departureTime;
        uint256 price;
        uint256 availableSeats;
    }

    struct Booking {
        uint256 bookingId;
        uint256 flightId;
        address passenger;
        uint256 amountPaid;
        uint256 bookingTime;
        bool isCancelled;
    }

    uint256 public flightCounter;
    uint256 public bookingCounter;
    address public owner;

    mapping(uint256 => Flight) private flights;
    mapping(uint256 => Booking) private bookings;
    mapping(address => uint256[]) private passengerBookings;

    event FlightAdded(
        uint256 flightId,
        string origin,
        string destination,
        uint256 departureTime,
        uint256 price,
        uint256 availableSeats
    );
    event FlightBooked(
        uint256 bookingId,
        uint256 flightId,
        address passenger,
        uint256 amountPaid
    );
    event BookingCancelled(uint256 bookingId, address passenger);
    event FundsWithdrawn(address owner, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    modifier flightExists(uint256 flightId) {
        require(flights[flightId].id != 0, "Flight does not exist");
        _;
    }

    modifier bookingExists(uint256 bookingId) {
        require(bookings[bookingId].bookingId != 0, "Booking does not exist");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function addFlight(
        string memory origin,
        string memory destination,
        uint256 departureTime,
        uint256 price,
        uint256 availableSeats
    ) external onlyOwner {
        require(
            departureTime > block.timestamp,
            "Departure time must be in the future"
        );
        require(
            availableSeats > 0,
            "Available seats must be greater than zero"
        );

        flightCounter++;
        flights[flightCounter] = Flight(
            flightCounter,
            origin,
            destination,
            departureTime,
            price,
            availableSeats
        );

        emit FlightAdded(
            flightCounter,
            origin,
            destination,
            departureTime,
            price,
            availableSeats
        );
    }

    function bookFlight(uint256 flightId)
        external
        payable
        flightExists(flightId)
    {
        Flight storage flight = flights[flightId];
        require(flight.availableSeats > 0, "No seats available on this flight");
        require(msg.value >= flight.price, "Insufficient payment");

        flight.availableSeats--;

        bookingCounter++;
        bookings[bookingCounter] = Booking(
            bookingCounter,
            flightId,
            msg.sender,
            msg.value,
            block.timestamp,
            false
        );
        passengerBookings[msg.sender].push(bookingCounter);

        emit FlightBooked(bookingCounter, flightId, msg.sender, msg.value);
    }

    function cancelBooking(uint256 bookingId)
        external
        bookingExists(bookingId)
    {
        Booking storage booking = bookings[bookingId];
        require(
            booking.passenger == msg.sender,
            "You can only cancel your own booking"
        );
        require(!booking.isCancelled, "Booking is already cancelled");

        booking.isCancelled = true;
        flights[booking.flightId].availableSeats++;

        payable(booking.passenger).transfer(booking.amountPaid);

        emit BookingCancelled(bookingId, msg.sender);
    }

    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds available to withdraw");

        payable(owner).transfer(balance);

        emit FundsWithdrawn(owner, balance);
    }

    function getPassengerBookings(address passenger)
        external
        view
        returns (uint256[] memory)
    {
        return passengerBookings[passenger];
    }

    function getFlightDetails(uint256 flightId)
        external
        view
        flightExists(flightId)
        returns (Flight memory)
    {
        return flights[flightId];
    }

    function getBookingDetails(uint256 bookingId)
        external
        view
        bookingExists(bookingId)
        returns (Booking memory)
    {
        return bookings[bookingId];
    }
}
