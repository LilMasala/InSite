//
//  HealthStore.swift
//  InSite
//
//  Created by Anand Parikh on 12/19/23.
//

import Foundation
import HealthKit
import SwiftUI
import HealthKitUI

enum HealthStoreError: Error {
    case notAvailable
    case dataUnavailable(String)
}


extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .americanFootball:             return "American Football"
        case .archery:                      return "Archery"
        case .australianFootball:           return "Australian Football"
        case .badminton:                    return "Badminton"
        case .baseball:                     return "Baseball"
        case .basketball:                   return "Basketball"
        case .bowling:                      return "Bowling"
        case .boxing:                       return "Boxing"
        case .climbing:                     return "Climbing"
        case .cricket:                      return "Cricket"
        case .crossTraining:                return "Cross Training"
        case .curling:                      return "Curling"
        case .cycling:                      return "Cycling"
        case .dance:                        return "Dance"
        case .danceInspiredTraining:        return "Dance Inspired Training"
        case .elliptical:                   return "Elliptical"
        case .equestrianSports:             return "Equestrian Sports"
        case .fencing:                      return "Fencing"
        case .fishing:                      return "Fishing"
        case .functionalStrengthTraining:   return "Functional Strength Training"
        case .golf:                         return "Golf"
        case .gymnastics:                   return "Gymnastics"
        case .handball:                     return "Handball"
        case .hiking:                       return "Hiking"
        case .hockey:                       return "Hockey"
        case .hunting:                      return "Hunting"
        case .lacrosse:                     return "Lacrosse"
        case .martialArts:                  return "Martial Arts"
        case .mindAndBody:                  return "Mind and Body"
        case .mixedMetabolicCardioTraining: return "Mixed Metabolic Cardio Training"
        case .paddleSports:                 return "Paddle Sports"
        case .play:                         return "Play"
        case .preparationAndRecovery:       return "Preparation and Recovery"
        case .racquetball:                  return "Racquetball"
        case .rowing:                       return "Rowing"
        case .rugby:                        return "Rugby"
        case .running:                      return "Running"
        case .sailing:                      return "Sailing"
        case .skatingSports:                return "Skating Sports"
        case .snowSports:                   return "Snow Sports"
        case .soccer:                       return "Soccer"
        case .softball:                     return "Softball"
        case .squash:                       return "Squash"
        case .stairClimbing:                return "Stair Climbing"
        case .surfingSports:                return "Surfing Sports"
        case .swimming:                     return "Swimming"
        case .tableTennis:                  return "Table Tennis"
        case .tennis:                       return "Tennis"
        case .trackAndField:                return "Track and Field"
        case .traditionalStrengthTraining:  return "Traditional Strength Training"
        case .volleyball:                   return "Volleyball"
        case .walking:                      return "Walking"
        case .waterFitness:                 return "Water Fitness"
        case .waterPolo:                    return "Water Polo"
        case .waterSports:                  return "Water Sports"
        case .wrestling:                    return "Wrestling"
        case .yoga:                         return "Yoga"

        // - iOS 10

        case .barre:                        return "Barre"
        case .coreTraining:                 return "Core Training"
        case .crossCountrySkiing:           return "Cross Country Skiing"
        case .downhillSkiing:               return "Downhill Skiing"
        case .flexibility:                  return "Flexibility"
        case .highIntensityIntervalTraining:    return "High Intensity Interval Training"
        case .jumpRope:                     return "Jump Rope"
        case .kickboxing:                   return "Kickboxing"
        case .pilates:                      return "Pilates"
        case .snowboarding:                 return "Snowboarding"
        case .stairs:                       return "Stairs"
        case .stepTraining:                 return "Step Training"
        case .wheelchairWalkPace:           return "Wheelchair Walk Pace"
        case .wheelchairRunPace:            return "Wheelchair Run Pace"

        // - iOS 11

        case .taiChi:                       return "Tai Chi"
        case .mixedCardio:                  return "Mixed Cardio"
        case .handCycling:                  return "Hand Cycling"

        // - iOS 13

        case .discSports:                   return "Disc Sports"
        case .fitnessGaming:                return "Fitness Gaming"

        // - iOS 14
        case .cardioDance:                  return "Cardio Dance"
        case .socialDance:                  return "Social Dance"
        case .pickleball:                   return "Pickleball"
        case .cooldown:                     return "Cooldown"

        // - Other
        case .other:                        return "Other"
        case .swimBikeRun:                  return "Swim Bike Run"
            
        case .transition:                   return "Transition"
            
        @unknown default:                   return "Other"
        }
    }
}


class HealthStore {
    
    public var healthStore: HKHealthStore?
    var observerQuery: HKObserverQuery?
    
    let menstrualType = HKObjectType.categoryType(forIdentifier: .menstrualFlow)!
    let bloodGlucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose)!
    let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass)!
    let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
    let restingHeartRateType = HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
    let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    let basalEnergyType = HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!
    let workoutType =  HKObjectType.workoutType()
    let activeEnergyType =  HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
    let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount)!
    let appleExerciseTimeType =  HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!
    let appleMoveTimeType =  HKObjectType.quantityType(forIdentifier: .appleMoveTime)!
    let appleSleepTempType =   HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature)!
 
    
    
    init(){
        if HKHealthStore.isHealthDataAvailable(){
            healthStore = HKHealthStore()
        }
    }
    func requestAuthorization(completion: @escaping (Bool) -> Void){
        
        guard let healthStore = self.healthStore else {return completion(false)}
        
        
        healthStore.requestAuthorization(toShare: [], read: [menstrualType, bloodGlucoseType, bodyMassType, heartRateType, restingHeartRateType, sleepType, basalEnergyType,workoutType, activeEnergyType, stepCountType, appleExerciseTimeType,appleMoveTimeType,appleSleepTempType ]) { (success, error) in
            completion(success)
        
        }
        
        
        
    }
    
    
    
}
