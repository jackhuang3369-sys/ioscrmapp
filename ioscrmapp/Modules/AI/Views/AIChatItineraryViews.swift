import SwiftUI

// MARK: - Itinerary Color Extensions

extension Color {
    static let itineraryCardBackground = Color(red: 30/255, green: 30/255, blue: 30/255)
    static let itineraryAccent = Color(red: 0/255, green: 180/255, blue: 216/255)
    static let itineraryGlow = Color(red: 100/255, green: 200/255, blue: 220/255)
    static let flightIconColor = Color(red: 86/255, green: 156/255, blue: 214/255)
    static let hotelIconColor = Color(red: 156/255, green: 86/255, blue: 214/255)
    static let activityIconColor = Color(red: 214/255, green: 156/255, blue: 86/255)
}

// MARK: - Main Itinerary Card View

struct AIChatItineraryCardView: View {
    let itineraryCard: AIChatItineraryCard
    @State private var expandedFlightIds: Set<String> = []
    @State private var expandedHotelIds: Set<String> = []
    @State private var expandedActivityIds: Set<String> = []

    var body: some View {
        VStack(spacing: 20) {
            itineraryHeader

            if !itineraryCard.flightSegments.isEmpty {
                itinerarySection(
                    title: "FLIGHTS",
                    icon: "airplane",
                    iconColor: Color.flightIconColor,
                    count: itineraryCard.flightSegments.count
                ) {
                    ForEach(itineraryCard.flightSegments) { segment in
                        FlightSegmentRow(
                            segment: segment,
                            isExpanded: expandedFlightIds.contains(segment.id)
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if expandedFlightIds.contains(segment.id) {
                                    expandedFlightIds.remove(segment.id)
                                } else {
                                    expandedFlightIds.insert(segment.id)
                                }
                            }
                        }
                    }
                }
            }

            if !itineraryCard.hotelBookings.isEmpty {
                itinerarySection(
                    title: "HOTELS",
                    icon: "bed.double",
                    iconColor: Color.hotelIconColor,
                    count: itineraryCard.hotelBookings.count
                ) {
                    ForEach(itineraryCard.hotelBookings) { booking in
                        HotelBookingRow(
                            booking: booking,
                            isExpanded: expandedHotelIds.contains(booking.id)
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if expandedHotelIds.contains(booking.id) {
                                    expandedHotelIds.remove(booking.id)
                                } else {
                                    expandedHotelIds.insert(booking.id)
                                }
                            }
                        }
                    }
                }
            }

            if !itineraryCard.activityTickets.isEmpty {
                itinerarySection(
                    title: "ACTIVITIES",
                    icon: "ticket",
                    iconColor: Color.activityIconColor,
                    count: itineraryCard.activityTickets.count
                ) {
                    ForEach(itineraryCard.activityTickets) { ticket in
                        ActivityTicketRow(
                            ticket: ticket,
                            isExpanded: expandedActivityIds.contains(ticket.id)
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if expandedActivityIds.contains(ticket.id) {
                                    expandedActivityIds.remove(ticket.id)
                                } else {
                                    expandedActivityIds.insert(ticket.id)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(Color.itineraryCardBackground.opacity(0.8))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.5), radius: 25, y: 25)
    }

    private var itineraryHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text(itineraryCard.bookingReference)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.itineraryAccent)

                Spacer()

                statusBadge
            }

            Text(itineraryCard.travelerName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.white)
        }
    }

    private var statusBadge: some View {
        Text(itineraryCard.status.rawValue.uppercased())
            .font(.caption2)
            .foregroundColor(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(statusColor.opacity(0.2)))
    }

    private var statusColor: Color {
        switch itineraryCard.status {
        case .confirmed: return Color.green
        case .pending: return Color.orange
        case .completed: return Color.itineraryAccent
        case .cancelled: return Color.red
        }
    }

    private func itinerarySection<Content: View>(
        title: String,
        icon: String,
        iconColor: Color,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(iconColor)

                Text(title)
                    .font(.caption2)
                    .foregroundColor(Color.gray)
                    .tracking(1)

                Text("(\(count))")
                    .font(.caption2)
                    .foregroundColor(Color.gray.opacity(0.6))

                Spacer()
            }

            content()
        }
    }
}

// MARK: - Flight Segment Row

struct FlightSegmentRow: View {
    let segment: FlightSegment
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text(segment.airlineCode ?? String(segment.airline.prefix(2)).uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.white)
                        Image(systemName: "airplane")
                            .font(.system(size: 16))
                            .foregroundColor(Color.flightIconColor)
                    }
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.flightIconColor.opacity(0.2)))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(segment.flightNumber)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.white)

                        HStack(spacing: 8) {
                            Text(segment.departureAirport)
                                .font(.system(size: 13))
                                .foregroundColor(Color.gray)

                            Image(systemName: "arrow.right")
                                .font(.system(size: 10))
                                .foregroundColor(Color.gray.opacity(0.5))

                            Text(segment.arrivalAirport)
                                .font(.system(size: 13))
                                .foregroundColor(Color.gray)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatTime(segment.departureTime))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.white)

                        if let duration = segment.durationMinutes {
                            Text(formatDuration(duration))
                                .font(.caption)
                                .foregroundColor(Color.gray)
                        }
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.gray.opacity(0.6))
                }

                if isExpanded {
                    expandedDetails
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16)
                .fill(Color.itineraryCardBackground.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var expandedDetails: some View {
        VStack(spacing: 8) {
            Divider().background(Color.white.opacity(0.1))

            HStack {
                detailItem(label: "SEAT", value: segment.seatNumber ?? "--")
                detailItem(label: "TERMINAL", value: segment.terminal ?? "--")
                detailItem(label: "GATE", value: segment.gate ?? "--")
            }

            HStack {
                detailItem(label: "BAGGAGE", value: segment.baggage ?? "--")
                detailItem(label: "MEAL", value: segment.meal ?? "Standard")
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(segment.departureCity)
                        .font(.system(size: 12))
                        .foregroundColor(Color.gray)
                    Spacer()
                    Text(segment.arrivalCity)
                        .font(.system(size: 12))
                        .foregroundColor(Color.gray)
                }
            }
        }
    }

    private func detailItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(Color.gray.opacity(0.6))
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)h \(mins)m"
    }
}

// MARK: - Hotel Booking Row

struct HotelBookingRow: View {
    let booking: HotelBooking
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Image(systemName: "bed.double")
                            .font(.system(size: 16))
                            .foregroundColor(Color.hotelIconColor)
                    }
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.hotelIconColor.opacity(0.2)))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(booking.hotelName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.white)

                        Text("\(formatDate(booking.checkInDate)) - \(formatDate(booking.checkOutDate))")
                            .font(.system(size: 13))
                            .foregroundColor(Color.gray)
                    }

                    Spacer()

                    if let nights = booking.nights {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(nights)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.white)
                            Text("nights")
                                .font(.caption)
                                .foregroundColor(Color.gray)
                        }
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.gray.opacity(0.6))
                }

                if isExpanded {
                    expandedDetails
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16)
                .fill(Color.itineraryCardBackground.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var expandedDetails: some View {
        VStack(spacing: 8) {
            Divider().background(Color.white.opacity(0.1))

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ROOM TYPE")
                        .font(.caption2)
                        .foregroundColor(Color.gray.opacity(0.6))
                    Text(booking.roomType)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("GUESTS")
                        .font(.caption2)
                        .foregroundColor(Color.gray.opacity(0.6))
                    Text("\(booking.guests)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white)
                }
            }

            if let confirmNum = booking.confirmationNumber {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CONFIRMATION")
                        .font(.caption2)
                        .foregroundColor(Color.gray.opacity(0.6))
                    Text(confirmNum)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.itineraryAccent)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("ADDRESS")
                    .font(.caption2)
                    .foregroundColor(Color.gray.opacity(0.6))
                Text(booking.address)
                    .font(.system(size: 12))
                    .foregroundColor(Color.gray)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        return formatter.string(from: date)
    }
}

// MARK: - Activity Ticket Row

struct ActivityTicketRow: View {
    let ticket: ActivityTicket
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Image(systemName: "ticket")
                            .font(.system(size: 16))
                            .foregroundColor(Color.activityIconColor)
                    }
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.activityIconColor.opacity(0.2)))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(ticket.activityName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.white)

                        Text("\(formatDate(ticket.date)) • \(ticket.time)")
                            .font(.system(size: 13))
                            .foregroundColor(Color.gray)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(ticket.ticketCount)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.white)
                        Text("tickets")
                            .font(.caption)
                            .foregroundColor(Color.gray)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.gray.opacity(0.6))
                }

                if isExpanded {
                    expandedDetails
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16)
                .fill(Color.itineraryCardBackground.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var expandedDetails: some View {
        VStack(spacing: 8) {
            Divider().background(Color.white.opacity(0.1))

            VStack(alignment: .leading, spacing: 4) {
                Text("VENUE")
                    .font(.caption2)
                    .foregroundColor(Color.gray.opacity(0.6))
                Text(ticket.venue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.white)
            }

            if let confirmNum = ticket.confirmationNumber {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CONFIRMATION")
                        .font(.caption2)
                        .foregroundColor(Color.gray.opacity(0.6))
                    Text(confirmNum)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.itineraryAccent)
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        return formatter.string(from: date)
    }
}