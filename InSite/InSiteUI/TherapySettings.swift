import SwiftUI
import UIKit

//Hold down on long press


struct DiabeticProfile: Codable, Identifiable {
    var id: String = UUID().uuidString
    var name: String
    var hourRanges: [HourRange] // Assuming HourRange is defined to group hours
}

struct HourRange: Codable, Identifiable {
    var id = UUID()
    var startHour: Int
    var endHour: Int
    var carbRatio: Double
    var basalRate: Double
    var insulinSensitivity: Double
}

class ProfileDataStore {
    private let profilesKey = "profilesData"
    private let activeProfileKey = "activeProfileID"

    func saveProfiles(_ profiles: [DiabeticProfile]) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(profiles) {
            UserDefaults.standard.set(encoded, forKey: profilesKey)
            print("Saving Profiles: \(profiles.count)")
        }

    }

    func loadProfiles() -> [DiabeticProfile] {
        if let savedProfiles = UserDefaults.standard.object(forKey: profilesKey) as? Data {
            let decoder = JSONDecoder()
            if let loadedProfiles = try? decoder.decode([DiabeticProfile].self, from: savedProfiles) {
                print("Loaded profiles: \(loadedProfiles.count)")
                return loadedProfiles
            }

        }

        // Return a default profile if no profiles are saved
        let defaultHourRange = HourRange(startHour: 0, endHour: 23, carbRatio: 1.0, basalRate: 0.1, insulinSensitivity: 50.0)
        let defaultProfile = DiabeticProfile(name: "Default Profile", hourRanges: [defaultHourRange])
        return [defaultProfile]
    }

    func saveActiveProfileID(_ id: String) {
        UserDefaults.standard.set(id, forKey: activeProfileKey)
    }

    func loadActiveProfileID() -> String? {
        UserDefaults.standard.string(forKey: activeProfileKey)
    }

    func clearActiveProfileID() {
        UserDefaults.standard.removeObject(forKey: activeProfileKey)
    }
}

struct TherapySettings: View {
    @State private var profiles = [DiabeticProfile(name: "Profile 1", hourRanges: [])]
    @State private var selectedProfileIndex = 0
    @State private var showingHourRangeSheet = false
    @State private var newProfileName = ""
    @State private var showingAddProfileAlert = false
    
    private let dataStore = ProfileDataStore()
    
    static func hourTo12HourFormat(_ hour: Int) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "ha" // "h" for hour without leading zero, "a" for AM/PM
            guard let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) else { return "" }
            return formatter.string(from: date)
        }

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                Form {
                    Section(header: Text("Profiles")) {
                        List {
                            ForEach(profiles.indices, id: \.self) { index in
                                HStack {
                                    Text(self.profiles[index].name)
                                    if index == selectedProfileIndex {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if self.selectedProfileIndex != index {
                                        self.selectedProfileIndex = index
                                        let profile = self.profiles[index]
                                        self.dataStore.saveActiveProfileID(profile.id)
                                        Task {
                                            try? await TherapySettingsLogManager.shared.logTherapySettingsChange(profile: profile, timestamp: Date())
                                        }
                                    }
                                }
                            }
                            .onDelete(perform: deleteProfile)
                        }
                        
                        Button("Add Profile") {
                            self.newProfileName = "" // Reset before showing
                            self.showingAddProfileAlert = true // Reuse the boolean for showing the modal
                        }
                        .sheet(isPresented: $showingAddProfileAlert) {
                            NavigationView {
                                Form {
                                    TextField("Profile Name", text: $newProfileName)
                                    Button("Add Profile") {
                                        let newProfile = DiabeticProfile(name: self.newProfileName, hourRanges: [])
                                        self.profiles.append(newProfile)
                                        self.dataStore.saveProfiles(self.profiles) // Save after adding
                                        self.newProfileName = "" // Reset for next use
                                        self.showingAddProfileAlert = false // Dismiss the sheet
                                    }
                                    .disabled(newProfileName.trimmingCharacters(in: .whitespaces).isEmpty)
                                }
                                .navigationBarTitle("New Profile", displayMode: .inline)
                                .navigationBarItems(trailing: Button("Cancel") {
                                    self.showingAddProfileAlert = false
                                })
                            }
                        }
                    }
                    
                    Section(header: Text("Hour Ranges")) {
                        ForEach(profiles[selectedProfileIndex].hourRanges, id: \.id) { hourRange in
                            VStack(alignment: .leading) {
                                Text("Start: \(TherapySettings.hourTo12HourFormat(hourRange.startHour)) - End: \(TherapySettings.hourTo12HourFormat(hourRange.endHour))")
                                    .font(.headline)
                                Text("Carb Ratio: \(hourRange.carbRatio, specifier: "%.2f")")
                                Text("Basal Rate: \(hourRange.basalRate, specifier: "%.2f")")
                                Text("Insulin Sensitivity: \(hourRange.insulinSensitivity, specifier: "%.2f")")
                            }
                        }
                        .onDelete(perform: deleteHourRange)
                    }
                    
                    Button("Add Hour Range") {
                        self.showingHourRangeSheet = true
                    }
                }
                .navigationBarTitle("Diabetes Management")
                .sheet(isPresented: $showingHourRangeSheet) {
                    HourRangeView(profile: $profiles[selectedProfileIndex])
                }
                .onChange(of: showingHourRangeSheet) { isPresented in
                    if !isPresented {
                        // Save the profiles when the sheet is dismissed
                        dataStore.saveProfiles(profiles)
                    }
                }
            }
            .onAppear {
                // Load profiles when the view appears
                self.profiles = self.dataStore.loadProfiles()
                if let activeProfileID = self.dataStore.loadActiveProfileID(),
                   let activeIndex = self.profiles.firstIndex(where: { $0.id == activeProfileID }) {
                    self.selectedProfileIndex = activeIndex
                } else {
                    self.selectedProfileIndex = min(self.selectedProfileIndex, max(self.profiles.count - 1, 0))
                    if let firstProfile = self.profiles.first {
                        self.dataStore.saveActiveProfileID(firstProfile.id)
                    } else {
                        self.dataStore.clearActiveProfileID()
                    }
                }
            }
        }
    }

    func deleteHourRange(at offsets: IndexSet) {
        if !profiles.isEmpty && selectedProfileIndex < profiles.count {
            profiles[selectedProfileIndex].hourRanges.remove(atOffsets: offsets)
        }
    }

    func deleteProfile(at offsets: IndexSet) {
        profiles.remove(atOffsets: offsets)
        if profiles.isEmpty {
            selectedProfileIndex = 0 // Reset to default or handle empty state appropriately
            dataStore.clearActiveProfileID()
        } else {
            selectedProfileIndex = min(selectedProfileIndex, profiles.count - 1)
            dataStore.saveActiveProfileID(profiles[selectedProfileIndex].id)
        }
        dataStore.saveProfiles(profiles) // Save after deletion
    }

    
        
}
struct HourRangeView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var profile: DiabeticProfile

    @State private var startHour = 0
    @State private var endHour = 0
    @State private var carbRatio = 1.0
    @State private var basalRate = 0.10
    @State private var insulinSensitivity = 50.0

    // MARK: - Formatters
    private var basalRateFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }
    private var twoDec: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }
    private var zeroDec: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        return f
    }

    // MARK: - Time helpers
    private func hourTo12HourFormat(_ hour: Int) -> String {
        let h = max(0, min(23, hour))
        var comps = DateComponents()
        comps.hour = h
        comps.minute = 0
        let date = Calendar.current.date(from: comps) ?? Date()
        let df = DateFormatter()
        df.dateFormat = "ha"
        return df.string(from: date)
    }

    /// Hours already taken by existing ranges (inclusive of end)
    private var takenHours: Set<Int> {
        var set = Set<Int>()
        for r in profile.hourRanges {
            let s = max(0, min(23, r.startHour))
            let e = max(0, min(23, r.endHour))
            if s <= e {
                for h in s...e { set.insert(h) }
            }
        }
        return set
    }

    /// Valid start hours are any hours not already taken.
    private var availableStarts: [Int] {
        (0...23).filter { !takenHours.contains($0) }
    }

    /// Given a start, valid end hours are the **contiguous free hours** after start (inclusive).
    /// We stop as soon as we hit a taken hour.
    private func availableEnds(from start: Int) -> [Int] {
        guard (0...23).contains(start), !takenHours.contains(start) else { return [] }
        var arr: [Int] = []
        var h = start
        while h <= 23, !takenHours.contains(h) {
            arr.append(h)
            h += 1
        }
        return arr
    }

    private var canSave: Bool {
        guard availableStarts.contains(startHour) else { return false }
        return availableEnds(from: startHour).contains(endHour)
    }

    // MARK: - View
    var body: some View {
        NavigationView {
            Form {
                Section("Time") {
                    if availableStarts.isEmpty {
                        Text("All hours are already covered by existing ranges.")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Start Hour", selection: $startHour) {
                            ForEach(availableStarts, id: \.self) { hour in
                                Text(hourTo12HourFormat(hour)).tag(hour)
                            }
                        }
                        .onChange(of: startHour) { s in
                            // Clamp end to a valid option when start changes
                            let ends = availableEnds(from: s)
                            if let first = ends.first {
                                if !ends.contains(endHour) { endHour = first }
                            } else {
                                endHour = s
                            }
                        }

                        let ends = availableEnds(from: startHour)
                        Picker("End Hour", selection: $endHour) {
                            ForEach(ends, id: \.self) { hour in
                                Text(hourTo12HourFormat(hour)).tag(hour)
                            }
                        }
                    }
                }

                Section("Therapy") {
                    HStack { Text("Carb Ratio"); Spacer()
                        TextField("1.00", value: $carbRatio, formatter: twoDec)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    HStack { Text("Basal Rate"); Spacer()
                        TextField("0.10", value: $basalRate, formatter: basalRateFormatter)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    HStack { Text("Sensitivity"); Spacer()
                        TextField("50", value: $insulinSensitivity, formatter: zeroDec)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
                }
            }
            .navigationBarTitle("Add Hour Range", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addRange() }
                        .disabled(!canSave)
                }
            }
            .onAppear { seedInitialSelection() }
        }
    }

    // MARK: - Actions
    private func seedInitialSelection() {
        if let firstFree = availableStarts.first {
            startHour = firstFree
            endHour = availableEnds(from: firstFree).first ?? firstFree
        } else {
            startHour = 0
            endHour = 0
        }
    }
    
    private func addRange() {
        guard canSave else { return }
        let newHourRange = HourRange(
            startHour: startHour,
            endHour: endHour,
            carbRatio: carbRatio,
            basalRate: basalRate,
            insulinSensitivity: insulinSensitivity
        )
        profile.hourRanges.append(newHourRange)
        // keep them tidy
        profile.hourRanges.sort { lhs, rhs in
            if lhs.startHour == rhs.startHour { return lhs.endHour < rhs.endHour }
            return lhs.startHour < rhs.startHour
        }
        dismiss()
    }
}



struct ContentViewPreviews: PreviewProvider {
    static var previews: some View {
        TherapySettings()
    }
}
