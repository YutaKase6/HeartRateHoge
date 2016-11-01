// //  InterfaceController.swift
//  HeartRateHoge WatchKit Extension
//
//・複数人(=体験者，実際はApple Watchの台数に対応する3人)がApple Watchを付けて，少し静止 (30sec程度)，静止時の脈拍を取得しておく
//・テレビ等に写った動画を見ながら，体験者は運動する．普段は，Apple Watchには心拍数が出ていれば良い．
//・心拍数が(静止時に比べて)10%以上増加したら，その時間を記録し，それから60sec後に，Apple Watchに静止画(提供される予定)と，音と振動を提示し終了
//・以下，体験者を変えて繰り返し．ボタン等の操作で開始で構わない．
//
//  Created by Yuta Kase on 2016/10/19.
//  Copyright © 2016年 Yuta Kase. All rights reserved.
//

import WatchKit
import Foundation
import HealthKit
import UserNotifications


class InterfaceController: WKInterfaceController, UNUserNotificationCenterDelegate{
    
    // 心拍数表示用ラベル
    @IBOutlet var heartRateLabel: WKInterfaceLabel!
    // メッセージ表示用ラベル
    @IBOutlet var messageLabel: WKInterfaceLabel!
    // タイマー表示用ラベル
    @IBOutlet var timerLabel: WKInterfaceLabel!
    // ログを表示するラベル
    @IBOutlet var logLabel: WKInterfaceLabel!
    // 測定開始、終了のボタン
    @IBOutlet var button: WKInterfaceButton!
    
    // HealthKitで扱うデータを管理するクラス(データの読み書きにはユーザの許可が必要)
    let healthStore = HKHealthStore()
    // 取得したいデータの識別子、ここでは心拍数
    let heartRateType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!
    // 取得したデータの単位、ここではBPM
    let heartRateUnit = HKUnit(from: "count/min")
    // workout利用することでスリープになっても心拍数を測定可能
    var workoutSession:HKWorkoutSession?
    
    // 心拍測定フラグ
    var isRunning = false
    // 静止時心拍測定フラグ
    var isRestState = false
    // 体験終了状態フラグ
    var isEndState = false
    // 心拍数保管配列
    var heartRateValues:[Double] = []
    // 体験終了しきい値心拍数(静止時に測定した心拍数の平均値から求める)
    var thresholdHeartRate = 0.0
    
    // タイマーカウント用
    var timeCount = 0
    // 秒数カウント用タイマー
    var timer:Timer!
    
    // 静止秒数
    let restSec = 30
    // 心拍数上昇から体験終了までの秒数
    let endOffsetSec = 60
    // 心拍数上昇判定係数
    let thresholdRate = 1.1
    
    // ログデータ表示用テキスト
    var text = ""
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
        self.initAll()
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        // HealthKitがデバイス上で利用できるか確認
        guard HKHealthStore.isHealthDataAvailable() else {
            print("not available")
            return
        }
        // アクセス許可をユーザに求める
        let dataTypes = Set([self.heartRateType])
        self.healthStore.requestAuthorization(toShare: nil, read: dataTypes) { (success, error) -> Void in
            guard success else {
                print("not allowed healthdata")
                return
            }
        }
        // 通知許可
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { (granted, error) in
            guard granted else {
                print("not allowed notification")
                return
            }
        }
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    // 初期化処理
    fileprivate func initAll() {
        // View関係
        self.button.setTitle("START")
        self.heartRateLabel.setText("---")
        self.messageLabel.setText("push button")
        self.timerLabel.setText("")
        self.logLabel.setText("")
        self.text = ""
        
        // パラメータ関係
        self.timeCount = self.restSec
        self.heartRateValues.removeAll()
        self.isRestState = false
        self.isEndState = false
        self.thresholdHeartRate = 0.0
    }
    
    // START/STOP button
    @IBAction func buttonTapped() {
        if self.isRunning == false {
            self.isRunning = true
            // 心拍測定開始(workout start)
            let configration = HKWorkoutConfiguration()
            configration.activityType = .other
            configration.locationType = .unknown
            do{
                self.workoutSession = try HKWorkoutSession(configuration: configration)
                self.workoutSession!.delegate = HeartRateWorkoutSessionDelegate(self.onReceiveHeartRate)
                self.healthStore.start(self.workoutSession!)
            }
            catch let error as NSError{
                fatalError("\(error.localizedDescription)")
            }
            // 静止状態カウントスタート
            self.isRestState = true
            self.timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.countDownRestTime), userInfo: nil, repeats: true)
            
            self.button.setTitle("STOP")
            self.messageLabel.setText("Measuring...")
        }else if self.isRunning == true {
            self.isRunning = false
            // 心拍測定終了
            self.healthStore.end(self.workoutSession!)
            self.timer.invalidate()
            self.initAll()
        }
    }
    
    // 心拍数取得時に呼ばれる
    fileprivate func onReceiveHeartRate(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample] else {
            return
        }
        guard let quantity = samples.last?.quantity else {
            return
        }
        // 取得心拍数
        let heartRateValue = quantity.doubleValue(for: self.heartRateUnit)
        // 静止状態時は平均心拍数計算のため心拍数を保管
        if self.isRestState {
            self.heartRateValues.append(heartRateValue)
        }
        // 体験終了判定
        if !isRestState && !isEndState {
            let isEnd = heartRateValue > self.thresholdHeartRate
            if isEnd {
                self.isEndState = true
                self.messageLabel.setText("Count down...")
                self.sendNotification()
                DispatchQueue.main.async(execute: {
                    self.timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.countDownRestTime), userInfo: nil, repeats: true)
                })
            }
        }
        self.heartRateLabel.setText("\(Int(heartRateValue))")
        
        
        guard let date = samples.last?.endDate else {
            return
        }
        print("\(Int(heartRateValue))")
        let formatter: DateFormatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        print(formatter.string(from: date))
        text =  "  \(Int(heartRateValue))\n" + text
        text =  formatter.string(from: date) + text
        self.logLabel.setText(self.text)
    }
    
    // タイマー作動時毎秒呼ばれる
    func countDownRestTime() {
        self.timerLabel.setText("\(self.timeCount)")
        
        if self.timeCount == 0 {
            if isRestState {
                // 静止状態終了処理
                // 平均心拍を計算
                let ave = self.calcAve(self.heartRateValues)
                self.thresholdHeartRate = ave * self.thresholdRate
                self.messageLabel.setText("ave=\(ave)\n*\(self.thresholdRate)=\(self.thresholdHeartRate)")
                
                self.isRestState = false
                self.timeCount = self.endOffsetSec
            }else {
                // 体験終了処理
                // 心拍測定終了
                self.healthStore.end(self.workoutSession!)
                self.timer.invalidate()
                self.initAll()
            }
            self.timer.invalidate()
            self.heartRateValues.removeAll()
        }else {
            //カウントダウン
            self.timeCount -= 1
        }
    }
    
    // 通知を送信
    fileprivate func sendNotification() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        let content = UNMutableNotificationContent()
        content.title = NSString.localizedUserNotificationString(forKey: "hoge", arguments: nil)
        content.body = NSString.localizedUserNotificationString(forKey: "hoge", arguments: nil)
        content.sound = UNNotificationSound.default()
        content.categoryIdentifier = "myCategory"
        
        let category = UNNotificationCategory(identifier: "myCategory", actions: [], intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
        
        // 60秒後に通知
        let trigger = UNTimeIntervalNotificationTrigger.init(timeInterval: TimeInterval(self.endOffsetSec), repeats: false)
        let id = String(Date().timeIntervalSinceReferenceDate)
        let request = UNNotificationRequest.init(identifier: id, content: content, trigger: trigger)
        
        center.add(request)
    }
    
    // 通知の閉じる押した時に呼ばれる
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
    // 通知が表示されると呼ばれる
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .sound])
    }
    
    // Arrayの平均値を計算
    fileprivate func calcAve(_ array:[Double]) -> Double{
        let sum = array.reduce(0) { (a, b) -> Double in
            a + b
        }
        return sum / Double(array.count)
    }
}
