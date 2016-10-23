//
//  HeartRateWorkoutSessionDelegate.swift
//  HeartRateHoge
//
//  Created by Yuta Kase on 2016/10/22.
//  Copyright © 2016年 Yuta Kase. All rights reserved.
//

import Foundation
import HealthKit

class HeartRateWorkoutSessionDelegate : NSObject, HKWorkoutSessionDelegate{
    
    // HealthKitで扱うデータを管理するクラス(データの読み書きにはユーザの許可が必要)
    let healthStore = HKHealthStore()
    // HealthStoreへのクエリ
    var heartRateQuery:HKQuery?
    // 心拍数測定時に実行される関数
    var handler:([HKSample]?) -> Void?
    
    init(_ onReceiveHeartRateHandler : @escaping ([HKSample]?) -> Void) {
        self.handler = onReceiveHeartRateHandler
    }
    
    // WorkoutSessionの状態が変化したときに呼ばれる
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        switch toState {
        case .running:
            // 心拍測定クエリ実行
            self.heartRateQuery = self.createStreamingQuery(date)
            self.healthStore.execute(self.heartRateQuery!)
        case .ended:
            // 心拍測定クエリ停止
            self.healthStore.stop(self.heartRateQuery!)
        default:
            print("Unexpected workout session state \(toState)")
        }
    }
    
    // エラーが発生したときに呼ばれる
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
    }
    
    // クエリ生成
    fileprivate func createStreamingQuery(_ date:Date) -> HKQuery {
        let predicate = HKQuery.predicateForSamples(withStart: date, end: nil, options: HKQueryOptions())
        let heartRateType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!
        let updateHandler = {(query:HKAnchoredObjectQuery, samples:[HKSample]?, deletedObjects:[HKDeletedObject]?, anchor:HKQueryAnchor?, error:Error?) -> Void in
            self.handler(samples)
        }
        let query = HKAnchoredObjectQuery(type: heartRateType, predicate: predicate, anchor: nil, limit: Int(HKObjectQueryNoLimit), resultsHandler: updateHandler)
        query.updateHandler = updateHandler
        
        return query
    }
}
