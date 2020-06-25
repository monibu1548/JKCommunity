//
//  FeedViewController.swift
//  JKCommunity_Example
//
//  Created by 정진규 on 2020/06/21.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit
import JKCommunity
import RxSwift

class FeedViewController: UIViewController {
    
    let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        
        //JKCommunity.shared.insertPost(title: "첫번째 포스트", content: "안녕하세요 :)").subscribe().disposed(by: disposeBag)
        
        //JKCommunity.shared.insertComment(postID: "r0yXwBRucKI9SOxcorD1", content: "헤헤 본인댓글 3").subscribe().disposed(by: disposeBag)
        
        //JKCommunity.shared.deletePost(postID: "1LbHbVvymA0NKQ4ACzBW").subscribe().disposed(by: disposeBag)
        
        //JKCommunity.shared.getPosts(limit: 20, latestPostID: nil).debug("xxx: ").subscribe().disposed(by: disposeBag)
        
        // JKCommunity.shared.getComments(commentIDs: ["AHubRnk29puR6PCutuqz", "jrhgMRxNhIhHmIC7v1zY", "sLTVIXjXTP1pu0NR5HLN"]).debug("xxx: ").subscribe().disposed(by: disposeBag)
    }
}
