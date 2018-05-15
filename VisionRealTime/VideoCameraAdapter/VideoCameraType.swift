//
//  AppDelegate.swift
//  CoreMLSample
//
//  Created by Kostya on 18.04.2018.
//  Copyright © 2018 K.S. All rights reserved.
//
//  Based on Shuichi Tsutsumi's Code

import AVFoundation


enum CameraType : Int {
    case back
    case front
    
    func captureDevice() -> AVCaptureDevice {
        switch self {
        case .front:
            let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [], mediaType: AVMediaType.video, position: .front).devices
            print("devices:\(devices)")
            for device in devices where device.position == .front {
                return device
            }
        default:
            break
        }
        return AVCaptureDevice.default(for: AVMediaType.video)!
    }
}
