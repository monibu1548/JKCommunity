//
//  JKPost.swift
//  JKCommunity
//
//  Created by 정진규 on 2020/06/21.
//

import Foundation
import JKFirebaseSDK

public struct JKPost: Codable {
    public let id: String
    public let title: String
    public let content: String
    public let userID: String
    public let createdAt: Int
    public let updatedAt: Int?
    public let commentIDs: [String]
    public let imageURLs: [String]
}
