//
//  SiteChangeData.swift
//  InSite
//
//  Created by Anand Parikh on 12/14/23.
//

import Foundation


struct SiteChangeEvent: Codable {
    let timestamp: Date        // server timestamp reflected on read
    let location: String       // consider an enum later
    let localTzId: String
}


class SiteChangeData: ObservableObject {
    static let shared = SiteChangeData()

    @Published var daysSinceSiteChange: Int = 0
    @Published var siteChangeLocation: String = "Not selected"

    private let lastUpdateKey = "LastSiteChangeUpdateDate"
    private var lastUpdateDate: Date? {
        get {
            UserDefaults.standard.object(forKey: lastUpdateKey) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: lastUpdateKey)
        }
    }

    private init() {
        updateDaysSinceSiteChange()
    }

//    func updateDaysSinceSiteChange() {
//        let currentDate = Date()
//        guard let lastUpdate = lastUpdateDate else {
//            // If never updated, set current date as the last update date
//            lastUpdateDate = currentDate
//            return
//        }
//
//        let calendar = Calendar.current
//        let daysPassed = calendar.dateComponents([.day], from: lastUpdate, to: currentDate).day ?? 0
//
//        if daysPassed > 0 {
//            daysSinceSiteChange += daysPassed
//            lastUpdateDate = currentDate
//        }
//    }
}



extension SiteChangeData {
    private var lastChangeDateKey: String { "LastSiteChangeDate" }
    private var lastLocationKey: String { "LastSiteChangeLocation" }

    var lastChangeDate: Date? {
        get { UserDefaults.standard.object(forKey: lastChangeDateKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastChangeDateKey) }
    }

    func setSiteChange(location: String) {
        self.siteChangeLocation = location
        self.daysSinceSiteChange = 0
        self.lastChangeDate = Date()
    }

    func updateDaysSinceSiteChange() {
        // compute from lastChangeDate -> today, no incremental drift
        guard let last = lastChangeDate else { return }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: last),
                                                   to: Calendar.current.startOfDay(for: Date())).day ?? 0
        self.daysSinceSiteChange = max(0, days)
    }
}
