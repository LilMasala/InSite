//
//  SiteChangeData.swift
//  InSite
//
//  Created by Anand Parikh on 12/14/23.
//

import Foundation



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

    func updateDaysSinceSiteChange() {
        let currentDate = Date()
        guard let lastUpdate = lastUpdateDate else {
            // If never updated, set current date as the last update date
            lastUpdateDate = currentDate
            return
        }

        let calendar = Calendar.current
        let daysPassed = calendar.dateComponents([.day], from: lastUpdate, to: currentDate).day ?? 0

        if daysPassed > 0 {
            daysSinceSiteChange += daysPassed
            lastUpdateDate = currentDate
        }
    }
}
