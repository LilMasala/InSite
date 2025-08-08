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
        } else {
            selectedProfileIndex = min(selectedProfileIndex, profiles.count - 1)
        }
        dataStore.saveProfiles(profiles) // Save after deletion
    }

    
        
}

struct HourRangeView: View {
    @Environment(\.presentationMode) var presentationMode
       @Binding var profile: DiabeticProfile
       @State private var startHour = 0
       @State private var endHour = 0
       @State private var carbRatio = 0.0
       @State private var basalRate = 0.0
       @State private var insulinSensitivity = 0.0
    
    
    func hourTo12HourFormat(_ hour: Int) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "ha" // "h" for hour without leading zero, "a" for AM/PM
            let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
            return formatter.string(from: date)
        }
    private var basalRateFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            return formatter
        }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                Form {
                    Section {
                        Picker("Start Hour", selection: $startHour) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(self.hourTo12HourFormat(hour)).tag(hour)
                            }
                        }
                        Picker("End Hour", selection: $endHour) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(self.hourTo12HourFormat(hour)).tag(hour)
                            }
                        }
                    }
                    
                    Section {
                        HStack(spacing: geometry.size.width * 0.02) {
                            Text("Carb Ratio: ")
                            TextField("Carb Ratio", value: $carbRatio, formatter: NumberFormatter())
                        }
                        HStack(spacing: geometry.size.width * 0.02) {
                            Text("Basal Rate: ")
                            TextField("Basal Rate", value: $basalRate, formatter: basalRateFormatter)
                        }
                        HStack(spacing: geometry.size.width * 0.02) {
                            Text("Insulin Sensitivity: ")
                            TextField("Insulin Sensitivity", value: $insulinSensitivity, formatter: NumberFormatter())
                        }
                    }
                    
                    Button("Add Range") {
                        let newHourRange = HourRange(startHour: startHour, endHour: endHour, carbRatio: carbRatio, basalRate: basalRate, insulinSensitivity: insulinSensitivity)
                        profile.hourRanges.append(newHourRange)
                        self.presentationMode.wrappedValue.dismiss() // Dismiss the modal view
                    }
                    .padding(.vertical, geometry.size.height * 0.01)
                }
                .navigationBarTitle("Add Hour Range")
            }
        }
    }
}

struct ContentViewPreviews: PreviewProvider {
    static var previews: some View {
        TherapySettings()
    }
}
