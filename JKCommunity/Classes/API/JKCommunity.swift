//
//  JKCommunity.swift
//  JKCommunity
//
//  Created by 정진규 on 2020/06/21.
//

import Foundation
import JKFirebaseSDK
import JKExtension
import RxSwift
import RxCocoa
import RxOptional

public enum JKCommunityError: Error {
    case defaultError
    case readPostError
}

fileprivate enum CommunityKeys: String {
    case user
    case post
    case comment
    
    case createdAt

    var key: String {
        return self.rawValue
    }
}

public class JKCommunity {
    public static let shared = JKCommunity()
    private init() {}

    private let firestore = FirebaseFirestore.shared

    public func insertPost(title: String, content: String) -> Single<Result<DocumentKey, FirestoreError>> {
        let userID = FirebaseAuthentication.shared.currentUser()?.uid ?? "EMPTY"

        let newPost = JKPost(id: "", title: title, content: content, userID: userID, createdAt: Date().toTimestamp(), updatedAt: nil, commentIDs: [])
        return firestore.rx.insert(key: CommunityKeys.post.key, object: newPost, withID: true)
    }
    
    public func updatePost(post: JKPost, title: String? = nil, content: String? = nil) -> Single<Result<Void, FirestoreError>> {
        let updatedPost = JKPost(
            id: post.id,
            title: title ?? post.title,
            content: content ?? post.content,
            userID: post.userID,
            createdAt: post.createdAt,
            updatedAt: Date().toTimestamp(),
            commentIDs: post.commentIDs
        )

        return firestore.rx.update(key: CommunityKeys.post.key, id: post.id, object: updatedPost)
    }

    public func insertComment(postID: String, content: String) -> Single<Result<Void, FirestoreError>> {
        let userID = FirebaseAuthentication.shared.currentUser()?.uid ?? "EMPTY"

        let comment = JKComment(
            id: "",
            postID: postID,
            content: content,
            userID: userID,
            createdAt: Date().toTimestamp(),
            updatedAt: nil
        )

        let commentID = firestore.rx.insert(key: CommunityKeys.comment.key, object: comment, withID: true)
            .asObservable()
            .filterMap { $0.value }
        
        let post = firestore.rx.read(key: CommunityKeys.post.key, id: postID, type: JKPost.self)
            .asObservable()
            .filterMap { $0.value }

        return Observable
            .zip(post, commentID) { post, commentID -> [String] in
                var commentIDs = post.commentIDs
                commentIDs.append(commentID)
                return commentIDs
            }
            .flatMapLatest { [weak self] commentIDs -> Single<Result<Void, FirestoreError>> in
                return (self?.firestore.rx.upsertDocumentField(key: CommunityKeys.post.key, id: postID, data: ["commentIDs": commentIDs]) ?? .just(.failure(.defaultError("error add comment"))))
            }
            .asSingle()
    }

    public func deletePost(postID: String) -> Single<Result<Void, FirestoreError>> {
        let commentIDs = firestore.rx.read(key: CommunityKeys.post.key, id: postID, type: JKPost.self)
            .filterMap { $0.value }
            .map { $0.commentIDs }
            .asObservable()

        let deleteComments = commentIDs
            .map { [weak self] comments -> [Observable<Result<Void, FirestoreError>>] in
                return comments
                    .map { self?.firestore.rx.delete(key: CommunityKeys.comment.key, id: $0).asObservable() }
                    .compactMap { $0 }
            }
            .flatMapLatest { comments -> Observable<Result<Void, FirestoreError>> in
                return Observable.zip(comments).map { _ -> Result<Void, FirestoreError> in
                    return .success(Void())
                }
            }

        let deletePost = firestore.rx.delete(key: CommunityKeys.post.key, id: postID)
            .asObservable()

        return deleteComments.concat(deletePost).asSingle()
    }

    public func deleteComment(commentID: String) -> Single<Result<Void, FirestoreError>> {
        let postID = firestore.rx.read(key: CommunityKeys.comment.key, id: commentID, type: JKComment.self)
            .filterMap { $0.value }
            .map { $0.postID }
            .asObservable()

        let commentRefPost = postID
            .flatMapLatest { [weak self] in
                return (self?.firestore.rx.read(key: CommunityKeys.post.key, id: $0, type: JKPost.self).asObservable()) ?? .just(.failure(.defaultError("error add comment")))
            }
            .filterMap { $0.value }
        
        let deleteCommentRefPost = commentRefPost
            .flatMapLatest { [weak self] post -> Observable<Result<Void, FirestoreError>> in
                let updatedCommentIDs = post.commentIDs.filter { $0 != commentID }
                return (self?.firestore.rx.upsertDocumentField(key: CommunityKeys.post.key, id: post.id, data: ["commentIDs": updatedCommentIDs]).asObservable()) ?? .just(.failure(.defaultError("error delete comment")))
            }
        
        let deleteComment = firestore.rx.delete(key: CommunityKeys.comment.key, id: commentID)

        return deleteCommentRefPost.concat(deleteComment).asSingle()
    }
    
    public func getPosts(limit: Int, latestPostID: String?) -> Single<Result<[JKPost], JKCommunityError>> {
        let postResult = firestore.rx.list(key: CommunityKeys.post.key, orderBy: [QueryOrder(key: CommunityKeys.createdAt.key, isDescending: true)], limit: limit, latestKey: latestPostID, type: JKPost.self)

        let postValue = postResult
            .filterMap { $0.value }
            .map { Result<[JKPost], JKCommunityError>.success($0) }
            .asObservable()

        let postError = postResult
            .filterMap { $0.error }
            .mapVoid()
            .map { Result<[JKPost], JKCommunityError>.failure(.readPostError) }
            .asObservable()

        return Observable
            .merge(postValue, postError)
            .asSingle()
    }
    
    private func primitiveCommentToComment(primitiveComment: JKComment) -> Single<Result<JKComment, FirestoreError>> {
        let userResult = firestore.rx.read(key: CommunityKeys.user.key, id: primitiveComment.userID, type: JKUser.self)

        let userValue = userResult
            .filterMap { $0.value }
            .map { user -> Result<JKComment, FirestoreError> in
                let comment = JKComment(
                    id: primitiveComment.id,
                    postID: primitiveComment.postID,
                    content: primitiveComment.content,
                    userID: primitiveComment.userID,
                    createdAt: primitiveComment.createdAt,
                    updatedAt: primitiveComment.updatedAt
                )
                return .success(comment)
            }
            .asObservable()
        
        let userError = userResult
            .filterMap { $0.error }
            .map { _ -> Result<JKComment, FirestoreError> in
                return .failure(.defaultError("cannot read comment id: \(primitiveComment.id)"))
            }
            .asObservable()
        
        return Observable
            .merge(
                userValue,
                userError
            )
            .asSingle()
    }
    
    public func getComments(commentIDs: [String]) -> Single<Result<[JKComment], FirestoreError>> {
        let commentObservablesResult = commentIDs.map { firestore.rx.read(key: CommunityKeys.comment.key, id: $0, type: JKComment.self).filterMap { $0 }.asObservable() }
        
        return Observable
            .zip(commentObservablesResult)
            .filterMap { $0.compactMap { $0.value } }
            .map { $0.sorted { (lComment, rComment) -> Bool in
                return lComment.createdAt <= rComment.createdAt
            }}
            .map { Result<[JKComment], FirestoreError>.success($0) }
            .catchErrorJustReturn(Result<[JKComment], FirestoreError>.failure(.defaultError("cannot read commnets")))
            .asSingle()
    }
}
