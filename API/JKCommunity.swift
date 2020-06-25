//
//  JKCommunity.swift
//  JKCommunity
//
//  Created by 정진규 on 2020/06/21.
//

import Foundation
import JKFirebaseSDK

public class JKCommunity {
    public static let shared = JKCommunity()
    private init() {}

    private let firestore = FirebaseFirestore.shared
}
