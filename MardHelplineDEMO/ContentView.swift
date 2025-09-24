import SwiftUI
import Photos
import UIKit

// MARK: - Splash Screen
// This view shows your app's name and then transitions to the main app.
struct SplashView: View {
    @State private var isActive = false

    var body: some View {
        VStack {
            if self.isActive {
                // Once active, show the main tab view
                MainTabView()
            } else {
                // Before active, show the app name as text
                ZStack {
                    Color.black.ignoresSafeArea()
                    Text("Mard Care")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.red)
                        .opacity(0.8)
                }
            }
        }
        .onAppear {
            // Wait for 2 seconds on the splash screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    self.isActive = true
                }
            }
        }
    }
}

// MARK: - Tabs
enum MTab: String, CaseIterable {
    case home = "house.fill"
    case legal = "book.fill"
    case chat = "message.fill"
    case community = "person.3.fill"
    case profile = "person.crop.circle"
}

// Central router to switch tabs and share app-wide navigation/auth state
final class AppRouter: ObservableObject {
    @Published var selectedTab: MTab = .home
}

// MARK: - Main Tab Container (custom glass bar + system bar hidden)
struct MainTabView: View {
    @EnvironmentObject private var router: AppRouter
    @Namespace private var indicatorNS
    @StateObject private var driveManager = GoogleDriveManager.shared

    init() {
        // Fully hide the native tab bar so no labels appear underneath the custom bar
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $router.selectedTab) {
                HomeScreen()
                    .tag(MTab.home)
                    .tabItem { Label("Home", systemImage: MTab.home.rawValue) }

                LegalHelpScreen()
                    .tag(MTab.legal)
                    .tabItem { Label("Legal", systemImage: MTab.legal.rawValue) }

                ChatScreen()
                    .tag(MTab.chat)
                    .tabItem { Label("Chat", systemImage: MTab.chat.rawValue) }

                CommunityEventsScreen()
                    .tag(MTab.community)
                    .tabItem { Label("Community", systemImage: MTab.community.rawValue) }

                ProfileScreen()
                    .tag(MTab.profile)
                    .tabItem { Label("Profile", systemImage: MTab.profile.rawValue) }
            }
            .tint(.red)

            GlassTabBar(selection: $router.selectedTab, indicatorNS: indicatorNS)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .alert("Upload to Google Drive", isPresented: $driveManager.showUploadOptions) {
            Button("Upload Now") {
                if let videoURL = driveManager.pendingVideoURL {
                    driveManager.manualUploadVideo(videoURL: videoURL)
                }
                driveManager.showUploadOptions = false
                driveManager.pendingVideoURL = nil
            }
            Button("Skip", role: .cancel) {
                driveManager.showUploadOptions = false
                driveManager.pendingVideoURL = nil
            }
        } message: {
            Text("Would you like to upload this video to Google Drive for backup?")
        }
    }
}

// MARK: - Custom Glass Tab Bar
struct GlassTabBar: View {
    @Binding private var selection: MTab
    private var indicatorNS: Namespace.ID
    @Environment(\.colorScheme) private var scheme
    private let tabs = MTab.allCases

    init(selection: Binding<MTab>, indicatorNS: Namespace.ID) {
        self._selection = selection
        self.indicatorNS = indicatorNS
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let itemWidth = max(60, (width - 24) / CGFloat(tabs.count))

            HStack(spacing: 0) {
                ForEach(tabs, id: \.rawValue) { tab in
                    Button {
                        if selection != tab {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                selection = tab
                            }
                        } else {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                if selection == tab {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.red.opacity(0.18))
                                        .matchedGeometryEffect(id: "bg", in: indicatorNS)
                                        .frame(width: 40, height: 36)
                                }
                                Image(systemName: tab.rawValue)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(selection == tab ? Color.red : Color.primary.opacity(0.7))
                                    .scaleEffect(selection == tab ? 1.08 : 1.0)
                            }
                            Text(title(for: tab))
                                .font(.caption2.weight(selection == tab ? .semibold : .regular))
                                .foregroundStyle(selection == tab ? Color.primary : Color.secondary)
                                .opacity(selection == tab ? 1 : 0.8)
                        }
                        .frame(width: itemWidth, height: 56)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.12), radius: 16, x: 0, y: 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Color.white.opacity(scheme == .dark ? 0.08 : 0.22), lineWidth: 0.6)
                    )
            )
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(height: 70)
    }

    private func title(for tab: MTab) -> String {
        switch tab {
        case .home: return "Home"
        case .legal: return "Legal"
        case .chat: return "Chat"
        case .community: return "Community"
        case .profile: return "Profile"
        }
    }
}

// MARK: - Home Screen
// Main home screen with emergency button, quick actions, and location sharing
import SwiftUI
import CoreLocation

struct HomeScreen: View {
    @State private var shareSheet = false
    @State private var emergencyContactsSheet = false
    @State private var showEmergencyPrompt = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MARD Care").font(.title2.bold())
                            Text("Together we are one").font(.footnote).foregroundColor(.secondary)
                        }
                        Spacer()
                        VideoCaptureButton()
                    }
                    .padding(.horizontal)

                    // Emergency button
                    VStack(spacing: 10) {
                        Button {
                            showEmergencyPrompt = true
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.red.gradient)
                                    .frame(width: 160, height: 160)
                                    .shadow(color: .red.opacity(0.35), radius: 24, x: 0, y: 12)
                                VStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("EMERGENCY")
                                        .font(.system(size: 17, weight: .heavy))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        Text("Tap to get immediate help").font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.top, 6)

                    // Enhanced Live location card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Live Location & Emergency").font(.headline.weight(.semibold))
                                Text("Share your location with trusted contacts")
                            .font(.subheadline).foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "location.circle.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                        }
                        
                        HStack(spacing: 12) {
                        Button { shareSheet.toggle() } label: {
                                HStack {
                                    Image(systemName: "location.circle.fill")
                                    Text("Share Live Location")
                                        .font(.subheadline.weight(.medium))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.red.gradient)
                                )
                            }
                            .buttonStyle(.plain)
                            
                            Button { 
                                emergencyContactsSheet.toggle()
                            } label: {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                    Text("Emergency Contacts")
                                        .font(.subheadline.weight(.medium))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.orange.gradient)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.regularMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                    .padding(.horizontal)

                    // Quick Actions
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Quick Actions").font(.title2.bold())
                            Spacer()
                            Text("Wellness Hub").font(.caption).foregroundColor(.secondary)
                        }
                        .padding(.horizontal)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            NavigationLink(destination: DailyJournalView()) {
                                EnhancedQuickTile(
                                    title: "Daily Journal",
                                    subtitle: "Track your thoughts",
                                    icon: "book.closed.fill",
                                    color: .orange,
                                    progress: min(1.0, Double(max(JournalStorage.load().count,1)) / 7.0),
                                    badge: "\(JournalStorage.load().count) entries"
                                )
                            }

                            NavigationLink(destination: RelaxingAudioView()) {
                                EnhancedQuickTile(
                                    title: "Relaxing Audio",
                                    subtitle: "Find your calm",
                                    icon: "waveform.and.mic",
                                    color: .indigo,
                                    progress: 0.3,
                                    badge: "\(RelaxingAudioView.createTracks().count) tracks"
                                )
                            }

                            NavigationLink(destination: LatestNewsView()) {
                                EnhancedQuickTile(
                                    title: "Latest News",
                                    subtitle: "Stay informed",
                                    icon: "newspaper.fill",
                                    color: .blue,
                                    progress: 1.0,
                                    badge: "Updated"
                                )
                            }

                            NavigationLink(destination: DailyChallengesView()) {
                                EnhancedQuickTile(
                                    title: "Daily Challenges",
                                    subtitle: "Build habits",
                                    icon: "target",
                                    color: .green,
                                    progress: 0.6,
                                    badge: "\(ChallengeStorage.loadDefault().filter{ $0.done }.count)/\(ChallengeStorage.loadDefault().count) done"
                                )
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }

                    // Tip
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Safety Tip").font(.headline)
                        Text("Pin emergency numbers and set a location-sharing shortcut on the Home screen.")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
                .padding(.top, 8)
                .padding(.bottom, 90)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $shareSheet) { ShareLocationSheet() }
        .sheet(isPresented: $emergencyContactsSheet) { EmergencyContactsSheet() }
        .confirmationDialog("Emergency Services", isPresented: $showEmergencyPrompt, titleVisibility: .visible) {
            Button("Police Help (100)") { dial("100") }
            Button("Ambulance (102)") { dial("102") }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Choose a service to contact") }
    }

    private func dial(_ number: String) {
        // Share location with emergency contacts before making the call
        shareLocationWithEmergencyContacts()
        
        // Make the emergency call
        guard let url = URL(string: "tel://\(number)"), UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
    
    private func shareLocationWithEmergencyContacts() {
        // Get emergency contacts
        let emergencyContacts = EmergencyContactStorage.load()
        
        // Get current location
        let locationManager = OneShotLocationManager()
        locationManager.requestOnce()
        
        // Wait a moment for location to be obtained, then send messages
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard let location = locationManager.last else {
                print("❌ Could not get location for emergency sharing")
                return
            }
            
            // Create location message
            let locationMessage = """
            🚨 EMERGENCY ALERT 🚨
            
            I need immediate help! My current location is:
            
            📍 Latitude: \(location.coordinate.latitude)
            📍 Longitude: \(location.coordinate.longitude)
            
            Please call emergency services and come to help me.
            
            Time: \(Date().formatted(date: .abbreviated, time: .shortened))
            
            This message was sent automatically by MARD Care app.
            """
            
            // Send SMS to emergency contacts
            for contact in emergencyContacts {
                sendEmergencySMS(to: contact.phoneNumber, message: locationMessage)
            }
        }
    }
    
    private func sendEmergencySMS(to phoneNumber: String, message: String) {
        let smsURL = "sms:\(phoneNumber)&body=\(message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        if let url = URL(string: smsURL), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            print("📱 Emergency SMS sent to \(phoneNumber)")
        } else {
            print("❌ Could not send SMS to \(phoneNumber)")
        }
    }
}

// MARK: - Quick Actions Components
// Enhanced Quick Tile with progress and badges
struct EnhancedQuickTile: View {
    var title: String
    var subtitle: String
    var icon: String
    var color: Color
    var progress: Double
    var badge: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            contentSection
            progressSection
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 140)
        .background(backgroundView)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private var headerSection: some View {
        HStack {
            iconView
            Spacer()
            badgeView
        }
    }
    
    private var iconView: some View {
        ZStack {
            Circle()
                .fill(color.gradient)
                .frame(width: 48, height: 48)
                .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
            
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
        }
    }
    
    private var badgeView: some View {
        Text(badge)
            .font(.caption2.weight(.medium))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.8), in: Capsule())
    }
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var progressSection: some View {
        ProgressView(value: progress)
            .progressViewStyle(LinearProgressViewStyle(tint: color))
            .scaleEffect(x: 1, y: 0.8, anchor: .center)
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(overlayView)
    }
    
    private var overlayView: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(color.opacity(0.2), lineWidth: 1)
    }
}

// MARK: - Location & Emergency Features
// Live Location sharing, emergency contacts, and safety tools
import CoreLocation
import ContactsUI
import MessageUI
import MapKit

@MainActor
final class OneShotLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var last: CLLocation?
    @Published var status: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func requestOnce() {
        let s = manager.authorizationStatus
        status = s
        if s == .notDetermined { manager.requestWhenInUseAuthorization() }
        manager.requestLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
        self.status = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
        last = locations.last
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Optionally surface errors to UI
    }
}

// Contact picker
struct ContactPickerSheet: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onNumbersPicked: ([String]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UINavigationController {
        let nav = UINavigationController()
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        nav.pushViewController(picker, animated: false)
        nav.isNavigationBarHidden = true
        return nav
    }
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: ContactPickerSheet
        init(_ p: ContactPickerSheet) { parent = p }
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
            if let phone = contactProperty.value as? CNPhoneNumber {
                parent.onNumbersPicked([phone.stringValue])
            }
            parent.isPresented = false
        }
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            let numbers = contacts.flatMap { $0.phoneNumbers.map { $0.value.stringValue } }
            if !numbers.isEmpty { parent.onNumbersPicked(numbers) }
            parent.isPresented = false
        }
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) { parent.isPresented = false }
    }
}

// SMS composer
struct SMSComposer: UIViewControllerRepresentable {
    var recipients: [String]
    var body: String
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.messageComposeDelegate = context.coordinator
        vc.recipients = recipients
        vc.body = body
        return vc
    }
    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true) { self.dismiss() }
        }
    }
}

// Styled map card with user location preview
struct ShareLocationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var lm = OneShotLocationManager()

    @State private var showPicker = false
    @State private var pickedNumbers: [String] = []
    @State private var showSMS = false
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)

    private var locationAvailable: Bool { lm.last != nil }

    private var mapsURL: URL? {
        guard let loc = lm.last else { return nil }
        let lat = loc.coordinate.latitude
        let lon = loc.coordinate.longitude
        return URL(string: "https://maps.apple.com/?ll=\(lat),\(lon)&q=My+Location")
    }

    private var messageBody: String {
        if let url = mapsURL { return "My live location: \(url.absoluteString)" }
        else { return "Trying to share my live location but it’s still loading." }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Enhanced Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "location.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
            Text("Share Live Location")
                .font(.title2.weight(.semibold))
                    Spacer()
                    Button("Done") { dismiss() }
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.blue)
                }
                
                Text("Share your current location with trusted contacts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Enhanced Map preview card
            ZStack(alignment: .topTrailing) {
                Map(position: $camera) {
                    UserAnnotation() // iOS 17+ user dot
                }
                .mapStyle(.standard(elevation: .realistic))
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 14, x: 0, y: 8)

                if !locationAvailable {
                    // Enhanced loading overlay
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.3)
                            .tint(.red)
                        Text("Getting your location...")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                        Text("This may take a few seconds")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(12)
                } else {
                    // Location status indicator
                    VStack {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Location Ready")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.regularMaterial)
                        )
                        Spacer()
                    }
                    .padding(12)
                }
            }

            // Details card
            VStack(alignment: .leading, spacing: 10) {
                Text("Details")
                    .font(.headline)
                if let loc = lm.last {
                    Text(String(format: "Lat: %.5f, Lon: %.5f", loc.coordinate.latitude, loc.coordinate.longitude))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let url = mapsURL {
                        ShareLink(item: url) {
                            Label("Share Link", systemImage: "square.and.arrow.up")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                } else {
                    Text("Awaiting GPS fix… move outdoors for better accuracy.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            // Enhanced Actions
            VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    showPicker = true
                } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.plus")
                            Text("Pick Contacts")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.blue, lineWidth: 1.5)
                        )
                }
                    .buttonStyle(.plain)

                Button {
                    showSMS = true
                } label: {
                        HStack {
                            Image(systemName: "message.fill")
                            Text("Send SMS")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.blue.gradient)
                        )
                }
                    .buttonStyle(.plain)
                .disabled(pickedNumbers.isEmpty || mapsURL == nil || !MFMessageComposeViewController.canSendText())
                    .opacity((pickedNumbers.isEmpty || mapsURL == nil || !MFMessageComposeViewController.canSendText()) ? 0.6 : 1.0)
                }
                
                // Quick share options
                if locationAvailable {
                    HStack(spacing: 8) {
                        Text("Quick Share:")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                        
                        if let url = mapsURL {
                            ShareLink(item: url) {
                                HStack(spacing: 4) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Share Link")
                                }
                                .font(.caption.weight(.medium))
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.green.opacity(0.1))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Spacer()
                    }
                }
            }

            if !pickedNumbers.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recipients")
                        .font(.caption).foregroundColor(.secondary)
                    Text(pickedNumbers.joined(separator: ", "))
                        .font(.caption)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

        }
        .padding()
        .onAppear {
            lm.requestOnce()
            camera = .userLocation(fallback: .automatic)
        }
        .sheet(isPresented: $showPicker) {
            ContactPickerSheet(isPresented: $showPicker) { numbers in
                pickedNumbers = numbers.map { $0.replacingOccurrences(of: " ", with: "") }
            }
        }
        .sheet(isPresented: $showSMS) {
            SMSComposer(recipients: pickedNumbers, body: messageBody)
        }
    }
}
// MARK: - Legal Help Screen
// Comprehensive legal information and resources based on Indian Constitution
struct LegalHelpScreen: View {
    @State private var selectedCategory: LegalCategory = .rights
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Category picker
                CategoryPicker(selectedCategory: $selectedCategory)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                
                // Content based on selected category
                ScrollView {
                    LazyVStack(spacing: 16) {
                        switch selectedCategory {
                        case .rights:
                            FundamentalRightsView()
                        case .procedures:
                            LegalProceduresView()
                        case .helplines:
                            LegalHelplinesView()
                        case .resources:
                            LegalResourcesView()
                        case .forms:
                            LegalFormsView()
                        case .courts:
                            CourtInformationView()
                        case .mensNGOs:
                            MensNGOsView()
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Legal Help")
            .navigationBarTitleDisplayMode(.large)
        }
        .padding(.bottom, 100) // Space for custom tab bar
    }
}

// MARK: - Legal Categories
enum LegalCategory: String, CaseIterable {
    case rights = "Fundamental Rights"
    case procedures = "Legal Procedures"
    case helplines = "Helplines"
    case resources = "Resources"
    case forms = "Forms"
    case courts = "Courts"
    case mensNGOs = "Men's NGOs"
    
    var icon: String {
        switch self {
        case .rights: return "checkmark.shield.fill"
        case .procedures: return "doc.text.fill"
        case .helplines: return "phone.fill"
        case .resources: return "book.fill"
        case .forms: return "doc.plaintext.fill"
        case .courts: return "building.2.fill"
        case .mensNGOs: return "person.2.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .rights: return .blue
        case .procedures: return .green
        case .helplines: return .red
        case .resources: return .purple
        case .forms: return .orange
        case .courts: return .indigo
        case .mensNGOs: return .teal
        }
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String
    @FocusState private var focused: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search legal topics...", text: $text)
                .textFieldStyle(.plain)
                .focused($focused)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focused = false }
            }
        }
    }
}

// MARK: - Category Picker
struct CategoryPicker: View {
    @Binding var selectedCategory: LegalCategory
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(LegalCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct CategoryButton: View {
    let category: LegalCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption)
                Text(category.rawValue)
                    .font(.caption.weight(.medium))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? AnyShapeStyle(category.color.gradient) : AnyShapeStyle(.ultraThinMaterial))
            )
        }
        .buttonStyle(.plain)
    }
}

struct DetailText: View {
    var text: String
    init(_ t: String) { text = t }
    var body: some View {
        ScrollView {
            Text(text)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationBarTitleDisplayMode(.inline)
        .padding(.bottom, 90)
    }
}

// MARK: - Fundamental Rights View
struct FundamentalRightsView: View {
    let fundamentalRights = [
        FundamentalRight(
            title: "Right to Equality (Article 14-18)",
            description: "Equality before law and equal protection of laws",
            details: "• Article 14: Equality before law\n• Article 15: Prohibition of discrimination\n• Article 16: Equality of opportunity in public employment\n• Article 17: Abolition of untouchability\n• Article 18: Abolition of titles",
            icon: "equal.circle.fill",
            color: .blue
        ),
        FundamentalRight(
            title: "Right to Freedom (Article 19-22)",
            description: "Freedom of speech, assembly, movement, residence",
            details: "• Article 19: Six freedoms (speech, assembly, association, movement, residence, profession)\n• Article 20: Protection in respect of conviction for offences\n• Article 21: Protection of life and personal liberty\n• Article 22: Protection against arrest and detention",
            icon: "person.2.fill",
            color: .green
        ),
        FundamentalRight(
            title: "Right against Exploitation (Article 23-24)",
            description: "Prohibition of trafficking and forced labor",
            details: "• Article 23: Prohibition of traffic in human beings and forced labor\n• Article 24: Prohibition of employment of children in factories",
            icon: "hand.raised.fill",
            color: .red
        ),
        FundamentalRight(
            title: "Right to Freedom of Religion (Article 25-28)",
            description: "Freedom of conscience and free profession",
            details: "• Article 25: Freedom of conscience and free profession\n• Article 26: Freedom to manage religious affairs\n• Article 27: Freedom from payment of taxes for promotion of any religion\n• Article 28: Freedom from attending religious instruction",
            icon: "book.closed.fill",
            color: .purple
        ),
        FundamentalRight(
            title: "Cultural and Educational Rights (Article 29-30)",
            description: "Protection of interests of minorities",
            details: "• Article 29: Protection of interests of minorities\n• Article 30: Right of minorities to establish and administer educational institutions",
            icon: "graduationcap.fill",
            color: .orange
        ),
        FundamentalRight(
            title: "Right to Constitutional Remedies (Article 32)",
            description: "Right to move Supreme Court for enforcement of rights",
            details: "• Article 32: Right to move Supreme Court for enforcement of fundamental rights\n• Writ jurisdiction: Habeas Corpus, Mandamus, Prohibition, Certiorari, Quo Warranto",
            icon: "scale.3d",
            color: .indigo
        )
    ]
    
    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(fundamentalRights) { right in
                FundamentalRightCard(right: right)
            }
        }
    }
}

struct FundamentalRight: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let details: String
    let icon: String
    let color: Color
}

struct FundamentalRightCard: View {
    let right: FundamentalRight
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: right.icon)
                    .font(.title2)
                    .foregroundColor(right.color)
                    .frame(width: 40, height: 40)
                    .background(right.color.opacity(0.1), in: Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(right.title)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text(right.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(right.color)
                }
                .buttonStyle(.plain)
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    Text(right.details)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(right.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Legal Procedures View
struct LegalProceduresView: View {
    let procedures = [
        LegalProcedure(
            title: "Filing a Police Complaint",
            steps: [
                "Visit the nearest police station",
                "Write complaint in local language or English",
                "Provide all relevant details and evidence",
                "Get acknowledgment receipt (FIR number)",
                "Follow up regularly on case progress"
            ],
            timeFrame: "Immediate",
            documents: ["Identity proof", "Address proof", "Evidence documents", "Witness statements"],
            icon: "doc.text.fill",
            color: .blue
        ),
        LegalProcedure(
            title: "Approaching Family Court",
            steps: [
                "Consult a family lawyer",
                "Prepare necessary documents",
                "File petition with appropriate court",
                "Pay required court fees",
                "Attend hearings as scheduled"
            ],
            timeFrame: "1-3 years",
            documents: ["Marriage certificate", "Income proof", "Property documents", "Medical reports"],
            icon: "building.2.fill",
            color: .green
        ),
        LegalProcedure(
            title: "Seeking Legal Aid",
            steps: [
                "Contact State Legal Services Authority",
                "Fill application form with case details",
                "Provide income certificate",
                "Submit required documents",
                "Wait for panel lawyer assignment"
            ],
            timeFrame: "1-2 weeks",
            documents: ["Income certificate", "Case details", "Identity proof", "Address proof"],
            icon: "scale.3d",
            color: .purple
        ),
        LegalProcedure(
            title: "Domestic Violence Complaint",
            steps: [
                "Contact Protection Officer or police",
                "File complaint under Protection of Women from Domestic Violence Act",
                "Seek protection order from court",
                "Document all incidents with evidence",
                "Follow up on case progress"
            ],
            timeFrame: "Immediate protection",
            documents: ["Incident reports", "Medical certificates", "Witness statements", "Photographs"],
            icon: "shield.lefthalf.filled",
            color: .red
        )
    ]
    
    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(procedures) { procedure in
                LegalProcedureCard(procedure: procedure)
            }
        }
    }
}

struct LegalProcedure: Identifiable {
    let id = UUID()
    let title: String
    let steps: [String]
    let timeFrame: String
    let documents: [String]
    let icon: String
    let color: Color
}

struct LegalProcedureCard: View {
    let procedure: LegalProcedure
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: procedure.icon)
                    .font(.title2)
                    .foregroundColor(procedure.color)
                    .frame(width: 40, height: 40)
                    .background(procedure.color.opacity(0.1), in: Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(procedure.title)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text("Time: \(procedure.timeFrame)")
                        .font(.caption.weight(.medium))
                        .foregroundColor(procedure.color)
                }
                
                Spacer()
                
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(procedure.color)
                }
                .buttonStyle(.plain)
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Steps:")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        ForEach(Array(procedure.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1).")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(procedure.color)
                                    .frame(width: 20, alignment: .leading)
                                
                                Text(step)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Required Documents:")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        ForEach(procedure.documents, id: \.self) { document in
                            HStack(spacing: 8) {
                                Image(systemName: "doc.fill")
                                    .font(.caption)
                                    .foregroundColor(procedure.color)
                                
                                Text(document)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(procedure.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Legal Helplines View
struct LegalHelplinesView: View {
    let helplines = [
        LegalHelpline(
            name: "National Legal Services Authority (NALSA)",
            number: "1800-345-0010",
            description: "Free legal aid and services",
            hours: "24/7",
            services: ["Legal advice", "Court representation", "Mediation", "Legal awareness"],
            icon: "phone.fill",
            color: .blue
        ),
        LegalHelpline(
            name: "Women Helpline",
            number: "181",
            description: "Emergency support for women",
            hours: "24/7",
            services: ["Emergency rescue", "Legal aid", "Counseling", "Rehabilitation"],
            icon: "phone.fill",
            color: .red
        ),
        LegalHelpline(
            name: "Child Helpline",
            number: "1098",
            description: "Child protection and welfare",
            hours: "24/7",
            services: ["Child rescue", "Legal aid", "Counseling", "Rehabilitation"],
            icon: "phone.fill",
            color: .green
        ),
        LegalHelpline(
            name: "Senior Citizen Helpline",
            number: "14567",
            description: "Support for senior citizens",
            hours: "24/7",
            services: ["Legal aid", "Healthcare", "Financial assistance", "Counseling"],
            icon: "phone.fill",
            color: .purple
        ),
        LegalHelpline(
            name: "Mental Health Helpline",
            number: "1800-599-0019",
            description: "Mental health support and counseling",
            hours: "24/7",
            services: ["Crisis intervention", "Counseling", "Referrals", "Support groups"],
            icon: "phone.fill",
            color: .orange
        ),
        LegalHelpline(
            name: "Cyber Crime Helpline",
            number: "1930",
            description: "Cyber crime reporting and support",
            hours: "24/7",
            services: ["Cyber crime reporting", "Digital forensics", "Legal aid", "Awareness"],
            icon: "phone.fill",
            color: .indigo
        ),
        LegalHelpline(
            name: "SIF ONE Helpline (Men Welfare Trust)",
            number: "8882 498 498",
            description: "Men's rights and matrimonial issues support",
            hours: "24/7",
            services: ["Legal aid", "Counseling", "Matrimonial support", "False cases help"],
            icon: "phone.fill",
            color: .blue
        ),
        LegalHelpline(
            name: "Save Indian Family Foundation",
            number: "8882 498 498",
            description: "Support for men facing false cases and matrimonial issues",
            hours: "24/7",
            services: ["Legal aid", "False case support", "Counseling", "Family mediation"],
            icon: "phone.fill",
            color: .green
        ),
        LegalHelpline(
            name: "Men's Rights Association",
            number: "011-2629 1111",
            description: "Men's rights advocacy and legal support",
            hours: "9 AM - 6 PM",
            services: ["Legal consultation", "Rights awareness", "Case guidance", "Support groups"],
            icon: "phone.fill",
            color: .purple
        ),
        LegalHelpline(
            name: "Indian Family Foundation",
            number: "1800 102 7222",
            description: "Family dispute resolution and men's support",
            hours: "24/7",
            services: ["Family counseling", "Legal aid", "Mediation", "Support groups"],
            icon: "phone.fill",
            color: .orange
        ),
        LegalHelpline(
            name: "Men's Helpline India",
            number: "1800 102 7222",
            description: "Comprehensive support for men's issues",
            hours: "24/7",
            services: ["Crisis intervention", "Legal aid", "Counseling", "Emergency support"],
            icon: "phone.fill",
            color: .red
        )
    ]
    
    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(helplines) { helpline in
                LegalHelplineCard(helpline: helpline)
            }
        }
    }
}

struct LegalHelpline: Identifiable {
    let id = UUID()
    let name: String
    let number: String
    let description: String
    let hours: String
    let services: [String]
    let icon: String
    let color: Color
}

struct LegalHelplineCard: View {
    let helpline: LegalHelpline
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: helpline.icon)
                    .font(.title2)
                    .foregroundColor(helpline.color)
                    .frame(width: 40, height: 40)
                    .background(helpline.color.opacity(0.1), in: Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(helpline.name)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text(helpline.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack {
                        Text(helpline.number)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(helpline.color)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text(helpline.hours)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Button {
                        if let url = URL(string: "tel://\(helpline.number)") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Image(systemName: "phone.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(helpline.color, in: Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(helpline.color)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    Text("Services:")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(helpline.services, id: \.self) { service in
                            Text(service)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(helpline.color.opacity(0.1), in: Capsule())
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(helpline.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Legal Resources View
struct LegalResourcesView: View {
    let resources = [
        LegalResource(
            title: "Section 498A IPC - Bail Rights",
            description: "Protection against false dowry cases",
            url: "https://indiankanoon.org/doc/538436/",
            icon: "shield.lefthalf.filled",
            color: .red
        ),
        LegalResource(
            title: "Section 41A CrPC - Notice Before Arrest",
            description: "Mandatory notice before arrest protection",
            url: "https://indiankanoon.org/doc/1142781/",
            icon: "bell.badge.fill",
            color: .orange
        ),
        LegalResource(
            title: "Section 438 CrPC - Anticipatory Bail",
            description: "Pre-arrest bail protection rights",
            url: "https://indiankanoon.org/doc/1679850/",
            icon: "lock.open.fill",
            color: .green
        ),
        LegalResource(
            title: "Section 482 CrPC - Quashing Powers",
            description: "High Court FIR quashing provisions",
            url: "https://indiankanoon.org/doc/1679850/",
            icon: "building.columns.fill",
            color: .blue
        ),
        LegalResource(
            title: "Section 125 CrPC - Maintenance Defense",
            description: "Contest unreasonable maintenance demands",
            url: "https://indiankanoon.org/doc/463458/",
            icon: "dollarsign.circle.fill",
            color: .purple
        ),
        LegalResource(
            title: "Section 9 Hindu Marriage Act",
            description: "Restitution of conjugal rights",
            url: "https://indiankanoon.org/doc/1041812/",
            icon: "house.fill",
            color: .teal
        ),
        LegalResource(
            title: "Section 26 Hindu Marriage Act",
            description: "Father's custody rights protection",
            url: "https://indiankanoon.org/doc/1041812/",
            icon: "figure.2.and.child.holdinghands",
            color: .yellow
        ),
        LegalResource(
            title: "Section 182 IPC - False Information",
            description: "Complaint against false police reports",
            url: "https://indiankanoon.org/doc/1556934/",
            icon: "exclamationmark.shield.fill",
            color: .pink
        ),
        LegalResource(
            title: "Section 340 CrPC - Perjury Complaint",
            description: "Action against false evidence",
            url: "https://indiankanoon.org/doc/445276/",
            icon: "person.badge.minus.fill",
            color: .mint
        ),
        LegalResource(
            title: "Article 21 - Writ Petition Rights",
            description: "Constitutional protection petitions",
            url: "https://indiankanoon.org/doc/1199182/",
            icon: "doc.text.magnifyingglass",
            color: .gray
        )

    ]
    
    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(resources) { resource in
                LegalResourceCard(resource: resource)
            }
        }
    }
}

struct LegalResource: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let url: String
    let icon: String
    let color: Color
}

struct LegalResourceCard: View {
    let resource: LegalResource
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: resource.icon)
                .font(.title2)
                .foregroundColor(resource.color)
                .frame(width: 40, height: 40)
                .background(resource.color.opacity(0.1), in: Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(resource.title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text(resource.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button {
                if let url = URL(string: resource.url) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Image(systemName: "arrow.up.right.square.fill")
                    .font(.title3)
                    .foregroundColor(resource.color)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(resource.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Legal Forms View
struct LegalFormsView: View {
    let forms = [
        LegalForm(
            title: "FIR Application Form",
            description: "First Information Report application",
            category: "Police",
            icon: "doc.text.fill",
            color: .blue,
            url: "https://cdnbbsr.s3waas.gov.in/s380537a945c7aaa788ccfcdf1b99b5d8f/uploads/2023/05/2023050599.pdf"
        ),
        LegalForm(
            title: "Anticipatory Bail Application",
            description: "Application for anticipatory bail under Section 438 CrPC",
            category: "Criminal Court",
            icon: "key.fill",
            color: .green,
            url: "https://cdnbbsr.s3waas.gov.in/s380537a945c7aaa788ccfcdf1b99b5d8f/uploads/2023/05/2023050598.pdf"
        ),
        LegalForm(
            title: "Divorce Petition Template",
            description: "Petition for divorce under Hindu Marriage Act",
            category: "Family Court",
            icon: "doc.text.fill",
            color: .red,
            url: "https://www.legalserviceindia.com/legal/article-4665-divorce-petition-format.html"
        ),
        LegalForm(
            title: "Maintenance Application",
            description: "Application under Section 125 CrPC for maintenance",
            category: "Family Court",
            icon: "dollarsign.circle.fill",
            color: .purple,
            url: "https://www.advocatekhoj.com/library/bareacts/crpc/125.php"
        ),
        LegalForm(
            title: "Child Custody Application",
            description: "Application for child custody",
            category: "Family Court",
            icon: "figure.2.and.child.holdinghands",
            color: .orange,
            url: "https://www.vakilsearch.com/advice/child-custody-application-format"
        ),
        LegalForm(
            title: "Legal Aid Application - NALSA",
            description: "Free legal aid application form",
            category: "Legal Aid",
            icon: "scale.3d",
            color: .mint,
            url: "https://nalsa.gov.in/sites/default/files/Application%20form%20for%20Legal%20Aid.pdf"
        ),
        LegalForm(
            title: "RTI Application Form",
            description: "Right to Information application",
            category: "Government",
            icon: "info.circle.fill",
            color: .teal,
            url: "https://rtionline.gov.in/RTIMIS/webrtipublic/app/forms/RTI_APPLICATION_FORM.pdf"
        ),
        LegalForm(
            title: "Consumer Complaint Form",
            description: "Online consumer complaint filing",
            category: "Consumer Court",
            icon: "person.fill.questionmark",
            color: .indigo,
            url: "https://consumerhelpline.gov.in/"
        )
    ]
    
    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(forms) { form in
                LegalFormCard(form: form)
            }
        }
    }
}

struct LegalForm: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let category: String
    let icon: String
    let color: Color
    let url: String
}

struct LegalFormCard: View {
    let form: LegalForm
    @State private var isOpening = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: form.icon)
                .font(.title2)
                .foregroundColor(form.color)
                .frame(width: 40, height: 40)
                .background(form.color.opacity(0.1), in: Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(form.title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text(form.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text(form.category)
                    .font(.caption.weight(.medium))
                    .foregroundColor(form.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(form.color.opacity(0.1), in: Capsule())
            }
            
            Spacer()
            
            Button {
                openForm()
            } label: {
                if isOpening {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: form.color))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "safari.fill")
                        .font(.title3)
                        .foregroundColor(form.color)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(form.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func openForm() {
        guard let url = URL(string: form.url) else {
            print("Invalid URL: \(form.url)")
            return
        }
        
        isOpening = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        // Check if URL can be opened
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { success in
                DispatchQueue.main.async {
                    isOpening = false
                    if !success {
                        print("Failed to open URL: \(form.url)")
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                isOpening = false
                print("Cannot open URL: \(form.url)")
            }
        }
    }
}

// Alternative: Add Safari View Controller for in-app browsing
import SafariServices

extension LegalFormCard {
    private func openInSafari() {
        guard let url = URL(string: form.url) else { return }
        
        isOpening = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                
                let safariVC = SFSafariViewController(url: url)
                safariVC.preferredControlTintColor = UIColor(form.color)
                rootViewController.present(safariVC, animated: true)
            }
            isOpening = false
        }
    }
}

// MARK: - Court Information View
struct CourtInformationView: View {
    let courts = [
        CourtInfo(
            name: "Supreme Court of India",
            location: "New Delhi",
            jurisdiction: "All India",
            contact: "011-23388942",
            website: "https://www.sci.gov.in",
            icon: "building.2.fill",
            color: .blue
        ),
        CourtInfo(
            name: "High Court",
            location: "State Capitals",
            jurisdiction: "State Level",
            contact: "Varies by state",
            website: "https://ecommitteesci.gov.in/high-courts/",
            icon: "building.2.fill",
            color: .green
        ),
        CourtInfo(
            name: "District Court",
            location: "District Headquarters",
            jurisdiction: "District Level",
            contact: "Varies by district",
            website: "https://ecourts.gov.in/ecourts_home/index.php",
            icon: "building.2.fill",
            color: .red
        ),
        CourtInfo(
            name: "Family Court",
            location: "Major Cities",
            jurisdiction: "Family Matters",
            contact: "Varies by location",
            website: "https://doj.gov.in/family-court/",
            icon: "heart.fill",
            color: .purple
        ),
    ]
    
    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(courts) { court in
                CourtInfoCard(court: court)
            }
        }
    }
}

struct CourtInfo: Identifiable {
    let id = UUID()
    let name: String
    let location: String
    let jurisdiction: String
    let contact: String
    let website: String
    let icon: String
    let color: Color
}

struct CourtInfoCard: View {
    let court: CourtInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: court.icon)
                    .font(.title2)
                    .foregroundColor(court.color)
                    .frame(width: 40, height: 40)
                    .background(court.color.opacity(0.1), in: Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(court.name)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text(court.location)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(court.jurisdiction)
                        .font(.caption.weight(.medium))
                        .foregroundColor(court.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(court.color.opacity(0.1), in: Capsule())
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "phone.fill")
                        .font(.caption)
                        .foregroundColor(court.color)
                    
                    Text(court.contact)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Image(systemName: "globe")
                        .font(.caption)
                        .foregroundColor(court.color)
                    
                    Button {
                        if let url = URL(string: court.website) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Visit Website")
                            .font(.subheadline)
                            .foregroundColor(court.color)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(court.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Men's NGOs View
struct MensNGOsView: View {
    let ngos = [
        MensNGO(
            name: "Men Welfare Trust",
            description: "A leading organization for men's rights, providing legal and emotional support.",
            website: "https://www.menwelfare.in",
            phone: "8882498498",
            email: "info@menwelfare.in",
            services: ["Legal Aid", "Counseling", "False Case Support", "Mediation"],
            location: "Delhi, India",
            icon: "shield.lefthalf.filled",
            color: .blue
        ),
        MensNGO(
            name: "Save Indian Family Foundation (SIFF)",
            description: "A prominent movement advocating against the misuse of gender-biased laws.",
            website: "https://www.saveindianfamily.org",
            phone: "8884242888",
            email: "siff.helpline@gmail.com",
            services: ["Legal Consultation", "Support Groups", "Activism", "Family Mediation"],
            location: "Pan India",
            icon: "person.3.fill",
            color: .green
        ),
        MensNGO(
            name: "Vaastav Foundation",
            description: "A Mumbai-based NGO dedicated to helping men in distress and their families.",
            website: "https://vaastav.org",
            phone: "8080696969",
            email: "help@vaastav.org",
            services: ["24/7 Helpline", "Counseling", "Legal Guidance", "Support Meetings"],
            location: "Mumbai, India",
            icon: "heart.fill",
            color: .orange
        ),
        MensNGO(
            name: "Confidare India",
            description: "Provides guidance to men on matrimonial, family, and criminal law issues.",
            website: "https://x.com/confidare",
            phone: "9902495651",
            email: "contact@confidareindia.com",
            services: ["Legal Consultation", "IPC 498a Help", "Documentation", "Matrimonial Issues"],
            location: "Bangalore, India",
            icon: "doc.text.fill",
            color: .purple
        ),
        MensNGO(
            name: "Sahodar",
            description: "A trust dedicated to promoting men's health, well-being, and family harmony.",
            website: "https://sahodar.in",
            phone: "9841422699",
            email: "sahodar.trust@gmail.com",
            services: ["Support Groups", "Mental Health", "Legal Awareness", "Family Harmony"],
            location: "Chennai, India",
            icon: "person.2.wave.2.fill",
            color: .red
        ),
        MensNGO(
            name: "CRISP",
            description: "Advocates for shared parenting and father's rights in child custody cases.",
            website:"https://www.facebook.com/p/Crisp-India-Childrens-Rights-Initiative-for-Shared-Parenting-100083375171744/", // Website was down, using official FB page
            phone: "9845044443",
            email: "crisp.bangalore@gmail.com",
            services: ["Shared Parenting Advocacy", "Legal Support", "Child Custody Help", "Counseling"],
            location: "Bangalore, Pan India",
            icon: "figure.and.child.holdinghands",
            color: .indigo
        ),
        MensNGO(
            name: "Hridaya Nest",
            description: "Part of the SIF movement, providing support for men and their families.",
            website: "https://www.facebook.com/Hridaya.Kolkata/", // Website was down, using official FB page
            phone: "9830151555", // Updated to local Kolkata number
            email: "hridaya.nest@gmail.com",
            services: ["Weekly Meetings", "Family Counseling", "Legal Guidance", "Emotional Support"],
            location: "Kolkata, India",
            icon: "house.fill",
            color: .teal
        ),
        MensNGO(
            name: "Men's Rights Association (MRA)",
            description: "Focuses on advocating for the rights and well-being of men and boys.",
            website: "https://www.facebook.com/mensrightsassociation/",
            phone: "N/A",
            email: "contact@mensrightsassociation.org",
            services: ["Rights Advocacy", "Legal Support", "Awareness Campaigns", "Community Support"],
            location: "Delhi, India",
            icon: "person.fill.questionmark",
            color: .pink
        )
    ]
    
    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(ngos) { ngo in
                MensNGOCard(ngo: ngo)
            }
        }
    }
}

struct MensNGO: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let website: String
    let phone: String
    let email: String
    let services: [String]
    let location: String
    let icon: String
    let color: Color
}

struct MensNGOCard: View {
    let ngo: MensNGO
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: ngo.icon)
                    .font(.title2)
                    .foregroundColor(ngo.color)
                    .frame(width: 40, height: 40)
                    .background(ngo.color.opacity(0.1), in: Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(ngo.name)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text(ngo.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    Text(ngo.location)
                        .font(.caption.weight(.medium))
                        .foregroundColor(ngo.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(ngo.color.opacity(0.1), in: Capsule())
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Button {
                        if let url = URL(string: "tel://\(ngo.phone.filter("0123456789.".contains))") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Image(systemName: "phone.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(ngo.color, in: Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        if let url = URL(string: ngo.website) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Image(systemName: "globe")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(ngo.color.opacity(0.8), in: Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(ngo.color)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Contact Information:")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        HStack {
                            Image(systemName: "phone.fill")
                                .font(.caption)
                                .foregroundColor(ngo.color)
                            Text(ngo.phone)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                        
                        HStack {
                            Image(systemName: "envelope.fill")
                                .font(.caption)
                                .foregroundColor(ngo.color)
                            Text(ngo.email)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                        
                        HStack {
                            Image(systemName: "globe")
                                .font(.caption)
                                .foregroundColor(ngo.color)
                            Button {
                                if let url = URL(string: ngo.website) {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Text("Visit Website")
                                    .font(.subheadline)
                                    .foregroundColor(ngo.color)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Services:")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(ngo.services, id: \.self) { service in
                                Text(service)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(ngo.color.opacity(0.1), in: Capsule())
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(ngo.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}


// MARK: - Chat Support
// AI-powered chat support with OpenAI integration
import SwiftUI

struct ChatMessage: Identifiable, Hashable {
    let id = UUID()
    var text: String
    let isUser: Bool
    let time: Date
}

@MainActor
final class ChatVM: ObservableObject {
    @Published var messages: [ChatMessage] = [
        ChatMessage(text: "Hello! How can I help today?", isUser: false, time: Date().addingTimeInterval(-3600))
    ]
    @Published var isLoading = false

    private enum Provider { case openAI, gemini }

    private var apiKey: String {
        // Store in Info.plist or use a backend proxy; do not hardcode
        Bundle.main.infoDictionary?["OpenAIAPIKey"] as? String ?? ""
    }
    private var geminiKey: String {
        Bundle.main.infoDictionary?["GeminiAPIKey"] as? String ?? ""
    }
    private var provider: Provider {
        if !geminiKey.isEmpty { return .gemini }
        if !apiKey.isEmpty { return .openAI }
        return .openAI
    }

    func send(userText: String) async {
        guard !userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        messages.append(ChatMessage(text: userText, isUser: true, time: Date()))
        // Placeholder assistant message to stream into
        var draft = ChatMessage(text: "", isUser: false, time: Date())
        messages.append(draft)
        isLoading = true
        do {
            switch provider {
            case .openAI:
            let stream = try await streamChatCompletions(userText: userText)
            for try await token in stream {
                draft.text += token
                    messages[messages.count - 1] = draft
                }
            case .gemini:
                let text = try await geminiComplete(userText: userText)
                draft.text = text
                messages[messages.count - 1] = draft
            }
        } catch {
            draft.text = "Sorry—there was a network issue."
            messages[messages.count - 1] = draft
        }
        isLoading = false
    }

    private func streamChatCompletions(userText: String) async throws -> AsyncThrowingStream<String, Error> {
        // OpenAI Chat Completions streaming SSE
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "stream": true,
            "messages": [
                ["role": "system", "content": "You are a supportive helpline assistant for safety, legal basics, and counseling guidance. Keep answers short, clear, and kind."],
                ["role": "user", "content": userText]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        // Parse SSE lines: data: {json}
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    var accumulator = Data()
                    for try await chunk in bytes {
                        accumulator.append(chunk)
                        // Split by newline
                        while let range = accumulator.firstRange(of: Data([0x0a])) { // \n
                            let line = accumulator.subdata(in: 0..<range.lowerBound)
                            accumulator.removeSubrange(0...range.lowerBound)
                            if let s = String(data: line, encoding: .utf8), s.hasPrefix("data: ") {
                                let payload = String(s.dropFirst(6))
                                if payload == "[DONE]" { continuation.finish(); return }
                                // Extract incremental delta
                                if let d = payload.data(using: .utf8),
                                   let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                                   let choices = obj["choices"] as? [[String: Any]],
                                   let delta = (choices.first?["delta"] as? [String: Any])?["content"] as? String {
                                    continuation.yield(delta)
                                }
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func geminiComplete(userText: String) async throws -> String {
        // Google Generative Language API - non-streaming completion
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(geminiKey)") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "contents": [[
                "role": "user",
                "parts": [["text": userText]]
            ]],
            "generationConfig": [
                "temperature": 0.7
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        // Parse minimal text from candidates[0].content.parts[].text
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let candidates = obj["candidates"] as? [[String: Any]],
           let content = candidates.first?["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]] {
            let texts = parts.compactMap { $0["text"] as? String }
            if let joined = texts.joined(separator: "\n").nilIfEmpty { return joined }
        }
        // Fallback to raw string
        return String(data: data, encoding: .utf8) ?? ""
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

struct ChatScreen: View {
    @StateObject private var vm = ChatVM()
    @State private var input = ""
    @FocusState private var focused: Bool
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        NavigationView {
            ZStack {
                // Black background
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(vm.messages) { msg in
                                    ChatBubble(message: msg)
                                        .id(msg.id)
                                }
                                if vm.isLoading {
                                    HStack {
                                        Spacer()
                                        TypingIndicator()
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                            .padding(.bottom, 20)
                        }
                        .onChange(of: vm.messages.count) { _, _ in
                            if let last = vm.messages.last?.id {
                                withAnimation(.easeOut(duration: 0.3)) { 
                                    proxy.scrollTo(last, anchor: .bottom) 
                                }
                            }
                        }
                    }

                    // ChatGPT-style input bar
                    VStack(spacing: 0) {
                        Divider()
                            .background(Color.gray.opacity(0.3))
                        
                        HStack(spacing: 12) {
                            // Voice note button
                            Button {
                                // TODO: Implement voice recording
                            } label: {
                                Image(systemName: "mic.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.3), in: Circle())
                            }
                            
                            // Text input with bubble style
                            HStack {
                                TextField("Ask anything", text: $input, axis: .vertical)
                                    .foregroundColor(.white)
                                    .lineLimit(1...6)
                                    .focused($focused)
                                    .submitLabel(.send)
                                    .onSubmit { Task { await send() } }
                                
                                if !input.isEmpty {
                                    Button { Task { await send() } } label: {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                    }
                                    .disabled(vm.isLoading)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.black)
                    }
                }
            }
            .navigationTitle("MARD Helpline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        focused = false
                        router.selectedTab = .home
                    } label: {
                        Image(systemName: "house.fill")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focused = false }
                }
            }
        }
        .navigationViewStyle(.stack)
        .padding(.bottom, 90)
    }

    private func send() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        input = ""
        await vm.send(userText: text)
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !message.isUser {
                Avatar(system: "person.fill")
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                Text(message.text)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(message.isUser ? Color.blue : Color.gray.opacity(0.3))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(message.isUser ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: message.isUser ? .trailing : .leading)
                
                Text(Self.ts(message.time))
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)
            }
            
            if message.isUser {
                Avatar(system: "person.crop.circle.fill")
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }
    
    static func ts(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}

struct TypingIndicator: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                    .offset(y: animationOffset)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animationOffset
                    )
            }
        }
        .onAppear {
            animationOffset = -4
        }
    }
}

struct Avatar: View {
    let system: String
    let color: Color
    
    init(system: String, color: Color = .gray) {
        self.system = system
        self.color = color
    }
    
    var body: some View {
        Image(systemName: system)
            .foregroundColor(.white)
            .frame(width: 28, height: 28)
            .background(color, in: Circle())
    }
}

// MARK: - Community & Events (Groups + Group Chat + Events Gallery)
struct CommunityEventsScreen: View {
    @State private var selection = 0
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("", selection: $selection) {
                    Text("Communities").tag(0)
                    Text("Events").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if selection == 0 {
                    CommunitiesList()
                } else {
                    EventsGallery()
                }
            }
            .navigationTitle("Community & Events")
        }
        .navigationViewStyle(.stack)
        .padding(.bottom, 90)
    }
}

// MARK: - Communities List
struct CommunitiesList: View {
    @State private var groups: [CommunityGroup] = CommunityGroupStorage.load()
    @State private var showingCreate = false

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Communities").font(.title2.bold())
                    Spacer()
                    Button { showingCreate = true } label: {
                        Image(systemName: "plus.circle.fill").foregroundColor(.green)
                    }
                    .accessibilityLabel("Create Group")
                }
            }

            ForEach(groups) { group in
                NavigationLink(destination: GroupChatScreen(group: group)) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color(.systemGray5)).frame(width: 44, height: 44)
                            Image(systemName: group.icon).foregroundColor(.green)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.name).font(.headline)
                            Text(group.lastMessagePreview)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(GroupChatScreen.fmtDate(group.lastUpdated))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            .onDelete { indexSet in
                groups.remove(atOffsets: indexSet)
                CommunityGroupStorage.save(groups)
            }
        }
        .listStyle(.insetGrouped)
        .sheet(isPresented: $showingCreate) {
            CreateGroupSheet { name in
                let ng = CommunityGroup(id: UUID(), name: name, icon: "megaphone.fill", messages: [
                    GroupMessage(id: UUID(), text: "Welcome!", isUser: false, time: Date())
                ], lastUpdated: Date())
                groups.insert(ng, at: 0)
                CommunityGroupStorage.save(groups)
            }
        }
    }
}

// MARK: - Group Chat Screen (minimal, restored)
struct GroupChatScreen: View {
    let group: CommunityGroup
    @State private var messages: [GroupMessage] = []
    @State private var input: String = ""
    @FocusState private var focused: Bool
    
    init(group: CommunityGroup) {
        self.group = group
        _messages = State(initialValue: CommunityGroupStorage.loadMessages(for: group.id, fallback: group.messages))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(messages) { msg in
                            ChatBubbleRow(text: msg.text, isUser: msg.isUser, time: msg.time)
                                .id(msg.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last?.id {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }
            
            HStack(spacing: 8) {
                TextField("Message", text: $input, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit { send() }
                Button { send() } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.red, in: Circle())
                }
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
        .navigationTitle(group.name)
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = false } } }
    }
    
    private func send() {
        let t = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        messages.append(.init(id: UUID(), text: t, isUser: true, time: Date()))
        input = ""
        CommunityGroupStorage.saveMessages(messages, for: group.id)
    }
    
    static func fmtDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "dd/MM/yy"; return f.string(from: d)
    }
}

struct CreateGroupSheet: View {
    var onCreate: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("New Community") { TextField("Group name", text: $name) }
                Section { Button("Create") { guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }; onCreate(name); dismiss() } }
            }
            .navigationTitle("Create Group")
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Close") { dismiss() } } }
        }
    }
}

struct ChatBubbleRow: View {
    var text: String
    var isUser: Bool
    var time: Date
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isUser { Avatar(system: "person.fill", color: .gray) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(text)
                    .padding(12)
                    .foregroundColor(isUser ? .white : .primary)
                    .background(
                        isUser
                        ? AnyView(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.red.gradient))
                        : AnyView(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.systemGray6)))
                    )
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: isUser ? .trailing : .leading)
                Text(Self.ts(time)).font(.caption2).foregroundColor(.secondary).padding(.horizontal, 4)
            }
            if isUser { Avatar(system: "person.crop.circle.fill", color: .blue) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
    
    static func ts(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}


// MARK: - App Event Detail Model (ONLY ONE)
struct AppEventDetail: Identifiable, Codable {
    let id: UUID
    let title: String
    let date: String
    let time: String
    let venue: String
    let address: String
    let imageCandidates: [String]
    let blurb: String
}

// MARK: - Event Registration Storage (ONLY ONE - KEEP THIS VERSION)
class EventRegistrationStorage {
    private static let registeredEventsKey = "RegisteredEvents"
    
    static func register(_ event: AppEventDetail) {
        var registeredIds = getRegisteredEventIds()
        registeredIds.insert(event.id)
        saveRegisteredEventIds(registeredIds)
    }
    
    static func isRegistered(_ eventId: UUID) -> Bool {
        let registeredIds = getRegisteredEventIds()
        return registeredIds.contains(eventId)
    }
    
    static func getRegisteredEventIds() -> Set<UUID> {
        if let data = UserDefaults.standard.data(forKey: registeredEventsKey),
           let uuidStrings = try? JSONDecoder().decode([String].self, from: data) {
            return Set(uuidStrings.compactMap { UUID(uuidString: $0) })
        }
        return Set<UUID>()
    }
    
    private static func saveRegisteredEventIds(_ ids: Set<UUID>) {
        let uuidStrings = Array(ids).map { $0.uuidString }
        if let data = try? JSONEncoder().encode(uuidStrings) {
            UserDefaults.standard.set(data, forKey: registeredEventsKey)
        }
    }
}

// MARK: - Events Gallery
struct EventsGallery: View {
    @State private var showRegisteredToast = false
    @State private var registeredEvents: Set<UUID> = []
    
    private let events: [AppEventDetail] = [
        .init(
            id: UUID(),
            title: "Therapy Workshop",
            date: "Sep 15, 2025",
            time: "5:00 PM – 7:00 PM",
            venue: "Near Akurdi Railway Station",
            address: "Mindful Space, Akurdi, Pune",
            imageCandidates: ["therapy"],
            blurb: "An introductory workshop to therapy and self-care routines. Small group activities with a licensed counselor."
        ),
        .init(
            id: UUID(),
            title: "Group Therapy Meetup",
            date: "Oct 02, 2025",
            time: "6:30 PM – 8:30 PM",
            venue: "DYPIU (D.Y. Patil International University)",
            address: "Akurdi, Pune",
            imageCandidates: ["groupTherapy"],
            blurb: "Peer-led sharing circle hosted at DYPIU with professional moderation. Open to all genders."
        ),
        .init(
            id: UUID(),
            title: "Game Therapy Night",
            date: "Oct 25, 2025",
            time: "7:00 PM – 9:30 PM",
            venue: "Wellness Hub, Nigdi",
            address: "Near Akurdi, Pune",
            imageCandidates: ["gameTherapy"],
            blurb: "Light games, conversation and guided breathing to unwind together in a safe space."
        )
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(events) { ev in
                    EventCard(
                        event: ev,
                        isRegistered: registeredEvents.contains(ev.id),
                        onRegister: {
                            registerForEvent(ev)
                        }
                    )
                }
            }
            .padding(.top, 8)
        }
        .overlay(alignment: .bottom) {
            if showRegisteredToast {
                Text("Registered successfully!")
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            loadRegisteredEvents()
        }
    }
    
    private func registerForEvent(_ event: AppEventDetail) {
        registeredEvents.insert(event.id)
        EventRegistrationStorage.register(event)
        withAnimation { showRegisteredToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showRegisteredToast = false }
        }
    }
    
    private func loadRegisteredEvents() {
        registeredEvents = EventRegistrationStorage.getRegisteredEventIds()
    }
}

// MARK: - Event Card Component
struct EventCard: View {
    let event: AppEventDetail
    let isRegistered: Bool
    let onRegister: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                Image(event.imageCandidates.first ?? "")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .bottom, endPoint: .center)
                    .cornerRadius(16)

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title).font(.headline).foregroundColor(.white)
                    Text("\(event.date) • \(event.time)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Label(event.venue, systemImage: "mappin.and.ellipse").font(.caption)
                    .foregroundColor(.secondary)
                Text(event.address).font(.caption2).foregroundColor(.secondary)
                    .padding(.leading, 26)
            }
            .padding(.horizontal, 4)

            HStack {
                NavigationLink(destination: EventDetailsView(event: event)) {
                    Label("Details", systemImage: "info.circle")
                }
                
                Spacer()
                
                Button {
                    if !isRegistered {
                        onRegister()
                    }
                } label: {
                    if isRegistered {
                        Label("Registered", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.white)
                    } else {
                        Label("Register", systemImage: "plus.circle.fill")
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(isRegistered ? .gray : .blue)
                .disabled(isRegistered)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal)
    }
}

// MARK: - Event Details View (ONLY ONE - KEEP THIS VERSION)
struct EventDetailsView: View {
    let event: AppEventDetail
    @State private var isRegistered: Bool = false
    @State private var showRegisteredToast = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Event Image
                Image(event.imageCandidates.first ?? "")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                VStack(alignment: .leading, spacing: 12) {
                    // Title
                    Text(event.title)
                        .font(.largeTitle.bold())
                    
                    // Date & Time
                    Label("\(event.date) • \(event.time)", systemImage: "calendar")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    // Venue
                    Label(event.venue, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(event.address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 28)
                    
                    Divider()
                    
                    // Description
                    Text("About This Event")
                        .font(.headline)
                    
                    Text(event.blurb)
                        .font(.body)
                        .lineSpacing(4)
                    
                    Divider()
                    
                    // What to Expect Section
                    Text("What to expect")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("• Safe and respectful environment")
                        Text("• Limited seats; arrive 10 minutes early")
                        Text("• Light refreshments available")
                    }
                    .font(.body)
                    .foregroundColor(.secondary)
                }
                .padding()
                
                Spacer(minLength: 100)
            }
        }
        .overlay(alignment: .bottom) {
            // Fixed Register Button
            VStack {
                Button {
                    if !isRegistered {
                        registerForEvent()
                    }
                } label: {
                    HStack {
                        Image(systemName: isRegistered ? "checkmark.circle.fill" : "plus.circle.fill")
                        Text(isRegistered ? "Registered" : "Register for Event")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isRegistered ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(isRegistered)
                .padding()
                .background(.ultraThinMaterial)
                
                if showRegisteredToast {
                    Text("Successfully registered!")
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.green, in: Capsule())
                        .foregroundColor(.white)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationTitle("Event Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkRegistrationStatus()
        }
    }
    
    private func registerForEvent() {
        EventRegistrationStorage.register(event)
        isRegistered = true
        
        withAnimation { showRegisteredToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showRegisteredToast = false }
        }
    }
    
    private func checkRegistrationStatus() {
        isRegistered = EventRegistrationStorage.isRegistered(event.id)
    }
}

// MARK: - Community Data Models & Storage (Keep this as is)
struct CommunityGroup: Identifiable, Codable {
    let id: UUID
    var name: String
    var icon: String
    var messages: [GroupMessage]
    var lastUpdated: Date
    var lastMessagePreview: String { messages.last?.text ?? "Announcements" }
}

struct GroupMessage: Identifiable, Codable {
    let id: UUID
    var text: String
    var isUser: Bool
    var time: Date
}

enum CommunityGroupStorage {
    private static let groupsKey = "community.groups.v1"
    static func load() -> [CommunityGroup] {
        if let data = UserDefaults.standard.data(forKey: groupsKey),
           let arr = try? JSONDecoder().decode([CommunityGroup].self, from: data) { return arr }
        return [
            CommunityGroup(
                id: UUID(),
                name: "Announcements",
                icon: "megaphone.fill",
                messages: [GroupMessage(id: UUID(), text: "Welcome to the community!", isUser: false, time: Date().addingTimeInterval(-86400))],
                lastUpdated: Date().addingTimeInterval(-86400)
            ),
            CommunityGroup(
                id: UUID(),
                name: "General Support",
                icon: "person.3.fill",
                messages: [GroupMessage(id: UUID(), text: "You are not alone.", isUser: false, time: Date().addingTimeInterval(-3600))],
                lastUpdated: Date().addingTimeInterval(-3600)
            )
        ]
    }
    static func save(_ arr: [CommunityGroup]) {
        if let data = try? JSONEncoder().encode(arr) { UserDefaults.standard.set(data, forKey: groupsKey) }
    }
    static func loadMessages(for groupId: UUID, fallback: [GroupMessage]) -> [GroupMessage] {
        let key = "community.messages.\(groupId.uuidString)"
        if let data = UserDefaults.standard.data(forKey: key), let arr = try? JSONDecoder().decode([GroupMessage].self, from: data) { return arr }
        return fallback
    }
    static func saveMessages(_ arr: [GroupMessage], for groupId: UUID) {
        let key = "community.messages.\(groupId.uuidString)"
        if let data = try? JSONEncoder().encode(arr) { UserDefaults.standard.set(data, forKey: key) }
    }
}

// MARK: - Asset Image (Keep this)
struct AssetImage: View {
    let candidates: [String]
    var body: some View {
        if let name = candidates.first(where: { UIImage(named: $0) != nil }) {
            Image(name)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray5))
                Image(systemName: "photo").font(.largeTitle).foregroundColor(.gray)
            }
        }
    }
}

import SwiftUI
import Photos
import AVKit
import GoogleSignIn
import GoogleAPIClientForREST_Drive

// MARK: - Google Drive Manager (Complete Fixed Version)
class GoogleDriveManager: ObservableObject {
    @Published var isSignedIn = false
    @Published var userEmail = ""
    @Published var isUploading = false
    @Published var uploadProgress = 0.0
    @Published var showUploadOptions = false
    @Published var pendingVideoURL: URL?
    
    private var driveService: GTLRDriveService?
    private let folderName = "Mard Helpline Evidence"
    
    static let shared = GoogleDriveManager()
    
    init() {
        checkSignInStatus()
    }
    
    func checkSignInStatus() {
        if let user = GIDSignIn.sharedInstance.currentUser {
            DispatchQueue.main.async {
                self.isSignedIn = true
                self.userEmail = user.profile?.email ?? ""
                self.setupDriveService(user: user)
            }
        }
    }
    
    func signIn() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            if let error = error {
                print("❌ Google Sign-In error: \(error.localizedDescription)")
                print("❌ Error details: \(error)")
                return
            }
            
            guard let user = result?.user else { 
                print("❌ No user returned from sign-in")
                return 
            }
            
            print("✅ Google Sign-In successful for user: \(user.profile?.email ?? "unknown")")
            
            DispatchQueue.main.async {
                self?.isSignedIn = true
                self?.userEmail = user.profile?.email ?? ""
                self?.setupDriveService(user: user)
                UserDefaults.standard.set(true, forKey: "googleDriveConnected")
                print("✅ Drive service setup complete")
            }
        }
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        DispatchQueue.main.async {
            self.isSignedIn = false
            self.userEmail = ""
            self.driveService = nil
            UserDefaults.standard.set(false, forKey: "googleDriveConnected")
        }
    }
    
    func debugDriveStatus() {
        print("🔍 === GOOGLE DRIVE DEBUG STATUS ===")
        print("🔍 isSignedIn: \(isSignedIn)")
        print("🔍 userEmail: \(userEmail)")
        print("🔍 driveService exists: \(driveService != nil)")
        print("🔍 autoUploadEnabled: \(UserDefaults.standard.bool(forKey: "autoUploadEnabled"))")
        print("🔍 googleDriveConnected: \(UserDefaults.standard.bool(forKey: "googleDriveConnected"))")
        print("🔍 Current user: \(GIDSignIn.sharedInstance.currentUser?.profile?.email ?? "None")")
        print("🔍 === END DEBUG STATUS ===")
    }
    
    private func setupDriveService(user: GIDGoogleUser) {
        driveService = GTLRDriveService()
        driveService?.authorizer = user.fetcherAuthorizer
    }
    
    func autoUploadVideo(videoURL: URL) {
        print("🔍 Debug: isSignedIn=\(isSignedIn), driveService=\(driveService != nil)")
        print("🔍 Debug: autoUploadEnabled=\(UserDefaults.standard.bool(forKey: "autoUploadEnabled"))")
        print("🔍 Debug: userEmail=\(userEmail)")
        
        guard UserDefaults.standard.bool(forKey: "autoUploadEnabled"),
              isSignedIn else {
            print("⚠️ Auto-upload disabled or not signed in")
            print("⚠️ autoUploadEnabled: \(UserDefaults.standard.bool(forKey: "autoUploadEnabled"))")
            print("⚠️ isSignedIn: \(isSignedIn)")
            return
        }
        
        ensureDriveScopes { [weak self] ok in
            guard let self = self, ok else {
                print("❌ Drive scopes not granted; cannot upload")
                return
            }
            print("🔄 Starting auto-upload...")
            self.isUploading = true
            self.createFolderIfNeeded { folderID in
                guard let folderID = folderID,
                      let service = self.driveService else {
                    DispatchQueue.main.async {
                        self.isUploading = false
                        print("❌ Upload failed: Missing folder or service")
                    }
                    return
                }
                self.uploadVideoToDrive(videoURL: videoURL, folderID: folderID, service: service)
            }
        }
    }

    // Request Drive scopes on-demand without changing the existing sign-in UI
    private func ensureDriveScopes(completion: @escaping (Bool) -> Void) {
        let needed = [
            "https://www.googleapis.com/auth/drive.file",
            "https://www.googleapis.com/auth/drive"
        ]
        guard let user = GIDSignIn.sharedInstance.currentUser else { completion(false); return }
        let granted = Set(user.grantedScopes ?? [])
        if Set(needed).isSubset(of: granted) { completion(true); return }
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first?.rootViewController else { completion(false); return }
        user.addScopes(needed, presenting: root) { _, error in
            if let error = error { print("❌ addScopes error: \(error)"); completion(false); return }
            completion(true)
        }
    }
    
    func manualUploadVideo(videoURL: URL) {
        print("🔄 Starting manual upload...")
        isUploading = true
        createFolderIfNeeded { folderID in
            guard let folderID = folderID,
                  let service = self.driveService else {
                DispatchQueue.main.async {
                    self.isUploading = false
                    print("❌ Manual upload failed: Missing folder or service")
                }
                return
            }
            
            self.uploadVideoToDrive(videoURL: videoURL, folderID: folderID, service: service)
        }
    }
    
    private func createFolderIfNeeded(completion: @escaping (String?) -> Void) {
        guard let service = driveService else {
            print("❌ Drive service is nil")
            completion(nil)
            return
        }
        
        print("🔍 Searching for existing folder: \(folderName)")
        let query = GTLRDriveQuery_FilesList.query()
        query.q = "name='\(folderName)' and mimeType='application/vnd.google-apps.folder' and trashed=false"
        
        service.executeQuery(query) { (ticket, result, error) in
            if let error = error {
                print("❌ Error searching for folder: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            if let fileList = result as? GTLRDrive_FileList,
               let existingFolder = fileList.files?.first {
                print("✅ Found existing folder: \(existingFolder.identifier ?? "unknown")")
                completion(existingFolder.identifier)
                return
            }
            
            print("🔍 Creating new folder: \(self.folderName)")
            let folder = GTLRDrive_File()
            folder.name = self.folderName
            folder.mimeType = "application/vnd.google-apps.folder"
            
            let createQuery = GTLRDriveQuery_FilesCreate.query(withObject: folder, uploadParameters: nil)
            
            service.executeQuery(createQuery) { (ticket, result, error) in
                if let error = error {
                    print("❌ Error creating folder: \(error.localizedDescription)")
                    completion(nil)
                } else if let createdFolder = result as? GTLRDrive_File {
                    print("✅ Created new folder: \(createdFolder.identifier ?? "unknown")")
                    completion(createdFolder.identifier)
                } else {
                    print("❌ Failed to create folder - no result")
                    completion(nil)
                }
            }
        }
    }
    
    private func uploadVideoToDrive(videoURL: URL, folderID: String, service: GTLRDriveService) {
        let file = GTLRDrive_File()
        file.name = "Evidence_\(Date().timeIntervalSince1970).mov"
        file.parents = [folderID]
        
        guard let videoData = try? Data(contentsOf: videoURL) else {
            DispatchQueue.main.async {
                self.isUploading = false
                print("❌ Upload failed: Could not read video file")
            }
            return
        }
        
        print("📁 Video size: \(videoData.count) bytes")
        
        let uploadParameters = GTLRUploadParameters(data: videoData, mimeType: "video/quicktime")
        let query = GTLRDriveQuery_FilesCreate.query(withObject: file, uploadParameters: uploadParameters)
        
        service.executeQuery(query) { (ticket, result, error) in
            DispatchQueue.main.async {
                self.isUploading = false
                
                if let error = error {
                    print("❌ Upload failed: \(error.localizedDescription)")
                } else {
                    print("✅ Video auto-uploaded to Google Drive!")
                }
            }
        }
    }
}

// MARK: - Video Manager (Your existing code - unchanged)
class VideoManager: ObservableObject {
    @Published var savedVideos: [SavedVideo] = []
    @Published var isLoading = false
    
    struct SavedVideo: Identifiable, Codable {
        let id = UUID()
        var fileName: String
        let url: URL
        let date: Date
        let fileSize: String
        
        // Add this coding keys enum
        enum CodingKeys: String, CodingKey {
            case fileName, url, date, fileSize
        }
        
        // The rest of your computed properties stay the same...
        var displayName: String {
            fileName.replacingOccurrences(of: ".mov", with: "")
                    .replacingOccurrences(of: ".mp4", with: "")
                    .replacingOccurrences(of: "evidence_", with: "")
                    .replacingOccurrences(of: "evidence-", with: "")
        }
        
        var formattedDate: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM dd, yyyy"
            return formatter.string(from: date)
        }
        
        var formattedTime: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        }
    }
    
    init() {
        loadSavedVideos()
    }
    
    func loadSavedVideos() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let videoExtensions = ["mov", "mp4", "m4v"]
            
            do {
                let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
                
                let videoFiles = files.filter { url in
                    videoExtensions.contains(url.pathExtension.lowercased()) &&
                    (url.lastPathComponent.contains("evidence") || url.lastPathComponent.contains("video"))
                }
                
                let savedVideos = videoFiles.compactMap { url -> SavedVideo? in
                    do {
                        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                        let fileSize = attributes[.size] as? Int64 ?? 0
                        let creationDate = attributes[.creationDate] as? Date ?? Date()
                        
                        return SavedVideo(
                            fileName: url.lastPathComponent,
                            url: url,
                            date: creationDate,
                            fileSize: ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
                        )
                    } catch {
                        return nil
                    }
                }.sorted { $0.date > $1.date }
                
                DispatchQueue.main.async {
                    self?.savedVideos = savedVideos
                    self?.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self?.isLoading = false
                    print("❌ Error loading videos: \(error)")
                }
            }
        }
    }
    
    func renameVideo(_ video: SavedVideo, to newName: String) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileExtension = video.url.pathExtension
        let cleanName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let newFileName = "evidence-\(cleanName).\(fileExtension)"
        let newURL = documentsPath.appendingPathComponent(newFileName)
        
        do {
            if FileManager.default.fileExists(atPath: newURL.path) {
                print("❌ A file with this name already exists")
                return
            }
            
            try FileManager.default.moveItem(at: video.url, to: newURL)
            
            if let index = savedVideos.firstIndex(where: { $0.id == video.id }) {
                var updatedVideo = savedVideos[index]
                updatedVideo.fileName = newFileName
                savedVideos[index] = updatedVideo
            }
            
            print("✅ Video renamed to: \(newFileName)")
        } catch {
            print("❌ Rename error: \(error.localizedDescription)")
        }
    }
    
    func deleteVideo(_ video: SavedVideo) {
        do {
            try FileManager.default.removeItem(at: video.url)
            savedVideos.removeAll { $0.id == video.id }
            print("✅ Video deleted: \(video.fileName)")
        } catch {
            print("❌ Delete error: \(error.localizedDescription)")
        }
    }
}


// MARK: - Updated Profile Screen (Google Drive Integration)
struct ProfileScreen: View {
    @State private var notifications = true
    @AppStorage("auth.loggedIn") private var loggedIn = false
    @AppStorage("auth.name") private var name = ""
    @AppStorage("auth.email") private var email = ""
    @State private var showAuth = false
    @StateObject private var videoManager = VideoManager()
    @StateObject private var driveManager = GoogleDriveManager.shared
    
    // Helper computed properties
    private var displayName: String {
        if driveManager.isSignedIn {
            // Use Google name if available, fallback to email username
            return driveManager.userEmail.components(separatedBy: "@").first?.capitalized ?? "Google User"
        } else if loggedIn {
            return name.isEmpty ? "Welcome" : name
        } else {
            return "Guest"
        }
    }
    
    private var displayEmail: String {
        if driveManager.isSignedIn {
            return driveManager.userEmail
        } else if loggedIn {
            return email
        } else {
            return "Please sign in to personalize"
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            // Profile Image - green if Google connected
                            Image(systemName: "person.crop.circle.fill")
                                .resizable().frame(width: 84, height: 84)
                                .foregroundColor(driveManager.isSignedIn ? .green : .gray)
                            
                            Text(displayName).font(.headline)
                            Text(displayEmail).font(.caption).foregroundColor(.secondary)
                            
                            // Google Drive Status
                            if driveManager.isSignedIn {
                                HStack {
                                    Image(systemName: "icloud.fill")
                                        .foregroundColor(.green)
                                    Text("Google Drive Connected")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                                .padding(.top, 2)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical)
                }

                Section(header: Text("Evidence")) {
                    NavigationLink {
                        SavedVideosView(videoManager: videoManager)
                    } label: {
                        HStack {
                            Image(systemName: "video.fill")
                                .foregroundColor(.red)
                                .frame(width: 25)
                            Text("Saved Videos")
                            Spacer()
                            if !videoManager.savedVideos.isEmpty {
                                Text("\(videoManager.savedVideos.count)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(.red, in: Capsule())
                            }
                        }
                    }
                }

                Section(header: Text("Preferences")) {
                    Toggle("Notifications", isOn: $notifications)
                    NavigationLink("Trusted Contacts") { DetailText("Add trusted contacts for quick share.") }
                    NavigationLink("Cloud Storage") { CloudStorageSettingsView() }
                }

                Section(header: Text("About")) {
                    NavigationLink("About App") { AboutAppView() }
                    NavigationLink("Privacy Policy") { PrivacyPolicyView() }
                }

                Section {
                    // Authentication options based on current state
                    if !loggedIn && !driveManager.isSignedIn {
                        // Not signed in anywhere
                        Button { showAuth = true } label: {
                            Text("Sign In / Create Account")
                        }
                        
                        Button {
                            driveManager.signIn()
                        } label: {
                            HStack {
                                Image(systemName: "icloud.fill")
                                Text("Sign In with Google")
                            }
                        }
                        .foregroundColor(.blue)
                        
                    } else if loggedIn && !driveManager.isSignedIn {
                        // Only local account
                        Button {
                            driveManager.signIn()
                        } label: {
                            HStack {
                                Image(systemName: "icloud.fill")
                                Text("Connect Google Drive")
                            }
                        }
                        .foregroundColor(.blue)
                        
                        Button(role: .destructive) {
                            loggedIn = false; name = ""; email = ""
                        } label: {
                            Text("Logout Local Account")
                        }
                        
                    } else if driveManager.isSignedIn && !loggedIn {
                        // Only Google account
                        Button { showAuth = true } label: {
                            Text("Add Local Profile")
                        }
                        
                        Button(role: .destructive) {
                            driveManager.signOut()
                        } label: {
                            Text("Disconnect Google Drive")
                        }
                        
                    } else {
                        // Both accounts connected
                        Button(role: .destructive) {
                            loggedIn = false; name = ""; email = ""
                        } label: {
                            Text("Logout Local Account")
                        }
                        
                        Button(role: .destructive) {
                            driveManager.signOut()
                        } label: {
                            Text("Disconnect Google Drive")
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .onAppear {
                videoManager.loadSavedVideos()
            }
        }
        .navigationViewStyle(.stack)
        .padding(.bottom, 90)
        .sheet(isPresented: $showAuth) { AuthSheet() }
    }
}

// MARK: - Saved Videos View with Gestures
struct SavedVideosView: View {
    @ObservedObject var videoManager: VideoManager
    @State private var showDeleteAlert = false
    @State private var videoToDelete: VideoManager.SavedVideo?
    @State private var showRenameAlert = false
    @State private var videoToRename: VideoManager.SavedVideo?
    @State private var newVideoName = ""
    
    var body: some View {
        Group {
            if videoManager.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading videos...")
                        .foregroundColor(.secondary)
                }
            } else if videoManager.savedVideos.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No Evidence Videos")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Recorded videos will appear here")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                List {
                    ForEach(videoManager.savedVideos) { video in
                        VideoCard(
                            video: video,
                            onRename: {
                                videoToRename = video
                                newVideoName = video.displayName
                                showRenameAlert = true
                            },
                            onDelete: {
                                videoToDelete = video
                                showDeleteAlert = true
                            }
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .padding(.vertical, 4)
                        // SWIPE TO DELETE
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                videoToDelete = video
                                showDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash.fill")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    videoManager.loadSavedVideos()
                }
            }
        }
        .navigationTitle("Saved Videos")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Rename Video", isPresented: $showRenameAlert) {
            TextField("Enter new name", text: $newVideoName)
                .textInputAutocapitalization(.words)
            Button("Cancel", role: .cancel) {
                newVideoName = ""
            }
            Button("Rename") {
                if let video = videoToRename, !newVideoName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    videoManager.renameVideo(video, to: newVideoName)
                }
                newVideoName = ""
            }
            .disabled(newVideoName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Enter a new name for this evidence video")
        }
        .alert("Delete Video", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let video = videoToDelete {
                    videoManager.deleteVideo(video)
                }
            }
        } message: {
            Text("This evidence video will be permanently deleted. This cannot be undone.")
        }
    }
}

// MARK: - Video Card with Long Press & Swipe
struct VideoCard: View {
    let video: VideoManager.SavedVideo
    let onRename: () -> Void
    let onDelete: () -> Void
    @State private var showVideoPlayer = false
    @State private var showShareSheet = false
    @State private var thumbnail: UIImage?
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Rectangle()
                    .fill(.red.opacity(0.1))
                    .frame(height: 120)
                    .overlay {
                        if let thumbnail = thumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .clipped()
                        }
                    }
                    .overlay {
                        Button {
                            showVideoPlayer = true
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                                    .background(.black.opacity(0.6), in: Circle())
                                
                                Text("Tap to Play")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.black.opacity(0.6), in: Capsule())
                            }
                        }
                    }
            }
            .cornerRadius(12, corners: [.topLeft, .topRight])
            .onAppear {
                generateThumbnail()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                        
                        HStack {
                            Text(video.formattedDate)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(video.formattedTime)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(video.fileSize)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        // LONG PRESS TO RENAME
        .onLongPressGesture {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onRename()
        }
        .fullScreenCover(isPresented: $showVideoPlayer) {
            SimpleVideoPlayer(videoURL: video.url)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [video.url])
        }
    }
    
    private func generateThumbnail() {
        let asset = AVURLAsset(url: video.url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 300, height: 200)
        
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        
        imageGenerator.generateCGImageAsynchronously(for: time) { cgImage, _, error in
            DispatchQueue.main.async {
                if let cgImage = cgImage {
                    self.thumbnail = UIImage(cgImage: cgImage)
                } else if let error = error {
                    print("❌ Thumbnail error: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Simple Video Player
struct SimpleVideoPlayer: View {
    let videoURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black
                .ignoresSafeArea()
            
            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Loading video...")
                        .foregroundColor(.white)
                        .padding(.top)
                }
            }
            
            Button {
                player?.pause()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .background(.black.opacity(0.5), in: Circle())
            }
            .padding()
        }
        .onAppear { setupPlayer() }
        .onDisappear { player?.pause() }
    }
    
    private func setupPlayer() {
        let asset = AVURLAsset(url: videoURL)
        let item = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: item)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { player?.play() }
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Cloud Storage Settings
struct CloudStorageSettingsView: View {
    @AppStorage("autoUploadEnabled") private var autoUploadEnabled = false
    @StateObject private var driveManager = GoogleDriveManager.shared
    @State private var showSignInAlert = false
    
    var body: some View {
        Form {
            Section(header: Text("Google Drive")) {
                if driveManager.isSignedIn {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading) {
                            Text("Connected")
                                .font(.headline)
                            Text(driveManager.userEmail)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Sign Out") {
                            driveManager.signOut()
                            autoUploadEnabled = false
                        }
                        .foregroundColor(.red)
                    }
                } else {
                    Button("Connect Google Drive") {
                        driveManager.signIn()
                    }
                    .foregroundColor(.blue)
                }
            }
            
            Section(header: Text("Auto Upload")) {
                Toggle("Auto-upload videos", isOn: $autoUploadEnabled)
                    .disabled(!driveManager.isSignedIn)
                    .onChange(of: autoUploadEnabled) {
                        if autoUploadEnabled && !driveManager.isSignedIn {
                            showSignInAlert = true
                            autoUploadEnabled = false
                        }
                    }
                
                Button("Debug Drive Status") {
                    driveManager.debugDriveStatus()
                }
                .foregroundColor(.blue)
                
                if driveManager.isUploading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Uploading video...")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section(header: Text("Storage Info")) {
                Label("Videos encrypted before upload", systemImage: "lock.fill")
                    .foregroundColor(.green)
                Label("Only you can access your videos", systemImage: "eye.slash.fill")
                    .foregroundColor(.blue)
                Label("Uploads to 'Mard Helpline Evidence' folder", systemImage: "folder.fill")
                    .foregroundColor(.orange)
            }
        }
        .navigationTitle("Cloud Storage")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Sign In Required", isPresented: $showSignInAlert) {
            Button("Sign In") {
                driveManager.signIn()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please connect your Google Drive account to enable auto-upload")
        }
    }
}


// MARK: - About & Privacy
struct AboutAppView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("About MARD Helpline").font(.title2.bold())
                Group {
                    Text("MARD Helpline is a community-first safety companion designed to help people navigate difficult moments with confidence. The app combines quick-access emergency tools, live location sharing, evidence capture, and a caring community space to talk, learn, and support one another. We believe that safety is a shared responsibility and that access to help should be immediate, respectful, and stigma-free.")
                    Text("Our product philosophy is simple: clarity over complexity, privacy by default, and empathy in every interaction. From the red emergency button to the calm wellness features, every screen is crafted to reduce friction when time and attention are scarce. We work with counselors, legal experts, and volunteers to continuously improve guidance and resources that reflect real needs.")
                    Text("The Communities tab offers moderated group conversations and local events such as therapy workshops and support circles. These spaces are built for trust—no public profile is required, conversations are civil by design, and you can control what you share. Our in-app reporting tools and clear community guidelines help keep discussions constructive and inclusive.")
                    Text("For evidence capture, the camera button enables quick video recording that saves both to your device’s Photos app and within the app’s secure storage. This is meant to preserve context around incidents and provide a time-stamped record should you need to reference it later. We recommend also keeping a personal journal entry to note details right after an event while they are fresh.")
                    Text("MARD Helpline is a living project. We ship improvements frequently, guided by feedback from learners, families, and professionals. If you have suggestions or find accessibility issues, please reach out through the Profile tab. Your input directly shapes our roadmap and helps us serve more people safely.")
                    Text("Important: This app does not replace emergency services or legal counsel. In urgent situations, please use the emergency button to contact authorities or dial local emergency numbers directly. For legal matters, consult a qualified professional; our legal resources are educational and not a substitute for advice.")
                }
            }
            .padding()
        }
        .navigationTitle("About App")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy").font(.title2.bold())
                Group {
                    Text("1. Data Minimization: We collect only what is necessary to provide core features such as emergency calling, location sharing, community messages, and wellness tracking. Most information you generate (journal entries, community posts, and camera evidence) is stored on your device and synced to your iCloud/backup only if enabled at the OS level.")
                    Text("2. Local-First Storage: Journal entries, community messages, and recorded videos are stored locally on your device. Registration for events is stored as simple records in local storage. We do not upload your personal content to our servers. If future features require remote storage, you will receive a clear in-app prompt and control over participation.")
                    Text("3. Permissions & Access: Camera, Photos, Contacts, and Location permissions are requested only when you invoke related features. You can revoke permissions anytime from System Settings. If a permission is denied, the feature will degrade gracefully with clear messaging.")
                    Text("4. No Third‑Party Ads: We do not serve ads or share your personal data with advertisers. Analytics, if enabled in future versions, will be privacy-preserving, aggregated, and optional. We do not sell personal information.")
                    Text("5. Community Safety: Community spaces are moderated. Abusive content, harassment, or illegal activity is not tolerated. We may provide tools to block, mute, or report users. If a report indicates imminent harm, we encourage contacting authorities; we do not monitor private content proactively.")
                    Text("6. Security Practices: The app leverages platform security (Keychain, App Transport Security, sandboxing). Where credentials are used, they are stored securely. Keep your device passcode enabled and software updated. Avoid sharing sensitive details publicly in community spaces.")
                    Text("7. Your Controls: You can edit or delete your journal entries and community posts stored on the device. Videos saved to Photos can be removed from the Photos app at any time. Uninstalling the app removes all app-stored data on your device.")
                }
                Group {
                    Text("8. Children’s Privacy: This app is intended for general audiences. If you are under the age threshold in your region, use the app with a guardian’s guidance. Do not share personal contact details publicly.")
                    Text("9. Policy Updates: If we change how data is handled, we will update this page and highlight changes in-app. Continuing to use the app after updates constitutes acceptance of the revised policy.")
                    Text("10. Contact: For privacy questions or requests, please reach out through the Profile tab’s feedback option or your app store contact channel. We aim to respond within a reasonable timeframe.")
                }
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
// Simple local auth sheet storing to AppStorage; persists across relaunches automatically
struct AuthSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("auth.loggedIn") private var loggedIn = false
    @AppStorage("auth.name") private var name = ""
    @AppStorage("auth.email") private var email = ""
    @State private var inputName = ""
    @State private var inputEmail = ""
    @State private var inputPassword = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Create Account / Sign In") {
                    TextField("Full Name", text: $inputName)
                    .textContentType(.name)
                    .autocapitalization(.words)
                    TextField("Email", text: $inputEmail)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                    SecureField("Password", text: $inputPassword)
                        .textContentType(.password)
                }
                Section {
                    Button {
                        guard !inputEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                              !inputPassword.isEmpty else { return }
                        name = inputName.trimmingCharacters(in: .whitespacesAndNewlines)
                        email = inputEmail.trimmingCharacters(in: .whitespacesAndNewlines)
                        loggedIn = true
                        dismiss()
                    } label: {
                        Text("Continue").frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Sign In")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Close") { dismiss() } }
            }
        }
    }
}

// MARK: - Wellness Features
// Daily Journal, Relaxing Audio, News, and Challenges
import AVFoundation

// MARK: - Daily Journal
// Mood tracking and journal entries with statistics
struct DailyJournalView: View {
    @State private var entries: [JournalEntry] = JournalStorage.load()
    @State private var text = ""
    @State private var selectedMood: Mood = .neutral
    @State private var showingMoodPicker = false
    @State private var isRecording = false
    @State private var selectedTab = 0
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var voiceEntries: [VoiceEntry] = VoiceStorage.load()
    @State private var renamingText: String = ""
    @State private var entryToRename: UUID?
    @State private var showRenameAlert = false
    @State private var sharingItems: [Any] = []
    @State private var showShareSheet = false
    @State private var audioPlayer: AVAudioPlayer?

    var body: some View {
        ZStack {
            // Black background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with mood insights
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(entries.count)")
                                .font(.title.bold())
                                .foregroundColor(.orange)
                            Text("Journal Entries")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(entries.filter { Calendar.current.isDateInToday($0.date) }.count)")
                                .font(.title.bold())
                                .foregroundColor(.green)
                            Text("Today")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Mood insights chart
                    if !entries.isEmpty {
                        MoodInsightsChart(entries: entries)
                    }
                }
                .padding(.vertical, 20)
                .background(Color.black)
                
                // Tab selector
                Picker("View", selection: $selectedTab) {
                    Text("Entries").tag(0)
                    Text("Insights").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                
                if selectedTab == 0 {
                    // Journal entries
                    if entries.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 48))
                                .foregroundColor(.orange.opacity(0.6))
                            Text("Start Your Journey")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                            Text("Write your first entry to begin tracking your thoughts and feelings.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(40)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(entries) { entry in
                                    JournalBubble(entry: entry)
                                }
                                if !voiceEntries.isEmpty {
                                    HStack { Text("Voice Journal").font(.headline).foregroundColor(.white); Spacer() }
                                    ForEach(voiceEntries) { v in
                                        VoiceRow(
                                            entry: v,
                                            onPlay: { playVoice(v) },
                                            onRename: { beginRenameVoice(v) },
                                            onShare: { shareVoice(v) },
                                            onDelete: { deleteVoice(v) }
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                } else {
                    // Mood insights
                    MoodInsightsView(entries: entries)
                }
                
                // ChatGPT-style input section
                VStack(spacing: 0) {
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    VStack(spacing: 12) {
                        // Mood selector
                        HStack {
                            Button {
                                showingMoodPicker = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: selectedMood.icon)
                                        .foregroundColor(selectedMood.color)
                                    Text(selectedMood.rawValue)
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedMood.color.opacity(0.2), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                        }
                        
                        // Input area
                        HStack(alignment: .bottom, spacing: 12) {
                            // Voice recording button
                            Button {
                                toggleRecording()
                            } label: {
                                Image(systemName: isRecording ? "stop.circle.fill" : "mic.fill")
                                    .font(.title3)
                                    .foregroundColor(isRecording ? .red : .white)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.3), in: Circle())
                            }
                            
                            // Text input with bubble style
                            HStack {
                                TextField("How are you feeling today?", text: $text, axis: .vertical)
                                    .foregroundColor(.white)
                                    .lineLimit(1...4)
                                    .submitLabel(.send)
                                    .onSubmit { addEntry() }
                                
                                if !text.isEmpty {
                                    Button { addEntry() } label: {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black)
                }
            }
        }
        .navigationTitle("Daily Journal")
        .navigationBarTitleDisplayMode(.inline)
        .padding(.bottom, 100)
        .confirmationDialog("Select Your Mood", isPresented: $showingMoodPicker) {
            ForEach(Mood.allCases, id: \.self) { mood in
                Button(mood.rawValue) { selectedMood = mood }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Rename entry", isPresented: $showRenameAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Save") { applyRename() }
            TextField("New title", text: $renamingText)
        }
        .sheet(isPresented: $showShareSheet) { ShareSheet(items: sharingItems) }
    }
    
    private func addEntry() {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        entries.insert(.init(id: UUID(), text: t, date: Date(), mood: selectedMood), at: 0)
        text = ""
        selectedMood = .neutral
        JournalStorage.save(entries)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func toggleRecording() {
        if isRecording {
            audioRecorder.stopRecording()
            isRecording = false
            if let url = audioRecorder.lastFileURL {
                let ve = VoiceEntry(id: UUID(), title: "Voice memo", url: url, date: Date())
                voiceEntries.insert(ve, at: 0)
                VoiceStorage.save(voiceEntries)
            }
        } else {
            audioRecorder.startRecording()
            isRecording = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
    
    private func applyRename() {
        if let id = entryToRename, let idx = voiceEntries.firstIndex(where: { $0.id == id }) {
            voiceEntries[idx].title = renamingText
            VoiceStorage.save(voiceEntries)
        }
        entryToRename = nil
        renamingText = ""
    }
    
    private func playVoice(_ v: VoiceEntry) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: v.url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Audio play error: \(error)")
        }
    }
    private func beginRenameVoice(_ v: VoiceEntry) {
        entryToRename = v.id
        renamingText = v.title
        showRenameAlert = true
    }
    private func shareVoice(_ v: VoiceEntry) {
        sharingItems = [v.url]
        showShareSheet = true
    }
    private func deleteVoice(_ v: VoiceEntry) {
        do { try FileManager.default.removeItem(at: v.url) } catch { }
        voiceEntries.removeAll { $0.id == v.id }
        VoiceStorage.save(voiceEntries)
    }
}

// MARK: - New Journal Components
struct JournalBubble: View {
    let entry: JournalEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: entry.mood.icon)
                        .foregroundColor(entry.mood.color)
                        .font(.caption)
                    Text(entry.mood.rawValue)
                        .font(.caption.weight(.medium))
                        .foregroundColor(entry.mood.color)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(entry.mood.color.opacity(0.2), in: Capsule())
                
                Spacer()
                
                Text(Self.fmt(entry.date))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Text(entry.text)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .padding(.horizontal, 16)
    }
    
    static func fmt(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f.string(from: date)
    }
}

struct MoodInsightsChart: View {
    let entries: [JournalEntry]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mood Trends")
                .font(.headline)
                .foregroundColor(.white)
            
            // Simple mood trend chart
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(last7DaysMoods, id: \.day) { dayMood in
                    VStack(spacing: 4) {
                        Rectangle()
                            .fill(dayMood.mood.color)
                            .frame(width: 20, height: CGFloat(dayMood.mood.rawValue.count) * 8)
                            .cornerRadius(4)
                        
                        Text(dayMood.day)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(height: 60)
        }
        .padding(.horizontal, 20)
    }
    
    private var last7DaysMoods: [(day: String, mood: Mood)] {
        let calendar = Calendar.current
        let today = Date()
        
        return (0..<7).compactMap { daysAgo in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return nil }
            let dayEntries = entries.filter { calendar.isDate($0.date, inSameDayAs: date) }
            let mostCommonMood = dayEntries.isEmpty ? Mood.neutral : 
                Dictionary(grouping: dayEntries, by: { $0.mood })
                    .max(by: { $0.value.count < $1.value.count })?.key ?? .neutral
            
            let formatter = DateFormatter()
            formatter.dateFormat = "E"
            return (day: formatter.string(from: date), mood: mostCommonMood)
        }.reversed()
    }
}

struct MoodInsightsView: View {
    let entries: [JournalEntry]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Mood distribution
                VStack(alignment: .leading, spacing: 12) {
                    Text("Mood Distribution")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    ForEach(Mood.allCases, id: \.self) { mood in
                        MoodDistributionRow(mood: mood, entries: entries)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Recent patterns
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Patterns")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("You've been feeling \(mostCommonMood.rawValue) lately")
                        .foregroundColor(.gray)
                    
                    Text("Keep up the great work! Your mood tracking helps you understand your emotional patterns.")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(.horizontal, 16)
        }
    }
    
    private var mostCommonMood: Mood {
        guard !entries.isEmpty else { return .neutral }
        return Dictionary(grouping: entries, by: { $0.mood })
            .max(by: { $0.value.count < $1.value.count })?.key ?? .neutral
    }
}

struct MoodDistributionRow: View {
    let mood: Mood
    let entries: [JournalEntry]
    
    private var count: Int {
        entries.filter { $0.mood == mood }.count
    }
    
    private var percentage: Double {
        entries.isEmpty ? 0 : Double(count) / Double(entries.count) * 100
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: mood.icon)
                    .foregroundColor(mood.color)
                    .frame(width: 20)
                
                Text(mood.rawValue)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(count) (\(String(format: "%.1f", percentage))%)")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            
            ProgressView(value: percentage, total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: mood.color))
        }
    }
}

// MARK: - Voice journal models & storage and row
struct VoiceEntry: Identifiable, Codable {
    var id: UUID
    var title: String
    var url: URL
    var date: Date
}

enum VoiceStorage {
    private static let key = "journal.voice.entries"
    static func load() -> [VoiceEntry] {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([VoiceEntry].self, from: data) { return decoded }
        return []
    }
    static func save(_ arr: [VoiceEntry]) {
        if let data = try? JSONEncoder().encode(arr) { UserDefaults.standard.set(data, forKey: key) }
    }
}

struct VoiceRow: View {
    let entry: VoiceEntry
    var onPlay: () -> Void
    var onRename: () -> Void
    var onShare: () -> Void
    var onDelete: () -> Void
    var body: some View {
        HStack {
            Image(systemName: "waveform")
                .foregroundColor(.orange)
            VStack(alignment: .leading) {
                Text(entry.title).foregroundColor(.white)
                Text(JournalEntryRow.fmt(entry.date))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
            Button(action: onPlay) { Image(systemName: "play.circle.fill").foregroundColor(.orange) }
            Button(action: onRename) { Image(systemName: "pencil").foregroundColor(.orange) }
            Button(action: onShare) { Image(systemName: "square.and.arrow.up").foregroundColor(.orange) }
            Button(role: .destructive, action: onDelete) { Image(systemName: "trash").foregroundColor(.red) }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.12)))
    }
}

// MARK: - Audio Recorder with AVFoundation
final class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private let session = AVAudioSession.sharedInstance()
    @Published var lastFileURL: URL?
    
    func startRecording() {
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let url = docs.appendingPathComponent("recording-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.delegate = self
            recorder?.record()
        } catch {
            print("Recorder error: \(error)")
        }
    }
    
    func stopRecording() {
        recorder?.stop()
        lastFileURL = recorder?.url
        recorder = nil
        do { try session.setActive(false) } catch {}
    }
}

struct JournalEntryRow: View {
    let entry: JournalEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: entry.mood.icon)
                        .foregroundColor(entry.mood.color)
                        .font(.caption)
                    Text(entry.mood.rawValue)
                        .font(.caption.weight(.medium))
                        .foregroundColor(entry.mood.color)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(entry.mood.color.opacity(0.1), in: Capsule())
                
                Spacer()
                
                Text(Self.fmt(entry.date))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(entry.text)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }

    static func fmt(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f.string(from: d)
    }
}

enum Mood: String, CaseIterable, Codable {
    case happy = "Happy"
    case sad = "Sad"
    case anxious = "Anxious"
    case calm = "Calm"
    case excited = "Excited"
    case neutral = "Neutral"
    case angry = "Angry"
    case grateful = "Grateful"
    
    var icon: String {
        switch self {
        case .happy: return "face.smiling"
        case .sad: return "face.dashed"
        case .anxious: return "face.dashed.fill"
        case .calm: return "leaf"
        case .excited: return "star.fill"
        case .neutral: return "minus.circle"
        case .angry: return "flame"
        case .grateful: return "heart.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .happy: return .yellow
        case .sad: return .blue
        case .anxious: return .orange
        case .calm: return .green
        case .excited: return .purple
        case .neutral: return .gray
        case .angry: return .red
        case .grateful: return .pink
        }
    }
}

struct JournalEntry: Identifiable, Codable {
    let id: UUID
    let text: String
    let date: Date
    let mood: Mood
    
    init(id: UUID, text: String, date: Date, mood: Mood = .neutral) {
        self.id = id
        self.text = text
        self.date = date
        self.mood = mood
    }
}
enum JournalStorage {
    static let key = "journal.entries"
    static func load() -> [JournalEntry] {
        if let data = UserDefaults.standard.data(forKey: key),
           let arr = try? JSONDecoder().decode([JournalEntry].self, from: data) { return arr }
        return []
    }
    static func save(_ arr: [JournalEntry]) {
        if let data = try? JSONEncoder().encode(arr) { UserDefaults.standard.set(data, forKey: key) }
    }
}

// MARK: - Community Persistence
enum CommunityStorage {
    private static let key = "community.posts"
    static func load() -> [String] {
        if let data = UserDefaults.standard.data(forKey: key),
           let arr = try? JSONDecoder().decode([String].self, from: data) {
            return arr
        }
        return [
            "Stay strong, you’re not alone.",
            "Therapy helped a lot."
        ]
    }
    static func save(_ arr: [String]) {
        if let data = try? JSONEncoder().encode(arr) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

import SwiftUI
import Photos
import AVFoundation

// MARK: - Video Capture Button (ONLY ONE - FIXED)
struct VideoCaptureButton: View {
    @State private var showRecorder = false
    
    var body: some View {
        Button {
            showRecorder = true
        } label: {
            Image(systemName: "camera.fill")
                .font(.title2)
                .foregroundColor(.red)
                .padding(10)
                .background(.ultraThinMaterial, in: Circle())
        }
        .fullScreenCover(isPresented: $showRecorder) {
            VideoRecorderSheet()
        }
    }
}

struct VideoRecorderSheet: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.movie", "public.image"]
        picker.videoQuality = .typeHigh
        picker.videoMaximumDuration = 300 // 5 minutes
        picker.cameraCaptureMode = .video
        picker.allowsEditing = false
        
        // Fix the UI issues
        picker.cameraOverlayView = createOverlayView()
        picker.showsCameraControls = true
        picker.cameraViewTransform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }
    
    // Create a simple overlay to fix UI
    private func createOverlayView() -> UIView {
        let overlayView = UIView()
        overlayView.backgroundColor = .clear
        
        // Add a subtle gradient at top to fix flash button visibility
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(0.3).cgColor,
            UIColor.clear.cgColor
        ]
        gradientLayer.locations = [0.0, 0.3]
        gradientLayer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 120)
        
        let gradientView = UIView()
        gradientView.layer.addSublayer(gradientLayer)
        gradientView.frame = gradientLayer.frame
        
        overlayView.addSubview(gradientView)
        
        return overlayView
    }
    
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let dismiss: DismissAction
        
        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            
            // Handle video
            if let videoURL = info[.mediaURL] as? URL {
                print("📹 Video recorded")
                saveVideo(url: videoURL)
                
            }
            // Handle photo
            else if let image = info[.originalImage] as? UIImage {
                print("📸 Photo captured")
                savePhoto(image: image)
            }
            
            dismiss()
        }
        
        private func saveVideo(url: URL) {
            // Save to Photos
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                guard status == .authorized || status == .limited else { return }
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            print("✅ Video saved to Photos")
                            // Auto-upload to Google Drive
                            GoogleDriveManager.shared.autoUploadVideo(videoURL: url)
                            
                            // Show manual upload options if auto-upload fails or is disabled
                            if !GoogleDriveManager.shared.isSignedIn || !UserDefaults.standard.bool(forKey: "autoUploadEnabled") {
                                GoogleDriveManager.shared.pendingVideoURL = url
                                GoogleDriveManager.shared.showUploadOptions = true
                            }

                        } else if let error = error {
                            print("❌ Video save error: \(error)")
                        }
                    }
                }
            }
            
            // Save to Documents
            saveToDocuments(url: url, isVideo: true)
        }
        
        private func savePhoto(image: UIImage) {
            // Save to Photos
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                guard status == .authorized || status == .limited else { return }
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            print("✅ Photo saved to Photos")
                        } else if let error = error {
                            print("❌ Photo save error: \(error)")
                        }
                    }
                }
            }
            
            // Save to Documents
            if let data = image.jpegData(compressionQuality: 0.8) {
                saveImageToDocuments(data: data)
            }
        }
        
        private func saveToDocuments(url: URL, isVideo: Bool) {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let fileName = "evidence_\(formatter.string(from: Date())).\(isVideo ? "mov" : "jpg")"
            let destinationURL = documentsPath.appendingPathComponent(fileName)
            
            do {
                try FileManager.default.copyItem(at: url, to: destinationURL)
                print("✅ \(isVideo ? "Video" : "Photo") saved to Documents: \(destinationURL)")
            } catch {
                print("❌ Save error: \(error)")
            }
        }
        
        private func saveImageToDocuments(data: Data) {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let fileName = "evidence_\(formatter.string(from: Date())).jpg"
            let destinationURL = documentsPath.appendingPathComponent(fileName)
            
            do {
                try data.write(to: destinationURL)
                print("✅ Photo saved to Documents: \(destinationURL)")
            } catch {
                print("❌ Photo save error: \(error)")
            }
        }
    }
}


// MARK: - Relaxing Audio
// Audio player with categories and progress tracking
struct RelaxingAudioView: View {
    @ObservedObject private var player = AudioPlayer.shared
    @State private var selectedCategory: AudioCategory = .all
    
    private let tracks: [RelaxTrack] = RelaxingAudioView.createTracks()
    
    var filteredTracks: [RelaxTrack] {
        if selectedCategory == .all {
            return tracks
        }
        return tracks.filter { $0.category == selectedCategory }
    }
    
    static func createTracks() -> [RelaxTrack] {
        return [
            RelaxTrack(name: "Ocean Waves", description: "Gentle waves for deep relaxation", file: "waves", ext: "mp3", duration: "10:00", category: .nature, color: .blue),
            RelaxTrack(name: "Rain Sounds", description: "Peaceful rain for focus", file: "rain", ext: "mp3", duration: "15:00", category: .nature, color: .indigo),
            RelaxTrack(name: "Forest Ambience", description: "Birds and nature sounds", file: "birds", ext: "mp3", duration: "20:00", category: .nature, color: .green),
            RelaxTrack(name: "Night Calm", description: "Peaceful night sounds for relaxation", file: "night", ext: "mp3", duration: "30:00", category: .focus, color: .purple),
            RelaxTrack(name: "Piano Melodies", description: "Soft instrumental music", file: "piano", ext: "mp3", duration: "12:00", category: .music, color: .orange)
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            categoryPicker
            nowPlayingBar
            tracksList
        }
        .navigationTitle("Relaxing Audio")
        .padding(.bottom, 100) // Add space for custom tab bar
    }
    
    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(AudioCategory.allCases, id: \.self) { category in
                    categoryButton(for: category)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
    
    private func categoryButton(for category: AudioCategory) -> some View {
        Button {
            selectedCategory = category
        } label: {
            Text(category.rawValue)
                .font(.caption.weight(.medium))
                .foregroundColor(selectedCategory == category ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                                .background(
                                    selectedCategory == category ? 
                                    AnyShapeStyle(.indigo.gradient) : 
                                    AnyShapeStyle(.ultraThinMaterial),
                                    in: Capsule()
                                )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var nowPlayingBar: some View {
        if player.isPlaying, let currentTrack = tracks.first(where: { $0.file == player.current }) {
            VStack(spacing: 8) {
            HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Now Playing")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                        Text(currentTrack.name)
                            .font(.subheadline.weight(.semibold))
                }
                Spacer()
                    Button {
                        player.toggle(file: currentTrack.file, ext: currentTrack.ext)
                    } label: {
                        Image(systemName: "pause.circle.fill")
                            .font(.title2)
                            .foregroundColor(.indigo)
                    }
                }
                
                ProgressView(value: player.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .indigo))
            }
            .padding()
            .background(.ultraThinMaterial)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(.separator),
                alignment: .bottom
            )
        }
    }
    
    private var tracksList: some View {
        List(filteredTracks) { track in
            AudioTrackRow(track: track, player: player)
        }
        .listStyle(.plain)
    }
}

struct AudioTrackRow: View {
    let track: RelaxTrack
    @ObservedObject var player: AudioPlayer
    
    var isPlaying: Bool {
        player.isPlaying && player.current == track.file
    }
    
    var body: some View {
        HStack(spacing: 16) {
            trackIcon
            trackInfo
            Spacer()
            playButton
        }
        .padding(.vertical, 8)
        .background(backgroundView)
    }
    
    private var trackIcon: some View {
        ZStack {
            Circle()
                .fill(track.color.gradient)
                .frame(width: 50, height: 50)
            
            Image(systemName: track.category.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
        }
    }
    
    private var trackInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(track.name)
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            Text(track.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack(spacing: 8) {
                Text(track.duration)
                    .font(.caption.weight(.medium))
                    .foregroundColor(track.color)
                
                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(track.category.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var playButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            player.toggle(file: track.file, ext: track.ext)
        } label: {
            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.title)
                .foregroundColor(track.color)
                .scaleEffect(isPlaying ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isPlaying)
        }
        .buttonStyle(.plain)
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isPlaying ? track.color.opacity(0.05) : Color.clear)
    }
}

enum AudioCategory: String, CaseIterable {
    case all = "All"
    case nature = "Nature"
    case meditation = "Meditation"
    case music = "Music"
    case focus = "Focus"
    
    var icon: String {
        switch self {
        case .all: return "music.note.list"
        case .nature: return "leaf"
        case .meditation: return "brain.head.profile"
        case .music: return "music.note"
        case .focus: return "target"
        }
    }
}

struct RelaxTrack: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let file: String
    let ext: String
    let duration: String
    let category: AudioCategory
    let color: Color
}
final class AudioPlayer: ObservableObject {
    static let shared = AudioPlayer()
    @Published var isPlaying = false
    @Published var current: String? = nil
    @Published var progress: Double = 0.0
    private var player: AVAudioPlayer?
    private var timer: Timer?

    func toggle(file: String, ext: String) {
        if isPlaying, current == file { 
            player?.pause()
            isPlaying = false
            timer?.invalidate()
            return 
        }
        
        // Try to load from Assets.xcassets first (as dataset)
        var url: URL?
        
        // First try: Load from Assets.xcassets as dataset
        if let asset = NSDataAsset(name: file) {
            // Create a temporary file from the asset data
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(file).\(ext)")
            do {
                try asset.data.write(to: tempURL)
                url = tempURL
                print("✅ Found audio file in Assets: \(file)")
            } catch {
                print("❌ Error writing asset to temp file: \(error)")
            }
        }
        
        // Second try: Load from main bundle (if not in Assets)
        if url == nil {
            url = Bundle.main.url(forResource: file, withExtension: ext)
            if url != nil {
                print("✅ Found audio file in bundle: \(file)")
            }
        }
        
        guard let audioURL = url else { 
            print("❌ Audio file not found: \(file).\(ext)")
            print("Available files in bundle:")
            if let resourcePath = Bundle.main.resourcePath {
                let fileManager = FileManager.default
                do {
                    let files = try fileManager.contentsOfDirectory(atPath: resourcePath)
                    let audioFiles = files.filter { $0.hasSuffix(".mp3") }
                    print("MP3 files found: \(audioFiles)")
                } catch {
                    print("Error reading bundle contents: \(error)")
                }
            }
            return 
        }
        
        print("🎵 Loading audio from: \(audioURL)")
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            player = try AVAudioPlayer(contentsOf: audioURL)
            player?.prepareToPlay()
            current = file
            player?.play()
            isPlaying = true
            
            print("🎵 Playing: \(file)")
            
            // Start progress tracking
            startProgressTimer()
        } catch {
            print("❌ Audio error: \(error.localizedDescription)")
        }
    }
    
    private func startProgressTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let player = self.player else { return }
            self.progress = player.currentTime / player.duration
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}

// MARK: - Latest News
// News articles with categories and real content
struct LatestNewsView: View {
    @StateObject private var vm = NewsVM()
    @State private var selectedCategory: NewsCategory = .all
    
    var body: some View {
        VStack(spacing: 0) {
            // Category picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(NewsCategory.allCases, id: \.self) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            Text(category.rawValue)
                                .font(.caption.weight(.medium))
                                .foregroundColor(selectedCategory == category ? .white : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    selectedCategory == category ? 
                                    AnyShapeStyle(.blue.gradient) : 
                                    AnyShapeStyle(.ultraThinMaterial),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            
            if vm.loading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading latest news...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(vm.filteredItems(for: selectedCategory)) { article in
                    NewsArticleRow(article: article)
                }
                .listStyle(.plain)
                .refreshable {
                    await vm.load()
                }
            }
        }
        .navigationTitle("Latest News")
        .padding(.bottom, 100) // Add space for custom tab bar
        .task { await vm.load() }
    }
}

struct NewsArticleRow: View {
    let article: Article
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // Article image
                Image(article.imageURL)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 6) {
                    // Category badge
                    Text(article.category.rawValue)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(article.category.color, in: Capsule())
                    
                    // Title
                    Text(article.title)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    // Source and time
                    HStack {
                        Text(article.source)
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(article.timeAgo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Summary
            if !article.summary.isEmpty {
                Text(article.summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            // Open article in Safari or detail view
            if let url = URL(string: article.url) {
                UIApplication.shared.open(url)
            }
        }
    }
}

enum NewsCategory: String, CaseIterable {
    case all = "All"
    case safety = "Safety"
    case health = "Health"
    case legal = "Legal"
    case community = "Community"
    case technology = "Technology"
    
    var color: Color {
        switch self {
        case .all: return .blue
        case .safety: return .red
        case .health: return .green
        case .legal: return .purple
        case .community: return .orange
        case .technology: return .indigo
        }
    }
}

@MainActor
final class NewsVM: ObservableObject {
    @Published var items: [Article] = []
    @Published var loading = false

    func load() async {
        loading = true
        defer { loading = false }
        
        // Simulate loading with realistic news articles
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        items = [
            Article(
                id: UUID(),
                title: "Domestic Violence Has No Gender: Why Husbands Need Legal Protection Too",
                summary: "This article discusses the need for gender-neutral domestic violence laws in India, arguing that the current framework leaves male victims without adequate legal protection.",
                source: "The New Indian Express",
                category: .legal,
                imageURL: "news1",
                url: "https://www.newindianexpress.com/web-only/2025/Jan/23/domestic-violence-has-no-gender-why-husbands-need-legal-protection-too",
                publishedAt: Date().addingTimeInterval(-3600)
            ),
            Article(
                id: UUID(),
                title: "Cruelty Against Husband In India: A Socio-Legal Analysis",
                summary: "This socio-legal analysis delves into the mental torment and cruelty faced by husbands, referencing false accusations and the resulting psychological impact, which aligns with the theme of mental health being affected by matrimonial discord.",
                source: "ResearchGate",
                category: .health,
                imageURL: "news2",
                url: "https://www.researchgate.net/publication/382211557_Cruelty_Against_Husband_In_India_A_Socio-Legal_Analysis",
                publishedAt: Date().addingTimeInterval(-7200)
            ),
            Article(
                id: UUID(),
                title: "Classic Case of Misuse: Delhi Court Sets Aside Conviction in Domestic Cruelty Case",
                summary: "This recent news report from The Times of India details a specific court case where a judge explicitly called it a 'classic example of misuse of Sec 498A of IPC,' reflecting the ongoing review and scrutiny of this law.",
                source: "Times of India",
                category: .legal,
                imageURL: "news3",
                url: "https://timesofindia.indiatimes.com/city/delhi/classic-case-of-misuse-delhi-court-sets-aside-conviction-in-domestic-cruelty-case-flags-contradictions/articleshow/123689406.cms",
                publishedAt: Date().addingTimeInterval(-10800)
            ),
            Article(
                id: UUID(),
                title: "Men Welfare Trust: Supporting Men's Rights and Legal Aid",
                summary: "The Men Welfare Trust is a prominent organization in India that runs one of the largest helplines (SIF ONE Helpline: 8882 498 498) and provides support for men facing matrimonial and legal issues.",
                source: "Men Welfare Trust",
                category: .community,
                imageURL: "news4",
                url: "https://www.menwelfare.in/",
                publishedAt: Date().addingTimeInterval(-14400)
            ),
            Article(
                id: UUID(),
                title: "Men Too Are Entitled to Same Protection: Delhi High Court Ruling",
                summary: "This article reports on a Delhi High Court ruling that explicitly acknowledges male victimization, stating that courts must have a gender-neutral approach and that stereotypes of men not being victims of domestic violence are flawed.",
                source: "Men Welfare Trust",
                category: .legal,
                imageURL: "news5",
                url: "https://www.menwelfare.in/judgements/men-too-are-entitled-to-same-protection-from-cruelty-and-violence-as-women-delhi-high-court/",
                publishedAt: Date().addingTimeInterval(-18000)
            )
        ]
    }
    
    func filteredItems(for category: NewsCategory) -> [Article] {
        if category == .all {
            return items
        }
        return items.filter { $0.category == category }
    }
}

struct Article: Identifiable {
    let id: UUID
    let title: String
    let summary: String
    let source: String
    let category: NewsCategory
    let imageURL: String
    let url: String
    let publishedAt: Date
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: publishedAt, relativeTo: Date())
    }
}

// MARK: - Daily Challenges
// Habit tracking with points and progress system
struct DailyChallengesView: View {
    @State private var tasks: [Challenge] = ChallengeStorage.loadDefault()
    
    @State private var showingAddChallenge = false
    @State private var streak = 3
    @State private var totalPoints = 45

    var completedTasks: Int {
        tasks.filter { $0.done }.count
    }
    
    var progressPercentage: Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(completedTasks) / Double(tasks.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress header
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Daily Progress")
                            .font(.headline.weight(.semibold))
                        Text("\(completedTasks) of \(tasks.count) completed")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(totalPoints)")
                            .font(.title.bold())
                            .foregroundColor(.green)
                        Text("Points")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Progress bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(Int(progressPercentage * 100))% Complete")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("🔥 \(streak) day streak")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.orange)
                    }
                    
                    ProgressView(value: progressPercentage)
                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                        .scaleEffect(x: 1, y: 1.5, anchor: .center)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            
            // Challenges list
            List {
                ForEach($tasks) { $task in
                    ChallengeRow(task: $task, onToggle: {
                        if task.done {
                            totalPoints += task.points
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } else {
                            totalPoints -= task.points
                        }
                    })
                }
                .onDelete { indexSet in
                    tasks.remove(atOffsets: indexSet)
                }
                
            Section {
                Button {
                        showingAddChallenge = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Add Custom Challenge")
                                .font(.subheadline.weight(.medium))
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle("Daily Challenges")
        .padding(.bottom, 100) // Add space for custom tab bar
        .onChange(of: tasks) {
            ChallengeStorage.save(tasks)
        }
        .sheet(isPresented: $showingAddChallenge) {
            AddChallengeSheet { newChallenge in
                tasks.append(newChallenge)
            }
        }
    }
}

struct ChallengeRow: View {
    @Binding var task: Challenge
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            categoryIcon
            taskContent
            Spacer()
            toggleButton
        }
        .padding(.vertical, 4)
        .background(backgroundView)
    }
    
    private var categoryIcon: some View {
        ZStack {
            Circle()
                .fill(task.category.color.opacity(0.2))
                .frame(width: 40, height: 40)
            
            Image(systemName: task.category.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(task.category.color)
        }
    }
    
    private var taskContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.title)
                .font(.headline.weight(.medium))
                .foregroundColor(.primary)
                .strikethrough(task.done)
            
            Text(task.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Text(task.category.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundColor(task.category.color)
                
                Spacer()
                
                Text("\(task.points) pts")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.green)
            }
        }
    }
    
    private var toggleButton: some View {
        Button {
            task.done.toggle()
            onToggle()
        } label: {
            Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundColor(task.done ? .green : .secondary)
                .scaleEffect(task.done ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: task.done)
        }
        .buttonStyle(.plain)
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(task.done ? .green.opacity(0.05) : Color.clear)
    }
}

struct AddChallengeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var selectedCategory: ChallengeCategory = .mindfulness
    @State private var points = 10
    
    let onAdd: (Challenge) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("Challenge Details") {
                    TextField("Challenge title", text: $title)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ChallengeCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundColor(category.color)
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Points") {
                    Stepper("\(points) points", value: $points, in: 5...50, step: 5)
                }
            }
            .navigationTitle("Add Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let challenge = Challenge(
                            title: title,
                            description: description,
                            done: false,
                            category: selectedCategory,
                            points: points
                        )
                        onAdd(challenge)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

enum ChallengeCategory: String, CaseIterable, Codable {
    case fitness = "Fitness"
    case mindfulness = "Mindfulness"
    case health = "Health"
    case learning = "Learning"
    case digital = "Digital Wellness"
    case social = "Social"
    
    var icon: String {
        switch self {
        case .fitness: return "figure.walk"
        case .mindfulness: return "brain.head.profile"
        case .health: return "heart.fill"
        case .learning: return "book.fill"
        case .digital: return "iphone"
        case .social: return "person.2.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .fitness: return .orange
        case .mindfulness: return .purple
        case .health: return .red
        case .learning: return .blue
        case .digital: return .indigo
        case .social: return .green
        }
    }
}

struct Challenge: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var description: String
    var done: Bool
    var category: ChallengeCategory
    var points: Int
}

enum ChallengeStorage {
    private static let key = "daily.challenges.v1"
    static func loadDefault() -> [Challenge] {
        if let data = UserDefaults.standard.data(forKey: key),
           let arr = try? JSONDecoder().decode([Challenge].self, from: data) {
            return arr
        }
        // Seed defaults once
        let defaults: [Challenge] = [
            .init(title: "10‑minute walk outside", description: "Get some fresh air and light exercise", done: false, category: .fitness, points: 10),
            .init(title: "Write 3 gratitudes", description: "Reflect on positive things in your life", done: false, category: .mindfulness, points: 15),
            .init(title: "2‑minute breathing exercise", description: "Practice deep breathing for relaxation", done: false, category: .mindfulness, points: 5),
            .init(title: "No social media for 30 min", description: "Take a break from digital distractions", done: false, category: .digital, points: 20),
            .init(title: "Drink 8 glasses of water", description: "Stay hydrated throughout the day", done: false, category: .health, points: 10),
            .init(title: "Read for 15 minutes", description: "Expand your knowledge or relax with a book", done: false, category: .learning, points: 15)
        ]
        save(defaults)
        return defaults
    }
    static func save(_ arr: [Challenge]) {
        if let data = try? JSONEncoder().encode(arr) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Safety Center
// Central hub for safety tools and guides
struct SafetyCenterView: View {
    var body: some View {
        List {
            Section("Safety Tools") {
                NavigationLink { DailyJournalView() } label: { Label("Journal", systemImage: "book.closed.fill") }
                NavigationLink { RelaxingAudioView() } label: { Label("Relaxing audio", systemImage: "waveform.and.mic") }
                NavigationLink { DailyChallengesView() } label: { Label("Daily challenges", systemImage: "target") }
            }
            Section("Guides") {
                Label("When to call 100/102", systemImage: "phone.fill")
                Label("Privacy & data use", systemImage: "lock.fill")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Safety Center")
        .padding(.bottom, 100) // Add space for custom tab bar
    }
}

// MARK: - Emergency Contacts
// Emergency contact management and communication
struct EmergencyContactsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var emergencyContacts: [EmergencyContact] = EmergencyContactStorage.load()
    @State private var showingAddContact = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                        Text("Emergency Contacts")
                            .font(.title2.weight(.semibold))
                        Spacer()
                        Button("Done") { dismiss() }
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.blue)
                    }
                    
                    Text("Add trusted contacts for emergency situations")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
                .background(.regularMaterial)
                
                if emergencyContacts.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.orange.opacity(0.6))
                        
                        Text("No Emergency Contacts")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Add trusted contacts who can help you in emergency situations")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        Button {
                            showingAddContact = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add First Contact")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.orange.gradient)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Contacts list
                    List {
                        ForEach(emergencyContacts) { contact in
                            EmergencyContactRow(contact: contact) {
                                callContact(contact)
                            } onMessage: {
                                messageContact(contact)
                            }
                        }
                        .onDelete { indexSet in
                            emergencyContacts.remove(atOffsets: indexSet)
                            EmergencyContactStorage.save(emergencyContacts)
                        }
                    }
                    .listStyle(.plain)
                }
                
                // Add contact button
                if !emergencyContacts.isEmpty {
                    VStack {
                        Divider()
                        Button {
                            showingAddContact = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Contact")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }
                    .background(.regularMaterial)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingAddContact) {
            AddEmergencyContactSheet { newContact in
                emergencyContacts.append(newContact)
                EmergencyContactStorage.save(emergencyContacts)
            }
        }
    }
    
    private func callContact(_ contact: EmergencyContact) {
        if let url = URL(string: "tel://\(contact.phoneNumber)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func messageContact(_ contact: EmergencyContact) {
        if let url = URL(string: "sms://\(contact.phoneNumber)") {
            UIApplication.shared.open(url)
        }
    }
}

struct EmergencyContactRow: View {
    let contact: EmergencyContact
    let onCall: () -> Void
    let onMessage: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text(contact.name.prefix(1).uppercased())
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.orange)
            }
            
            // Contact info
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name)
                    .font(.headline.weight(.medium))
                    .foregroundColor(.primary)
                
                Text(contact.phoneNumber)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !contact.relationship.isEmpty {
                    Text(contact.relationship)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: onMessage) {
                    Image(systemName: "message.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(.blue.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
                
                Button(action: onCall) {
                    Image(systemName: "phone.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(.green.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
}

struct AddEmergencyContactSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (EmergencyContact) -> Void
    
    @State private var name = ""
    @State private var phoneNumber = ""
    @State private var relationship = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Contact Information") {
                    TextField("Full Name", text: $name)
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    TextField("Relationship (Optional)", text: $relationship)
                }
            }
            .navigationTitle("Add Emergency Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let newContact = EmergencyContact(
                            name: name,
                            phoneNumber: phoneNumber,
                            relationship: relationship
                        )
                        onSave(newContact)
                        dismiss()
                    }
                    .disabled(name.isEmpty || phoneNumber.isEmpty)
                }
            }
        }
    }
}

struct EmergencyContact: Identifiable, Codable {
    let id: UUID
    let name: String
    let phoneNumber: String
    let relationship: String
    
    init(name: String, phoneNumber: String, relationship: String) {
        self.id = UUID()
        self.name = name
        self.phoneNumber = phoneNumber
        self.relationship = relationship
    }
}


enum EmergencyContactStorage {
    static let key = "emergency.contacts"
    
    static func load() -> [EmergencyContact] {
        if let data = UserDefaults.standard.data(forKey: key),
           let contacts = try? JSONDecoder().decode([EmergencyContact].self, from: data) {
            return contacts
        }
        return []
    }
    
    static func save(_ contacts: [EmergencyContact]) {
        if let data = try? JSONEncoder().encode(contacts) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
