//
//  ViewController.swift
//  HeartRateHoge
//
//  Created by Yuta Kase on 2016/10/19.
//  Copyright © 2016年 Yuta Kase. All rights reserved.
//

import UIKit
import HealthKit
import UserNotifications

class ViewController: UIViewController {
    
    let healthStore = HKHealthStore()
    let heartRateType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // HealthKitがデバイス上で利用できるか確認
        guard HKHealthStore.isHealthDataAvailable() else {
            print("not available")
            return
        }
        
        // アクセス許可をユーザに求める
        let dataTypes = Set([self.heartRateType])
        self.healthStore.requestAuthorization(toShare: nil, read: dataTypes) { (success, error) -> Void in
            guard success else {
                print("not allowed")
                return
            }
        }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { (granted, error) in
            guard granted else {
                print("not allowed notification")
                return
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

